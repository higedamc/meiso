# オンボーディング画面実装ガイド

## 概要

Meisoアプリの初回起動時に表示されるオンボーディングフローの実装ガイドです。
ユーザーがNostrアカウントを設定し、リレーを選択して、アプリの使い方を理解できるようにします。

---

## 画面フロー

```
起動
  ↓
[初回起動判定]
  ↓
  No → HomeScreen
  ↓
 Yes
  ↓
OnboardingScreen
  ↓
1. ウェルカムページ
  ↓
2. 機能紹介ページ
  ↓
3. Nostrアカウントセットアップ
  ├─ Amber連携（推奨）
  ├─ 新規アカウント作成
  └─ 秘密鍵インポート
  ↓
4. リレー設定ページ
  ↓
[完了]
  ↓
HomeScreen
```

---

## ディレクトリ構造

```
lib/
├── presentation/
│   └── onboarding/
│       ├── onboarding_screen.dart          # メイン画面
│       ├── pages/
│       │   ├── welcome_page.dart           # ウェルカムページ
│       │   ├── feature_intro_page.dart     # 機能紹介
│       │   ├── nostr_setup_page.dart       # Nostrセットアップ
│       │   └── relay_setup_page.dart       # リレー設定
│       └── widgets/
│           ├── onboarding_button.dart      # 共通ボタン
│           ├── page_indicator.dart         # ページインジケーター
│           └── setup_option_card.dart      # セットアップ選択肢カード
├── providers/
│   └── onboarding_provider.dart            # オンボーディング状態管理
└── services/
    ├── amber_service.dart                  # Amber連携サービス
    └── account_service.dart                # アカウント管理サービス
```

---

## 実装詳細

### 1. ウェルカムページ (`welcome_page.dart`)

#### UI要素
- アプリロゴ（大きく中央配置）
- キャッチコピー
  - 「Meiso」
  - 「Nostrベースのシンプルなタスク管理」
- サブテキスト
  - 「分散型で、どこからでもアクセス可能」
  - 「データはあなたの管理下に」
- 「始める」ボタン

#### コード例
```dart
class WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  
  const WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // ロゴ
              Icon(
                Icons.spa,
                size: 120,
                color: Theme.of(context).primaryColor,
              ),
              
              const SizedBox(height: 32),
              
              // タイトル
              Text(
                'Meiso',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // キャッチコピー
              Text(
                'Nostrベースの\nシンプルなタスク管理',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              
              const SizedBox(height: 24),
              
              // サブテキスト
              Text(
                '分散型で、どこからでもアクセス可能\nデータはあなたの管理下に',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const Spacer(),
              
              // 始めるボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('始める'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### 2. 機能紹介ページ (`feature_intro_page.dart`)

#### UI要素
- スワイプ可能な機能紹介カルーセル
  - 3列レイアウト（Today / Tomorrow / Someday）の説明
  - タスクの作成・編集・削除
  - ドラッグ&ドロップでの並び替え
  - マルチデバイス同期
- ページインジケーター
- 「次へ」ボタン / 「スキップ」ボタン

#### コード例
```dart
class FeatureIntroPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  
  const FeatureIntroPage({
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<FeatureIntroPage> createState() => _FeatureIntroPageState();
}

class _FeatureIntroPageState extends State<FeatureIntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<FeatureInfo> _features = [
    FeatureInfo(
      icon: Icons.view_column,
      title: '3列レイアウト',
      description: 'Today、Tomorrow、Somedayでタスクを整理',
    ),
    FeatureInfo(
      icon: Icons.drag_indicator,
      title: 'ドラッグ&ドロップ',
      description: 'タスクを簡単に並び替え',
    ),
    FeatureInfo(
      icon: Icons.sync,
      title: 'マルチデバイス同期',
      description: 'Nostrプロトコルで自動同期',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onSkip,
                child: const Text('スキップ'),
              ),
            ),
            
            // 機能紹介カルーセル
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _features.length,
                itemBuilder: (context, index) {
                  return _buildFeatureCard(_features[index]);
                },
              ),
            ),
            
            // ページインジケーター
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _features.length,
                (index) => _buildPageIndicator(index == _currentPage),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 次へボタン
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('次へ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureCard(FeatureInfo feature) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            feature.icon,
            size: 100,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 32),
          Text(
            feature.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPageIndicator(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).primaryColor
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class FeatureInfo {
  final IconData icon;
  final String title;
  final String description;
  
  FeatureInfo({
    required this.icon,
    required this.title,
    required this.description,
  });
}
```

---

### 3. Nostrアカウントセットアップページ (`nostr_setup_page.dart`)

#### UI要素
- ページタイトル：「Nostrアカウントを設定」
- 3つのセットアップオプション：
  1. **Amber連携**（推奨）
     - アイコン：盾マーク
     - 説明：「既存のNostrアカウントをAmberアプリで管理」
     - ボタンスタイル：Primary
  2. **新規アカウント作成**
     - アイコン：プラスマーク
     - 説明：「アプリ内で新規作成（秘密鍵をローカル保存）」
     - ボタンスタイル：Outlined
  3. **秘密鍵インポート**
     - ボタンスタイル：Text
     - 説明：「既存の秘密鍵を入力してインポート」

#### コード例
```dart
class NostrSetupPage extends StatelessWidget {
  final VoidCallback onComplete;
  
  const NostrSetupPage({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              
              // タイトル
              Text(
                'Nostrアカウントを設定',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'タスクを同期するためにNostrアカウントが必要です',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // オプション1: Amber連携
              _SetupOptionCard(
                icon: Icons.security,
                title: 'Amberで署名',
                subtitle: '既存のNostrアカウントをAmberアプリで管理',
                badge: '推奨',
                onTap: () => _setupWithAmber(context),
                isPrimary: true,
              ),
              
              const SizedBox(height: 16),
              
              // オプション2: 新規作成
              _SetupOptionCard(
                icon: Icons.add_circle_outline,
                title: '新しいアカウントを作成',
                subtitle: 'アプリ内で新規作成（秘密鍵をローカル保存）',
                onTap: () => _createNewAccount(context),
                isPrimary: false,
              ),
              
              const SizedBox(height: 32),
              
              // オプション3: インポート
              TextButton(
                onPressed: () => _importPrivateKey(context),
                child: const Text('秘密鍵をインポート'),
              ),
              
              const Spacer(),
              
              // スキップオプション（開発用）
              TextButton(
                onPressed: () => _skipSetup(context),
                child: Text(
                  'スキップ（後で設定）',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _setupWithAmber(BuildContext context) async {
    // Amber連携処理
    final amberService = AmberService();
    
    // 1. Amberのインストール確認
    final isInstalled = await amberService.isAmberInstalled();
    if (!isInstalled) {
      _showInstallAmberDialog(context);
      return;
    }
    
    // 2. 公開鍵の取得
    try {
      final pubkey = await amberService.requestPublicKey();
      
      // 3. 公開鍵を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nostr_public_key', pubkey);
      await prefs.setString('signer_type', 'amber');
      
      onComplete();
    } catch (e) {
      _showErrorDialog(context, 'Amber連携に失敗しました: $e');
    }
  }
  
  Future<void> _createNewAccount(BuildContext context) async {
    // 新規アカウント作成処理
    try {
      // Rust側で鍵生成
      final account = await api.generateNewAccount();
      
      // セキュリティ警告を表示
      final confirmed = await _showSecurityWarningDialog(context);
      if (!confirmed) return;
      
      // 秘密鍵を安全に保存
      final storage = FlutterSecureStorage();
      await storage.write(
        key: 'nostr_secret_key',
        value: account.secretKey,
      );
      
      // 公開鍵を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nostr_public_key', account.publicKey);
      await prefs.setString('signer_type', 'local');
      
      // バックアップ推奨ダイアログ
      await _showBackupDialog(context, account.secretKey);
      
      onComplete();
    } catch (e) {
      _showErrorDialog(context, 'アカウント作成に失敗しました: $e');
    }
  }
  
  Future<void> _importPrivateKey(BuildContext context) async {
    // インポートダイアログを表示
    final secretKey = await _showImportDialog(context);
    if (secretKey == null || secretKey.isEmpty) return;
    
    try {
      // 秘密鍵の検証
      final pubkey = await api.getPublicKeyFromSecret(secretKey);
      
      // 秘密鍵を保存
      final storage = FlutterSecureStorage();
      await storage.write(
        key: 'nostr_secret_key',
        value: secretKey,
      );
      
      // 公開鍵を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nostr_public_key', pubkey);
      await prefs.setString('signer_type', 'local');
      
      onComplete();
    } catch (e) {
      _showErrorDialog(context, '無効な秘密鍵です: $e');
    }
  }
  
  Future<void> _skipSetup(BuildContext context) async {
    // テストアカウントで一時的に動作
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('signer_type', 'demo');
    
    _showDemoModeDialog(context);
    onComplete();
  }
}

class _SetupOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  final bool isPrimary;
  
  const _SetupOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isPrimary ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPrimary
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // アイコン
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isPrimary
                      ? Theme.of(context).primaryColor
                      : Colors.grey[700],
                  size: 32,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // テキスト
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isPrimary
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 矢印
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### 4. リレー設定ページ (`relay_setup_page.dart`)

#### UI要素
- ページタイトル：「リレーの設定」
- 説明テキスト：「データを保存するNostrリレーを選択してください」
- デフォルトリレーリスト（チェックボックス付き）
  - `wss://relay.damus.io` ✓
  - `wss://nos.lol` ✓
  - `wss://relay.nostr.band` ✓
  - `wss://nostr.wine`
- カスタムリレー追加ボタン
- 「完了」ボタン

#### コード例
```dart
class RelaySetupPage extends StatefulWidget {
  final VoidCallback onComplete;
  
  const RelaySetupPage({required this.onComplete});

  @override
  State<RelaySetupPage> createState() => _RelaySetupPageState();
}

class _RelaySetupPageState extends State<RelaySetupPage> {
  final List<RelayItem> _relays = [
    RelayItem(url: 'wss://relay.damus.io', enabled: true),
    RelayItem(url: 'wss://nos.lol', enabled: true),
    RelayItem(url: 'wss://relay.nostr.band', enabled: true),
    RelayItem(url: 'wss://nostr.wine', enabled: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            
            // タイトル
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  Text(
                    'リレーの設定',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'データを保存するNostrリレーを選択してください\n複数選択すると冗長性が高まります',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // リレーリスト
            Expanded(
              child: ListView.builder(
                itemCount: _relays.length,
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                itemBuilder: (context, index) {
                  return _buildRelayTile(_relays[index]);
                },
              ),
            ),
            
            // カスタムリレー追加
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: TextButton.icon(
                onPressed: _showAddRelayDialog,
                icon: const Icon(Icons.add),
                label: const Text('カスタムリレーを追加'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 完了ボタン
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: ElevatedButton(
                onPressed: _saveAndComplete,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('完了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRelayTile(RelayItem relay) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: CheckboxListTile(
        title: Text(
          relay.url,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        value: relay.enabled,
        onChanged: (value) {
          setState(() {
            relay.enabled = value ?? false;
          });
        },
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
  
  Future<void> _showAddRelayDialog() async {
    final controller = TextEditingController();
    
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('カスタムリレーを追加'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'リレーURL',
              hintText: 'wss://example.com',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
    
    if (url != null && url.isNotEmpty) {
      // URLバリデーション
      if (!url.startsWith('wss://') && !url.startsWith('ws://')) {
        _showErrorDialog('無効なURL形式です');
        return;
      }
      
      setState(() {
        _relays.add(RelayItem(url: url, enabled: true));
      });
    }
  }
  
  Future<void> _saveAndComplete() async {
    // 最低1つのリレーが選択されているか確認
    final enabledRelays = _relays.where((r) => r.enabled).toList();
    if (enabledRelays.isEmpty) {
      _showErrorDialog('最低1つのリレーを選択してください');
      return;
    }
    
    // リレー設定を保存
    final prefs = await SharedPreferences.getInstance();
    final relayUrls = enabledRelays.map((r) => r.url).toList();
    await prefs.setStringList('enabled_relays', relayUrls);
    
    // オンボーディング完了フラグを立てる
    await prefs.setBool('has_completed_onboarding', true);
    
    widget.onComplete();
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('エラー'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class RelayItem {
  final String url;
  bool enabled;
  
  RelayItem({required this.url, required this.enabled});
}
```

---

### 5. オンボーディングメイン画面 (`onboarding_screen.dart`)

#### コード例
```dart
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // スワイプ無効化
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          WelcomePage(
            onNext: () => _nextPage(),
          ),
          FeatureIntroPage(
            onNext: () => _nextPage(),
            onSkip: () => _jumpToPage(2),
          ),
          NostrSetupPage(
            onComplete: () => _nextPage(),
          ),
          RelaySetupPage(
            onComplete: () => _completeOnboarding(),
          ),
        ],
      ),
    );
  }
  
  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _jumpToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _completeOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }
}
```

---

### 6. Provider実装 (`onboarding_provider.dart`)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// オンボーディング完了状態
final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('has_completed_onboarding') ?? false;
});

// 現在のオンボーディングステップ
final onboardingStepProvider = StateProvider<int>((ref) => 0);

// Nostrアカウント設定状態
final nostrAccountSetupProvider = StateProvider<NostrAccountSetup?>((ref) => null);

// リレー設定状態
final relaySetupProvider = StateProvider<List<RelayConfig>>((ref) {
  return [
    RelayConfig(url: 'wss://relay.damus.io', enabled: true),
    RelayConfig(url: 'wss://nos.lol', enabled: true),
    RelayConfig(url: 'wss://relay.nostr.band', enabled: true),
    RelayConfig(url: 'wss://nostr.wine', enabled: false),
  ];
});

class NostrAccountSetup {
  final String publicKey;
  final SignerType signerType;
  
  NostrAccountSetup({
    required this.publicKey,
    required this.signerType,
  });
}

enum SignerType {
  amber,
  local,
  demo,
}

class RelayConfig {
  final String url;
  bool enabled;
  
  RelayConfig({required this.url, required this.enabled});
}
```

---

### 7. Amberサービス (`amber_service.dart`)

```dart
import 'package:device_apps/device_apps.dart';

class AmberService {
  static const String amberPackage = 'com.greenart7c3.nostrsigner';
  
  /// Amberがインストールされているか確認
  Future<bool> isAmberInstalled() async {
    final app = await DeviceApps.getApp(amberPackage);
    return app != null;
  }
  
  /// Amberから公開鍵を取得
  Future<String> requestPublicKey() async {
    // TODO: Amber Intent連携実装
    // Phase 2で実装
    throw UnimplementedError('Amber integration not yet implemented');
  }
  
  /// Amberでイベントに署名
  Future<String> signEvent(Map<String, dynamic> event) async {
    // TODO: Amber Intent連携実装
    // Phase 2で実装
    throw UnimplementedError('Amber integration not yet implemented');
  }
}
```

---

### 8. main.dartの更新

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'providers/onboarding_provider.dart';
import 'app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meiso',
      theme: AppTheme.lightTheme,
      home: Consumer(
        builder: (context, ref, child) {
          final hasCompletedAsync = ref.watch(hasCompletedOnboardingProvider);
          
          return hasCompletedAsync.when(
            data: (hasCompleted) {
              return hasCompleted ? const HomeScreen() : const OnboardingScreen();
            },
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
```

---

## テスト項目

### 基本フロー
- [ ] 初回起動時にオンボーディングが表示される
- [ ] 2回目以降の起動ではホーム画面が表示される
- [ ] ページ遷移がスムーズに動作する

### ウェルカムページ
- [ ] ロゴが正しく表示される
- [ ] 「始める」ボタンで次のページに遷移

### 機能紹介ページ
- [ ] 3つの機能が正しく表示される
- [ ] ページインジケーターが動作する
- [ ] スキップボタンでセットアップページにジャンプ

### Nostrセットアップページ
- [ ] Amber連携オプションが表示される
- [ ] 新規作成オプションが表示される
- [ ] インポートオプションが表示される
- [ ] スキップでデモモードに移行できる

### リレー設定ページ
- [ ] デフォルトリレーが表示される
- [ ] リレーの有効/無効を切り替えられる
- [ ] カスタムリレーを追加できる
- [ ] 最低1つのリレーが選択されている状態で完了できる

### データ永続化
- [ ] オンボーディング完了後、フラグが保存される
- [ ] アプリ再起動後もオンボーディングがスキップされる

---

## Phase 3での拡張

### Citrine推奨ページの追加

リレー設定ページの後に、Citrine推奨ページを追加：

```dart
class CitrineRecommendationPage extends StatelessWidget {
  final VoidCallback onComplete;
  
  const CitrineRecommendationPage({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Spacer(),
              
              Icon(
                Icons.rocket_launch,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Citrineでさらに快適に',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'ローカルリレーアプリCitrineを使用すると:\n\n'
                '• オフラインでもタスク管理可能\n'
                '• より高速な同期\n'
                '• プライバシーの強化\n'
                '• バッテリー消費の削減',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _installCitrine(context),
                  child: const Text('Citrineをインストール'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: onComplete,
                child: const Text('後でインストール'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _installCitrine(BuildContext context) {
    // Play Storeを開く
    // TODO: url_launcherで実装
  }
}
```

---

## デザインガイドライン

### カラー
- プライマリカラー：紫系（Theme.of(context).primaryColor）
- アクセントカラー：青系
- テキストカラー：ダークグレー
- 背景：ホワイト

### フォント
- タイトル：太字、大きめ
- 本文：レギュラー、読みやすいサイズ
- リレーURL：等幅フォント

### スペーシング
- ページ余白：32px
- 要素間：16px - 32px
- ボタン内部：縦16px

### アニメーション
- ページ遷移：300ms、easeInOut
- ボタンタップ：ripple効果
- カード：elevation 1-4

---

## 実装順序

1. **ディレクトリ・ファイル作成**
   - `lib/presentation/onboarding/` ディレクトリ作成
   - 各ページファイルを作成

2. **ウェルカムページ実装**
   - 静的UIを作成
   - ボタン動作を実装

3. **機能紹介ページ実装**
   - PageViewを実装
   - ページインジケーターを追加

4. **Nostrセットアップページ実装**
   - UI実装
   - スキップ機能実装（デモモード）
   - Amber連携はPhase 2で実装

5. **リレー設定ページ実装**
   - リレーリスト表示
   - チェックボックス動作
   - カスタムリレー追加

6. **オンボーディングメイン画面実装**
   - PageView統合
   - ページ遷移制御

7. **Provider実装**
   - 状態管理追加
   - データ永続化

8. **main.dart更新**
   - 初回起動判定追加
   - ルーティング実装

9. **テスト**
   - 各ページ単体テスト
   - フロー全体のテスト
   - データ永続化テスト

---

## 参考リソース

- [Flutter PageView](https://api.flutter.dev/flutter/widgets/PageView-class.html)
- [Riverpod Provider](https://riverpod.dev/)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)
- [FlutterSecureStorage](https://pub.dev/packages/flutter_secure_storage)
- [DeviceApps](https://pub.dev/packages/device_apps)

---

**オンボーディング画面で、新規ユーザーをスムーズにMeisoの世界へ導きましょう！** 🎉

