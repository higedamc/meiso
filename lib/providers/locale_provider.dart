import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

/// ロケール管理のProvider
/// ユーザーが選択した言語設定を管理します。
/// nullの場合はシステムのデフォルト言語を使用します。
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  /// 保存されたロケール設定を読み込む
  Future<void> _loadLocale() async {
    final languageCode = localStorageService.getLanguage();
    if (languageCode != null && languageCode.isNotEmpty) {
      state = Locale(languageCode);
    }
  }

  /// ロケールを変更する
  /// [locale] が null の場合はシステムのデフォルト言語を使用
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    if (locale != null) {
      await localStorageService.setLanguage(locale.languageCode);
    } else {
      await localStorageService.clearLanguage();
    }
  }

  /// システムのデフォルト言語を使用する
  Future<void> useSystemDefault() async {
    await setLocale(null);
  }
}

