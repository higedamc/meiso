import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    
    // ページの内容を定義
    // ローカルの実際のLottieアニメーションを使用
    final pages = [
      _OnboardingPage(
        lottieUrl: 'assets/lottie/checklist.json',
        title: l10n.onboardingWelcomeTitle,
        description: l10n.onboardingWelcomeDescription,
        fallbackIcon: Icons.check_circle_outline,
      ),
      _OnboardingPage(
        lottieUrl: 'assets/lottie/sync.json',
        title: l10n.onboardingNostrSyncTitle,
        description: l10n.onboardingNostrSyncDescription,
        fallbackIcon: Icons.cloud_sync,
      ),
      _OnboardingPage(
        lottieUrl: 'assets/lottie/calendar.json',
        title: l10n.onboardingSmartDateTitle,
        description: l10n.onboardingSmartDateDescription,
        fallbackIcon: Icons.edit_calendar_outlined,
      ),
      _OnboardingPage(
        lottieUrl: 'assets/lottie/privacy.json',
        title: l10n.onboardingPrivacyTitle,
        description: l10n.onboardingPrivacyDescription,
        fallbackIcon: Icons.privacy_tip_outlined,
      ),
      _OnboardingPage(
        lottieUrl: 'assets/lottie/rocket.json',
        title: l10n.onboardingGetStartedTitle,
        description: l10n.onboardingGetStartedDescription,
        fallbackIcon: Icons.rocket_launch,
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1), // Indigo
              Color(0xFF8B5CF6), // Purple
              Color(0xFFA855F7), // Purple-400
            ],
          ),
        ),
        child: SafeArea(
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
                    child: Text(
                      l10n.skipButton,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                    (index) => _buildPageIndicator(index),
                  ),
                ),
              ),

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
                      backgroundColor: const Color(0xFF1F2937), // Gray-800
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == pages.length - 1 ? l10n.startButton : l10n.nextButton,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_currentPage < pages.length - 1) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Colors.white
            : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// オンボーディングページ
class _OnboardingPage extends StatefulWidget {
  final String lottieUrl;
  final String title;
  final String description;
  final IconData fallbackIcon;

  const _OnboardingPage({
    required this.lottieUrl,
    required this.title,
    required this.description,
    required this.fallbackIcon,
  });

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _titleAnimation;
  late Animation<double> _descriptionAnimation;
  late Animation<double> _lottieAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラーの初期化
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // タイトルのフェードイン（0.0 - 0.3秒）
    _titleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.0,
          0.3,
          curve: Curves.easeOut,
        ),
      ),
    );

    // 説明のフェードイン（0.2 - 0.5秒）
    _descriptionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.2,
          0.5,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Lottieアニメーションのフェードイン（0.4 - 0.8秒）
    _lottieAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.4,
          0.8,
          curve: Curves.easeOut,
        ),
      ),
    );

    // カード全体のスライドアニメーション
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Lottieアニメーション領域のスケール
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.4,
          0.8,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // アニメーション開始
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _animationController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 12,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // タイトル（フェードイン）
                      FadeTransition(
                        opacity: _titleAnimation,
                        child: Text(
                          widget.title,
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1F2937),
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 説明（フェードイン）
                      FadeTransition(
                        opacity: _descriptionAnimation,
                        child: Text(
                          widget.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF6B7280),
                                height: 1.6,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Lottieアニメーション（フェードイン + スケール）
                      FadeTransition(
                        opacity: _lottieAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: SizedBox(
                            height: 280,
                            child: _buildAnimation(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    // Lottieアニメーションをロード（ローカルアセット）
    return Lottie.asset(
      widget.lottieUrl,
      fit: BoxFit.contain,
      animate: true,
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder();
      },
    );
  }


  Widget _buildPlaceholder() {
    // プレースホルダー: グラデーション付きの丸角矩形
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.1),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          size: 120,
          color: const Color(0xFF6366F1).withOpacity(0.3),
        ),
      ),
    );
  }
}

