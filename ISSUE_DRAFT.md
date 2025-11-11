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

## テスト項目

### 🧪 テストシナリオ一覧

#### A. 基本機能テスト

**A-1: アプリ起動直後のKey Package取得（正常系）**
- [ ] **手順**:
  1. アプリを完全に終了
  2. アプリを起動
  3. 起動後**即座**にSOMEDAY画面 → 「+」 → 「CREATE GROUP LIST」を開く
  4. 「MLS (Beta)」タブを選択
  5. 有効なnpub（Key Package公開済み）を入力
  6. ダウンロードアイコンをタップ
- [ ] **期待される動作**:
  - オレンジ色の警告バナーが表示される: 「Nostr接続を初期化中...」
  - ダウンロードボタンがグレーアウトされている
  - 5秒以内にバナーが消え、ボタンが有効化される
  - Key Package取得が自動的に成功する
  - メンバーリストに✅アイコン付きで追加される
- [ ] **ログ確認**:
  ```
  ⚠️ [AddGroupListDialog] Nostrクライアントが初期化されていません。待機中...
  ✅ [AddGroupListDialog] Nostrクライアント初期化完了
  🔍 [AddGroupListDialog] Fetching Key Package for: npub1...
  ✅ [AddGroupListDialog] Key Package fetched successfully
  ```

**A-2: 初期化完了後のKey Package取得（正常系）**
- [ ] **手順**:
  1. アプリを起動してから5秒以上待機
  2. SOMEDAY画面 → 「+」 → 「CREATE GROUP LIST」を開く
  3. 「MLS (Beta)」タブを選択
  4. 有効なnpubを入力
  5. ダウンロードアイコンをタップ
- [ ] **期待される動作**:
  - オレンジ色の警告バナーが**表示されない**
  - ダウンロードボタンが最初から有効
  - Key Package取得が即座に成功
  - メンバーリストに追加される

**A-3: Key Package未公開のnpub（警告表示）**
- [ ] **手順**:
  1. Key Packageを公開していないnpubを入力
  2. ダウンロードアイコンをタップ
- [ ] **期待される動作**:
  - 警告ダイアログが表示される: 「Key Package未公開」
  - メンバーリストに⚠️アイコン付きで追加される
  - サブタイトル: 「Key Package未公開」（オレンジ色）
  - 再試行ボタン（🔄）が表示される

**A-4: Key Package再試行（リトライ機能）**
- [ ] **手順**:
  1. A-3で警告状態のメンバーの再試行ボタン（🔄）をタップ
- [ ] **期待される動作**:
  - 初期化待機ロジックが再度実行される
  - Key Packageが見つかれば✅アイコンに変わる
  - 見つからなければ警告メッセージを表示

#### B. エラーハンドリングテスト

**B-1: Nostr初期化タイムアウト（異常系）**
- [ ] **手順**:
  1. ネットワークを完全に遮断（機内モード）
  2. アプリを起動
  3. 即座にCREATE GROUP LIST画面を開く
  4. Key Package取得を試みる
- [ ] **期待される動作**:
  - 警告バナーが5秒間表示される
  - タイムアウト後、エラーメッセージ:  
    `Nostrクライアントの初期化がタイムアウトしました。アプリを再起動してください。`
  - メンバーは⚠️状態で追加される

**B-2: 無効なnpub入力（バリデーション）**
- [ ] **手順**:
  1. 無効なnpubを入力（例: `invalid_npub`）
  2. ダウンロードアイコンをタップ
- [ ] **期待される動作**:
  - Snackbar表示: 「有効なnpubを入力してください」
  - メンバーリストに追加されない

**B-3: 重複npub入力（重複チェック）**
- [ ] **手順**:
  1. 有効なnpubでKey Package取得成功
  2. 同じnpubを再度入力
  3. ダウンロードアイコンをタップ
- [ ] **期待される動作**:
  - Snackbar表示: 「このメンバーは既に追加されています」
  - メンバーリストに重複して追加されない

#### C. グループ作成フローテスト

**C-1: 警告メンバーを含むグループ作成**
- [ ] **手順**:
  1. メンバーA: Key Package取得成功（✅）
  2. メンバーB: Key Package未公開（⚠️）
  3. グループ名を入力
  4. 「CREATE」ボタンをタップ
- [ ] **期待される動作**:
  - 確認ダイアログ表示:  
    `一部のメンバーのKey Packageが未公開です`  
    `Key Packageが未公開: 1人`  
    `招待可能なメンバー: 1人`
  - 「作成する」を選択すると、メンバーBを除外してグループ作成
  - メンバーAのみに招待が送信される

**C-2: 全メンバーが警告状態（作成不可）**
- [ ] **手順**:
  1. メンバーA: Key Package未公開（⚠️）
  2. メンバーB: Key Package未公開（⚠️）
  3. 「CREATE」ボタンをタップ
- [ ] **期待される動作**:
  - Snackbar表示:  
    `⚠️ Key Packageが取得できたメンバーが必要です`
  - グループ作成が中断される

**C-3: 正常なグループ作成（2人）**
- [ ] **手順**:
  1. メンバーA: Key Package取得成功
  2. メンバーB: Key Package取得成功
  3. グループ名を入力
  4. 「CREATE」ボタンをタップ
- [ ] **期待される動作**:
  - グループ作成成功
  - Welcome Message送信成功
  - ダイアログが閉じる
  - SOMEDAY画面に新しいグループリストが表示される

#### D. UI/UX検証テスト

**D-1: 初期化警告バナーの表示/非表示**
- [ ] **テスト1: 起動直後**
  - バナーが表示される
  - オレンジ色の背景
  - ローディングアイコンが回転
  - 2行テキスト表示
- [ ] **テスト2: 初期化完了後**
  - バナーが自動的に消える
  - レイアウトがスムーズに再調整される

**D-2: ダウンロードボタンの状態変化**
- [ ] **未初期化時**:
  - アイコンがグレー
  - タップ不可
  - ツールチップ: 「Nostr初期化中...」
- [ ] **初期化完了後**:
  - アイコンが通常色
  - タップ可能
  - ツールチップ: 「Fetch Key Package」

**D-3: メンバーリストの表示**
- [ ] **成功メンバー**:
  - ✅ 緑色アイコン
  - サブタイトルなし
  - 削除ボタンのみ
- [ ] **警告メンバー**:
  - ⚠️ オレンジ色アイコン
  - サブタイトル: 「Key Package未公開」
  - 再試行ボタン + 削除ボタン

#### E. PoC画面との互換性テスト

**E-1: PoC画面での動作確認**
- [ ] **手順**:
  1. 設定画面 → 「MLS統合テスト」をタップ
  2. 相手のnpubを入力
  3. 「取得」ボタンをタップ
- [ ] **期待される動作**:
  - 従来通り正常に動作
  - Key Package取得成功
  - 初期化待機ロジックも同様に機能

#### F. ストレス＆エッジケーステスト

**F-1: 高速連打テスト**
- [ ] **手順**:
  1. アプリ起動直後
  2. ダウンロードボタンを連続でタップ（5回）
- [ ] **期待される動作**:
  - 初回のみ処理が実行される
  - 重複リクエストが発生しない
  - UIがクラッシュしない

**F-2: ネットワーク切り替えテスト**
- [ ] **手順**:
  1. 機内モードでアプリ起動
  2. CREATE GROUP LIST画面を開く
  3. Key Package取得を試みる（タイムアウト）
  4. 機内モードをOFF
  5. 再試行ボタンをタップ
- [ ] **期待される動作**:
  - タイムアウト後、再試行で成功
  - ネットワーク復帰が検知される

**F-3: 複数メンバー追加テスト（5人）**
- [ ] **手順**:
  1. 5人のnpubを順次追加
  2. 全員のKey Package取得を試みる
- [ ] **期待される動作**:
  - 全員が正常に追加される
  - メンバーリストがスクロール可能
  - パフォーマンス問題なし

### 📊 テスト結果

#### 修正前
- ❌ アプリ起動直後にCREATE GROUP LIST画面を開き、Key Package取得を試みると失敗
- ❌ エラーメッセージ: `Nostrクライアント [default] が初期化されていません`
- ❌ ユーザーフィードバックなし（突然のエラー）
- ❌ リトライ方法が不明

#### 修正後（期待される動作）
- ✅ アプリ起動直後でも、初期化待機により自動的に成功
- ✅ 初期化中はオレンジ色の警告バナーが表示される
- ✅ ダウンロードボタンが初期化完了まで無効化される
- ✅ 最大5秒待機してもタイムアウトした場合は明確なエラーメッセージ
- ✅ 警告メンバーには再試行ボタンが表示される
- ✅ グループ作成時に警告メンバーを自動除外

### 🎯 テスト合格基準

**必須項目（Must Pass）**:
- [ ] A-1: アプリ起動直後のKey Package取得が成功
- [ ] A-3: Key Package未公開のnpubで警告表示
- [ ] B-1: Nostr初期化タイムアウトで適切なエラー表示
- [ ] C-1: 警告メンバーを除外してグループ作成成功
- [ ] D-1: 初期化警告バナーの表示/非表示が正しく動作
- [ ] E-1: PoC画面での動作に影響なし

**推奨項目（Should Pass）**:
- [ ] A-4: Key Package再試行機能が正常動作
- [ ] B-2, B-3: バリデーションが適切に機能
- [ ] C-3: 正常な2人グループ作成が成功
- [ ] D-2, D-3: UI状態が正しく表示される

**オプション項目（Nice to Have）**:
- [ ] F-1, F-2, F-3: エッジケース＆ストレステスト

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

