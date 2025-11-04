import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';

/// オンボーディングスクリーン
/// 初回起動時にアプリの使い方を説明
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _navigateToLoginPage() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // ページの内容を定義
    final pages = [
      _OnboardingPage(
        icon: Icons.check_circle_outline,
        iconColor: AppTheme.primaryColor,
        title: 'Meisoへようこそ',
        description: 'シンプルで美しいToDoアプリ\nNostrで同期して、どこでもタスク管理',
      ),
      _OnboardingPage(
        icon: Icons.cloud_sync,
        iconColor: AppTheme.accentColor,
        title: 'Nostrで同期',
        description: 'あなたのタスクをNostrネットワークで同期\n複数デバイスで自動的に最新状態を保ちます',
      ),
      _OnboardingPage(
        icon: Icons.edit_calendar_outlined,
        iconColor: Colors.purple,
        title: 'スマートな日付入力',
        description: 'タスクに "tomorrow" と入力すれば明日のタスクに\n"everyday" で毎日繰り返すタスクを作成\nTeuxDeuxスタイルの自然な入力をサポート',
      ),
      _OnboardingPage(
        icon: Icons.privacy_tip_outlined,
        iconColor: Colors.green,
        title: 'プライバシー第一',
        description: '中央サーバーなし。すべてのデータはあなたの管理下に\nNostrの分散型ネットワークで安全に保管',
      ),
      _OnboardingPage(
        icon: Icons.rocket_launch,
        iconColor: Colors.orange,
        title: 'さあ、始めましょう',
        description: 'Amberでログインするか、\n新しい秘密鍵を生成してスタート',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            if (_currentPage < pages.length - 1)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => _pageController.animateToPage(
                    pages.length - 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: const Text('スキップ'),
                ),
              )
            else
              const SizedBox(height: 48),

            // ページビュー
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return pages[index];
                },
              ),
            ),

            // インジケーター
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => _buildPageIndicator(index),
              ),
            ),

            const SizedBox(height: 32),

            // ボタン
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _currentPage == pages.length - 1
                      ? _navigateToLoginPage
                      : () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage == pages.length - 1 ? 'ログイン' : '次へ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? AppTheme.primaryColor
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// オンボーディングページ
class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: iconColor,
            ),
          ),

          const SizedBox(height: 48),

          // タイトル
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // 説明
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

