import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Convenience accessors so screens read cleanly.
extension ContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Translate a key with optional `{placeholder}` params.
  String t(String key, [Map<String, Object>? params]) => l10n.tr(key, params);

  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  void showSnack(String message, {bool error = false}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(this);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(this).colorScheme.error : null,
      ),
    );
  }
}
