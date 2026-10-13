import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/services/settings_service.dart';

/// Holds app-wide preferences and rebuilds the app when they change (Spec §12).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._service);

  final SettingsService _service;

  ThemeMode _themeMode = ThemeMode.system;
  ThemePack _themePack = ThemePack.classic;
  LayoutModeValue _layout = LayoutModeValue.grid;
  Locale _locale = const Locale('en');
  int _defaultColor = 0;
  bool _moveCompletedToBottom = true;
  bool _appLock = false;
  bool _onboardingDone = false;
  bool _guestMode = true;
  String? _accountEmail;
  bool _ready = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  ThemePack get themePack => _themePack;
  LayoutModeValue get layout => _layout;
  Locale get locale => _locale;
  int get defaultColor => _defaultColor;
  bool get moveCompletedToBottom => _moveCompletedToBottom;
  bool get appLockEnabled => _appLock;
  bool get onboardingDone => _onboardingDone;
  bool get guestMode => _guestMode;
  String? get accountEmail => _accountEmail;
  bool get ready => _ready;

  Future<void> load() async {
    _themeMode = await _service.themeMode();
    _themePack = await _service.themePack();
    _layout = (await _service.layoutMode()) == 'list'
        ? LayoutModeValue.list
        : LayoutModeValue.grid;
    _locale = await _service.locale();
    _defaultColor = await _service.defaultNoteColor();
    _moveCompletedToBottom = await _service.moveCompletedToBottom();
    _appLock = await _service.appLockEnabled();
    _onboardingDone = await _service.onboardingDone();
    _guestMode = await _service.guestMode();
    _accountEmail = await _service.accountEmail();
    _ready = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _service.setThemeMode(mode);
  }

  Future<void> setThemePack(ThemePack pack) async {
    _themePack = pack;
    notifyListeners();
    await _service.setThemePack(pack);
  }

  Future<void> setLayout(LayoutModeValue layout) async {
    _layout = layout;
    notifyListeners();
    await _service.setLayoutMode(layout.name);
  }

  Future<void> toggleLayout() async {
    await setLayout(
      _layout == LayoutModeValue.grid ? LayoutModeValue.list : LayoutModeValue.grid,
    );
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _service.setLocale(locale);
  }

  Future<void> setDefaultColor(int color) async {
    _defaultColor = color;
    notifyListeners();
    await _service.setDefaultNoteColor(color);
  }

  Future<void> setMoveCompletedToBottom(bool value) async {
    _moveCompletedToBottom = value;
    notifyListeners();
    await _service.setMoveCompletedToBottom(value);
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLock = value;
    notifyListeners();
    await _service.setAppLockEnabled(value);
  }

  Future<void> setOnboardingDone(bool value) async {
    _onboardingDone = value;
    notifyListeners();
    await _service.setOnboardingDone(value);
  }

  Future<void> setGuestMode(bool value) async {
    _guestMode = value;
    notifyListeners();
    await _service.setGuestMode(value);
  }

  Future<void> setAccountEmail(String? email) async {
    _accountEmail = email;
    notifyListeners();
    await _service.setAccountEmail(email);
  }
}

/// Local mirror of the layout enum so the provider stays independent of the
/// data-layer enum ordering.
enum LayoutModeValue { grid, list }
