import 'package:flutter/material.dart';

import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';
import '../data/services/ai_service.dart';
import '../data/services/settings_service.dart';

/// A provider preset — fills the Base URL (and a suggested model).
class _Preset {
  const _Preset(this.name, this.baseUrl, this.model);
  final String name;
  final String baseUrl;
  final String model;
}

/// Full AI configuration: provider preset, Base URL, model, key and a real
/// "Test connection" check. This is what makes the AI features actually work.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  static const List<_Preset> _presets = <_Preset>[
    _Preset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
    _Preset('Groq', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile'),
    _Preset('OpenRouter', 'https://openrouter.ai/api/v1', 'openai/gpt-4o-mini'),
    _Preset('Together', 'https://api.together.xyz/v1',
        'meta-llama/Llama-3.3-70B-Instruct-Turbo'),
    _Preset('Google Gemini',
        'https://generativelanguage.googleapis.com/v1beta/openai', 'gemini-2.0-flash'),
  ];

  final TextEditingController _baseController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  bool _obscure = true;
  bool _testing = false;
  bool _loaded = false;
  AiTestResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SettingsService s = SettingsService.instance;
    final String? key = await s.aiApiKey();
    final String base = await s.aiBaseUrl();
    final String model = await s.aiModel();
    if (!mounted) return;
    setState(() {
      _keyController.text = key ?? '';
      _baseController.text = base;
      _modelController.text = model;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _baseController.dispose();
    _modelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final SettingsService s = SettingsService.instance;
    await s.setAiBaseUrl(AiService.normaliseBase(_baseController.text));
    await s.setAiModel(_modelController.text);
    await s.setAiApiKey(_keyController.text);
    if (!mounted) return;
    setState(() => _baseController.text = AiService.normaliseBase(_baseController.text));
    context.showSnack(context.t('saved'));
  }

  Future<void> _test() async {
    await _save();
    if (!mounted) return;
    setState(() {
      _testing = true;
      _result = null;
    });
    final AiTestResult result = await AiService.instance.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = result;
    });
  }

  void _applyPreset(_Preset preset) {
    setState(() {
      _baseController.text = preset.baseUrl;
      _modelController.text = preset.model;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('aiSettings'))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                _infoCard(context),
                const SizedBox(height: 18),
                _label(context.t('aiProvider')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets
                      .map((_Preset p) => ActionChip(
                            avatar: const Icon(Icons.bolt_rounded, size: 16),
                            label: Text(p.name),
                            onPressed: () => _applyPreset(p),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('aiPresetNote'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _baseController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: context.t('aiBaseUrl'),
                    hintText: 'https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: context.t('aiModel'),
                    helperText: context.t('aiModelHint'),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _keyController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: context.t('aiApiKey'),
                    helperText: context.t('aiApiKeyHint'),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _test,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: Text(_testing ? context.t('aiTesting') : context.t('aiTest')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(context.t('save')),
                      ),
                    ),
                  ],
                ),
                if (_result != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _resultCard(context, _result!),
                ],
              ],
            ),
    );
  }

  Widget _infoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Theme.of(context).colorScheme.primary.withOpacity(0.12),
            AppColors.champagne.withOpacity(0.22),
          ],
        ),
        border: Border.all(color: AppColors.goldHairline, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t('aiGetKeyHint'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, AiTestResult result) {
    final Color color =
        result.ok ? const Color(0xFF2E7D57) : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(result.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.scheme.primary,
          ),
    );
  }
}
