import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../models/app_settings.dart';
import '../../../../models/custom_list.dart';

/// TodoRepositoryインターフェース
/// 
/// データアクセス層の抽象化。
/// TodosProviderから呼び出され、実装はInfrastructure層（TodoRepositoryImpl）で行う。
/// 
/// 責務:
/// - ローカルストレージへのアクセス（永続化）
/// - Nostrリレーとの同期（リモート）
/// - データの取得・保存・削除
/// 
/// Phase C: 個人Todo同期のみ実装
/// Phase D: グループTodo同期（MLS）を追加
abstract class TodoRepository {
  // ============================================================
  // ローカルストレージ操作
  // ============================================================
  
  /// ローカルストレージから全Todoを読み込み
  Future<Either<Failure, List<Todo>>> loadTodosFromLocal();
  
  /// ローカルストレージに全Todoを保存
  Future<Either<Failure, void>> saveTodosToLocal(List<Todo> todos);
  
  /// ローカルストレージに単一Todoを保存
  Future<Either<Failure, void>> saveTodoToLocal(Todo todo);
  
  /// ローカルストレージから単一Todoを削除
  Future<Either<Failure, void>> deleteTodoFromLocal(String id);
  
  // ============================================================
  // Nostr同期操作（個人Todo）
  // ============================================================
  
  /// Nostrから個人Todoを同期取得（Kind 30001）
  /// 
  /// 返り値:
  /// - Right<SyncResult>: 同期結果（Todos、AppSettings、CustomLists）
  /// - Left<Failure>: 同期エラー
  Future<Either<Failure, PersonalTodoSyncResult>> syncPersonalTodosFromNostr();
  
  /// Nostrへ個人Todoを送信（Kind 30001）
  /// 
  /// パラメータ:
  /// - todos: 送信するTodoリスト
  /// - isAmberMode: Amber署名を使用するか
  Future<Either<Failure, void>> syncPersonalTodosToNostr({
    required List<Todo> todos,
    required bool isAmberMode,
  });
  
  // ============================================================
  // マイグレーション関連
  // ============================================================
  
  /// Kind 30001（新形式）の存在確認
  Future<Either<Failure, bool>> checkKind30001Exists();
  
  /// Kind 30078（旧形式）からマイグレーションが必要か確認
  Future<Either<Failure, bool>> checkMigrationNeeded();
  
  /// Kind 30078（旧形式）からTodoデータを取得
  /// 
  /// Phase C.2.1: マイグレーション用の旧データ取得
  /// Phase C.2.2: 完全なマイグレーション処理実装後に統合
  Future<Either<Failure, List<Todo>>> fetchOldTodosFromKind30078({
    required String publicKey,
  });
  
  /// Kind 30078 → Kind 30001 へマイグレーション実行
  /// 
  /// Phase C.2.2で完全実装予定
  /// （fetchOldTodos + 新形式送信 + 旧イベント削除）
  Future<Either<Failure, void>> migrateFromKind30078ToKind30001();
  
  // ============================================================
  // Phase Dで実装予定（MLS関連）
  // ============================================================
  // TODO: Phase D
  // Future<Either<Failure, List<Todo>>> syncGroupTodosFromMls(String groupId);
  // Future<Either<Failure, void>> syncGroupTodosToMls(String groupId, List<Todo> todos);
}

/// 個人Todo同期の結果
/// 
/// Nostrから取得したデータの集合。
/// AppSettingsとCustomListsも同時に取得するため、まとめて返す。
class PersonalTodoSyncResult {
  final List<Todo> todos;
  final AppSettings? appSettings;
  final List<CustomList> customLists;
  
  const PersonalTodoSyncResult({
    required this.todos,
    this.appSettings,
    required this.customLists,
  });
}
