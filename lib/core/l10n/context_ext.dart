import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Convenience accessors so screens read cleanly.
extension ContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Translate a key with optional `{placeholder}` params.
  String t(String key, [Map<String, Object>? params]) => l10n.tr(key, params);

  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  void showSnack(
    String message, {
    bool error = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(this);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: actionLabel != null
            ? const Duration(seconds: 8)
            : const Duration(seconds: 4),
        backgroundColor: error ? Theme.of(this).colorScheme.error : null,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: error ? Theme.of(this).colorScheme.onError : null,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
