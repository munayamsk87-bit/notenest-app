import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/context_ext.dart';
import '../data/services/sync_service.dart';
import '../providers/settings_provider.dart';

/// Optional account screen. Cloud sync is NOT configured in this build, so this
/// screen is honest about it and keeps local-only mode as the default (Spec §9).
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.t('account'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: <Widget>[
                Icon(Icons.cloud_off_rounded,
                    size: 44, color: context.scheme.primary),
                const SizedBox(height: 12),
                Text(context.t('cloudSync'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  context.t('syncNotConfigured'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('privacyBody'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              // No backend is wired in: keep the user local-only and be honest.
              await settings.setGuestMode(true);
              await settings.setAccountEmail(null);
              if (context.mounted) {
                context.showSnack(context.t('guestMode'));
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.person_outline_rounded),
            label: Text(context.t('continueAsGuest')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await SyncService.instance.signInWithGoogle();
              } on SyncNotConfiguredException {
                if (context.mounted) {
                  context.showSnack(context.t('syncNotConfigured'), error: true);
                }
              }
            },
            icon: const Icon(Icons.login_rounded),
            label: Text(context.t('signIn')),
          ),
          const SizedBox(height: 24),
          Text(
            '• ${context.t('guestMode')}\n'
            '• ${context.t('privacy')}\n'
            '• ${context.t('backupRestore')}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
