# Issue #66: 多言語対応 (l10n) 実装完了

## 概要

Meisoアプリに多言語対応（l10n: localization）を実装しました。英語、日本語、スペイン語の3言語に対応し、OSのシステム言語設定に合わせた自動切り替えと、設定画面での手動言語切り替えが可能になりました。

## 実装内容

### 1. パッケージ依存関係の追加

**ファイル**: `pubspec.yaml`

- `flutter_localizations` パッケージを追加
- `intl` パッケージを `0.19.0` → `0.20.2` にアップグレード
- `generate: true` を設定して、ARBファイルから自動コード生成を有効化

### 2. l10n設定ファイルの作成

**ファイル**: `l10n.yaml`

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

### 3. ARBファイルの作成

3つの言語に対応したARBファイルを作成しました：

- **`lib/l10n/app_en.arb`** (英語 - テンプレート)
- **`lib/l10n/app_ja.arb`** (日本語)
- **`lib/l10n/app_es.arb`** (スペイン語)

#### 翻訳された主要な文字列

- オンボーディング画面の全文字列（5ページ分）
- 設定画面の全文字列
- ナビゲーションボタン（スキップ、次へ、スタート、保存、キャンセル等）
- ステータスメッセージ（Nostr接続状態、リレー接続数等）
- 言語選択オプション（システムデフォルト、English、日本語、Español）

### 4. 言語選択プロバイダーの実装

**ファイル**: `lib/providers/locale_provider.dart`

- `LocaleNotifier` クラスを実装
- ローカルストレージに言語設定を永続化
- システムデフォルトまたは手動選択した言語をサポート

### 5. ローカルストレージサービスの拡張

**ファイル**: `lib/services/local_storage_service.dart`

言語設定の保存・読み込み・クリアメソッドを追加：
- `setLanguage(String languageCode)`
- `getLanguage() → String?`
- `clearLanguage()`

### 6. メインアプリの更新

**ファイル**: `lib/main.dart`

- `AppLocalizations` のimportを追加
- `localizationsDelegates` を設定
- `supportedLocales` を設定（英語、日本語、スペイン語）
- `localeProvider` を監視して、言語変更を反映

### 7. 画面の多言語対応

#### オンボーディング画面

**ファイル**: `lib/presentation/onboarding/onboarding_screen.dart`

- 5ページすべての文字列を多言語対応
- スキップ、次へ、スタートボタンを多言語対応

#### 設定画面

**ファイル**: `lib/presentation/settings/settings_screen.dart`

- Nostr接続ステータス表示を多言語対応
- 設定項目（秘密鍵管理、リレーサーバー管理、アプリ設定等）を多言語対応
- Amberモード情報カードを多言語対応
- 自動同期情報カードを多言語対応
- バージョン情報を多言語対応

#### アプリ設定詳細画面

**ファイル**: `lib/presentation/settings/app_settings_detail_screen.dart`

- 言語選択UI を追加（設定項目の最上部に配置）
- 言語選択ダイアログを実装
  - システムのデフォルト
  - English
  - 日本語
  - Español
- 選択中の言語にチェックマークを表示

## 動作仕様

### 言語切り替えの仕組み

1. **初回起動時**: システムのデフォルト言語を使用
2. **設定画面で変更**: 
   - 設定 → アプリ設定 → 言語 から選択
   - 変更は即座に反映
   - 選択した言語はローカルストレージに保存
3. **アプリ再起動時**: 保存された言語設定を自動的に読み込み

### サポートする言語

| 言語コード | 言語名 | サポート状況 |
|-----------|--------|------------|
| `en` | English | ✅ 完全サポート |
| `ja` | 日本語 | ✅ 完全サポート |
| `es` | Español | ✅ 完全サポート |

### フォールバック動作

- ユーザーが選択した言語が利用できない場合、英語にフォールバック
- システム言語が対応していない場合も、英語にフォールバック

## コード生成

ARBファイルから自動生成されるコードは `.dart_tool/flutter_gen/gen_l10n/` に配置されます。

生成されるファイル：
- `app_localizations.dart` (抽象クラス)
- `app_localizations_en.dart` (英語実装)
- `app_localizations_ja.dart` (日本語実装)
- `app_localizations_es.dart` (スペイン語実装)

## 使用方法

### 画面で多言語文字列を使用する

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Text(l10n.settingsTitle); // "Settings" / "設定" / "Configuración"
  }
}
```

### パラメータ付き文字列

```dart
// ARBファイル:
// "relaysConnectedCount": "Relays: {count}/{total} connected"

// Dartコード:
Text(l10n.relaysConnectedCount(5, 10)) // "Relays: 5/10 connected"
```

## 今後の拡張

### 未対応画面

以下の画面は今後のリファクタリングで多言語対応予定：

- [ ] ログイン画面 (`login_screen.dart`)
- [ ] 秘密鍵管理画面 (`secret_key_management_screen.dart`)
- [ ] リレー管理画面 (`relay_management_screen.dart`)
- [ ] 暗号化詳細画面 (`cryptography_detail_screen.dart`)
- [ ] ホーム画面 (`home_screen.dart`)
- [ ] Somedayリスト画面 (`someday_screen.dart`)
- [ ] リスト詳細画面 (`list_detail_screen.dart`)
- [ ] Todo編集ダイアログ (`todo_edit_screen.dart`)
- [ ] 各種ウィジェット

### 追加したい機能

- [ ] 日付フォーマットの言語対応（現在は英語のみ）
- [ ] 曜日名の多言語対応
- [ ] エラーメッセージの多言語対応
- [ ] Nostrイベント関連のメッセージ多言語対応

## テスト方法

### 言語切り替えのテスト

1. アプリを起動
2. 設定 → アプリ設定 → 言語 を選択
3. 任意の言語を選択
4. オンボーディング画面、設定画面で言語が切り替わることを確認

### システム言語のテスト

1. ローカルストレージから言語設定をクリア
2. デバイスのシステム言語を変更（英語/日本語/スペイン語）
3. アプリを再起動
4. システム言語に応じた表示になることを確認

## 関連Issue

- Issue #66: feature: l10n 対応

## 参考資料

- [Flutter Internationalization](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)
- [ARB file format](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [intl package](https://pub.dev/packages/intl)

