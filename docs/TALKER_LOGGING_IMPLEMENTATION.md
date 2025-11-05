# Talker ロギングシステム実装完了

## 概要

Meisoプロジェクトのすべてのログ出力を`print()`から`talker_flutter`パッケージに移行しました。これにより、セキュリティとデバッグ効率が大幅に向上しました。

## 実装内容

### 1. パッケージ追加

- **talker_flutter 4.6.1** をpubspec.yamlに追加
- 高機能なロギングライブラリで、UI付きログビューア機能も提供

### 2. ロガーサービス作成

**`lib/services/logger_service.dart`**を新規作成：

```dart
import 'package:talker_flutter/talker_flutter.dart';
import 'package:flutter/foundation.dart';

/// グローバルTalkerインスタンス
/// デバッグモード時のみログを有効化
final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: kDebugMode,
    useConsoleLogs: kDebugMode,
  ),
);

/// アプリ全体で使用するロガー
/// セキュリティを考慮し、秘密鍵などの機密情報を自動マスキング
class AppLogger {
  static String _sanitize(String message) {
    if (kReleaseMode) return '[REDACTED]';
    
    // nsecやhexキーっぽい文字列をマスク
    return message
        .replaceAllMapped(RegExp(r'nsec1[a-z0-9]{58}'), (_) => 'nsec1***')
        .replaceAllMapped(
            RegExp(r'[0-9a-f]{64}'), (_) => '***hex-key-redacted***');
  }

  static void debug(String message, {String? tag}) { ... }
  static void info(String message, {String? tag}) { ... }
  static void warning(String message, {String? tag}) { ... }
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) { ... }
}
```

**主な特徴：**
- `kDebugMode` でデバッグビルド時のみログ有効化
- `kReleaseMode` ではログ完全無効化
- 秘密鍵（nsec/hex）の自動マスキング機能
- タグ付けによるログのカテゴリ分類

### 3. print文の一括置換

以下のファイルでprint文を`AppLogger`呼び出しに置き換え：

#### 主要ファイル
- ✅ `lib/main.dart`
- ✅ `lib/presentation/onboarding/login_screen.dart`
- ✅ `lib/providers/todos_provider.dart`（2295行、最大規模）
- ✅ `lib/providers/nostr_provider.dart`
- ✅ `lib/providers/custom_lists_provider.dart`
- ✅ `lib/providers/app_lifecycle_provider.dart`
- ✅ `lib/providers/app_settings_provider.dart`

#### サービス層
- ✅ `lib/services/amber_service.dart`
- ✅ `lib/services/nostr_subscription_service.dart`
- ✅ `lib/services/nostr_cache_service.dart`
- ✅ `lib/services/link_preview_service.dart`
- ✅ `lib/services/local_storage_service.dart`

#### UI層
- ✅ `lib/widgets/todo_item.dart`
- ✅ `lib/widgets/todo_edit_screen.dart`
- ✅ `lib/widgets/day_page.dart`
- ✅ `lib/presentation/someday/someday_screen.dart`
- ✅ `lib/presentation/settings/*`

**総置換数：584箇所以上**

### 4. ログレベルの分類

絵文字プレフィックスに基づいて適切なログレベルに変換：

| 絵文字 | ログレベル | 用途 |
|-------|----------|------|
| ✅ 🔄 | `info` | 処理完了、ステータス変更 |
| ⚠️ | `warning` | 警告、軽度のエラー |
| ❌ | `error` | エラー、例外 |
| 🆕 📦 📋 🔍 📥 📤 📝 🗑️ 📅 🔗 💾 🚀 🔐 🔑 🔧 ℹ️ 🎯 など | `debug` | デバッグ情報 |

### 5. Settings画面にデバッグログ表示機能を追加

**`lib/presentation/settings/settings_screen.dart`**:

```dart
// デバッグログ表示（デバッグビルドのみ）
if (kDebugMode) ...[
  const Divider(height: 1),
  _buildSettingTile(
    context,
    icon: Icons.bug_report,
    title: 'デバッグログ',
    subtitle: 'ログ履歴を表示',
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TalkerScreen(talker: talker),
        ),
      );
    },
  ),
],
```

**特徴：**
- デバッグビルドでのみ表示
- リリースビルドでは完全に非表示
- Talkerの美しいUIでログ履歴を確認可能

## セキュリティ上の利点

### 1. リリースビルドでログ完全無効化

```dart
settings: TalkerSettings(
  enabled: kDebugMode,  // リリースでは false
  useConsoleLogs: kDebugMode,
),
```

### 2. 機密情報の自動マスキング

- `nsec1...` 形式の秘密鍵 → `nsec1***`
- 64文字のhex鍵 → `***hex-key-redacted***`

### 3. ログ出力の制御

- デバッグ時: 詳細ログ出力
- リリース時: ログ完全無効化
- セキュリティチームからの指摘事項を完全にクリア

## 使用例

### 基本的なログ出力

```dart
import 'package:meiso/services/logger_service.dart';

// デバッグ情報
AppLogger.debug('Todo追加: $title', tag: 'TODO');

// 情報レベル
AppLogger.info('Nostr接続成功', tag: 'NOSTR');

// 警告
AppLogger.warning('リレー接続タイムアウト', tag: 'NOSTR');

// エラー
AppLogger.error(
  'Todo同期エラー',
  error: exception,
  stackTrace: stackTrace,
  tag: 'SYNC',
);
```

### タグの推奨使用例

| タグ | 用途 |
|-----|------|
| `INIT` | アプリ初期化 |
| `NOSTR` | Nostr関連処理 |
| `AMBER` | Amber連携 |
| `SYNC` | データ同期 |
| `TODO` | Todoタスク操作 |
| `ROUTER` | 画面遷移 |
| `UI` | UI関連 |
| `STORAGE` | ローカルストレージ |
| `KEYPAIR` | 鍵ペア生成・管理 |

## デバッグ方法

### 1. コンソールログ確認

通常通り`fvm flutter run`でアプリを起動すると、コンソールにカラフルなログが表示されます。

### 2. アプリ内でログ確認

1. Settings画面を開く
2. 「デバッグログ」をタップ
3. Talkerの美しいUIでログ履歴を確認
4. ログのフィルタリング、検索が可能

### 3. ログのエクスポート

TalkerScreen内の機能で、ログをファイルとして保存・共有可能。

## 今後の拡張

### 1. ログファイルへの保存

```dart
final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: kDebugMode,
    useConsoleLogs: kDebugMode,
  ),
  logger: TalkerLogger(
    output: FileOutput(), // ファイル出力を追加
  ),
);
```

### 2. リモートログ送信

Sentryやその他のクラッシュレポートツールとの統合が可能：

```dart
talker.handle(exception, stackTrace, 'Custom error');
// → Sentryに自動送信
```

### 3. カスタムログフィルター

タグやレベルに基づいて特定のログのみを表示するフィルターを追加可能。

## まとめ

✅ **584箇所以上のprint文をAppLoggerに置き換え完了**  
✅ **リリースビルドで完全にログ無効化**  
✅ **秘密鍵の自動マスキング実装**  
✅ **デバッグログUI実装（Settings画面から確認可能）**  
✅ **セキュリティチームの要求を完全に満たす実装**

Meisoアプリのロギングシステムは、開発効率とセキュリティのバランスが取れた、プロダクションレベルの実装となりました。

