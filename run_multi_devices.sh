#!/bin/bash

# Meiso 複数デバイス実行スクリプト
# Usage: ./run_multi_devices.sh

set -e

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# デバイスID定義
EMULATOR_ID="emulator-5554"
PHYSICAL_DEVICE_ID="39221JEHN10328"

# Android SDKのパス確認
if [ -z "$ANDROID_HOME" ]; then
  echo -e "${RED}エラー: ANDROID_HOME環境変数が設定されていません${NC}"
  echo "以下のコマンドで設定してください:"
  echo "export ANDROID_HOME=\$HOME/Library/Android/sdk"
  exit 1
fi

EMULATOR_BIN="$ANDROID_HOME/emulator/emulator"

# ==========================================
# 関数定義
# ==========================================

# エミュレータが起動しているかチェック
check_emulator_running() {
  adb devices | grep -q "$EMULATOR_ID"
  return $?
}

# エミュレータを起動
start_emulator() {
  echo -e "${YELLOW}エミュレータが起動していません。起動を開始します...${NC}"
  echo ""
  
  if [ ! -f "$EMULATOR_BIN" ]; then
    echo -e "${RED}エラー: emulatorコマンドが見つかりません${NC}"
    echo "パス: $EMULATOR_BIN"
    return 1
  fi
  
  # 利用可能なAVDをリスト表示
  AVDS=$($EMULATOR_BIN -list-avds)
  
  if [ -z "$AVDS" ]; then
    echo -e "${RED}エラー: AVDが見つかりません${NC}"
    echo "Android Studioで仮想デバイスを作成してください"
    return 1
  fi
  
  # 最初のAVDを使用
  AVD_NAME=$(echo "$AVDS" | head -n 1)
  echo -e "${GREEN}AVD: $AVD_NAME を起動中...${NC}"
  
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
  adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
  
  echo -e "${GREEN}✓ エミュレータの起動が完了しました！${NC}"
  echo ""
  
  return 0
}

# デバイスが接続されているかチェック
check_device_connected() {
  local device_id=$1
  adb devices | grep -q "$device_id"
  return $?
}

# ==========================================
# メイン処理
# ==========================================

echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Meiso マルチデバイス実行ツール      ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
echo ""

# 1. アクション選択
echo -e "${BLUE}【ステップ 1/2】実行するアクションを選択してください:${NC}"
echo ""
PS3="選択してください (番号を入力): "
actions=("fvm flutter run" "fvm flutter install")
select action in "${actions[@]}"; do
  case $action in
    "fvm flutter run")
      COMMAND="run"
      echo -e "${GREEN}✓ 選択: fvm flutter run${NC}"
      break
      ;;
    "fvm flutter install")
      COMMAND="install"
      echo -e "${GREEN}✓ 選択: fvm flutter install${NC}"
      break
      ;;
    *)
      echo -e "${RED}無効な選択です。もう一度選択してください。${NC}"
      ;;
  esac
done
echo ""

# 2. デバイス選択（複数選択可能）
echo -e "${BLUE}【ステップ 2/2】実行するデバイスを選択してください:${NC}"
echo -e "${YELLOW}(複数選択可能。完了したら 'q' を入力)${NC}"
echo ""

SELECTED_DEVICES=()
DEVICE_OPTIONS=(
  "1) Emulator (emulator-5554)"
  "2) Physical Device (39221JEHN10328)"
  "3) 両方とも"
)

for option in "${DEVICE_OPTIONS[@]}"; do
  echo "$option"
done
echo ""

while true; do
  read -p "選択 (1/2/3/q): " choice
  case $choice in
    1)
      if [[ ! " ${SELECTED_DEVICES[@]} " =~ " ${EMULATOR_ID} " ]]; then
        SELECTED_DEVICES+=("$EMULATOR_ID")
        echo -e "${GREEN}✓ Emulator を追加しました${NC}"
      else
        echo -e "${YELLOW}既に選択されています${NC}"
      fi
      break
      ;;
    2)
      if [[ ! " ${SELECTED_DEVICES[@]} " =~ " ${PHYSICAL_DEVICE_ID} " ]]; then
        SELECTED_DEVICES+=("$PHYSICAL_DEVICE_ID")
        echo -e "${GREEN}✓ Physical Device を追加しました${NC}"
      else
        echo -e "${YELLOW}既に選択されています${NC}"
      fi
      break
      ;;
    3)
      SELECTED_DEVICES=("$EMULATOR_ID" "$PHYSICAL_DEVICE_ID")
      echo -e "${GREEN}✓ 両方のデバイスを追加しました${NC}"
      break
      ;;
    q|Q)
      break
      ;;
    *)
      echo -e "${RED}無効な選択です (1/2/3/q)${NC}"
      ;;
  esac
done
echo ""

# デバイスが選択されているか確認
if [ ${#SELECTED_DEVICES[@]} -eq 0 ]; then
  echo -e "${RED}エラー: デバイスが選択されていません${NC}"
  exit 1
fi

# 選択内容の確認
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}実行内容の確認${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "アクション: ${GREEN}fvm flutter $COMMAND${NC}"
echo -e "デバイス数: ${GREEN}${#SELECTED_DEVICES[@]}台${NC}"
for device in "${SELECTED_DEVICES[@]}"; do
  echo -e "  - ${YELLOW}$device${NC}"
done
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "実行しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "キャンセルしました"
  exit 0
fi
echo ""

# 3. デバイス準備＆実行
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}デバイスの準備${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# エミュレータが選択されている場合、起動チェック
for device in "${SELECTED_DEVICES[@]}"; do
  if [ "$device" = "$EMULATOR_ID" ]; then
    echo -e "${BLUE}🔍 エミュレータの状態をチェック中...${NC}"
    if check_emulator_running; then
      echo -e "${GREEN}✓ エミュレータは既に起動しています${NC}"
    else
      start_emulator
    fi
    echo ""
  elif [ "$device" = "$PHYSICAL_DEVICE_ID" ]; then
    echo -e "${BLUE}🔍 物理デバイスの接続をチェック中...${NC}"
    if check_device_connected "$PHYSICAL_DEVICE_ID"; then
      echo -e "${GREEN}✓ 物理デバイスが接続されています${NC}"
    else
      echo -e "${RED}警告: 物理デバイスが検出されません${NC}"
      echo -e "${YELLOW}USBデバッグが有効か確認してください${NC}"
      echo ""
      read -p "続行しますか？ (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "キャンセルしました"
        exit 0
      fi
    fi
    echo ""
  fi
done

# 現在接続されているデバイス一覧
echo -e "${BLUE}現在接続されているデバイス:${NC}"
adb devices -l
echo ""

# 4. 実行
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}実行開始${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

PIDS=()

for device in "${SELECTED_DEVICES[@]}"; do
  echo -e "${GREEN}📱 $device で実行中...${NC}"
  fvm flutter $COMMAND -d "$device" &
  PIDS+=($!)
  sleep 1  # 少し間隔を開ける
done

echo ""
echo -e "${YELLOW}すべてのプロセスの完了を待機中...${NC}"
echo -e "${YELLOW}(Ctrl+C で中断可能)${NC}"
echo ""

# すべてのプロセスの完了を待つ
for pid in "${PIDS[@]}"; do
  wait $pid
done

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ すべての実行が完了しました！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

