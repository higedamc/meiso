# MLS統合テスト完全フロー

## 前提条件

- Alice と Bob 両方が Amber モードで Meiso にログイン済み
- 両デバイスがインターネットに接続

---

## 📱 Alice デバイス: アプリ起動からの流れ

### Step 1: アプリ起動 & Nostr 初期化
1. **アプリ起動**
2. ✅ Amber で公開鍵取得（自動）
3. ✅ Nostr クライアント初期化（自動）
   - デフォルトリレー接続:
     - wss://relay.damus.io
     - wss://nos.lol
     - wss://relay.nostr.band
     - wss://nostr.wine
4. ✅ TODO 同期（自動）
5. ✅ カスタムリスト同期（自動）

### Step 2: 待機（Bob の Key Package 公開を待つ）
- **重要**: Bob が先に Key Package を公開する必要があります
- Bob の準備完了を確認してから次に進む

### Step 3: MLS テストダイアログ
1. **設定画面** を開く
2. **「MLS 統合テスト」** タイルをタップ
3. MLS テストダイアログが開く

### Step 4: 自分の Key Package 準備
1. **「KP 生成」** ボタンをタップ
   - ✅ MLS Key Package 生成
   - ✅ ログに表示される
2. **「KP 公開」** ボタンをタップ（オレンジ色）
   - ✅ Amber で署名（自動プロンプト）
   - ✅ Kind 10443 イベントとして公開
   - ✅ ログに Event ID 表示

### Step 5: Bob の Key Package 取得
1. **「相手の npub」** フィールドに **Bob の npub** をペースト
   - 例: `npub1v27rk6mc39tuy...`
2. **「取得」** ボタンをタップ
   - ✅ Bob の Kind 10443 イベントをリレーから取得
   - ✅ ログに Key Package 情報表示
   - ⚠️ ここで「相手がまだ Key Package を公開していない」エラーが出る場合:
     - Bob が KP 公開していない
     - リレー同期に時間がかかっている（数秒待って再試行）
     - Nostr クライアント未初期化（アプリ再起動）

### Step 6: 2 人グループ作成 & 招待送信
1. **「2 人グループ作成」** ボタンをタップ
   - ✅ MLS グループ作成
   - ✅ Bob を招待（Welcome Message 生成）
   - ✅ Kind 30078 招待イベント送信
   - ✅ ログに完了メッセージ表示
2. ダイアログを閉じる

---

## 📱 Bob デバイス: アプリ起動からの流れ

### Step 1: アプリ起動 & Nostr 初期化
1. **アプリ起動**
2. ✅ Amber で公開鍵取得（自動）
3. ✅ Nostr クライアント初期化（自動）
   - デフォルトリレー接続
4. ✅ TODO 同期（自動）
5. ✅ カスタムリスト同期（自動）

### Step 2: MLS テストダイアログ
1. **設定画面** を開く
2. **「MLS 統合テスト」** タイルをタップ
3. MLS テストダイアログが開く

### Step 3: 自分の Key Package 準備（先に実行！）
1. **「KP 生成」** ボタンをタップ
   - ✅ MLS Key Package 生成
2. **「KP 公開」** ボタンをタップ（オレンジ色）
   - ✅ Amber で署名
   - ✅ Kind 10443 イベント公開
3. ダイアログを閉じる

### Step 4: Alice からの招待を待つ
- Alice がグループ作成 & 招待送信するまで待機

### Step 5: 招待を受信
1. **SOMEDAY 画面** を開く
2. **Pull-to-refresh**（画面を下にスワイプ）
   - ✅ Kind 30078 招待イベントを同期
3. 招待バッジ付きリストが表示される
   - 📧 **「2 PERSON TEST GROUP」**
   - グループアイコン + オレンジ色の「招待」バッジ

### Step 6: グループに参加
1. 招待リストを**タップ**
2. グループ招待ダイアログが表示
   - グループ名: 「2 PERSON TEST GROUP」
   - 招待者: Alice の情報
3. **「参加する」** ボタンをタップ
   - ✅ MLS DB 初期化
   - ✅ Welcome Message 処理
   - ✅ MLS グループに参加
4. 成功メッセージ表示: 「✅ 2 PERSON TEST GROUP に参加しました」
5. 招待バッジが消え、通常のグループリストとして表示

---

## ⚠️ トラブルシューティング

### 「相手がまだ Key Package を公開していない可能性があります」エラー

#### 原因 1: Nostr クライアント未初期化
**解決策**:
1. アプリを完全に終了
2. 再起動
3. メイン画面（TODAY）が表示されるまで待つ（5-10 秒）
4. 設定画面を開く
5. MLS テストを実行

#### 原因 2: Bob が KP 公開していない
**解決策**:
- Bob デバイスで「KP 生成」→「KP 公開」が完了していることを確認
- Bob のログに「✅ Key Package 公開成功！」が表示されていることを確認

#### 原因 3: リレー同期の遅延
**解決策**:
- Bob の KP 公開後、10-15 秒待つ
- Alice 側で「取得」を再試行

#### 原因 4: リレー接続の問題
**解決策**:
1. 設定画面 → リレー管理
2. デフォルトリレーが接続されていることを確認
3. 必要に応じてリレーを再接続

---

## ✅ 成功の確認

### Alice 側
- ログに「✅ グループ招待通知送信完了！」
- ダイアログに Event ID 表示

### Bob 側
- SOMEDAY に招待バッジ付きリスト表示
- 参加後に「✅ 2 PERSON TEST GROUP に参加しました」
- 招待バッジが消える

---

## 🎯 推奨フロー（順序厳守）

```
1. Bob:   アプリ起動 → 設定 → MLS テスト
2. Bob:   KP 生成 → KP 公開 → ダイアログを閉じる
3. Alice: アプリ起動 → 設定 → MLS テスト
4. Alice: KP 生成 → KP 公開
5. Alice: Bob の npub で KP 取得
6. Alice: 2 人グループ作成
7. Bob:   SOMEDAY で Pull-to-refresh
8. Bob:   招待リストをタップ → 参加
```

---

## 📝 注意事項

- **Bob が先に KP 公開**: Alice が取得するため
- **アプリ起動後 5-10 秒待つ**: Nostr クライアント初期化完了まで
- **Amber プロンプト**: 署名時に必ず表示される（承認が必要）
- **リレー同期**: 数秒かかる場合がある（焦らない）
- **エラー時**: アプリ再起動が最も確実

---

## 🐛 デバッグ情報

### Alice 側ログ確認
```
📤 Key Package 公開開始...
✅ Key Package 公開成功！
📝 Event ID: abc123...
🔍 Key Package 取得テスト開始
✅ Key Package 取得成功！
📦 Step 2: グループ招待通知送信
✅ グループ招待通知送信完了！
```

### Bob 側ログ確認
```
📤 Key Package 公開開始...
✅ Key Package 公開成功！
📥 [GroupInvitations] Syncing group invitations...
✅ [GroupInvitations] Found 1 pending invitations
🎉 [GroupInvitation] Accepting invitation for: 2 PERSON TEST GROUP
✅ [GroupInvitation] Successfully joined MLS group
```

