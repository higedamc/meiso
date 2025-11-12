import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/custom_list.dart';

part 'custom_list_state.freezed.dart';

/// CustomListの状態を表すクラス
@freezed
class CustomListState with _$CustomListState {
  /// 初期状態
  const factory CustomListState.initial() = _Initial;
  
  /// 読み込み中
  const factory CustomListState.loading() = _Loading;
  
  /// 読み込み完了
  const factory CustomListState.loaded({
    required List<CustomList> customLists,
  }) = _Loaded;
  
  /// エラー
  const factory CustomListState.error(Failure failure) = _Error;
}

