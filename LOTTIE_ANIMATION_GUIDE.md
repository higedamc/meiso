# Lottieアニメーション更新ガイド

## 概要
このガイドでは、オンボーディング画面のLottieアニメーションを実際のアニメーションに更新する方法を説明します。

## 現在の状態
現在、各ページには**プレースホルダーURL**が設定されています。実際のLottieアニメーションに置き換える必要があります。

## 手順

### 1. LottieFilesでアニメーションを探す

#### ページ1: チェックリスト/TODO
1. https://lottiefiles.com/ にアクセス
2. 検索バーに「checklist」または「todo」と入力
3. 以下のような特徴のアニメーションを選択:
   - シンプルなチェックマークのアニメーション
   - TeuxDeuxのミニマルなデザインに合う
   - ファイルサイズ: 100KB以下
   - ライセンス: 無料（Free）

**推奨アニメーション例:**
- "Checklist Animation" by LottieFiles
- "Task Complete" by Various Artists
- "To-Do List" by Community

#### ページ2: クラウド同期
1. 検索: "cloud sync" または "data transfer"
2. 特徴:
   - クラウドとデバイス間の矢印
   - 同期のアニメーション
   - 青/紫系の色合い

**推奨アニメーション例:**
- "Cloud Sync" by LottieFiles
- "Data Upload Download" by Various Artists
- "Sync Animation" by Community

#### ページ3: プライバシー/セキュリティ
1. 検索: "privacy" または "security shield"
2. 特徴:
   - 盾や鍵のアイコン
   - 安全性を表現
   - 落ち着いた色合い

**推奨アニメーション例:**
- "Privacy Shield" by LottieFiles
- "Security Lock" by Various Artists
- "Data Protection" by Community

#### ページ4: ロケット/スタート
1. 検索: "rocket launch" または "startup"
2. 特徴:
   - ロケット発射のアニメーション
   - ポジティブな印象
   - 明るい色合い

**推奨アニメーション例:**
- "Rocket Launch" by LottieFiles
- "Startup Animation" by Various Artists
- "Get Started" by Community

### 2. Lottie URLを取得

#### 方法1: Lottie URLをコピー（推奨）
1. 選択したアニメーションのページを開く
2. 「Lottie JSON」ボタンをクリック
3. 「Copy Lottie URL」をクリック
4. URLをコピー（例: `https://lottie.host/xxxxx-xxxxx/animation.json`）

#### 方法2: JSONファイルをダウンロード
1. 「Download」ボタンをクリック
2. 「Lottie JSON」を選択
3. ファイルを `assets/lottie/` に保存
4. 後でコードを変更（`Lottie.network` → `Lottie.asset`）

### 3. コードを更新

#### ファイル: `lib/presentation/onboarding/onboarding_screen.dart`

現在のコード（38-63行目）:
```dart
final pages = [
  const _OnboardingPage(
    lottieUrl: 'https://lottie.host/4c3e5c3e-5e5e-4e5e-8e5e-5e5e5e5e5e5e/checklist.json',
    title: 'Meisoへようこそ',
    description: 'シンプルで美しいToDoアプリ\nNostrで同期して、どこでもタスク管理',
    fallbackIcon: Icons.check_circle_outline,
  ),
  // ... 他のページ
];
```

更新後のコード例:
```dart
final pages = [
  const _OnboardingPage(
    lottieUrl: 'https://lottie.host/【実際のURL】/checklist.json',
    title: 'Meisoへようこそ',
    description: 'シンプルで美しいToDoアプリ\nNostrで同期して、どこでもタスク管理',
    fallbackIcon: Icons.check_circle_outline,
  ),
  // ... 他のページも同様に更新
];
```

### 4. テスト

#### ビルドして実行
```bash
cd /Users/apple/work/meiso
fvm flutter run
```

#### 確認項目
- [ ] アニメーションが正しく表示される
- [ ] ロード時間が許容範囲内（2秒以内）
- [ ] アニメーションがループする（必要に応じて）
- [ ] オフライン時にフォールバックが表示される

## ローカルアセットを使う場合

### 手順
1. LottieFilesからJSONファイルをダウンロード
2. ファイル名を変更（例: `checklist.json`, `sync.json`, `privacy.json`, `rocket.json`）
3. `assets/lottie/` に配置
4. コードを変更:

```dart
// Before (ネットワーク)
Lottie.network(
  lottieUrl,
  fit: BoxFit.contain,
)

// After (ローカル)
Lottie.asset(
  'assets/lottie/checklist.json',
  fit: BoxFit.contain,
)
```

### メリット・デメリット

#### ネットワーク版
**メリット:**
- APKサイズが小さい
- アニメーション更新が容易

**デメリット:**
- 初回ロード時にネットワーク必要
- オフライン時はフォールバック表示

#### ローカル版
**メリット:**
- オフラインでも常に表示
- ロード時間が短い

**デメリット:**
- APKサイズが増加（1アニメーション約50-100KB）
- 更新にはアプリ再配布が必要

## トラブルシューティング

### アニメーションが表示されない
1. **ネットワーク接続を確認**
   - Wi-Fiまたはモバイルデータが有効か
   - LottieFilesのURLにアクセスできるか

2. **URLを確認**
   - コピーしたURLが正しいか
   - `https://lottie.host/` で始まっているか

3. **フォールバックを確認**
   - フォールバックアイコンが表示されているか
   - エラーログを確認

### ロード時間が長い
1. **ファイルサイズを確認**
   - 100KB以下のアニメーションを選択
   - 複雑すぎるアニメーションは避ける

2. **キャッシュを確認**
   - 2回目以降は自動的にキャッシュされる
   - アプリを再起動して確認

### アニメーションが途切れる
1. **デバイスの性能を確認**
   - 古いデバイスでは簡単なアニメーションを選択
   - フレームレートを下げる

2. **アニメーションの複雑度を確認**
   - レイヤー数が多すぎないか
   - エフェクトが多すぎないか

## 推奨設定

### アニメーションの選択基準
- **ファイルサイズ**: 50-100KB
- **解像度**: 512x512px または 1024x1024px
- **フレームレート**: 30fps または 60fps
- **ループ**: Yes（無限ループ）
- **色**: TeuxDeuxのカラーパレットに合う

### パフォーマンス
- **ロード時間**: 2秒以内
- **メモリ使用量**: 10MB以内
- **CPU使用率**: 20%以内

## 参考リンク

- [LottieFiles](https://lottiefiles.com/)
- [Lottie for Flutter](https://pub.dev/packages/lottie)
- [Lottie Community](https://lottiefiles.com/community)
- [Lottie Documentation](https://airbnb.io/lottie/)

## サポート

質問や問題がある場合は、以下のドキュメントを参照してください:
- `docs/ONBOARDING_RICH_UI_IMPLEMENTATION.md` - 詳細な実装ガイド
- `docs/PR34_ONBOARDING_RICH_UI_SUMMARY.md` - 実装サマリー

---

**最終更新日**: 2025年11月5日

