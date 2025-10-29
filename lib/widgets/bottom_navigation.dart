import 'package:flutter/material.dart';

/// 底部ナビゲーションバー（TODAY / + / SOMEDAY）
class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    required this.onTodayTap,
    required this.onAddTap,
    required this.onSomedayTap,
    this.onSomedayLongPress,
    super.key,
  });

  final VoidCallback onTodayTap;
  final VoidCallback onAddTap;
  final VoidCallback onSomedayTap;
  final VoidCallback? onSomedayLongPress;

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'TODAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
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
                child: const Text(
                  'SOMEDAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

