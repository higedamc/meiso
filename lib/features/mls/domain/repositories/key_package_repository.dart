import 'package:dartz/dartz.dart';
import '../../../core/common/failure.dart';
import '../entities/key_package.dart';

/// Key Package Repository Interface
/// 
/// MLS Key Packageの管理を抽象化する。
/// Infrastructure層で実装される。
abstract class KeyPackageRepository {
  // ========================================
  // ローカル操作
  // ========================================
  
  /// Key Packageをローカルストレージから読み込み
  /// 
  /// [publicKey]: 公開鍵（hex形式）
  /// 
  /// Returns: Key Package（存在しない場合はnull）
  Future<Either<Failure, KeyPackage?>> loadKeyPackageFromLocal({
    required String publicKey,
  });
  
  /// Key Packageをローカルストレージに保存
  /// 
  /// [keyPackage]: 保存するKey Package
  Future<Either<Failure, void>> saveKeyPackageToLocal(KeyPackage keyPackage);
  
  /// Key Packageをローカルストレージから削除
  /// 
  /// [publicKey]: 公開鍵（hex形式）
  Future<Either<Failure, void>> deleteKeyPackageFromLocal({
    required String publicKey,
  });
  
  /// 最後の公開時刻を読み込み
  Future<Either<Failure, DateTime?>> loadLastPublishTime();
  
  /// 最後の公開時刻を保存
  /// 
  /// [dateTime]: 公開日時
  Future<Either<Failure, void>> saveLastPublishTime(DateTime dateTime);
  
  // ========================================
  // Nostr操作
  // ========================================
  
  /// Key Packageを生成
  /// 
  /// Rust APIを呼び出してKey Packageを生成する。
  /// MLS DB初期化も含む。
  /// 
  /// [publicKey]: 公開鍵（hex形式）
  /// 
  /// Returns: 生成されたKey Package
  Future<Either<Failure, KeyPackage>> generateKeyPackage({
    required String publicKey,
  });
  
  /// Key PackageをNostrに公開
  /// 
  /// Kind 10443イベントとして公開する。
  /// 
  /// [keyPackage]: 公開するKey Package
  /// 
  /// Returns: イベントID
  Future<Either<Failure, String>> publishKeyPackage(KeyPackage keyPackage);
  
  /// npubからKey Packageを取得
  /// 
  /// Nostrリレーから指定されたnpubのKey Packageを取得する。
  /// 
  /// [npub]: npub形式の公開鍵
  /// 
  /// Returns: Key Package（見つからない場合はnull）
  Future<Either<Failure, KeyPackage?>> fetchKeyPackageByNpub({
    required String npub,
  });
  
  /// 複数のnpubからKey Packageを一括取得
  /// 
  /// [npubs]: npub形式の公開鍵リスト
  /// 
  /// Returns: Map<npub, KeyPackage>（見つからないnpubは含まれない）
  Future<Either<Failure, Map<String, KeyPackage>>> fetchKeyPackagesByNpubs({
    required List<String> npubs,
  });
}

