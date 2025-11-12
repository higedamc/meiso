import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/custom_list_view_model.dart';
import '../view_models/custom_list_state.dart';

/// CustomListViewModel Provider
final customListViewModelProvider =
    StateNotifierProvider<CustomListViewModel, CustomListState>((ref) {
  return CustomListViewModel(ref);
});

