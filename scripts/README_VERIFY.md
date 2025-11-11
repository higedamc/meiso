# グループリスト機能の検証方法

このドキュメントでは、Meisoのグループリスト機能を検証する方法を説明します。

## セットアップ

### 1. .envファイルの作成

```bash
# scriptsディレクトリに移動
cd scripts

# .env.exampleをコピーして.envを作成
cp .env.example .env
```

### 2. .envファイルの編集

`scripts/.env`ファイルを開いて、実際の公開鍵を設定します：

```bash
# Aliceの公開鍵（npub形式）
ALICE_NPUB=npub1abc123...

# Bobの公開鍵（npub形式）
BOB_NPUB=npub1def456...

# 使用するNostrリレー（オプション、デフォルト: wss://relay.damus.io）
RELAY_URL=wss://relay.damus.io
```

## 検証の実行

### 自動検証スクリプト

```bash
./scripts/verify_group_lists.sh
```

このスクリプトは以下をチェックします：

1. Aliceが作成したグループリストの存在確認
2. pタグにBobの公開鍵が含まれているか確認
3. Bobの視点でグループリストが検索できるか確認
4. イベント構造の正確性確認

### 手動検証

#### Aliceのグループリストを検索

```bash
nak req -k 30001 --author npub1alice... wss://relay.damus.io | jq
```

#### Bobがメンバーとして含まれるグループを検索

```bash
nak req -k 30001 -p npub1bob... wss://relay.damus.io | jq
```

#### 特定のイベント詳細を確認

```bash
# イベントID指定
nak req -i <event_id> wss://relay.damus.io | jq '.tags'

# dタグでフィルタ
nak req -k 30001 wss://relay.damus.io | jq 'select(.tags[][] | select(startswith("meiso-group-")))'
```

## トラブルシューティング

### .envファイルが読み込まれない

```bash
# .envファイルの存在確認
ls -la scripts/.env

# .envファイルの内容確認
cat scripts/.env

# 権限確認
chmod 600 scripts/.env
```

### 公開鍵の形式

- **npub形式**: `npub1...` で始まる形式
- **hex形式**: 64文字の16進数文字列

検証スクリプトはnpub形式を使用します。hex形式の場合、nakで変換できます：

```bash
# hex → npub変換
nak encode npub <hex_pubkey>

# npub → hex変換
nak decode <npub>
```

## 期待される結果

### 成功時の出力例

```
🔍 Meiso グループリスト機能検証
================================

📄 .envファイルを読み込み中: /Users/apple/work/meiso/scripts/.env
✅ .envファイルを読み込みました

👤 Alice: npub1abc123...
👤 Bob: npub1def456...

🔎 Step 1: Aliceが作成したグループリストを検索...
✅ Aliceのグループリスト: 2個

📋 グループリストの詳細:
  - d tag: meiso-group-uuid1
    title: Team Tasks
    eventId: abc123...
    members (p tags): pubkey1, pubkey2

🔎 Step 2: Bobの公開鍵がpタグに含まれているか確認...
Bob hex pubkey: def456...
✅ Bobがメンバーとして含まれています

🔎 Step 3: Bobの視点でグループリストを検索...
✅ Bobが参照できるグループリスト: 2個

✅ 検証完了！

📊 結果サマリー:
  - Aliceのグループリスト: 2個
  - Bobが参照可能: 2個
  - pタグによる検索: 正常
```

## nakのインストール

nakがインストールされていない場合：

```bash
# Goが必要
go install github.com/fiatjaf/nak@latest

# または
brew install nak
```

## 参考資料

- [Meisoグループリスト実装記録](anytype://...)
- [NIP-01: Basic protocol](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [nak - Nostr Army Knife](https://github.com/fiatjaf/nak)

