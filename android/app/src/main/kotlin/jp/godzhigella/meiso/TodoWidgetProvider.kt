package jp.godzhigella.meiso

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * MeisoのホームスクリーンWidget
 * Today/Tomorrow/Somedayのタスクを表示
 */
class TodoWidgetProvider : AppWidgetProvider() {
    
    companion object {
        private const val TAG = "TodoWidgetProvider"
        private const val PREFS_NAME = "meiso_widget_prefs"
        private const val PREF_TODOS_DATA = "todos_data"
        
        /**
         * Widgetを手動で更新（Flutter側から呼ばれる）
         */
        fun updateWidgets(context: Context, todosJson: String) {
            Log.d(TAG, "🔄 Updating widgets with new data")
            
            // データをSharedPreferencesに保存
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(PREF_TODOS_DATA, todosJson).apply()
            
            // すべてのWidgetを更新
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, TodoWidgetProvider::class.java)
            )
            
            appWidgetIds.forEach { widgetId ->
                updateAppWidget(context, appWidgetManager, widgetId, todosJson)
            }
            
            Log.d(TAG, "✅ Updated ${appWidgetIds.size} widgets")
        }
        
        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            todosJson: String
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_todo)
            
            try {
                // JSONデータをパース
                val todosData = parseTodosJson(todosJson)
                
                // Todayのセクションを更新
                updateSection(context, views, R.id.today_list, todosData["today"] ?: emptyList())
                
                // ウィジェットをタップしたらアプリを開く
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context, 
                    0, 
                    intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                views.setOnClickPendingIntent(R.id.add_button, pendingIntent)
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error updating widget", e)
                // エラー時は空のリストを表示
                views.setTextViewText(R.id.today_list, "")
            }
            
            // Widgetを更新
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        
        private fun parseTodosJson(todosJson: String): Map<String, List<TodoItem>> {
            val result = mutableMapOf<String, MutableList<TodoItem>>()
            result["today"] = mutableListOf()
            
            try {
                val json = JSONObject(todosJson)
                
                // 今日の日付（ローカルタイムゾーン、時刻は00:00:00）
                val todayLocal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                
                Log.d(TAG, "📅 Today (local): ${SimpleDateFormat("yyyy-MM-dd", Locale.US).format(todayLocal.time)}")
                
                // JSONの各日付キーをイテレート
                val keys = json.keys()
                while (keys.hasNext()) {
                    val dateKey = keys.next()
                    val todosArray = json.getJSONArray(dateKey)
                    
                    Log.d(TAG, "🔍 Processing dateKey: $dateKey (${todosArray.length()} todos)")
                    
                    for (i in 0 until todosArray.length()) {
                        val todoJson = todosArray.getJSONObject(i)
                        val completed = todoJson.optBoolean("completed", false)
                        val title = todoJson.optString("title", "")
                        
                        Log.d(TAG, "  📝 Task: \"$title\" (completed: $completed)")
                        
                        // 完了済みタスクはスキップ
                        if (completed) {
                            Log.d(TAG, "    ⏭️ Skipping completed task")
                            continue
                        }
                        
                        // dateフィールドを取得（nullまたは"null"の場合はSomeday）
                        val dateStr = if (todoJson.isNull("date")) {
                            null
                        } else {
                            todoJson.optString("date", null)
                        }
                        
                        Log.d(TAG, "    📅 Date string: $dateStr")
                        
                        // 日付が null または "null" の場合はスキップ（Somedayタスク）
                        if (dateStr == null || dateStr == "null" || dateStr.isEmpty()) {
                            Log.d(TAG, "    ⏭️ Skipping someday task")
                            continue
                        }
                        
                        try {
                            // ISO8601形式をパース（複数フォーマットに対応）
                            val formats = listOf(
                                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US),
                                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US),
                                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS", Locale.US),
                                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                            )
                            
                            var todoDate: Date? = null
                            for (format in formats) {
                                format.timeZone = TimeZone.getTimeZone("UTC")
                                try {
                                    todoDate = format.parse(dateStr)
                                    if (todoDate != null) {
                                        Log.d(TAG, "    ✅ Parsed date successfully with format: ${format.toPattern()}")
                                        break
                                    }
                                } catch (e: Exception) {
                                    // 次のフォーマットを試す
                                }
                            }
                            
                            if (todoDate != null) {
                                // タスクの日付をローカルタイムゾーンのCalendarに変換
                                val todoLocalCal = Calendar.getInstance().apply {
                                    time = todoDate
                                    set(Calendar.HOUR_OF_DAY, 0)
                                    set(Calendar.MINUTE, 0)
                                    set(Calendar.SECOND, 0)
                                    set(Calendar.MILLISECOND, 0)
                                }
                                
                                val todoDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(todoLocalCal.time)
                                val todayDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(todayLocal.time)
                                
                                Log.d(TAG, "    📅 Comparing: todo=$todoDateStr, today=$todayDateStr")
                                
                                // 日付を比較（年月日のみ）
                                val isSameDay = (todayLocal.get(Calendar.YEAR) == todoLocalCal.get(Calendar.YEAR) &&
                                                todayLocal.get(Calendar.DAY_OF_YEAR) == todoLocalCal.get(Calendar.DAY_OF_YEAR))
                                
                                if (isSameDay) {
                                    result["today"]?.add(TodoItem(title, completed))
                                    Log.d(TAG, "    ✅ Added to TODAY: \"$title\"")
                                } else {
                                    Log.d(TAG, "    ⏭️ Skipping non-today task: \"$title\" (date: $todoDateStr)")
                                }
                            } else {
                                Log.w(TAG, "    ⚠️ Could not parse date with any format: $dateStr")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "    ❌ Exception parsing date: $dateStr for task \"$title\"", e)
                        }
                    }
                }
                
                Log.d(TAG, "📊 Parsed todos - Today: ${result["today"]?.size}")
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error parsing todos JSON", e)
            }
            
            return result
        }
        
        private fun updateSection(
            context: Context,
            views: RemoteViews,
            listId: Int,
            todos: List<TodoItem>
        ) {
            if (todos.isEmpty()) {
                views.setTextViewText(listId, "No tasks for today")
                return
            }
            
            // 未完了タスクのみを表示（最大10件）
            val incompleteTodos = todos.filter { !it.completed }.take(10)
            
            if (incompleteTodos.isEmpty()) {
                views.setTextViewText(listId, "All done! 🎉")
                return
            }
            
            val listText = incompleteTodos.joinToString("\n") { todo ->
                "• ${todo.title}"
            }
            
            views.setTextViewText(listId, listText)
        }
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "🔄 onUpdate called for ${appWidgetIds.size} widgets")
        
        // SharedPreferencesから保存されたデータを読み込み
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val todosJson = prefs.getString(PREF_TODOS_DATA, null)
        
        if (todosJson != null) {
            appWidgetIds.forEach { appWidgetId ->
                updateAppWidget(context, appWidgetManager, appWidgetId, todosJson)
            }
        } else {
            Log.w(TAG, "⚠️ No todos data available in SharedPreferences")
            // データがない場合は空のウィジェットを表示
            appWidgetIds.forEach { appWidgetId ->
                val views = RemoteViews(context.packageName, R.layout.widget_todo)
                views.setTextViewText(R.id.today_list, "Open Meiso to sync")
                
                // タップでアプリを開く
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                views.setOnClickPendingIntent(R.id.add_button, pendingIntent)
                
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
    
    override fun onEnabled(context: Context) {
        Log.d(TAG, "✅ Widget enabled")
    }
    
    override fun onDisabled(context: Context) {
        Log.d(TAG, "❌ Widget disabled")
    }
    
    data class TodoItem(
        val title: String,
        val completed: Boolean
    )
}

