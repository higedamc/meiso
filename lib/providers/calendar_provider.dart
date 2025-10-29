import 'package:flutter_riverpod/flutter_riverpod.dart';

/// カレンダーの表示/非表示を管理するProvider
final calendarVisibleProvider = StateProvider<bool>((ref) => false);

