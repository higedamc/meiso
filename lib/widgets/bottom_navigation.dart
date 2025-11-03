import 'package:flutter/material.dart';

/// 底部ナビゲーションバー（TODAY / + / SOMEDAY）
class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    required this.onTodayTap,
    required this.onAddTap,
    required this.onSomedayTap,
    this.onSomedayLongPress,
    this.isSomedayActive = false,
    super.key,
  });

  final VoidCallback onTodayTap;
  final VoidCallback onAddTap;
  final VoidCallback onSomedayTap;
  final VoidCallback? onSomedayLongPress;
  final bool isSomedayActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade700,
            Colors.deepPurple.shade900,
          ],
        ),
      ),
      child: Row(
        children: [
          // TODAY
          Expanded(
            child: InkWell(
              onTap: onTodayTap,
              child: Container(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'TODAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // アクティブ時のインジケーター（TODAYページにいる時のみ表示）
                    if (!isSomedayActive)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 6), // スペース確保
                  ],
                ),
              ),
            ),
          ),

          // + ボタン
          InkWell(
            onTap: onAddTap,
            child: Container(
              width: 60,
              alignment: Alignment.center,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // SOMEDAY
          Expanded(
            child: InkWell(
              onTap: onSomedayTap,
              onLongPress: onSomedayLongPress,
              child: Container(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'SOMEDAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // アクティブ時のインジケーター（SOMEDAYページにいる時のみ表示）
                    if (isSomedayActive)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 6), // スペース確保
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

