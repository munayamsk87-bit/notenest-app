import 'package:flutter/material.dart';

import '../core/constants/app_info.dart';
import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';
import '../widgets/mascot.dart';

/// About + privacy information (Spec §11, §12, §13 screen 17).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('about'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.darkSurfaceAlt
                        : AppColors.lavender,
                    borderRadius: BorderRadius.circular(34),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Mascot(size: 100, bob: false),
                ),
                const SizedBox(height: 14),
                Text(
                  AppInfo.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(AppInfo.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text('${context.t('appVersion')}: ${AppInfo.versionLabel}',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _card(context, context.t('about'), context.t('aboutBody')),
          const SizedBox(height: 12),
          _card(context, context.t('privacy'), context.t('privacyBody')),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.tag_rounded),
            title: const Text('Package ID'),
            trailing: const Text(AppInfo.packageId),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: Text(context.t('builtWith')),
            trailing: const Text('Flutter / Dart'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, String body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
