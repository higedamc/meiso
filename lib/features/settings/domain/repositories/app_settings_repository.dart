import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../entities/app_settings.dart';

/// アプリ設定のリポジトリインターフェース
///
/// データの永続化とビジネスロジックの間の抽象化層
abstract class AppSettingsRepository {
  /// アプリ設定を取得
  Future<Either<Failure, AppSettings>> getAppSettings();
  
  /// アプリ設定を更新
  Future<Either<Failure, AppSettings>> updateAppSettings(AppSettings settings);
  
  /// ダークモードを切り替え
  Future<Either<Failure, AppSettings>> toggleDarkMode();
  
  /// 週の開始曜日を変更
  Future<Either<Failure, AppSettings>> setWeekStartDay(int day);
  
  /// カレンダー表示形式を変更
  Future<Either<Failure, AppSettings>> setCalendarView(String view);
  
  /// 通知設定を切り替え
  Future<Either<Failure, AppSettings>> toggleNotifications();
  
  /// リレーリストを更新（ローカルのみ）
  Future<Either<Failure, AppSettings>> updateRelays(List<String> relays);
  
  /// リレーリストをNostr（Kind 10002）に保存
  Future<Either<Failure, void>> saveRelaysToNostr(List<String> relays);
  
  /// Nostrから設定を同期（Kind 30078）
  Future<Either<Failure, AppSettings>> syncFromNostr();
  
  /// Nostrに設定を同期（Kind 30078）
  Future<Either<Failure, void>> syncToNostr(AppSettings settings);
}

