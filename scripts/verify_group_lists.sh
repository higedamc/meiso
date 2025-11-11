#!/bin/bash
# グループリスト機能の検証スクリプト

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔍 Meiso グループリスト機能検証"
echo "================================"
echo ""

# .envファイルを読み込む（scriptsディレクトリ内）
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "📄 .envファイルを読み込み中: $ENV_FILE"
    # .envファイルから環境変数を読み込む（コメント行と空行をスキップ）
    # より確実な方法: 一時ファイルを経由
    TEMP_ENV=$(mktemp)
    grep -v '^#' "$ENV_FILE" | grep -v '^$' > "$TEMP_ENV"
    set -a
    source "$TEMP_ENV"
    set +a
    rm -f "$TEMP_ENV"
    echo "✅ .envファイルを読み込みました"
    echo ""
else
    echo "⚠️  .envファイルが見つかりません: $ENV_FILE"
    echo "💡 .env.exampleをコピーして.envを作成してください："
    echo "   cd $SCRIPT_DIR"
    echo "   cp .env.example .env"
    echo ""
    
    # 環境変数が直接設定されているかチェック
    if [ -z "$ALICE_NPUB" ] || [ -z "$BOB_NPUB" ]; then
        echo "❌ 環境変数 ALICE_NPUB と BOB_NPUB も設定されていません"
        echo ""
        echo "次のいずれかの方法で設定してください："
        echo "1. .envファイルを作成:"
        echo "   cd $SCRIPT_DIR"
        echo "   cp .env.example .env"
        echo "   # .envファイルを編集して実際の公開鍵を設定"
        echo ""
        echo "2. 環境変数を直接エクスポート:"
        echo "   export ALICE_NPUB=npub1..."
        echo "   export BOB_NPUB=npub1..."
        exit 1
    fi
fi

# リレーURLの設定（.envから読み込むか、デフォルト値を使用）
RELAY="${RELAY_URL:-wss://relay.damus.io}"

# 必須変数のチェック
if [ -z "$ALICE_NPUB" ] || [ -z "$BOB_NPUB" ]; then
    echo "❌ ALICE_NPUB または BOB_NPUB が設定されていません"
    echo "💡 .envファイルを確認してください"
    exit 1
fi

echo "👤 Alice: $ALICE_NPUB"
echo "👤 Bob: $BOB_NPUB"
echo ""

# npub形式をhex形式に変換
echo "🔄 npub形式をhex形式に変換中..."
ALICE_HEX=$(nak decode "$ALICE_NPUB" 2>/dev/null)
BOB_HEX=$(nak decode "$BOB_NPUB" 2>/dev/null)

if [ -z "$ALICE_HEX" ] || [ -z "$BOB_HEX" ]; then
    echo "❌ 公開鍵の変換に失敗しました"
    echo "💡 npub形式が正しいか確認してください"
    exit 1
fi

echo "✅ Alice hex: ${ALICE_HEX:0:16}..."
echo "✅ Bob hex: ${BOB_HEX:0:16}..."
echo ""

# Aliceのグループリストイベントを検索
echo "🔎 Step 1: Aliceが作成したグループリストを検索..."
echo "コマンド: nak req -k 30001 --author $ALICE_HEX $RELAY"
echo ""

ALICE_EVENTS=$(nak req -k 30001 --author "$ALICE_HEX" "$RELAY" 2>/dev/null)

if [ -z "$ALICE_EVENTS" ]; then
    echo "❌ Aliceのイベントが見つかりませんでした"
    exit 1
fi

echo "$ALICE_EVENTS" | jq -c 'select(.tags[] | select(.[0] == "d" and (.[1] | startswith("meiso-group-"))))' > /tmp/alice_groups.json

GROUP_COUNT=$(cat /tmp/alice_groups.json | wc -l | tr -d ' ')
echo "✅ Aliceのグループリスト: ${GROUP_COUNT}個"

if [ "$GROUP_COUNT" -eq 0 ]; then
    echo "⚠️  グループリストが見つかりません"
    echo "💡 Aliceアカウントでグループリストを作成してから再度実行してください"
    exit 0
fi

echo ""
echo "📋 グループリストの詳細:"
cat /tmp/alice_groups.json | while read -r event; do
    D_TAG=$(echo "$event" | jq -r '.tags[] | select(.[0] == "d") | .[1]')
    TITLE=$(echo "$event" | jq -r '.tags[] | select(.[0] == "title") | .[1]')
    P_TAGS=$(echo "$event" | jq -r '[.tags[] | select(.[0] == "p") | .[1]] | join(", ")')
    EVENT_ID=$(echo "$event" | jq -r '.id')
    
    echo "  - d tag: $D_TAG"
    echo "    title: $TITLE"
    echo "    eventId: $EVENT_ID"
    echo "    members (p tags): $P_TAGS"
    echo ""
done

echo ""
echo "🔎 Step 2: Bobの公開鍵がpタグに含まれているか確認..."
echo "Bob hex pubkey: $BOB_HEX"

BOB_IN_GROUP=$(cat /tmp/alice_groups.json | jq --arg bob "$BOB_HEX" 'select(.tags[] | select(.[0] == "p" and .[1] == $bob))')

if [ -z "$BOB_IN_GROUP" ]; then
    echo "❌ Bobがメンバーとしてpタグに含まれていません"
    echo "💡 グループリスト作成時にBobの公開鍵を追加してください"
    exit 1
fi

echo "✅ Bobがメンバーとして含まれています"
echo ""

echo "🔎 Step 3: Bobの視点でグループリストを検索..."
echo "コマンド: nak req -k 30001 -p $BOB_HEX $RELAY"
echo ""

BOB_VIEW=$(nak req -k 30001 -p "$BOB_HEX" "$RELAY" 2>/dev/null | jq -c 'select(.tags[] | select(.[0] == "d" and (.[1] | startswith("meiso-group-"))))')

BOB_GROUP_COUNT=$(echo "$BOB_VIEW" | wc -l | tr -d ' ')
echo "✅ Bobが参照できるグループリスト: ${BOB_GROUP_COUNT}個"

if [ "$BOB_GROUP_COUNT" -eq 0 ]; then
    echo "❌ Bobがグループリストを参照できません"
    echo "💡 pタグでの検索が機能していない可能性があります"
    exit 1
fi

echo ""
echo "✅ 検証完了！"
echo ""
echo "📊 結果サマリー:"
echo "  - Aliceのグループリスト: ${GROUP_COUNT}個"
echo "  - Bobが参照可能: ${BOB_GROUP_COUNT}個"
echo "  - pタグによる検索: 正常"

# クリーンアップ
rm -f /tmp/alice_groups.json

exit 0

