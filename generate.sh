#!/bin/bash
set -e

echo "🔨 Generating Flutter Rust Bridge code..."

# Flutter Rust Bridgeのコード生成
flutter_rust_bridge_codegen generate

echo "✨ Code generation complete!"
echo ""

# Rustライブラリのビルド
echo "🦀 Building Rust library (release mode)..."
cd rust
cargo build --release
cd ..

echo ""
echo "✅ All done!"
echo ""
echo "📝 Next steps:"
echo "  1. Run 'flutter pub get' (if needed)"
echo "  2. Run 'flutter run' to test"
echo "  3. Build for Android: 'flutter build apk'"

