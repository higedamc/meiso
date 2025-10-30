package jp.godzhigella.meiso

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val AMBER_CHANNEL = "jp.godzhigella.meiso/amber"
    private val AMBER_EVENT_CHANNEL = "jp.godzhigella.meiso/amber_events"
    private var amberMethodChannel: MethodChannel? = null
    private var amberEventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingResult: MethodChannel.Result? = null
    private var bufferedResponse: Map<String, Any?>? = null
    private var pendingIntent: Intent? = null
    
    // Amberリクエスト用のリクエストコードとタイプ
    private val AMBER_REQUEST_CODE = 1001
    private var currentAmberRequestType: String? = null  // 現在のリクエストタイプを保存
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        android.util.Log.d("MainActivity", "🎬 onCreate called")
        
        // Amberからの復帰時のIntentを保存（SharedPreferencesに永続化）
        intent?.let { 
            if (it.data?.scheme == "meiso") {
                val uriString = it.data.toString()
                android.util.Log.d("MainActivity", "📦 Storing Amber intent to SharedPreferences: $uriString")
                
                // SharedPreferencesに保存
                val prefs = getSharedPreferences("amber_prefs", MODE_PRIVATE)
                prefs.edit().putString("pending_amber_uri", uriString).apply()
                
                pendingIntent = it
            }
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // MethodChannel設定
        amberMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AMBER_CHANNEL
        )
        
        // EventChannel設定
        amberEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AMBER_EVENT_CHANNEL
        )
        
        amberEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                android.util.Log.d("MainActivity", "✅ EventChannel listener registered, eventSink=${eventSink != null}")
                
                // バッファされたレスポンスがあれば即座に送信
                bufferedResponse?.let { response ->
                    android.util.Log.d("MainActivity", "📤 Sending buffered response immediately: $response")
                    // 確実に送信されるまで待機
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        eventSink?.success(response)
                        bufferedResponse = null
                        android.util.Log.d("MainActivity", "✨ Buffered response sent and cleared")
                    }
                }
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
                android.util.Log.d("MainActivity", "EventChannel listener cancelled")
            }
        })
        
        amberMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPublicKeyFromAmber" -> {
                    // Amberから公開鍵を取得するリクエスト (NIP-55準拠)
                    pendingResult = result
                    currentAmberRequestType = "get_public_key"
                    
                    val currentPackage = packageName
                    
                    // パーミッションをJSON配列として作成（1行に圧縮）
                    // Amberが期待する形式: [{"type":"nip44_decrypt","kind":null}, ...]
                    val permissionsJson = """[{"type":"nip44_decrypt","kind":null},{"type":"nip44_encrypt","kind":null},{"type":"sign_event","kind":30078}]"""
                    
                    // NIP-55 format: パラメータをIntentのextrasとして送信
                    // startActivityForResult()を使用することで、Amberが callingPackage を取得でき、
                    // アプリ登録とパーミッション管理が正常に動作する
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = android.net.Uri.parse("nostrsigner:")
                        `package` = "com.greenart7c3.nostrsigner"
                        // Amberが期待するextras
                        putExtra("type", "get_public_key")
                        putExtra("package", currentPackage)
                        putExtra("appName", "Meiso")  // アプリ名を送信
                        // パーミッション要求：JSON配列として送信
                        // これによりAmberがアプリを登録し、パーミッションを保存する
                        putExtra("permissions", permissionsJson)
                    }
                    
                    try {
                        android.util.Log.d("MainActivity", "🚀 Launching Amber with startActivityForResult (permissions: $permissionsJson)")
                        android.util.Log.d("MainActivity", "📝 App name: Meiso, Package: $currentPackage")
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, AMBER_REQUEST_CODE)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to launch Amber", e)
                        result.error("AMBER_ERROR", "Failed to launch Amber: ${e.message}", null)
                        pendingResult = null
                    }
                }
                "signEventWithAmber" -> {
                    // Amberでイベントに署名するリクエスト (NIP-55準拠)
                    val eventJson = call.argument<String>("event")
                    if (eventJson == null) {
                        result.error("INVALID_ARGUMENT", "event parameter is required", null)
                        return@setMethodCallHandler
                    }
                    
                    pendingResult = result
                    currentAmberRequestType = "sign_event"
                    
                    val currentPackage = packageName
                    
                    // NIP-55 format: パラメータをIntentのextrasとして送信
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = android.net.Uri.parse("nostrsigner:$eventJson")
                        `package` = "com.greenart7c3.nostrsigner"
                        // Amberが期待するextras
                        putExtra("type", "sign_event")
                        putExtra("package", currentPackage)
                        putExtra("appName", "Meiso")  // アプリ名も送信
                    }
                    
                    try {
                        android.util.Log.d("MainActivity", "✍️ Launching Amber for signing with startActivityForResult")
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, AMBER_REQUEST_CODE)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to launch Amber for signing", e)
                        result.error("AMBER_ERROR", "Failed to launch Amber: ${e.message}", null)
                        pendingResult = null
                    }
                }
                "encryptNip44WithAmber" -> {
                    // AmberでNIP-44暗号化するリクエスト
                    val plaintext = call.argument<String>("plaintext")
                    val pubkey = call.argument<String>("pubkey")
                    
                    if (plaintext == null || pubkey == null) {
                        result.error("INVALID_ARGUMENT", "plaintext and pubkey parameters are required", null)
                        return@setMethodCallHandler
                    }
                    
                    pendingResult = result
                    currentAmberRequestType = "nip44_encrypt"
                    
                    val currentPackage = packageName
                    
                    // NIP-55 format
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = android.net.Uri.parse("nostrsigner:$plaintext")
                        `package` = "com.greenart7c3.nostrsigner"
                        putExtra("type", "nip44_encrypt")
                        putExtra("pubkey", pubkey)
                        putExtra("package", currentPackage)
                        putExtra("appName", "Meiso")  // アプリ名も送信
                    }
                    
                    try {
                        android.util.Log.d("MainActivity", "🔐 Launching Amber for NIP-44 encryption with startActivityForResult")
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, AMBER_REQUEST_CODE)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to launch Amber for encryption", e)
                        result.error("AMBER_ERROR", "Failed to launch Amber: ${e.message}", null)
                        pendingResult = null
                    }
                }
                "decryptNip44WithAmber" -> {
                    // AmberでNIP-44復号化するリクエスト
                    val ciphertext = call.argument<String>("ciphertext")
                    val pubkey = call.argument<String>("pubkey")
                    
                    if (ciphertext == null || pubkey == null) {
                        result.error("INVALID_ARGUMENT", "ciphertext and pubkey parameters are required", null)
                        return@setMethodCallHandler
                    }
                    
                    pendingResult = result
                    currentAmberRequestType = "nip44_decrypt"
                    
                    val currentPackage = packageName
                    
                    // NIP-55 format
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = android.net.Uri.parse("nostrsigner:$ciphertext")
                        `package` = "com.greenart7c3.nostrsigner"
                        putExtra("type", "nip44_decrypt")
                        putExtra("pubkey", pubkey)
                        putExtra("package", currentPackage)
                        putExtra("appName", "Meiso")  // アプリ名も送信
                    }
                    
                    try {
                        android.util.Log.d("MainActivity", "🔓 Launching Amber for NIP-44 decryption with startActivityForResult")
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, AMBER_REQUEST_CODE)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to launch Amber for decryption", e)
                        result.error("AMBER_ERROR", "Failed to launch Amber: ${e.message}", null)
                        pendingResult = null
                    }
                }
                "launchAmber" -> {
                    // Amberアプリを起動
                    try {
                        val intent = packageManager.getLaunchIntentForPackage("com.greenart7c3.nostrsigner")
                        if (intent != null) {
                            startActivity(intent)
                            result.success(null)
                        } else {
                            result.error("NOT_INSTALLED", "Amber is not installed", null)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", "Failed to launch Amber: ${e.message}", null)
                    }
                }
                "openAmberInStore" -> {
                    // Google PlayでAmberを開く
                    try {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            data = android.net.Uri.parse("https://play.google.com/store/apps/details?id=com.greenart7c3.nostrsigner")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", "Failed to open Play Store: ${e.message}", null)
                    }
                }
                "signEventWithAmberContentProvider" -> {
                    // ContentProvider経由でAmberにイベント署名を依頼（バックグラウンド処理）
                    val eventJson = call.argument<String>("event")
                    val npub = call.argument<String>("npub")
                    
                    if (eventJson == null || npub == null) {
                        result.error("INVALID_ARGUMENT", "event and npub parameters are required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val uri = android.net.Uri.parse("content://com.greenart7c3.nostrsigner.SIGN_EVENT")
                        val cursor = contentResolver.query(
                            uri,
                            arrayOf(eventJson, "", npub),  // projection: [event, pubkey, npub]
                            null,  // selection
                            null,  // selectionArgs
                            null   // sortOrder
                        )
                        
                        if (cursor != null && cursor.moveToFirst()) {
                            val rejectedIndex = cursor.getColumnIndex("rejected")
                            if (rejectedIndex >= 0) {
                                val rejected = cursor.getString(rejectedIndex)
                                cursor.close()
                                result.error("AMBER_REJECTED", "Permission not granted. User needs to approve in Amber.", null)
                                return@setMethodCallHandler
                            }
                            
                            val signatureIndex = cursor.getColumnIndex("signature")
                            val eventIndex = cursor.getColumnIndex("event")
                            
                            val signature = if (signatureIndex >= 0) cursor.getString(signatureIndex) else null
                            val signedEvent = if (eventIndex >= 0) cursor.getString(eventIndex) else null
                            
                            cursor.close()
                            
                            if (signedEvent != null) {
                                android.util.Log.d("MainActivity", "✅ Event signed via ContentProvider (background)")
                                result.success(signedEvent)
                            } else if (signature != null) {
                                android.util.Log.d("MainActivity", "✅ Signature obtained via ContentProvider (background)")
                                result.success(signature)
                            } else {
                                result.error("AMBER_ERROR", "No valid response from Amber", null)
                            }
                        } else {
                            result.error("AMBER_ERROR", "No response from Amber ContentProvider", null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to sign event via ContentProvider", e)
                        result.error("AMBER_ERROR", "Failed to sign event: ${e.message}", null)
                    }
                }
                "encryptNip44WithAmberContentProvider" -> {
                    // ContentProvider経由でAmberにNIP-44暗号化を依頼（バックグラウンド処理）
                    val plaintext = call.argument<String>("plaintext")
                    val pubkey = call.argument<String>("pubkey")
                    val npub = call.argument<String>("npub")
                    
                    if (plaintext == null || pubkey == null || npub == null) {
                        result.error("INVALID_ARGUMENT", "plaintext, pubkey, and npub parameters are required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val uri = android.net.Uri.parse("content://com.greenart7c3.nostrsigner.NIP44_ENCRYPT")
                        val cursor = contentResolver.query(
                            uri,
                            arrayOf(plaintext, pubkey, npub),  // projection: [content, pubkey, npub]
                            null,
                            null,
                            null
                        )
                        
                        if (cursor != null && cursor.moveToFirst()) {
                            val rejectedIndex = cursor.getColumnIndex("rejected")
                            if (rejectedIndex >= 0) {
                                cursor.close()
                                result.error("AMBER_REJECTED", "Permission not granted. User needs to approve in Amber.", null)
                                return@setMethodCallHandler
                            }
                            
                            val resultIndex = cursor.getColumnIndex("result")
                            val encryptedContent = if (resultIndex >= 0) cursor.getString(resultIndex) else null
                            
                            cursor.close()
                            
                            if (encryptedContent != null) {
                                android.util.Log.d("MainActivity", "✅ Content encrypted via ContentProvider (background)")
                                result.success(encryptedContent)
                            } else {
                                result.error("AMBER_ERROR", "No valid response from Amber", null)
                            }
                        } else {
                            result.error("AMBER_ERROR", "No response from Amber ContentProvider", null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to encrypt via ContentProvider", e)
                        result.error("AMBER_ERROR", "Failed to encrypt: ${e.message}", null)
                    }
                }
                "decryptNip44WithAmberContentProvider" -> {
                    // ContentProvider経由でAmberにNIP-44復号化を依頼（バックグラウンド処理）
                    val ciphertext = call.argument<String>("ciphertext")
                    val pubkey = call.argument<String>("pubkey")
                    val npub = call.argument<String>("npub")
                    
                    if (ciphertext == null || pubkey == null || npub == null) {
                        result.error("INVALID_ARGUMENT", "ciphertext, pubkey, and npub parameters are required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val uri = android.net.Uri.parse("content://com.greenart7c3.nostrsigner.NIP44_DECRYPT")
                        val cursor = contentResolver.query(
                            uri,
                            arrayOf(ciphertext, pubkey, npub),  // projection: [content, pubkey, npub]
                            null,
                            null,
                            null
                        )
                        
                        if (cursor != null && cursor.moveToFirst()) {
                            val rejectedIndex = cursor.getColumnIndex("rejected")
                            if (rejectedIndex >= 0) {
                                cursor.close()
                                result.error("AMBER_REJECTED", "Permission not granted. User needs to approve in Amber.", null)
                                return@setMethodCallHandler
                            }
                            
                            val resultIndex = cursor.getColumnIndex("result")
                            val decryptedContent = if (resultIndex >= 0) cursor.getString(resultIndex) else null
                            
                            cursor.close()
                            
                            if (decryptedContent != null) {
                                android.util.Log.d("MainActivity", "✅ Content decrypted via ContentProvider (background)")
                                result.success(decryptedContent)
                            } else {
                                result.error("AMBER_ERROR", "No valid response from Amber", null)
                            }
                        } else {
                            result.error("AMBER_ERROR", "No response from Amber ContentProvider", null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to decrypt via ContentProvider", e)
                        result.error("AMBER_ERROR", "Failed to decrypt: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // FlutterEngine準備完了後、保留されたIntentを処理
        pendingIntent?.let { 
            android.util.Log.d("MainActivity", "🚀 Processing pending Amber intent")
            handleAmberResponse(it)
            pendingIntent = null
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        android.util.Log.d("MainActivity", "📨 onNewIntent called")
        // 新しいIntentを現在のIntentとして設定
        setIntent(intent)
        handleAmberResponse(intent)
    }
    
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        android.util.Log.d("MainActivity", "🎯 onActivityResult called - requestCode: $requestCode, resultCode: $resultCode")
        
        if (requestCode == AMBER_REQUEST_CODE) {
            if (resultCode == RESULT_OK && data != null) {
                android.util.Log.d("MainActivity", "✅ Amber returned successfully")
                
                // Amberから返されたデータを取得
                // Amberは get_public_key の場合も "result" または "signature" に公開鍵を入れる
                val result = data.getStringExtra("result") ?: data.getStringExtra("signature")
                val signedEvent = data.getStringExtra("event")
                val id = data.getStringExtra("id")
                val error = data.getStringExtra("error")
                val rejected = data.getStringExtra("rejected")
                
                android.util.Log.d("MainActivity", "Amber returned (type: $currentAmberRequestType) - result: ${result?.take(50)}..., event: ${signedEvent?.take(50)}..., error: $error, rejected: $rejected")
                
                when {
                    rejected != null -> {
                        // ユーザーが拒否した
                        android.util.Log.w("MainActivity", "⚠️ User rejected the request in Amber")
                        pendingResult?.error("AMBER_REJECTED", "User rejected the request", null)
                        pendingResult = null
                        currentAmberRequestType = null  // リセット
                        
                        eventSink?.error("AMBER_REJECTED", "User rejected the request", null)
                    }
                    error != null -> {
                        // エラーが発生
                        android.util.Log.e("MainActivity", "❌ Amber returned error: $error")
                        pendingResult?.error("AMBER_ERROR", error, null)
                        pendingResult = null
                        currentAmberRequestType = null  // リセット
                        
                        eventSink?.error("AMBER_ERROR", error, null)
                    }
                    result != null || signedEvent != null -> {
                        // 成功レスポンス - リクエストタイプに応じて適切な値を返す
                        val responseValue = when (currentAmberRequestType) {
                            "sign_event" -> signedEvent ?: result  // sign_event の場合は event を優先
                            else -> result  // get_public_key, nip44_encrypt, nip44_decrypt はすべて result を使用
                        }
                        
                        android.util.Log.d("MainActivity", "Amber returned for type '$currentAmberRequestType': ${responseValue?.take(50)}...")
                        
                        // MethodChannelのpendingResultがあれば返す（Stringとして）
                        pendingResult?.success(responseValue)
                        pendingResult = null
                        currentAmberRequestType = null  // リセット
                        
                        // EventChannelにも送信（念のため）
                        if (responseValue != null) {
                            eventSink?.success(responseValue)
                        }
                        
                        android.util.Log.d("MainActivity", "✨ Result sent to Flutter as String")
                    }
                    else -> {
                        android.util.Log.w("MainActivity", "⚠️ No valid response data from Amber")
                        pendingResult?.error("AMBER_ERROR", "No valid response from Amber", null)
                        pendingResult = null
                        currentAmberRequestType = null  // リセット
                        
                        eventSink?.error("AMBER_ERROR", "No valid response from Amber", null)
                    }
                }
            } else {
                // キャンセルまたはエラー
                android.util.Log.w("MainActivity", "⚠️ Amber request cancelled or failed - resultCode: $resultCode")
                pendingResult?.error("AMBER_CANCELLED", "Request was cancelled", null)
                pendingResult = null
                currentAmberRequestType = null  // リセット
                
                eventSink?.error("AMBER_CANCELLED", "Request was cancelled", null)
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        android.util.Log.d("MainActivity", "▶️ onResume called")
        
        // SharedPreferencesから保留中のAmber URIを確認
        val prefs = getSharedPreferences("amber_prefs", MODE_PRIVATE)
        val pendingUriString = prefs.getString("pending_amber_uri", null)
        
        if (pendingUriString != null) {
            android.util.Log.d("MainActivity", "🚀 Found pending Amber URI in SharedPreferences: $pendingUriString")
            
            // FlutterEngineとEventChannelの準備を待つ
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    // URIから Intent を再構築
                    val uri = android.net.Uri.parse(pendingUriString)
                    val reconstructedIntent = Intent().apply {
                        data = uri
                    }
                    
                    android.util.Log.d("MainActivity", "📤 Processing pending Amber intent")
                    handleAmberResponse(reconstructedIntent)
                    
                    // 処理完了後、SharedPreferencesから削除
                    prefs.edit().remove("pending_amber_uri").apply()
                    android.util.Log.d("MainActivity", "✅ Pending Amber URI cleared")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "❌ Error processing pending Amber intent", e)
                    prefs.edit().remove("pending_amber_uri").apply()
                }
            }, 1000) // 1秒待機してFlutterEngineとEventChannelが確実に準備完了するのを待つ
        }
        
        // メンバー変数のpendingIntentも処理（念のため）
        pendingIntent?.let { 
            if (pendingUriString == null) { // SharedPreferencesで処理されていない場合のみ
                android.util.Log.d("MainActivity", "🚀 Processing pending Amber intent from member variable")
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    handleAmberResponse(it)
                    pendingIntent = null
                }, 1000)
            } else {
                pendingIntent = null // SharedPreferencesで処理されるので、メンバー変数はクリア
            }
        }
    }
    
    private fun handleAmberResponse(intent: Intent) {
        val data = intent.data ?: return
        val scheme = data.scheme ?: return
        
        // すでに処理済みのIntentをスキップ
        val isProcessed = intent.getBooleanExtra("meiso_processed", false)
        if (isProcessed) {
            android.util.Log.d("MainActivity", "Intent already processed, skipping")
            return
        }
        
        android.util.Log.d("MainActivity", "🎯 Processing Amber response - scheme: $scheme, data: $data")
        android.util.Log.d("MainActivity", "Full URI: ${data.toString()}")
        
        // Amberからのレスポンスを処理 (meiso:// スキーム)
        if (scheme == "meiso") {
            try {
                val uriString = data.toString()
                
                // Amberが返す形式に対応:
                // 正常: meiso://result?pubkey={hex}
                // 実際: meiso://result{hex} (クエリパラメータなし)
                
                var pubkey: String? = data.getQueryParameter("pubkey")
                var signedEvent: String? = data.getQueryParameter("event")
                var signature: String? = data.getQueryParameter("signature")
                var id: String? = data.getQueryParameter("id")
                var result: String? = data.getQueryParameter("result")
                val error: String? = data.getQueryParameter("error")
                
                // クエリパラメータがない場合、URIパスから直接抽出
                if (pubkey == null && signedEvent == null && result == null) {
                    val path = data.host + data.path
                    android.util.Log.d("MainActivity", "Parsing from path: $path")
                    
                    if (path.startsWith("result")) {
                        // "result" の後の文字列を抽出
                        val dataString = path.substring(6) // "result" (6文字) を除く
                        
                        when {
                            dataString.length == 64 && dataString.matches(Regex("^[0-9a-fA-F]{64}$")) -> {
                                // 公開鍵（64文字のhex）
                                pubkey = dataString
                                android.util.Log.d("MainActivity", "✅ Extracted pubkey from path: $pubkey")
                            }
                            dataString.startsWith("{") || dataString.startsWith("[") -> {
                                // JSON形式（NIP-44復号化結果など）
                                result = dataString
                                android.util.Log.d("MainActivity", "✅ Extracted result (JSON) from path: ${result.take(100)}...")
                            }
                            dataString.isNotEmpty() -> {
                                // その他のデータ（暗号化されたペイロードなど）
                                result = dataString
                                android.util.Log.d("MainActivity", "✅ Extracted result (other) from path: ${result.take(100)}...")
                            }
                            else -> {
                                android.util.Log.w("MainActivity", "⚠️ Empty data after 'result'")
                            }
                        }
                    }
                }
                
                android.util.Log.d("MainActivity", "Parsed - id: $id, signature: $signature, pubkey: $pubkey, result: $result, error: $error")
                
                // pendingResultがnullの場合、EventSinkを使用
                if (pendingResult == null) {
                    android.util.Log.w("MainActivity", "pendingResult is null - using EventSink instead")
                    
                    val resultMap = mutableMapOf<String, Any?>()
                    
                    when {
                        error != null -> {
                            android.util.Log.e("MainActivity", "Amber error: $error")
                            resultMap["type"] = "error"
                            resultMap["error"] = error
                        }
                        pubkey != null -> {
                            android.util.Log.d("MainActivity", "Amber returned pubkey: $pubkey")
                            resultMap["type"] = "pubkey"
                            resultMap["data"] = pubkey
                        }
                        signedEvent != null -> {
                            android.util.Log.d("MainActivity", "Amber returned signed event")
                            resultMap["type"] = "signedEvent"
                            resultMap["data"] = signedEvent
                        }
                        result != null -> {
                            android.util.Log.d("MainActivity", "Amber returned result: ${result.take(50)}...")
                            resultMap["type"] = "result"
                            resultMap["result"] = result
                        }
                        signature != null && id != null -> {
                            android.util.Log.d("MainActivity", "Amber returned signature")
                            resultMap["type"] = "signature"
                            resultMap["data"] = signature
                            resultMap["id"] = id
                        }
                        else -> {
                            android.util.Log.w("MainActivity", "No valid response from Amber")
                            resultMap["type"] = "error"
                            resultMap["error"] = "No valid response from Amber"
                        }
                    }
                    
                    if (eventSink != null) {
                        android.util.Log.d("MainActivity", "✅ Sending response via EventSink immediately")
                        eventSink?.success(resultMap)
                    } else {
                        android.util.Log.w("MainActivity", "📦 No eventSink available - buffering response")
                        bufferedResponse = resultMap
                    }
                    
                    // Intentを処理済みとしてマーク
                    intent.putExtra("meiso_processed", true)
                    intent.data = null
                    android.util.Log.d("MainActivity", "✨ Intent processed and cleared")
                    return
                }
                
                when {
                    error != null -> {
                        android.util.Log.e("MainActivity", "Amber returned error: $error")
                        pendingResult?.error("AMBER_USER_REJECTED", error, null)
                    }
                    pubkey != null -> {
                        // get_public_keyのレスポンス
                        android.util.Log.d("MainActivity", "Amber returned pubkey: $pubkey")
                        pendingResult?.success(pubkey)
                    }
                    signedEvent != null -> {
                        // sign_eventのレスポンス（署名済みイベントJSON）
                        android.util.Log.d("MainActivity", "Amber returned signed event")
                        pendingResult?.success(signedEvent)
                    }
                    result != null -> {
                        // nip44_encrypt/nip44_decryptのレスポンス
                        android.util.Log.d("MainActivity", "Amber returned result: ${result.take(50)}...")
                        pendingResult?.success(result)
                    }
                    signature != null && id != null -> {
                        // sign_eventのレスポンス（署名とID）
                        android.util.Log.d("MainActivity", "Amber returned signature and id")
                        pendingResult?.success(signature)
                    }
                    else -> {
                        android.util.Log.w("MainActivity", "No valid response parameter found from Amber")
                        pendingResult?.error("AMBER_ERROR", "No valid response from Amber", null)
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to process Amber response", e)
                pendingResult?.error("AMBER_ERROR", "Failed to process Amber response: ${e.message}", null)
            } finally {
                pendingResult = null
                // Intentを処理済みとしてマーク
                intent.putExtra("meiso_processed", true)
                intent.data = null
                android.util.Log.d("MainActivity", "✨ Intent processed and cleared (MethodChannel path)")
            }
        } else {
            android.util.Log.d("MainActivity", "Intent not matching criteria - scheme: $scheme")
        }
    }
}
