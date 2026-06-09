import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Meisoアプリのテーマ設定
///
/// Material 3 (Material You) をベースに、Nostr 風の紫をシードカラーとした
/// ラベンダー基調のトーナルパレットで全体感を統一する。Android 専用リリースの
/// ため、M3 コンポーネント(角丸カード / ピル型ボタン / NavigationBar インジケーター)を
/// 積極的に採用する。
class AppTheme {
  // ブランドの紫（シードカラー）
  static const Color primaryPurple = Color(0xFF7C3AED); // メインの紫
  static const Color lightPurple = Color(0xFF9F7AEA); // 明るい紫
  static const Color darkPurple = Color(0xFF5B21B6); // 濃い紫
  static const Color accentPurple = Color(0xFFA78BFA); // アクセント用

  // エイリアス（後方互換性のため）
  static const Color primaryColor = primaryPurple;
  static const Color accentColor = accentPurple;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;

  // ライトモードカラー（ラベンダー基調のトーナルサーフェス）
  static const Color lightBackground = Color(0xFFF7F2FC); // 画面背景（淡いラベンダー）
  static const Color lightSurface = Color(0xFFFBF8FE);
  static const Color lightCard = Color(0xFFFFFFFF); // タスク行などのカード
  static const Color lightSurfaceContainer = Color(0xFFEFE8FA); // セクションカード/チップ
  static const Color lightDivider = Color(0xFFE7E0F2);
  static const Color lightTextPrimary = Color(0xFF1C1B1F);
  static const Color lightTextSecondary = Color(0xFF625B71);
  static const Color lightTextDisabled = Color(0xFF9A93A8);

  // ダークモードカラー（M3 ダークのラベンダートーン）
  static const Color darkBackground = Color(0xFF141218); // 画面背景
  static const Color darkSurface = Color(0xFF1C1A21);
  static const Color darkCard = Color(0xFF211F26);
  static const Color darkSurfaceContainer = Color(0xFF2A2731); // セクションカード/チップ
  static const Color darkDivider = Color(0xFF3A3641);
  static const Color darkTextPrimary = Color(0xFFE7E0EB);
  static const Color darkTextSecondary = Color(0xFFCAC2D6);
  static const Color darkTextDisabled = Color(0xFF8F8799);

  // 共通カラー
  static const Color completedColor = Color(0xFF9A93A8);

  // 角丸・余白の共通トークン
  static const double radiusCard = 20;
  static const double radiusButton = 16;
  static const double radiusDialog = 28;

  // ライトテーマ
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryPurple,
      onPrimary: Colors.white,
      secondary: lightPurple,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      onSurfaceVariant: lightTextSecondary,
      error: const Color(0xFFBA1A1A),
      outlineVariant: lightDivider,
    );
    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      background: lightBackground,
      card: lightCard,
      surfaceContainer: lightSurfaceContainer,
      divider: lightDivider,
      textPrimary: lightTextPrimary,
      textSecondary: lightTextSecondary,
      textDisabled: lightTextDisabled,
      accent: primaryPurple,
      onAccent: Colors.white,
    );
  }

  // ダークテーマ
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accentPurple,
      onPrimary: darkBackground,
      secondary: lightPurple,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      onSurfaceVariant: darkTextSecondary,
      error: const Color(0xFFFFB4AB),
      outlineVariant: darkDivider,
    );
    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      background: darkBackground,
      card: darkCard,
      surfaceContainer: darkSurfaceContainer,
      divider: darkDivider,
      textPrimary: darkTextPrimary,
      textSecondary: darkTextSecondary,
      textDisabled: darkTextDisabled,
      accent: accentPurple,
      onAccent: darkBackground,
    );
  }

  /// ライト/ダーク共通のテーマ構築。値だけを差し替えて重複を避ける。
  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color background,
    required Color card,
    required Color surfaceContainer,
    required Color divider,
    required Color textPrimary,
    required Color textSecondary,
    required Color textDisabled,
    required Color accent,
    required Color onAccent,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.notoSansJp().fontFamily,
      scaffoldBackgroundColor: background,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),

      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          color: textDisabled,
          fontSize: 16,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onAccent),
        side: BorderSide(
          color: divider,
          width: 2,
        ),
        shape: const CircleBorder(),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: isDark ? 0.30 : 0.16),
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : textSecondary,
            size: 24,
          );
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainer,
        selectedColor: accent.withValues(alpha: 0.18),
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return onAccent;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return null;
        }),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusDialog),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusDialog)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
      ),
    );
  }

  // セクションカード用の塗りカラー（M3 surfaceContainer 相当）
  static Color sectionCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkSurfaceContainer : lightSurfaceContainer;
  }

  // セクション見出しスタイル（紫・大文字・字間広め）
  static TextStyle sectionHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? accentPurple : primaryPurple,
      letterSpacing: 1.2,
    );
  }

  // テキストスタイル（カスタム）- テーマに応じて動的に色を決定
  static TextStyle todoTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: isDark ? darkTextPrimary : lightTextPrimary,
      height: 1.4,
      letterSpacing: 0.1,
    );
  }

  static const TextStyle todoTitleCompleted = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: completedColor,
    decoration: TextDecoration.lineThrough,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static TextStyle dateHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: isDark ? darkTextSecondary : lightTextSecondary,
      letterSpacing: 0.5,
    );
  }

  static TextStyle columnTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: isDark ? darkTextPrimary : lightTextPrimary,
      letterSpacing: 0.3,
    );
  }
}
