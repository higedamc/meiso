import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/local_storage_service.dart';
import '../../../../services/amber_service.dart';
import '../../../../providers/nostr_provider.dart';
import '../../domain/repositories/todo_repository.dart';
import '../repositories/todo_repository_impl.dart';

/// LocalStorageServiceのProvider
/// 
/// グローバルインスタンスを使用（main.dartで初期化済み）
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return localStorageService;
});

/// AmberServiceのProvider
final amberServiceProvider = Provider<AmberService>((ref) {
  return AmberService();
});

/// TodoRepositoryのProvider
/// 
/// Phase C: Repository層の導入
/// 依存関係を自動注入してTodoRepositoryImplのインスタンスを提供
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final amberService = ref.watch(amberServiceProvider);
  
  return TodoRepositoryImpl(
    localStorageService: localStorage,
    nostrService: nostrService,
    amberService: amberService,
  );
});

