#!/bin/bash
set -e

echo "🔨 Generating Flutter Rust Bridge code..."

# Flutter Rust Bridgeのコード生成
flutter_rust_bridge_codegen generate

echo "✨ Code generation complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Run 'cargo build' in rust/ directory"
echo "  2. Run 'flutter pub get'"
echo "  3. Build for Android: 'flutter build apk'"

