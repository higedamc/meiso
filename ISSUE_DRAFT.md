# Bug: Key Package取得がCREATE GROUP LIST画面で失敗する

## 問題の概要

設定画面のPoC画面（MLSテストダイアログ）からnpub経由でKey Packageを取得することはできるが、CREATE GROUP LIST画面から同じnpubでKey Packageを取得しようとすると、Nostrクライアント未初期化エラーで失敗する。

## 再現手順

### ✅ 成功するケース（PoC画面）
1. アプリを起動
2. 設定画面を開く
3. 「MLS統合テスト」タイルをタップ
4. 「相手のnpub」フィールドに有効なnpubを入力
5. 「取得」ボタンをタップ
6. ✅ Key Packageが正常に取得される

### ❌ 失敗するケース（CREATE GROUP LIST画面）
1. アプリを起動
2. SOMEDAY画面を開く
3. 「+」ボタンをタップ → 「CREATE GROUP LIST」を選択
4. 「MLS (Beta)」タブを選択
5. 「Member npub」フィールドに同じnpubを入力
6. ダウンロードアイコンをタップ
7. ❌ エラー: `Nostrクライアント [default] が初期化されていません`

## 期待される動作

CREATE GROUP LIST画面からもPoC画面と同様にKey Packageを取得できるべき。

## 根本原因

### タイミング問題
- **PoC画面**: 設定画面経由でアクセスするため、アプリ起動後に十分な時間が経過しており、Nostrクライアント初期化が完了している
- **CREATE GROUP LIST画面**: 直接開かれる可能性があり、Nostrクライアント初期化が完了していない

### コードレベルの問題

**Rust側**: `rust/src/api.rs:3024-3074`

```rust
pub fn fetch_key_package_by_npub(npub: String) -> Result<String> {
    fetch_key_package_by_npub_with_client_id(npub, None)
}

pub fn fetch_key_package_by_npub_with_client_id(
    npub: String,
    client_id: Option<String>,
) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;  // ← ここでエラー
        // ...
    })
}

async fn get_client(client_id: Option<String>) -> Result<MeisoNostrClient> {
    let id = client_id.unwrap_or_else(|| DEFAULT_CLIENT_ID.to_string());
    let clients = NOSTR_CLIENTS.lock().await;
    clients
        .get(&id)
        .cloned()
        .with_context(|| format!("Nostrクライアント [{}] が初期化されていません", id))
        // ← エラーメッセージ
}
```

**Flutter側**: `lib/widgets/add_group_list_dialog.dart:154-179`（修正前）

```dart
Future<void> _fetchKeyPackage() async {
    // ...
    final nostrService = ref.read(nostrServiceProvider);
    final keyPackage = await nostrService.fetchKeyPackageByNpub(npub);
    // ← Nostrクライアント初期化チェックなし
}
```

## 解決策（実装済み）

### 1. Nostrクライアント初期化待機

Key Package取得前に、Nostrクライアントの初期化完了を確認し、最大5秒待機する。

```dart
// Nostrクライアント初期化確認（最大5秒待機）
final isInitialized = ref.read(nostrInitializedProvider);
if (!isInitialized) {
    AppLogger.warning('⚠️ [AddGroupListDialog] Nostrクライアントが初期化されていません。待機中...');
    
    // 最大10回（5秒）待機
    bool initCompleted = false;
    for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (ref.read(nostrInitializedProvider)) {
            AppLogger.info('✅ [AddGroupListDialog] Nostrクライアント初期化完了');
            initCompleted = true;
            break;
        }
    }
    
    // まだ初期化されていない場合はエラー
    if (!initCompleted) {
        throw Exception('Nostrクライアントの初期化がタイムアウトしました。アプリを再起動してください。');
    }
}
```

### 2. 初期化状態のUI表示

ダイアログ上部に初期化状態を視覚的に表示し、ユーザーに待機を促す。

```dart
// Nostr初期化状態の表示
if (!isNostrInitialized)
    Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Colors.orange.withOpacity(0.3),
            ),
        ),
        child: Row(
            children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Nostr接続を初期化中...\nKey Package取得は初期化完了後に可能です',
                        style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 11,
                        ),
                    ),
                ),
            ],
        ),
    ),
```

### 3. ダウンロードボタンの無効化

初期化完了まで、Key Package取得ボタンを無効化する。

```dart
IconButton(
    icon: const Icon(Icons.download),
    tooltip: isNostrInitialized 
        ? 'Fetch Key Package' 
        : 'Nostr初期化中...',
    color: isNostrInitialized 
        ? null 
        : Colors.grey,
    onPressed: isNostrInitialized 
        ? _fetchKeyPackage 
        : null,
),
```

## 影響範囲

- **影響あり**: CREATE GROUP LIST画面からのMLS招待フロー
- **影響なし**: PoC画面（設定画面内）でのテスト機能

## 優先度

**High** - Phase 8.1の主要機能（通常UXフローへのMLS統合）に影響

## テスト結果

### 修正前
- ❌ アプリ起動直後にCREATE GROUP LIST画面を開き、Key Package取得を試みると失敗
- ❌ エラーメッセージ: `Nostrクライアント [default] が初期化されていません`

### 修正後（期待される動作）
- ✅ アプリ起動直後でも、初期化待機により自動的に成功
- ✅ 初期化中はオレンジ色の警告バナーが表示される
- ✅ ダウンロードボタンが初期化完了まで無効化される
- ✅ 最大5秒待機してもタイムアウトした場合は明確なエラーメッセージ

## 関連ファイル

- `lib/widgets/add_group_list_dialog.dart` (154-179行, 344-379行, 557-607行, 728-739行)
- `lib/providers/nostr_provider.dart` (26行: `nostrInitializedProvider`定義)
- `rust/src/api.rs` (1031-1038行, 3024-3074行)

## 参考ドキュメント

- `docs/MLS_IMPLEMENTATION_STRATEGY.md`
- `docs/MLS_BETA_ROADMAP.md` (Phase 8.1)
- `docs/MLS_TEST_FLOW.md`

## コミット履歴

- `87ca7f7`: Phase 8.1 通常UXフローへのMLS統合完了
- `d2168d8`: Phase 6.1 - Key Package公開機能（Kind 10443）実装完了
- `a13dd10`: Phase 6.2 - npubからKey Package自動取得機能実装完了

---

**報告者**: Oracle  
**発見日**: 2025-11-11  
**修正日**: 2025-11-11  
**ブランチ**: `feature/amber-group-list-phase2`  
**ステータス**: ✅ 修正完了

