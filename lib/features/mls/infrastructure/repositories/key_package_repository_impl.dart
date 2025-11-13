import 'package:dartz/dartz.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/key_package.dart';
import '../../domain/repositories/key_package_repository.dart';
import '../../domain/errors/mls_errors.dart';
import '../datasources/key_package_local_datasource.dart';
import '../../../../services/logger_service.dart';
import '../../../../services/amber_service.dart';
import '../../../../providers/nostr_provider.dart';
import '../../../../bridge_generated.dart/api.dart' as rust_api;
import '../../../../bridge_generated.dart/group_tasks_mls.dart' show KeyPackageResult;

/// Key Package Repository Implementation
/// 
/// Key Packageの生成、公開、取得を実装する。
/// 既存のnostr_provider.dartのpublishKeyPackage()ロジックを移植。
class KeyPackageRepositoryImpl implements KeyPackageRepository {
  final KeyPackageLocalDataSource _localDataSource;
  final NostrService _nostrService;
  final bool _isAmberMode;
  
  const KeyPackageRepositoryImpl({
    required KeyPackageLocalDataSource localDataSource,
    required NostrService nostrService,
    required bool isAmberMode,
  })  : _localDataSource = localDataSource,
        _nostrService = nostrService,
        _isAmberMode = isAmberMode;
  
  // ========================================
  // ローカル操作
  // ========================================
  
  @override
  Future<Either<Failure, KeyPackage?>> loadKeyPackageFromLocal({
    required String publicKey,
  }) async {
    // Note: Key Package本体はMLS DBで管理されるため、
    // ローカルストレージからの読み込みは現在未実装。
    // 将来的に必要になれば実装する。
    AppLogger.debug('[KeyPackageRepo] loadKeyPackageFromLocal: Not implemented');
    return Right(null);
  }
  
  @override
  Future<Either<Failure, void>> saveKeyPackageToLocal(KeyPackage keyPackage) async {
    // Note: Key Package本体はMLS DBで管理されるため、
    // ローカルストレージへの保存は現在未実装。
    AppLogger.debug('[KeyPackageRepo] saveKeyPackageToLocal: Not implemented');
    return Right(null);
  }
  
  @override
  Future<Either<Failure, void>> deleteKeyPackageFromLocal({
    required String publicKey,
  }) async {
    AppLogger.debug('[KeyPackageRepo] deleteKeyPackageFromLocal: Not implemented');
    return Right(null);
  }
  
  @override
  Future<Either<Failure, DateTime?>> loadLastPublishTime() async {
    try {
      final dateTime = await _localDataSource.loadLastPublishTime();
      return Right(dateTime);
    } catch (e, st) {
      AppLogger.error(
        '[KeyPackageRepo] Failed to load last publish time',
        error: e,
        stackTrace: st,
      );
      return Left(KeyPackageFailure(
        MlsError.unknown,
        'Key Package公開時刻の読み込みに失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveLastPublishTime(DateTime dateTime) async {
    try {
      await _localDataSource.saveLastPublishTime(dateTime);
      return Right(null);
    } catch (e, st) {
      AppLogger.error(
        '[KeyPackageRepo] Failed to save last publish time',
        error: e,
        stackTrace: st,
      );
      return Left(KeyPackageFailure(
        MlsError.unknown,
        'Key Package公開時刻の保存に失敗しました: $e',
      ));
    }
  }
  
  // ========================================
  // Nostr操作
  // ========================================
  
  @override
  Future<Either<Failure, KeyPackage>> generateKeyPackage({
    required String publicKey,
  }) async {
    try {
      AppLogger.info('[KeyPackageRepo] Generating Key Package...');
      
      // Step 0: MLS DB初期化（Key Package生成前に必須）
      AppLogger.debug('  Step 0: MLS DB初期化中...');
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/mls.db';
      
      await rust_api.mlsInitDb(
        dbPath: dbPath,
        nostrId: publicKey,
      );
      AppLogger.debug('  ✅ MLS DB初期化完了');
      
      // Step 1: Key Package生成
      AppLogger.debug('  Step 1: Key Package生成中...');
      final keyPackageResult = await rust_api.mlsCreateKeyPackage(
        nostrId: publicKey,
      );
      AppLogger.debug('  ✅ Key Package生成完了');
      AppLogger.debug('    Protocol: \${keyPackageResult.mlsProtocolVersion}');
      AppLogger.debug('    Ciphersuite: \${keyPackageResult.ciphersuite}');
      
      // KeyPackageエンティティに変換
      final now = DateTime.now();
      final keyPackage = KeyPackage(
        keyPackage: keyPackageResult.keyPackage,
        ownerPubkey: publicKey,
        publishedAt: now,
        mlsProtocolVersion: keyPackageResult.mlsProtocolVersion,
        ciphersuite: keyPackageResult.ciphersuite,
      );
      
      AppLogger.info('[KeyPackageRepo] Key Package generated successfully');
      return Right(keyPackage);
      
    } catch (e, st) {
      AppLogger.error(
        '[KeyPackageRepo] Failed to generate Key Package',
        error: e,
        stackTrace: st,
      );
      return Left(MlsCryptoFailure.mlsDbInitFailed(
        'Key Packageの生成に失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, String>> publishKeyPackage(KeyPackage keyPackage) async {
    try {
      AppLogger.info('[KeyPackageRepo] Publishing Key Package...');
      
      // Step 1: 未署名イベント作成
      AppLogger.debug('  Step 1: Kind 10443イベント作成中...');
      
      // defaultRelaysはトップレベルの定数（nostr_provider.dartで定義）
      final relays = defaultRelays;
      
      // KeyPackageResultを再構成（Rust APIが期待する形式）
      final keyPackageResult = KeyPackageResult(
        keyPackage: keyPackage.keyPackage,
        mlsProtocolVersion: keyPackage.mlsProtocolVersion ?? '',
        ciphersuite: keyPackage.ciphersuite ?? '',
        extensions: '', // デフォルト値
      );
      
      final unsignedEventJson = await rust_api.createUnsignedKeyPackageEvent(
        keyPackageResult: keyPackageResult,
        publicKeyHex: keyPackage.ownerPubkey,
        relays: relays,
      );
      
      AppLogger.debug('  ✅ 未署名イベント作成完了');
      
      // Step 2: 署名
      String signedEvent;
      
      if (_isAmberMode) {
        AppLogger.debug('  Step 2: Amberで署名中...');
        final amberService = AmberService();
        signedEvent = await amberService.signEventWithTimeout(
          unsignedEventJson,
          timeout: const Duration(minutes: 2),
        );
        AppLogger.debug('  ✅ Amber署名完了');
      } else {
        // 秘密鍵モードは現在pending
        throw Exception('秘密鍵モードでのKey Package公開は未実装です。Amberモードをご利用ください。');
      }
      
      // Step 3: リレーに送信
      AppLogger.debug('  Step 3: リレーに送信中...');
      final sendResult = await _nostrService.sendSignedEvent(signedEvent);
      
      AppLogger.info('[KeyPackageRepo] Key Package published successfully');
      AppLogger.info('   Event ID: \${sendResult.eventId}');
      AppLogger.info('   公開先リレー数: \${relays.length}');
      
      return Right(sendResult.eventId);
      
    } catch (e, st) {
      AppLogger.error(
        '[KeyPackageRepo] Failed to publish Key Package',
        error: e,
        stackTrace: st,
      );
      return Left(KeyPackageFailure.publishFailed(
        'Key Packageの公開に失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, KeyPackage?>> fetchKeyPackageByNpub({
    required String npub,
  }) async {
    try {
      AppLogger.info('[KeyPackageRepo] Fetching Key Package for npub: \${npub.substring(0, 16)}...');
      
      // TODO: Phase D.6以降で実装
      // Nostrリレーからnpubに対応するKind 10443イベントを取得
      // 現在は未実装（グループ招待機能で必要）
      
      AppLogger.debug('[KeyPackageRepo] fetchKeyPackageByNpub: Not implemented yet');
      return Right(null);
      
    } catch (e, st) {
      AppLogger.error(
        '[KeyPackageRepo] Failed to fetch Key Package',
        error: e,
        stackTrace: st,
      );
      return Left(MlsNetworkFailure.networkError(
        'Key Packageの取得に失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, Map<String, KeyPackage>>> fetchKeyPackagesByNpubs({
    required List<String> npubs,
  }) async {
    try {
      AppLogger.info('[KeyPackageRepo] Fetching Key Packages for \${npubs.length} npubs...');
      
      // TODO: Phase D.6以降で実装
      // 複数npubからKey Packageを一括取得
      // 現在は未実装（グループ作成機能で必要）
      
      AppLogger.debug('[KeyPackageRepo] fetchKeyPackagesByNpubs: Not implemented yet');
      return Right({});
      
    } catch (e, st) {
      AppLogger.error(
        '[KeyPackageRepo] Failed to fetch Key Packages',
        error: e,
        stackTrace: st,
      );
      return Left(MlsNetworkFailure.networkError(
        'Key Packagesの一括取得に失敗しました: $e',
      ));
    }
  }
}

