import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';

/// Persists user preferences (Spec §12). Non-secret values live in
/// SharedPreferences; the AI key is kept in the platform secure store and is
/// never written to the database, logs or source.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _kThemeMode = 'theme_mode';
  static const String _kThemePack = 'theme_pack';
  static const String _kLayout = 'layout_mode';
  static const String _kLocale = 'locale';
  static const String _kDefaultColor = 'default_color';
  static const String _kMoveCompleted = 'move_completed_bottom';
  static const String _kAppLock = 'app_lock';
  static const String _kOnboardingDone = 'onboarding_done';
  static const String _kAiBaseUrl = 'ai_base_url';
  static const String _kAiModel = 'ai_model';
  static const String _kGuestMode = 'guest_mode';
  static const String _kAccountEmail = 'account_email';

  static const String _secureAiKey = 'notenest.ai_api_key';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Appearance -------------------------------------------------------------

  Future<ThemeMode> themeMode() async {
    final String value = (await _p).getString(_kThemeMode) ?? 'system';
    return ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async =>
      (await _p).setString(_kThemeMode, mode.name);

  Future<ThemePack> themePack() async {
    final String value = (await _p).getString(_kThemePack) ?? ThemePack.classic.name;
    return ThemePack.values.firstWhere(
      (ThemePack p) => p.name == value,
      orElse: () => ThemePack.classic,
    );
  }

  Future<void> setThemePack(ThemePack pack) async =>
      (await _p).setString(_kThemePack, pack.name);

  Future<String> layoutMode() async =>
      (await _p).getString(_kLayout) ?? 'grid';

  Future<void> setLayoutMode(String mode) async =>
      (await _p).setString(_kLayout, mode);

  Future<Locale> locale() async {
    final String value = (await _p).getString(_kLocale) ?? 'en';
    return Locale(value);
  }

  Future<void> setLocale(Locale locale) async =>
      (await _p).setString(_kLocale, locale.languageCode);

  Future<int> defaultNoteColor() async =>
      (await _p).getInt(_kDefaultColor) ?? 0;

  Future<void> setDefaultNoteColor(int color) async =>
      (await _p).setInt(_kDefaultColor, color);

  Future<bool> moveCompletedToBottom() async =>
      (await _p).getBool(_kMoveCompleted) ?? true;

  Future<void> setMoveCompletedToBottom(bool value) async =>
      (await _p).setBool(_kMoveCompleted, value);

  Future<bool> appLockEnabled() async => (await _p).getBool(_kAppLock) ?? false;

  Future<void> setAppLockEnabled(bool value) async =>
      (await _p).setBool(_kAppLock, value);

  Future<bool> onboardingDone() async =>
      (await _p).getBool(_kOnboardingDone) ?? false;

  Future<void> setOnboardingDone(bool value) async =>
      (await _p).setBool(_kOnboardingDone, value);

  // --- AI (optional, Spec §7) --------------------------------------------------

  Future<String?> aiApiKey() => _secure.read(key: _secureAiKey);

  Future<void> setAiApiKey(String? key) async {
    if (key == null || key.trim().isEmpty) {
      await _secure.delete(key: _secureAiKey);
    } else {
      await _secure.write(key: _secureAiKey, value: key.trim());
    }
  }

  Future<String> aiBaseUrl() async =>
      (await _p).getString(_kAiBaseUrl) ?? 'https://api.openai.com/v1';

  Future<void> setAiBaseUrl(String url) async =>
      (await _p).setString(_kAiBaseUrl, url.trim());

  Future<String> aiModel() async =>
      (await _p).getString(_kAiModel) ?? 'gpt-4o-mini';

  Future<void> setAiModel(String model) async =>
      (await _p).setString(_kAiModel, model.trim());

  // --- Account (optional cloud, Spec §9) --------------------------------------

  Future<bool> guestMode() async => (await _p).getBool(_kGuestMode) ?? true;

  Future<void> setGuestMode(bool value) async =>
      (await _p).setBool(_kGuestMode, value);

  Future<String?> accountEmail() async => (await _p).getString(_kAccountEmail);

  Future<void> setAccountEmail(String? email) async {
    if (email == null) {
      await (await _p).remove(_kAccountEmail);
    } else {
      await (await _p).setString(_kAccountEmail, email);
    }
  }
}
