import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../models/custom_list.dart';

part 'custom_list_state.freezed.dart';

/// CustomListのState（Freezed Union型）
@freezed
class CustomListState with _$CustomListState {
  const factory CustomListState.initial() = _Initial;
  
  const factory CustomListState.loading() = _Loading;
  
  const factory CustomListState.loaded({
    required List<CustomList> customLists,
  }) = _Loaded;
  
  const factory CustomListState.error({
    required String message,
  }) = _Error;
}

