import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/storage_keys.dart';
import '../storage/local_store.dart';
import '../i18n/app_lang.dart';

/// 앱 언어 상태. 기기 전역(계정 스코프 제외)으로 저장.
///
/// 첫 실행에서 언어를 묻지 않는다 — 기기 로케일을 그대로 쓴다(스펙 §28).
/// 바꾸고 싶으면 더보기 → 설정에서 고른다.
class LocaleNotifier extends Notifier<AppLang> {
  @override
  AppLang build() {
    final saved = LocalStore.instance.getString(StorageKeys.appLang);
    if (saved != null) return appLangFromCode(saved);
    return deviceLang();
  }

  /// 기기 로케일에 맞는 언어. 지원하지 않는 언어면 한국어.
  static AppLang deviceLang() {
    final code =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return appLangFromCode(code);
  }

  Future<void> set(AppLang lang) async {
    state = lang;
    await LocalStore.instance.setString(StorageKeys.appLang, lang.code);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, AppLang>(LocaleNotifier.new);
