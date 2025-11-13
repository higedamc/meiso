import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/key_package_repository.dart';
import '../../domain/repositories/mls_group_repository.dart';
import '../repositories/key_package_repository_impl.dart';
import '../repositories/mls_group_repository_impl.dart';
import '../datasources/key_package_local_datasource.dart';
import '../datasources/mls_group_local_datasource.dart';
import '../../../../services/local_storage_service.dart';
import '../../../../providers/nostr_provider.dart';

// ========================================
// DataSource Providers
// ========================================

/// KeyPackageLocalDataSource Provider
/// 
/// LocalStorageService（Hive）を使用してKey Package公開時刻を管理
final keyPackageLocalDataSourceProvider = Provider<KeyPackageLocalDataSource>((ref) {
  return KeyPackageLocalDataSource(localStorageService);
});

/// MlsGroupLocalDataSource Provider
/// 
/// LocalStorageService（Hive）を使用してMLSグループと招待を管理
final mlsGroupLocalDataSourceProvider = Provider<MlsGroupLocalDataSource>((ref) {
  return MlsGroupLocalDataSource(localStorageService);
});

// ========================================
// Repository Providers
// ========================================

/// KeyPackageRepository Provider
/// 
/// Key Package管理のRepository
final keyPackageRepositoryProvider = Provider<KeyPackageRepository>((ref) {
  final dataSource = ref.watch(keyPackageLocalDataSourceProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final isAmberMode = ref.watch(isAmberModeProvider);
  
  return KeyPackageRepositoryImpl(
    localDataSource: dataSource,
    nostrService: nostrService,
    isAmberMode: isAmberMode,
  );
});

/// MlsGroupRepository Provider
/// 
/// MLSグループ管理のRepository
/// ✅ Phase D.5.2で実装完了
final mlsGroupRepositoryProvider = Provider<MlsGroupRepository>((ref) {
  final dataSource = ref.watch(mlsGroupLocalDataSourceProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final isAmberMode = ref.watch(isAmberModeProvider);
  
  return MlsGroupRepositoryImpl(
    localDataSource: dataSource,
    nostrService: nostrService,
    isAmberMode: isAmberMode,
  );
});

