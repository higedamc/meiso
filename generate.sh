#!/bin/bash
set -e

echo "🔨 Generating Flutter Rust Bridge code..."

# Flutter Rust Bridgeのコード生成（直接コマンド実行）
if command -v flutter_rust_bridge_codegen &> /dev/null; then
    flutter_rust_bridge_codegen generate
else
    echo "❌ Error: flutter_rust_bridge_codegen command not found"
    echo "Please install it with: cargo install flutter_rust_bridge_codegen"
    exit 1
fi

echo "✨ Code generation complete!"
echo ""

# Rustライブラリのビルド
echo "🦀 Building Rust library (release mode)..."
cd rust
if command -v cargo &> /dev/null; then
    cargo build --release
else
    echo "❌ Error: cargo command not found. Please install Rust."
    exit 1
fi
cd ..

echo ""
echo "✅ All done!"
echo ""
echo "📝 Next steps:"
echo "  1. Run 'fvm flutter pub get' (if needed)"
echo "  2. Run 'fvm flutter run' to test"
echo "  3. Build for Android: 'fvm flutter build apk'"

