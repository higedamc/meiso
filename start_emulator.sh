#!/bin/bash

# Android Emulator起動スクリプト
# Usage: ./start_emulator.sh [AVD名]

set -e

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Android SDKのパスを確認
if [ -z "$ANDROID_HOME" ]; then
  echo -e "${RED}エラー: ANDROID_HOME環境変数が設定されていません${NC}"
  echo "以下のコマンドで設定してください:"
  echo "export ANDROID_HOME=\$HOME/Library/Android/sdk"
  exit 1
fi

EMULATOR_BIN="$ANDROID_HOME/emulator/emulator"

if [ ! -f "$EMULATOR_BIN" ]; then
  echo -e "${RED}エラー: emulatorコマンドが見つかりません${NC}"
  echo "パス: $EMULATOR_BIN"
  exit 1
fi

# 利用可能なAVDをリスト表示
echo -e "${GREEN}利用可能なAndroid Virtual Devices:${NC}"
AVDS=$($EMULATOR_BIN -list-avds)

if [ -z "$AVDS" ]; then
  echo -e "${RED}エラー: AVDが見つかりません${NC}"
  echo "Android Studioで仮想デバイスを作成してください"
  exit 1
fi

echo "$AVDS" | nl
echo ""

# AVD名が引数で指定されている場合
if [ -n "$1" ]; then
  AVD_NAME="$1"
  echo -e "${GREEN}指定されたAVD: $AVD_NAME を起動します...${NC}"
else
  # 最初のAVDをデフォルトとして使用
  AVD_NAME=$(echo "$AVDS" | head -n 1)
  echo -e "${YELLOW}デフォルトAVD: $AVD_NAME を起動します...${NC}"
  echo -e "${YELLOW}別のAVDを起動する場合: ./start_emulator.sh <AVD名>${NC}"
  echo ""
fi

# エミュレータが既に起動しているかチェック
RUNNING=$(adb devices | grep emulator | wc -l)
if [ "$RUNNING" -gt 0 ]; then
  echo -e "${YELLOW}警告: エミュレータが既に起動している可能性があります${NC}"
  adb devices
  echo ""
  read -p "続行しますか？ (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "キャンセルしました"
    exit 0
  fi
fi

# エミュレータを起動
echo -e "${GREEN}エミュレータを起動中...${NC}"
echo "AVD: $AVD_NAME"
echo ""

# バックグラウンドで起動
$EMULATOR_BIN -avd "$AVD_NAME" \
  -gpu host \
  -no-snapshot-load \
  -netdelay none \
  -netspeed full &

EMULATOR_PID=$!
echo -e "${GREEN}エミュレータを起動しました (PID: $EMULATOR_PID)${NC}"
echo ""

# 起動完了を待つ
echo -e "${YELLOW}起動完了を待機中...${NC}"
adb wait-for-device
echo -e "${GREEN}デバイスが検出されました${NC}"

# ブート完了を待つ
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
  echo -n "."
  sleep 1
done
echo ""

echo -e "${GREEN}✓ エミュレータの起動が完了しました！${NC}"
echo ""
echo "デバイス情報:"
adb devices -l
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  - エミュレータを終了: adb -s <device> emu kill"
echo "  - 全エミュレータを終了: adb devices | grep emulator | cut -f1 | xargs -I {} adb -s {} emu kill"
echo "  - Flutterアプリを実行: fvm flutter run"

