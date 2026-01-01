import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/todo.dart';
import 'logger_service.dart';

/// Android Widget更新用のサービス
class WidgetService {
  static const MethodChannel _channel =
      MethodChannel('jp.godzhigella.meiso/widget');

  /// Widgetを更新する
  /// 
  /// [todos]: 日付ごとにグループ化されたTodoリスト
  static Future<void> updateWidget(Map<DateTime?, List<Todo>> todos) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      AppLogger.debug('📱 WidgetService: updateWidget called');
      AppLogger.debug('   Today date: ${today.toIso8601String()}');
      AppLogger.debug('   Total date groups: ${todos.length}');
      
      // 各日付グループの内容をログ出力
      todos.forEach((date, todoList) {
        final dateStr = date != null 
            ? DateTime(date.year, date.month, date.day).toIso8601String()
            : 'null (Someday)';
        final incompleteTodos = todoList.where((t) => !t.completed).length;
        AppLogger.debug('   Date: $dateStr → ${todoList.length} todos ($incompleteTodos incomplete)');
        
        // TODAYの日付の場合、タスクをログ出力
        if (date != null) {
          final todoDate = DateTime(date.year, date.month, date.day);
          if (todoDate.isAtSameMomentAs(today)) {
            AppLogger.debug('   ✅ This is TODAY! Tasks:');
            for (final todo in todoList) {
              AppLogger.debug('      - "${todo.title}" (completed: ${todo.completed})');
            }
          }
        }
      });
      
      // JSONに変換（Android側で解析しやすい形式）
      final todosMap = <String, dynamic>{};
      
      todos.forEach((date, todoList) {
        final key = date?.toIso8601String() ?? 'null';
        todosMap[key] = todoList.map((todo) => {
          'id': todo.id,
          'title': todo.title,
          'completed': todo.completed,
          'date': date?.toIso8601String(),
        }).toList();
      });
      
      final todosJson = jsonEncode(todosMap);
      AppLogger.debug('📱 JSON length: ${todosJson.length} characters');
      AppLogger.debug('📱 JSON preview: ${todosJson.substring(0, todosJson.length > 200 ? 200 : todosJson.length)}...');
      
      await _channel.invokeMethod('updateWidget', {
        'todosJson': todosJson,
      });
      
      AppLogger.debug('✅ Widget updated successfully');
    } on PlatformException catch (e) {
      AppLogger.warning('⚠️ Failed to update widget: ${e.message}');
      // ウィジェット更新の失敗はアプリの動作に影響しないため、エラーを握りつぶす
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update widget: $e');
    }
  }
}

