# Meiso クリーンアーキテクチャ移行計画

**作成日**: 2025-11-12  
**ステータス**: 📋 計画策定完了  
**関連Issue**: #64

## 📊 エグゼクティブサマリー

### 目的
MeisoをFeature-based + 4層クリーンアーキテクチャに移行し、以下を実現する：
- **保守性向上**: 責任分離による変更影響範囲の局所化
- **拡張性向上**: 新機能追加の容易化
- **テスタビリティ向上**: 各層の独立したテストが可能に

### アプローチ
- ✅ **独自実装** - パッケージ依存なし、Meisoの要件に100%適合
- ✅ **段階的移行** - 既存機能を壊さず、小さなステップで進める
- ✅ **Riverpod活用** - 既存の`flutter_riverpod`をそのまま活用
- ⚠️ **dartz非採用** - Either型は独自実装（軽量化、学習コスト削減）

### 期間
- **Phase 1-5**: 3-4日（Todo機能の完全移行）
- **Phase 6-7**: 2-3日（他機能の展開とテスト）
- **合計**: 5-7日

---

## 🏛️ 目標アーキテクチャ

### ディレクトリ構造

```
lib/
├── core/                           # アプリ基盤
│   ├── common/
│   │   ├── either.dart            # 独自Either型実装
│   │   ├── usecase.dart           # UseCaseベースクラス
│   │   └── failure.dart           # Failureベースクラス
│   ├── config/
│   │   └── app_config.dart        # アプリ設定
│   └── theme/
│       └── app_theme.dart         # テーマ（既存維持）
│
├── shared/                         # 共有機能モジュール
│   ├── nostr/                      # Nostr機能
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── nostr_event.dart
│   │   │   │   └── relay.dart
│   │   │   ├── repositories/
│   │   │   │   └── nostr_repository.dart
│   │   │   └── errors/
│   │   │       └── nostr_errors.dart
│   │   ├── infrastructure/
│   │   │   ├── datasources/
│   │   │   │   ├── nostr_relay_datasource.dart
│   │   │   │   └── nostr_cache_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── nostr_repository_impl.dart
│   │   │   └── services/
│   │   │       └── nostr_subscription_service.dart
│   │   └── providers/
│   │       └── nostr_providers.dart
│   │
│   ├── amber/                      # Amber統合
│   │   ├── domain/
│   │   ├── infrastructure/
│   │   └── providers/
│   │
│   ├── storage/                    # ローカルストレージ
│   │   ├── domain/
│   │   ├── infrastructure/
│   │   └── providers/
│   │
│   └── widgets/                    # 共通Widget
│       ├── sync_status_indicator.dart
│       └── circular_checkbox.dart
│
└── features/                       # 機能別モジュール
    ├── todo/                       # Todo機能（最初に移行）
    │   ├── presentation/
    │   │   ├── screens/
    │   │   │   └── todo_edit_screen.dart
    │   │   ├── widgets/
    │   │   │   ├── todo_item.dart
    │   │   │   ├── todo_column.dart
    │   │   │   └── add_todo_field.dart
    │   │   ├── view_models/
    │   │   │   ├── todos_view_model.dart
    │   │   │   └── todos_state.dart
    │   │   └── errors/
    │   │       └── todo_error_messages.dart
    │   │
    │   ├── application/            # UseCase層
    │   │   └── usecases/
    │   │       ├── create_todo_usecase.dart
    │   │       ├── update_todo_usecase.dart
    │   │       ├── delete_todo_usecase.dart
    │   │       ├── toggle_todo_usecase.dart
    │   │       ├── reorder_todo_usecase.dart
    │   │       ├── move_todo_usecase.dart
    │   │       └── sync_todos_usecase.dart
    │   │
    │   ├── domain/                 # ビジネスロジック層
    │   │   ├── entities/
    │   │   │   └── todo.dart
    │   │   ├── value_objects/
    │   │   │   ├── todo_title.dart
    │   │   │   └── todo_date.dart
    │   │   ├── repositories/
    │   │   │   └── todo_repository.dart
    │   │   └── errors/
    │   │       └── todo_errors.dart
    │   │
    │   ├── infrastructure/         # データ層
    │   │   ├── repositories/
    │   │   │   └── todo_repository_impl.dart
    │   │   ├── datasources/
    │   │   │   ├── todo_local_datasource.dart
    │   │   │   └── todo_remote_datasource.dart
    │   │   └── services/
    │   │       ├── recurrence_service.dart
    │   │       └── link_preview_service.dart
    │   │
    │   └── providers/
    │       ├── repository_providers.dart
    │       ├── usecase_providers.dart
    │       └── view_model_providers.dart
    │
    ├── custom_list/                # カスタムリスト機能
    │   └── (同様の構造)
    │
    ├── settings/                   # 設定機能
    │   └── (同様の構造)
    │
    └── home/                       # ホーム画面
        └── (同様の構造)
```

### 4層の責務

| 層 | 責務 | 具体例 | Meisoでの役割 |
|---|---|---|---|
| **Presentation** | UI表示、ユーザー入力、画面遷移 | Screen, Widget, ViewModel | `todo_item.dart`, `todos_view_model.dart` |
| **Application** | ビジネスフロー調整、UseCase実装 | CreateTodoUseCase | `create_todo_usecase.dart` |
| **Domain** | ビジネスルール、エンティティ定義 | Todo Entity, TodoRepository | `todo.dart`, `todo_repository.dart` |
| **Infrastructure** | 外部サービス連携、永続化 | TodoRepositoryImpl, Hive, Rust API | `todo_repository_impl.dart` |

---

## 📅 段階的実装計画

### Phase 0: 準備（1時間）

#### チェックリスト
- [x] 現状分析完了
- [x] リファクタリング計画策定
- [x] チーム共有（Oracleとの確認）
- [x] ブランチ確認（`refactor/clean-architecture`使用）
- [x] 技術的判断確定（dartz採用、テスト網羅的実装）

#### ステータス
✅ **完了** - 2025-11-12

---

### Phase 1: Core層の基盤整備（2-3時間）

#### チェックリスト
- [x] dartz依存関係追加
- [x] Failureベースクラス実装
- [x] UseCaseベースクラス実装
- [x] AppConfig実装
- [x] テストファイル作成（failure_test.dart, usecase_test.dart）
- [x] mocktail依存関係追加
- [x] 依存関係インストール（`flutter pub get`）
- [x] テスト実行（`flutter test`） - 31個のテストケース全てパス
- [x] ビルド確認

#### ステータス
✅ **完了** - 2025-11-12

#### 目標
クリーンアーキテクチャの基盤となる共通インターフェースを実装

#### 成果物

##### 1. dartzパッケージの採用（Either型）

dartzパッケージを採用し、成熟したEither型実装を使用。

**使用例**:
```dart
import 'package:dartz/dartz.dart';

Either<Failure, String> result = Right('成功');
result.fold(
  (failure) => print('失敗: ${failure.message}'),
  (value) => print('成功: $value'),
);
```

##### 2. Failureベースクラス

```dart
// lib/core/common/failure.dart

/// エラーを表現する基底クラス
abstract class Failure {
  const Failure(this.message);
  final String message;
  
  @override
  String toString() => message;
}

/// ネットワークエラー
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'ネットワークエラーが発生しました']) 
      : super(message);
}

/// 認証エラー
class AuthFailure extends Failure {
  const AuthFailure([String message = '認証に失敗しました']) 
      : super(message);
}

/// サーバーエラー
class ServerFailure extends Failure {
  const ServerFailure([String message = 'サーバーエラーが発生しました']) 
      : super(message);
}

/// キャッシュエラー
class CacheFailure extends Failure {
  const CacheFailure([String message = 'キャッシュエラーが発生しました']) 
      : super(message);
}

/// 検証エラー
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message);
}

/// 予期せぬエラー
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([String message = '予期しないエラーが発生しました']) 
      : super(message);
}
```

##### 3. UseCaseベースクラス

```dart
// lib/core/common/usecase.dart

import 'either.dart';
import 'failure.dart';

/// UseCaseの基底クラス
/// 
/// すべてのUseCaseはこのインターフェースを実装する
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// パラメータが不要なUseCase用
class NoParams {
  const NoParams();
}
```

#### 実装済みファイル
- ✅ `lib/core/common/failure.dart` - 11種類のFailureクラス
- ✅ `lib/core/common/usecase.dart` - UseCaseベースクラスとNoParams
- ✅ `lib/core/config/app_config.dart` - アプリ設定定数
- ✅ `test/core/common/failure_test.dart` - Failureの単体テスト（20テストケース）
- ✅ `test/core/common/usecase_test.dart` - UseCaseの単体テスト（11テストケース）

#### 次のアクション（Oracle手動確認）
以下のコマンドを実行してください：

```bash
# 1. 依存関係のインストール
flutter pub get

# 2. テストの実行
flutter test test/core/

# 3. ビルド確認
flutter build apk --debug
```

テストがすべてパスしたら、Phase 1完了です。

---

### Phase 2: Todo機能のDomain層抽出（3-4時間）

#### チェックリスト
- [x] 既存Todoモデルの分析
- [x] Value Objects実装（TodoTitle, TodoDate）
- [x] Todoエンティティの移行
- [x] TodoRepositoryインターフェース定義
- [x] Domainエラー定義
- [x] 69個のテストケース実装（全てパス）
- [x] Freezedコード生成

#### ステータス
✅ **完了** - 2025-11-12

#### 目標
現在の`lib/models/todo.dart`をDomain層に移行し、ビジネスルールを明確化

#### 成果物

##### 1. Todoエンティティ（既存の改良版）

```dart
// lib/features/todo/domain/entities/todo.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import '../value_objects/todo_title.dart';
import '../value_objects/todo_date.dart';

part 'todo.freezed.dart';

/// Todoエンティティ（ビジネスロジック層）
/// 
/// Nostr NIP-44暗号化でリレーに保存される
@Freezed(makeCollectionsUnmodifiable: false)
class Todo with _$Todo {
  const factory Todo({
    required String id,
    required TodoTitle title,
    required bool completed,
    TodoDate? date,
    required int order,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? eventId,
    String? linkPreviewJson,  // LinkPreviewをJSON化して保存
    String? recurrenceJson,    // RecurrencePatternをJSON化
    String? parentRecurringId,
    String? customListId,
    required bool needsSync,
  }) = _Todo;
}

/// Todoの便利な拡張メソッド
extension TodoExtension on Todo {
  bool get isRecurring => recurrenceJson != null;
  bool get isRecurringInstance => parentRecurringId != null;
  
  /// JSON変換用のシンプルなマップに変換
  Map<String, dynamic> toSimpleJson() => {
    'id': id,
    'title': title.value,
    'completed': completed,
    'date': date?.value.toIso8601String(),
    'order': order,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'eventId': eventId,
    'linkPreview': linkPreviewJson,
    'recurrence': recurrenceJson,
    'parentRecurringId': parentRecurringId,
    'customListId': customListId,
    'needsSync': needsSync,
  };
}
```

##### 2. Value Objects

```dart
// lib/features/todo/domain/value_objects/todo_title.dart

import '../../../../core/common/either.dart';
import '../../../../core/common/failure.dart';

/// Todoのタイトル（Value Object）
class TodoTitle {
  const TodoTitle._(this.value);
  
  final String value;
  
  /// バリデーション付きファクトリー
  static Either<Failure, TodoTitle> create(String input) {
    if (input.isEmpty) {
      return const Left(ValidationFailure('タイトルを入力してください'));
    }
    if (input.length > 500) {
      return const Left(ValidationFailure('タイトルは500文字以内にしてください'));
    }
    return Right(TodoTitle._(input));
  }
  
  /// 検証なしで作成（既存データ読み込み時）
  factory TodoTitle.unsafe(String value) => TodoTitle._(value);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoTitle && value == other.value;
  
  @override
  int get hashCode => value.hashCode;
}
```

```dart
// lib/features/todo/domain/value_objects/todo_date.dart

/// Todoの日付（Value Object）
class TodoDate {
  const TodoDate(this.value);
  
  final DateTime value;
  
  /// 日付のみを保持（時刻を00:00:00にする）
  factory TodoDate.dateOnly(DateTime date) {
    return TodoDate(DateTime(date.year, date.month, date.day));
  }
  
  /// 今日
  factory TodoDate.today() => TodoDate.dateOnly(DateTime.now());
  
  /// 明日
  factory TodoDate.tomorrow() => 
      TodoDate.dateOnly(DateTime.now().add(const Duration(days: 1)));
  
  /// 日付が今日かどうか
  bool get isToday {
    final now = DateTime.now();
    return value.year == now.year &&
           value.month == now.month &&
           value.day == now.day;
  }
  
  /// 日付が明日かどうか
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return value.year == tomorrow.year &&
           value.month == tomorrow.month &&
           value.day == tomorrow.day;
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoDate &&
      value.year == other.value.year &&
      value.month == other.value.month &&
      value.day == other.value.day;
  
  @override
  int get hashCode => Object.hash(value.year, value.month, value.day);
}
```

##### 3. Repositoryインターフェース

```dart
// lib/features/todo/domain/repositories/todo_repository.dart

import '../../../../core/common/either.dart';
import '../../../../core/common/failure.dart';
import '../entities/todo.dart';
import '../errors/todo_errors.dart';

/// TodoリポジトリのDomain層インターフェース
/// 
/// Infrastructure層で実装される
abstract class TodoRepository {
  /// すべてのTodoを取得（ローカルキャッシュから）
  Future<Either<Failure, List<Todo>>> getAllTodos();
  
  /// 特定のTodoを取得
  Future<Either<Failure, Todo>> getTodoById(String id);
  
  /// Todoを作成
  Future<Either<Failure, Todo>> createTodo(Todo todo);
  
  /// Todoを更新
  Future<Either<Failure, Todo>> updateTodo(Todo todo);
  
  /// Todoを削除
  Future<Either<Failure, void>> deleteTodo(String id);
  
  /// NostrリレーからTodoを同期
  Future<Either<Failure, List<Todo>>> syncFromNostr();
  
  /// TodoをNostrリレーに送信
  Future<Either<Failure, void>> syncToNostr(Todo todo);
  
  /// ローカルストレージに保存
  Future<Either<Failure, void>> saveLocal(List<Todo> todos);
  
  /// ローカルストレージから読み込み
  Future<Either<Failure, List<Todo>>> loadLocal();
}
```

##### 4. Domainエラー

```dart
// lib/features/todo/domain/errors/todo_errors.dart

import '../../../../core/common/failure.dart';

/// Todo機能固有のエラー
class TodoFailure extends Failure {
  const TodoFailure(this.error) : super(_errorMessage(error));
  
  final TodoError error;
  
  static String _errorMessage(TodoError error) {
    switch (error) {
      case TodoError.notFound:
        return 'タスクが見つかりませんでした';
      case TodoError.alreadyExists:
        return 'タスクは既に存在します';
      case TodoError.invalidTitle:
        return 'タイトルが無効です';
      case TodoError.syncFailed:
        return '同期に失敗しました';
      case TodoError.encryptionFailed:
        return '暗号化に失敗しました';
      case TodoError.decryptionFailed:
        return '復号化に失敗しました';
    }
  }
}

enum TodoError {
  notFound,
  alreadyExists,
  invalidTitle,
  syncFailed,
  encryptionFailed,
  decryptionFailed,
}
```

#### 作業内容
1. `lib/features/todo/domain/`ディレクトリ構造作成
2. 既存の`todo.dart`をDomain層に移行（Value Object化）
3. Repositoryインターフェース定義
4. Domainエラー定義

---

### Phase 3: Todo機能のInfrastructure層分離（4-5時間）

#### チェックリスト
- [x] DataSourceインターフェース定義
- [x] LocalDataSource実装（Hive）
- [x] RemoteDataSource定義（スケルトン）
- [x] TodoRepositoryImpl実装
- [x] 23個のテストケース実装（全てパス）
- [x] Mocktailでモック化

#### ステータス
✅ **完了** - 2025-11-12

#### 目標
データアクセス層を分離し、Rust API・Hive・Nostr通信を抽象化

#### 成果物

##### 1. TodoリポジトリImpl

```dart
// lib/features/todo/infrastructure/repositories/todo_repository_impl.dart

import '../../../../core/common/either.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/errors/todo_errors.dart';
import '../datasources/todo_local_datasource.dart';
import '../datasources/todo_remote_datasource.dart';

/// TodoリポジトリのInfrastructure層実装
class TodoRepositoryImpl implements TodoRepository {
  const TodoRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });
  
  final TodoLocalDataSource localDataSource;
  final TodoRemoteDataSource remoteDataSource;
  
  @override
  Future<Either<Failure, List<Todo>>> getAllTodos() async {
    try {
      final todos = await localDataSource.loadAllTodos();
      return Right(todos);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Todo>> getTodoById(String id) async {
    try {
      final todo = await localDataSource.loadTodoById(id);
      if (todo == null) {
        return const Left(TodoFailure(TodoError.notFound));
      }
      return Right(todo);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Todo>> createTodo(Todo todo) async {
    try {
      // ローカルに保存
      await localDataSource.saveTodo(todo);
      
      // Nostrに送信（非同期、エラーは無視）
      remoteDataSource.syncTodoToNostr(todo).catchError((e) {
        // ログ記録のみ
        print('Nostr sync failed: $e');
      });
      
      return Right(todo);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Todo>> updateTodo(Todo todo) async {
    try {
      await localDataSource.saveTodo(todo);
      
      // Nostr同期（非同期）
      remoteDataSource.syncTodoToNostr(todo).catchError((e) {
        print('Nostr sync failed: $e');
      });
      
      return Right(todo);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteTodo(String id) async {
    try {
      await localDataSource.deleteTodo(id);
      
      // Nostrからも削除（非同期）
      remoteDataSource.deleteTodoFromNostr(id).catchError((e) {
        print('Nostr delete failed: $e');
      });
      
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<Todo>>> syncFromNostr() async {
    try {
      final todos = await remoteDataSource.fetchTodosFromNostr();
      
      // ローカルに保存
      for (final todo in todos) {
        await localDataSource.saveTodo(todo);
      }
      
      return Right(todos);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> syncToNostr(Todo todo) async {
    try {
      await remoteDataSource.syncTodoToNostr(todo);
      return const Right(null);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveLocal(List<Todo> todos) async {
    try {
      for (final todo in todos) {
        await localDataSource.saveTodo(todo);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<Todo>>> loadLocal() async {
    try {
      final todos = await localDataSource.loadAllTodos();
      return Right(todos);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
```

##### 2. DataSourceインターフェース

```dart
// lib/features/todo/infrastructure/datasources/todo_local_datasource.dart

import '../../domain/entities/todo.dart';

/// ローカルストレージDataSource（Hive）
abstract class TodoLocalDataSource {
  Future<List<Todo>> loadAllTodos();
  Future<Todo?> loadTodoById(String id);
  Future<void> saveTodo(Todo todo);
  Future<void> deleteTodo(String id);
  Future<void> clear();
}

/// Hive実装
class TodoLocalDataSourceHive implements TodoLocalDataSource {
  // 既存のHiveロジックを移植
  // （省略、既存の local_storage_service.dart から移行）
}
```

```dart
// lib/features/todo/infrastructure/datasources/todo_remote_datasource.dart

import '../../domain/entities/todo.dart';

/// NostrリレーDataSource
abstract class TodoRemoteDataSource {
  Future<List<Todo>> fetchTodosFromNostr();
  Future<void> syncTodoToNostr(Todo todo);
  Future<void> deleteTodoFromNostr(String id);
}

/// Nostr実装（Rust API + Amber統合）
class TodoRemoteDataSourceNostr implements TodoRemoteDataSource {
  // 既存のNostr同期ロジックを移植
  // （省略、現在の TodosProvider から移行）
}
```

#### 作業内容
1. `lib/features/todo/infrastructure/`ディレクトリ構造作成
2. TodoRepositoryImplの実装
3. LocalDataSourceの実装（既存のHiveロジック移植）
4. RemoteDataSourceの実装（既存のNostr同期ロジック移植）

---

### Phase 4: Todo機能のApplication層（UseCase）実装（3-4時間）

#### 目標
ビジネスフローをUseCaseとして明確化

#### 成果物

##### 主要UseCase

```dart
// lib/features/todo/application/usecases/create_todo_usecase.dart

import '../../../../core/common/either.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/value_objects/todo_title.dart';
import '../../domain/value_objects/todo_date.dart';
import 'package:uuid/uuid.dart';

class CreateTodoUseCase implements UseCase<Todo, CreateTodoParams> {
  const CreateTodoUseCase(this.repository);
  
  final TodoRepository repository;
  final _uuid = const Uuid();
  
  @override
  Future<Either<Failure, Todo>> call(CreateTodoParams params) async {
    // 1. バリデーション
    final titleResult = TodoTitle.create(params.title);
    if (titleResult.isLeft) {
      return titleResult.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected Right'),
      );
    }
    
    final title = titleResult.fold(
      (_) => throw Exception('Unexpected Left'),
      (t) => t,
    );
    
    // 2. Todoエンティティ作成
    final now = DateTime.now();
    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      completed: false,
      date: params.date,
      order: params.order,
      createdAt: now,
      updatedAt: now,
      customListId: params.customListId,
      needsSync: true,
    );
    
    // 3. リポジトリに保存
    return repository.createTodo(todo);
  }
}

class CreateTodoParams {
  const CreateTodoParams({
    required this.title,
    this.date,
    required this.order,
    this.customListId,
  });
  
  final String title;
  final TodoDate? date;
  final int order;
  final String? customListId;
}
```

```dart
// lib/features/todo/application/usecases/update_todo_usecase.dart

import '../../../../core/common/either.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

class UpdateTodoUseCase implements UseCase<Todo, UpdateTodoParams> {
  const UpdateTodoUseCase(this.repository);
  
  final TodoRepository repository;
  
  @override
  Future<Either<Failure, Todo>> call(UpdateTodoParams params) async {
    // 既存のTodoを取得
    final result = await repository.getTodoById(params.id);
    
    return result.fold(
      (failure) => Left(failure),
      (existingTodo) async {
        // 更新されたTodoを作成
        final updatedTodo = Todo(
          id: existingTodo.id,
          title: params.title ?? existingTodo.title,
          completed: params.completed ?? existingTodo.completed,
          date: params.date ?? existingTodo.date,
          order: params.order ?? existingTodo.order,
          createdAt: existingTodo.createdAt,
          updatedAt: DateTime.now(),
          eventId: existingTodo.eventId,
          customListId: params.customListId ?? existingTodo.customListId,
          needsSync: true,
        );
        
        return repository.updateTodo(updatedTodo);
      },
    );
  }
}

class UpdateTodoParams {
  const UpdateTodoParams({
    required this.id,
    this.title,
    this.completed,
    this.date,
    this.order,
    this.customListId,
  });
  
  final String id;
  final TodoTitle? title;
  final bool? completed;
  final TodoDate? date;
  final int? order;
  final String? customListId;
}
```

```dart
// lib/features/todo/application/usecases/toggle_todo_usecase.dart

import '../../../../core/common/either.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

class ToggleTodoUseCase implements UseCase<Todo, String> {
  const ToggleTodoUseCase(this.repository);
  
  final TodoRepository repository;
  
  @override
  Future<Either<Failure, Todo>> call(String todoId) async {
    final result = await repository.getTodoById(todoId);
    
    return result.fold(
      (failure) => Left(failure),
      (todo) async {
        final toggled = Todo(
          id: todo.id,
          title: todo.title,
          completed: !todo.completed,
          date: todo.date,
          order: todo.order,
          createdAt: todo.createdAt,
          updatedAt: DateTime.now(),
          eventId: todo.eventId,
          customListId: todo.customListId,
          needsSync: true,
        );
        
        return repository.updateTodo(toggled);
      },
    );
  }
}
```

```dart
// lib/features/todo/application/usecases/sync_todos_usecase.dart

import '../../../../core/common/either.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

class SyncTodosUseCase implements UseCase<List<Todo>, NoParams> {
  const SyncTodosUseCase(this.repository);
  
  final TodoRepository repository;
  
  @override
  Future<Either<Failure, List<Todo>>> call(NoParams params) async {
    // Nostrから同期
    return repository.syncFromNostr();
  }
}
```

#### 作業内容
1. `lib/features/todo/application/usecases/`ディレクトリ作成
2. 主要UseCase実装（Create, Update, Delete, Toggle, Move, Reorder, Sync）
3. UseCaseのパラメータクラス定義

---

### Phase 5: Todo機能のPresentation層リファクタリング（3-4時間）

#### 目標
ViewModelを導入し、UIロジックとビジネスロジックを分離

#### 成果物

##### 1. TodosState

```dart
// lib/features/todo/presentation/view_models/todos_state.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/todo.dart';

part 'todos_state.freezed.dart';

@freezed
class TodosState with _$TodosState {
  const factory TodosState({
    @Default({}) Map<DateTime?, List<Todo>> groupedTodos,
    @Default(false) bool isLoading,
    @Default(false) bool isSyncing,
    String? errorMessage,
  }) = _TodosState;
}
```

##### 2. TodosViewModel

```dart
// lib/features/todo/presentation/view_models/todos_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/common/usecase.dart';
import '../../application/usecases/create_todo_usecase.dart';
import '../../application/usecases/update_todo_usecase.dart';
import '../../application/usecases/delete_todo_usecase.dart';
import '../../application/usecases/toggle_todo_usecase.dart';
import '../../application/usecases/sync_todos_usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/value_objects/todo_date.dart';
import '../../domain/value_objects/todo_title.dart';
import 'todos_state.dart';

class TodosViewModel extends StateNotifier<TodosState> {
  TodosViewModel({
    required this.createTodoUseCase,
    required this.updateTodoUseCase,
    required this.deleteTodoUseCase,
    required this.toggleTodoUseCase,
    required this.syncTodosUseCase,
  }) : super(const TodosState()) {
    _initialize();
  }
  
  final CreateTodoUseCase createTodoUseCase;
  final UpdateTodoUseCase updateTodoUseCase;
  final DeleteTodoUseCase deleteTodoUseCase;
  final ToggleTodoUseCase toggleTodoUseCase;
  final SyncTodosUseCase syncTodosUseCase;
  
  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    
    // 初回同期
    await sync();
    
    state = state.copyWith(isLoading: false);
  }
  
  /// Todoを追加
  Future<void> addTodo({
    required String title,
    TodoDate? date,
    String? customListId,
  }) async {
    final params = CreateTodoParams(
      title: title,
      date: date,
      order: _getNextOrder(date),
      customListId: customListId,
    );
    
    final result = await createTodoUseCase(params);
    
    result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
      (todo) {
        _addTodoToState(todo);
      },
    );
  }
  
  /// Todoをトグル
  Future<void> toggleTodo(String id) async {
    final result = await toggleTodoUseCase(id);
    
    result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
      (todo) {
        _updateTodoInState(todo);
      },
    );
  }
  
  /// Todoを削除
  Future<void> deleteTodo(String id) async {
    final result = await deleteTodoUseCase(id);
    
    result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
      (_) {
        _removeTodoFromState(id);
      },
    );
  }
  
  /// Nostr同期
  Future<void> sync() async {
    state = state.copyWith(isSyncing: true);
    
    final result = await syncTodosUseCase(const NoParams());
    
    result.fold(
      (failure) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: failure.message,
        );
      },
      (todos) {
        _rebuildGroupedTodos(todos);
        state = state.copyWith(isSyncing: false);
      },
    );
  }
  
  // 内部ヘルパーメソッド
  void _addTodoToState(Todo todo) {
    final newGrouped = Map<DateTime?, List<Todo>>.from(state.groupedTodos);
    newGrouped[todo.date?.value] ??= [];
    newGrouped[todo.date?.value]!.add(todo);
    newGrouped[todo.date?.value]!.sort((a, b) => a.order.compareTo(b.order));
    
    state = state.copyWith(groupedTodos: newGrouped);
  }
  
  void _updateTodoInState(Todo todo) {
    final newGrouped = Map<DateTime?, List<Todo>>.from(state.groupedTodos);
    
    // 古い日付から削除
    for (final key in newGrouped.keys) {
      newGrouped[key]!.removeWhere((t) => t.id == todo.id);
    }
    
    // 新しい日付に追加
    newGrouped[todo.date?.value] ??= [];
    newGrouped[todo.date?.value]!.add(todo);
    newGrouped[todo.date?.value]!.sort((a, b) => a.order.compareTo(b.order));
    
    state = state.copyWith(groupedTodos: newGrouped);
  }
  
  void _removeTodoFromState(String id) {
    final newGrouped = Map<DateTime?, List<Todo>>.from(state.groupedTodos);
    
    for (final key in newGrouped.keys) {
      newGrouped[key]!.removeWhere((t) => t.id == id);
    }
    
    state = state.copyWith(groupedTodos: newGrouped);
  }
  
  void _rebuildGroupedTodos(List<Todo> todos) {
    final Map<DateTime?, List<Todo>> newGrouped = {};
    
    for (final todo in todos) {
      newGrouped[todo.date?.value] ??= [];
      newGrouped[todo.date?.value]!.add(todo);
    }
    
    for (final key in newGrouped.keys) {
      newGrouped[key]!.sort((a, b) => a.order.compareTo(b.order));
    }
    
    state = state.copyWith(groupedTodos: newGrouped);
  }
  
  int _getNextOrder(TodoDate? date) {
    final todos = state.groupedTodos[date?.value] ?? [];
    return todos.isEmpty ? 0 : todos.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }
}
```

##### 3. Providers

```dart
// lib/features/todo/providers/todo_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/usecases/create_todo_usecase.dart';
import '../application/usecases/update_todo_usecase.dart';
import '../application/usecases/delete_todo_usecase.dart';
import '../application/usecases/toggle_todo_usecase.dart';
import '../application/usecases/sync_todos_usecase.dart';
import '../infrastructure/repositories/todo_repository_impl.dart';
import '../infrastructure/datasources/todo_local_datasource.dart';
import '../infrastructure/datasources/todo_remote_datasource.dart';
import '../domain/repositories/todo_repository.dart';
import '../presentation/view_models/todos_view_model.dart';
import '../presentation/view_models/todos_state.dart';

// DataSource Providers
final todoLocalDataSourceProvider = Provider<TodoLocalDataSource>((ref) {
  return TodoLocalDataSourceHive();
});

final todoRemoteDataSourceProvider = Provider<TodoRemoteDataSource>((ref) {
  return TodoRemoteDataSourceNostr();
});

// Repository Provider
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepositoryImpl(
    localDataSource: ref.watch(todoLocalDataSourceProvider),
    remoteDataSource: ref.watch(todoRemoteDataSourceProvider),
  );
});

// UseCase Providers
final createTodoUseCaseProvider = Provider<CreateTodoUseCase>((ref) {
  return CreateTodoUseCase(ref.watch(todoRepositoryProvider));
});

final updateTodoUseCaseProvider = Provider<UpdateTodoUseCase>((ref) {
  return UpdateTodoUseCase(ref.watch(todoRepositoryProvider));
});

final deleteTodoUseCaseProvider = Provider<DeleteTodoUseCase>((ref) {
  return DeleteTodoUseCase(ref.watch(todoRepositoryProvider));
});

final toggleTodoUseCaseProvider = Provider<ToggleTodoUseCase>((ref) {
  return ToggleTodoUseCase(ref.watch(todoRepositoryProvider));
});

final syncTodosUseCaseProvider = Provider<SyncTodosUseCase>((ref) {
  return SyncTodosUseCase(ref.watch(todoRepositoryProvider));
});

// ViewModel Provider
final todosViewModelProvider = 
    StateNotifierProvider<TodosViewModel, TodosState>((ref) {
  return TodosViewModel(
    createTodoUseCase: ref.watch(createTodoUseCaseProvider),
    updateTodoUseCase: ref.watch(updateTodoUseCaseProvider),
    deleteTodoUseCase: ref.watch(deleteTodoUseCaseProvider),
    toggleTodoUseCase: ref.watch(toggleTodoUseCaseProvider),
    syncTodosUseCase: ref.watch(syncTodosUseCaseProvider),
  );
});
```

#### 作業内容
1. `lib/features/todo/presentation/view_models/`作成
2. TodosState定義（freezed）
3. TodosViewModel実装（既存の`TodosNotifier`からロジックを移行）
4. Providers配線
5. 既存のWidget（`todo_item.dart`等）をViewModel対応に更新

---

### Phase 8: 他機能への展開（6-8時間）

#### ステータス
🔄 **実装中** - 2025-11-12

#### 目標
Todo機能で確立したパターンをCustomList・Settings機能にも適用

#### 対象機能
1. **CustomList機能** - カスタムリスト管理（SOMEDAYページ）
2. **Settings機能** - アプリ設定、Amber連携、リレー管理

---

#### Phase 8.1: CustomList機能のClean Architecture移行（3-4時間）

##### 既存コード分析
- `lib/models/custom_list.dart` - 既存エンティティ
- `lib/providers/custom_lists_provider.dart` - 複雑なロジック（318行）
  - ローカルストレージ（Hive）との同期
  - AppSettingsとの連携（リスト順の保存）
  - Nostr同期（リスト名のList受信）
  - デフォルトリスト作成

##### 実装計画

**Domain層**
```
lib/features/custom_list/
├── domain/
│   ├── entities/
│   │   └── custom_list.dart (移行)
│   ├── value_objects/
│   │   └── list_name.dart (NEW)
│   ├── repositories/
│   │   └── custom_list_repository.dart (NEW)
│   └── errors/
│       └── custom_list_errors.dart (NEW)
```

**Infrastructure層**
```
├── infrastructure/
│   ├── datasources/
│   │   └── custom_list_local_datasource.dart (NEW)
│   └── repositories/
│       └── custom_list_repository_impl.dart (NEW)
```

**Application層 - 6つのUseCases**
```
├── application/
│   └── usecases/
│       ├── create_custom_list_usecase.dart
│       ├── update_custom_list_usecase.dart
│       ├── delete_custom_list_usecase.dart
│       ├── reorder_custom_lists_usecase.dart
│       ├── get_all_custom_lists_usecase.dart
│       └── sync_custom_lists_from_nostr_usecase.dart
```

**Presentation層**
```
├── presentation/
│   ├── view_models/
│   │   ├── custom_list_state.dart (NEW)
│   │   └── custom_list_view_model.dart (NEW)
│   └── providers/
│       ├── custom_list_providers.dart (NEW)
│       └── custom_list_providers_compat.dart (NEW - 互換レイヤー)
```

---

#### Phase 8.2: Settings機能のClean Architecture移行（3-4時間）

##### 既存コード分析
- `lib/models/app_settings.dart` - 既存エンティティ
- `lib/providers/app_settings_provider.dart` - 複雑なロジック（520行）
  - ローカルストレージとの同期
  - Nostr同期（NIP-78 Kind 30078）
  - リレーリスト管理（NIP-65 Kind 10002）
  - Amber連携

##### 実装計画

**Domain層**
```
lib/features/settings/
├── domain/
│   ├── entities/
│   │   └── app_settings.dart (移行)
│   ├── repositories/
│   │   └── app_settings_repository.dart (NEW)
│   └── errors/
│       └── app_settings_errors.dart (NEW)
```

**Infrastructure層**
```
├── infrastructure/
│   ├── datasources/
│   │   ├── app_settings_local_datasource.dart (NEW)
│   │   └── app_settings_remote_datasource.dart (NEW - Nostr)
│   └── repositories/
│       └── app_settings_repository_impl.dart (NEW)
```

**Application層 - 10個のUseCases**
```
├── application/
│   └── usecases/
│       ├── get_app_settings_usecase.dart
│       ├── update_app_settings_usecase.dart
│       ├── toggle_dark_mode_usecase.dart
│       ├── set_week_start_day_usecase.dart
│       ├── set_calendar_view_usecase.dart
│       ├── toggle_notifications_usecase.dart
│       ├── update_relays_usecase.dart
│       ├── save_relays_to_nostr_usecase.dart
│       ├── sync_from_nostr_usecase.dart
│       └── sync_to_nostr_usecase.dart
```

**Presentation層**
```
├── presentation/
│   ├── view_models/
│   │   ├── app_settings_state.dart (NEW)
│   │   └── app_settings_view_model.dart (NEW)
│   └── providers/
│       ├── app_settings_providers.dart (NEW)
│       └── app_settings_providers_compat.dart (NEW - 互換レイヤー)
```

---

### Phase 7: テスト実装とドキュメント整備（3-4時間）

#### 目標
品質保証とチーム全体への知識共有

#### 成果物

##### 1. ユニットテスト

```dart
// test/features/todo/domain/value_objects/todo_title_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';

void main() {
  group('TodoTitle', () {
    test('空文字列はエラーを返す', () {
      final result = TodoTitle.create('');
      expect(result.isLeft, true);
    });
    
    test('正常な文字列はTodoTitleを返す', () {
      final result = TodoTitle.create('買い物');
      expect(result.isRight, true);
    });
    
    test('500文字以上はエラーを返す', () {
      final result = TodoTitle.create('a' * 501);
      expect(result.isLeft, true);
    });
  });
}
```

```dart
// test/features/todo/application/usecases/create_todo_usecase_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meiso/features/todo/application/usecases/create_todo_usecase.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late CreateTodoUseCase useCase;
  late MockTodoRepository mockRepository;
  
  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = CreateTodoUseCase(mockRepository);
  });
  
  test('正常にTodoを作成できる', () async {
    // Arrange
    when(() => mockRepository.createTodo(any()))
        .thenAnswer((_) async => Right(/* mock todo */));
    
    // Act
    final result = await useCase(CreateTodoParams(
      title: '買い物',
      order: 0,
    ));
    
    // Assert
    expect(result.isRight, true);
    verify(() => mockRepository.createTodo(any())).called(1);
  });
}
```

##### 2. 実装ガイドライン

```markdown
// docs/IMPLEMENTATION_GUIDE.md

## 新機能の追加方法

### 1. Domain層から開始
- Entity定義
- Repository interface定義
- Domain Error定義

### 2. Infrastructure層の実装
- RepositoryImplの実装
- DataSourcesの実装
- 外部サービス連携

### 3. Application層の実装
- UseCases実装
- ビジネスフローの調整

### 4. Presentation層の実装
- State定義
- ViewModel実装
- Widgetの作成

### 5. Providerの配線
- DataSource Provider
- Repository Provider
- UseCase Providers
- ViewModel Provider
```

#### 作業内容
1. 主要な単体テストの実装
2. 実装ガイドラインの作成
3. ADR（Architecture Decision Records）の作成
4. READMEの更新

---

## 📐 設計原則

### Dependency Rule（依存性の規則）

```
Presentation → Application → Domain ← Infrastructure
                                ↑
                            依存の方向
```

- **Domain層**: 他の層に依存しない（最も安定）
- **Application層**: Domainに依存
- **Infrastructure層**: Domainに依存（Repositoryを実装）
- **Presentation層**: ApplicationとDomainに依存

### Single Responsibility Principle（単一責任の原則）

- 各クラスは1つの責任のみを持つ
- UseCaseは1つのビジネスフローのみを実行
- Repositoryは1つのEntityの永続化のみを担当

### Open/Closed Principle（開放閉鎖の原則）

- Interfaceを介して拡張可能
- 既存コードの変更を最小化

---

## ⚠️ 移行時の注意点

### 1. 既存機能を壊さない

- **段階的移行**: 一度に全てを変えない
- **動作確認**: 各Phaseごとに動作確認
- **ロールバック可能**: いつでも前の状態に戻せる

### 2. Rust APIとの連携

- Rust bridgeの呼び出しは`Infrastructure/DataSources`層に集約
- Domain層にRust APIの詳細を漏らさない

### 3. Amber統合

- Amber関連ロジックは`shared/amber/`に集約
- Amber署名・暗号化処理はInfrastructure層で実施

### 4. Nostr同期

- 楽観的UI更新は維持
- バッチ同期タイマーは維持
- エラーハンドリングを強化

---

## 📊 進捗管理

### マイルストーン

| Phase | 内容 | 期間 | ステータス |
|-------|------|------|----------|
| Phase 0 | 準備 | 1時間 | ✅ 完了 |
| Phase 1 | Core層基盤 | 2-3時間 | ✅ 完了 |
| Phase 2 | Todo Domain | 3-4時間 | ✅ 完了 |
| Phase 3 | Todo Infrastructure | 4-5時間 | ✅ 完了 |
| Phase 4 | Todo Application | 3-4時間 | ✅ 完了 |
| Phase 5 | Todo Presentation | 3-4時間 | ✅ 完了 |
| Phase 6 | Provider統合 | 2-3時間 | ✅ 完了 |
| Phase 7 | UI統合・ViewModels | 4-5時間 | ✅ 完了 |
| Phase 8 | 他機能展開 | 6-8時間 | ⏸️ 未着手 |

### チェックポイント

各Phase完了時に以下を確認：
- [ ] ビルドが通る
- [ ] 既存機能が動作する
- [ ] 新しいアーキテクチャパターンが適用されている
- [ ] コードレビュー完了

---

## 🎓 参考資料

### アーキテクチャ
- [Clean Architecture (Robert C. Martin)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Feature-based Design Pattern in Flutter](https://medium.com/@rk0936626/feature-based-design-pattern-in-flutter-ce5fdb5abf04)

### Flutter & Riverpod
- [Riverpod 公式ドキュメント](https://riverpod.dev/)
- [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)

### Nostr
- [NIP-44: Encrypted Payloads](https://github.com/nostr-protocol/nips/blob/master/44.md)
- [NIP-78: Application-specific data](https://github.com/nostr-protocol/nips/blob/master/78.md)

---

## 🚀 次のアクション

### 即座に開始可能
1. ✅ このドキュメントをOracleとレビュー
2. Phase 1: Core層の基盤整備を開始
3. Phase 2: Todo機能のDomain層抽出

### Oracleへの確認事項
- この計画でOKか？
- 優先度の変更はあるか？（Todo以外の機能を先に進めるべきか？）
- 独自Either型実装 vs dartz採用の判断
- テストの粒度（どこまで書くか）

---

**作成日**: 2025-11-12  
**最終更新**: 2025-11-12  
**ステータス**: 🎉 Phase 7.6実装完了（未実装メソッド完全統合）

---

## 📝 変更履歴

### 2025-11-12
- **Phase 0完了**: 現状分析、計画策定、Oracle承認取得
- **Phase 1完了**:
  - dartz, mocktail依存関係追加
  - Core層基盤実装（Failure, UseCase, AppConfig）
  - 31個のテストケース作成・全パス
- **Phase 2完了**:
  - Value Objects実装（TodoTitle, TodoDate）
  - TodoエンティティをDomain層に移行
  - TodoRepositoryインターフェース定義
  - Domainエラー定義（8種類のTodoError）
  - 69個のテストケース作成・全パス
  - 既存のlinkPreview, recurrenceをそのまま活用
- **Phase 3完了**:
  - DataSourceパターン実装（Local + Remote）
  - TodoLocalDataSourceHive実装（Hiveでの永続化）
  - TodoRepositoryImpl実装（フィルタリング機能付き）
  - 23個のテストケース作成・全パス
  - Mocktailでのモック化対応
- **Phase 4完了**:
  - 12個のUseCaseを実装（CRUD + 操作 + 同期 + フィルタリング）
  - 47個のテストケース作成・全パス
  - dartz Either型でのエラーハンドリング統一
  - needsSync フラグで楽観的UI更新をサポート
  - LinkPreview/RecurrencePattern統合
- **Phase 5完了**:
  - Riverpod Providerレイヤー実装（依存性注入の基盤）
  - TodoListState（Freezed）実装
  - TodoListNotifier（StateNotifier）実装
  - 7個のテストケース作成・全パス
  - UseCaseベースのPresentation層統合完了
- **Phase 6完了**:
  - Hive初期化をProviderレベルで管理（FutureProvider）
  - TodoLocalDataSourceの初期化タイミング制御
  - TodoListNotifierの遅延初期化対応（autoLoadパラメータ）
  - Provider依存関係の最適化
  - 全170テストケースでパス確認
- **Phase 7完了**:
  - ViewModels構造への移行（`presentation/state/` → `presentation/view_models/`）
  - `TodoListNotifier` → `TodoListViewModel`に改名
  - `todoListNotifierProvider` → `todoListViewModelProvider`に改名
  - 互換レイヤー実装（`todo_providers_compat.dart`）
    - `todosProviderCompat`: AsyncValue変換Provider
    - `todosProviderNotifierCompat`: .notifier互換ラッパー
    - `TodoListViewModelCompat`: 既存メソッド互換クラス
    - `todosForDateProvider`: 日付別Todoリスト取得Provider
  - 既存UI統合（24ファイル修正）
    - import文の一括置換（11ファイル）
    - `.notifier`アクセス修正（9ファイル、24箇所）
    - `reorderTodo`呼び出し修正（3ファイル）
    - `updateTodoWithRecurrence`シグネチャ修正
  - 全170テストケースでパス確認
  - コンパイルエラー0件達成
- **Phase 7.6完了**:
  - **オプションA: 暫定ハイブリッド実装**採用
  - 互換レイヤーから旧`todosProvider`へブリッジ実装
  - 7個の未実装メソッドを完全統合：
    1. `manualSyncToNostr()` - 手動Nostr同期
    2. `addTodoWithData()` - 削除Undo機能
    3. `updateTodo()` - Todo更新
    4. `removeLinkPreview()` - リンクプレビュー削除
    5. `deleteRecurringInstance()` - 繰り返しタスクの1つ削除
    6. `deleteAllRecurringInstances()` - 繰り返しタスク全削除
    7. `updateTodoWithRecurrence()` - 繰り返しパターン更新
  - `TodoListViewModelCompat`に`Ref`を追加
  - 全7テストケースでパス確認
  - コンパイルエラー0件達成
