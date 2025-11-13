#!/bin/bash

# Meiso 統合開発スクリプト
# Usage: ./dev.sh

set -e

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# セクションヘッダー表示
print_section() {
  local title=$1
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}$title${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# Yes/No質問
ask_yes_no() {
  local prompt=$1
  local default=$2  # Y or N
  
  if [ "$default" = "Y" ]; then
    read -p "$prompt (Y/n): " -n 1 -r
  else
    read -p "$prompt (y/N): " -n 1 -r
  fi
  echo
  
  if [ -z "$REPLY" ]; then
    # Enterだけ押された場合はデフォルト値を使用
    [ "$default" = "Y" ]
    return $?
  fi
  
  [[ $REPLY =~ ^[Yy]$ ]]
  return $?
}

# ==========================================
# メイン処理
# ==========================================

echo -e "${MAGENTA}"
cat << "EOF"
╔════════════════════════════════════════════╗
║                                            ║
║       🚀 Meiso 統合開発スクリプト 🚀       ║
║                                            ║
╚════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ==========================================
# Phase 1: ビルド設定
# ==========================================

print_section "【Phase 1】ビルド設定"

# Rustビルド
if ask_yes_no "Rustコードをビルドしますか？" "Y"; then
  BUILD_RUST=true
  echo -e "${GREEN}✓ Rustビルドを実行します${NC}"
else
  BUILD_RUST=false
  echo -e "${YELLOW}⊘ Rustビルドをスキップします${NC}"
fi
echo ""

# build_runner
if ask_yes_no "build_runnerを実行しますか？" "Y"; then
  RUN_BUILD_RUNNER=true
  echo -e "${GREEN}✓ build_runnerを実行します${NC}"
else
  RUN_BUILD_RUNNER=false
  echo -e "${YELLOW}⊘ build_runnerをスキップします${NC}"
fi

# ==========================================
# Phase 2: アクション選択
# ==========================================

print_section "【Phase 2】実行モード選択"

echo "1) fvm flutter run (デバッグモード)"
echo "2) fvm flutter install (リリースビルド & インストール)"
echo ""

while true; do
  read -p "選択してください (1/2): " choice
  case $choice in
    1)
      COMMAND="run"
      BUILD_RELEASE=false
      echo -e "${GREEN}✓ デバッグモード (flutter run)${NC}"
      break
      ;;
    2)
      COMMAND="install"
      BUILD_RELEASE=true
      echo -e "${GREEN}✓ リリースモード (build apk + install)${NC}"
      break
      ;;
    *)
      echo -e "${RED}無効な選択です (1 または 2 を入力)${NC}"
      ;;
  esac
done

# ==========================================
# Phase 3: デバイス選択
# ==========================================

print_section "【Phase 3】デバイス選択"

echo "1) Emulator (emulator-5554)"
echo "2) Physical Device (39221JEHN10328)"
echo "3) 両方とも"
echo ""

while true; do
  read -p "選択してください (1/2/3): " choice
  case $choice in
    1)
      SELECTED_DEVICES=("$EMULATOR_ID")
      echo -e "${GREEN}✓ Emulator を選択${NC}"
      break
      ;;
    2)
      SELECTED_DEVICES=("$PHYSICAL_DEVICE_ID")
      echo -e "${GREEN}✓ Physical Device を選択${NC}"
      break
      ;;
    3)
      SELECTED_DEVICES=("$EMULATOR_ID" "$PHYSICAL_DEVICE_ID")
      echo -e "${GREEN}✓ 両方のデバイスを選択${NC}"
      break
      ;;
    *)
      echo -e "${RED}無効な選択です (1/2/3)${NC}"
      ;;
  esac
done

# ==========================================
# Phase 4: 設定確認
# ==========================================

print_section "【確認】実行内容"

echo -e "Rustビルド:       $([ "$BUILD_RUST" = true ] && echo -e "${GREEN}✓ 実行${NC}" || echo -e "${YELLOW}⊘ スキップ${NC}")"
echo -e "build_runner:     $([ "$RUN_BUILD_RUNNER" = true ] && echo -e "${GREEN}✓ 実行${NC}" || echo -e "${YELLOW}⊘ スキップ${NC}")"
echo -e "flutter clean:    ${GREEN}✓ 実行${NC}"
echo -e "flutter pub get:  ${GREEN}✓ 実行${NC}"
echo -e "リリースビルド:   $([ "$BUILD_RELEASE" = true ] && echo -e "${GREEN}✓ 実行${NC}" || echo -e "${YELLOW}⊘ スキップ${NC}")"
echo -e "実行コマンド:     ${GREEN}fvm flutter $COMMAND${NC}"
echo -e "デバイス数:       ${GREEN}${#SELECTED_DEVICES[@]}台${NC}"
for device in "${SELECTED_DEVICES[@]}"; do
  echo -e "  - ${YELLOW}$device${NC}"
done

echo ""
if ! ask_yes_no "この内容で実行しますか？" "Y"; then
  echo "キャンセルしました"
  exit 0
fi

# ==========================================
# Phase 5: ビルド実行
# ==========================================

print_section "【Phase 5】ビルド実行"

# Rustビルド
if [ "$BUILD_RUST" = true ]; then
  echo -e "${BLUE}🦀 Rustコードをビルド中...${NC}"
  if ! ./generate.sh; then
    echo -e "${RED}エラー: Rustビルドに失敗しました${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Rustビルド完了${NC}"
  echo ""
fi

# build_runner
if [ "$RUN_BUILD_RUNNER" = true ]; then
  echo -e "${BLUE}🔧 build_runnerを実行中...${NC}"
  if ! fvm flutter pub run build_runner build --delete-conflicting-outputs; then
    echo -e "${RED}エラー: build_runnerに失敗しました${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ build_runner完了${NC}"
  echo ""
fi

# flutter clean (必須)
echo -e "${BLUE}🧹 Flutter環境をクリーンアップ中...${NC}"
if ! fvm flutter clean; then
  echo -e "${RED}エラー: flutter cleanに失敗しました${NC}"
  exit 1
fi
echo -e "${GREEN}✓ クリーンアップ完了${NC}"
echo ""

# flutter pub get (必須)
echo -e "${BLUE}📦 依存パッケージを取得中...${NC}"
if ! fvm flutter pub get; then
  echo -e "${RED}エラー: flutter pub getに失敗しました${NC}"
  exit 1
fi
echo -e "${GREEN}✓ パッケージ取得完了${NC}"
echo ""

# リリースビルド (installモードの場合のみ)
if [ "$BUILD_RELEASE" = true ]; then
  echo -e "${BLUE}📱 リリースAPKをビルド中...${NC}"
  if ! fvm flutter build apk --release; then
    echo -e "${RED}エラー: APKビルドに失敗しました${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ リリースAPKビルド完了${NC}"
  echo ""
fi

# ==========================================
# Phase 6: デバイス準備
# ==========================================

print_section "【Phase 6】デバイス準備"

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
      if ! ask_yes_no "続行しますか？" "N"; then
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

# ==========================================
# Phase 7: アプリ実行
# ==========================================

print_section "【Phase 7】アプリ実行"

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

# ==========================================
# 完了
# ==========================================

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ すべての処理が完了しました！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 実行サマリー
echo -e "${CYAN}実行サマリー:${NC}"
echo -e "  実行モード: ${GREEN}$COMMAND${NC}"
echo -e "  デバイス数: ${GREEN}${#SELECTED_DEVICES[@]}台${NC}"
[ "$BUILD_RUST" = true ] && echo -e "  Rustビルド: ${GREEN}✓${NC}" || echo -e "  Rustビルド: ${YELLOW}スキップ${NC}"
[ "$RUN_BUILD_RUNNER" = true ] && echo -e "  build_runner: ${GREEN}✓${NC}" || echo -e "  build_runner: ${YELLOW}スキップ${NC}"
[ "$BUILD_RELEASE" = true ] && echo -e "  APKビルド: ${GREEN}✓${NC}" || echo -e "  APKビルド: ${YELLOW}スキップ${NC}"
echo ""

