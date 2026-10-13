import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// Thrown when the user hasn't supplied an AI key/endpoint yet. The UI shows a
/// setup message instead of a fabricated result (Spec §7).
class AiNotConfiguredException implements Exception {
  const AiNotConfiguredException();
}

/// A user-facing AI failure. [hint] carries an actionable next step.
class AiException implements Exception {
  AiException(this.message, {this.hint});
  final String message;
  final String? hint;
  @override
  String toString() => hint == null ? message : '$message\n$hint';
}

/// Outcome of the "Test connection" check.
class AiTestResult {
  const AiTestResult({required this.ok, required this.message});
  final bool ok;
  final String message;
}

/// Optional AI helpers (summarise / rewrite / checklist). Entirely opt-in and
/// only ever called from an explicit user action. No keys are hardcoded — the
/// key lives in the platform secure store (Spec §7, §11).
///
/// Works with any OpenAI-compatible endpoint: the user chooses the Base URL and
/// model in AI settings, so providers other than OpenAI are supported.
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final SettingsService _settings = SettingsService.instance;

  Future<bool> get isConfigured async {
    final String? key = await _settings.aiApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<String> summarize(String text) =>
      _complete('Summarise the following note in a few clear sentences:\n\n$text');

  Future<String> rewrite(String text) =>
      _complete('Rewrite the following note to be clearer and better organised, '
          'keeping its meaning:\n\n$text');

  Future<List<String>> generateChecklist(String text) async {
    final String raw = await _complete(
      'Turn the following note into a short actionable checklist. '
      'Return only the items, one per line, without numbering or bullets:\n\n$text',
    );
    return raw
        .split('\n')
        .map((String line) => line.replaceFirst(RegExp(r'^[\-\*\d\.\)\s]+'), '').trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  }

  /// Sends a tiny request so the user can verify their key and endpoint before
  /// relying on AI features. Returns a precise, human-readable result.
  Future<AiTestResult> testConnection() async {
    final String? key = await _settings.aiApiKey();
    if (key == null || key.isEmpty) {
      return const AiTestResult(
        ok: false,
        message: 'No API key saved yet. Paste your key and tap Save first.',
      );
    }
    try {
      final String reply = await _complete('Reply with exactly: ok');
      return AiTestResult(
        ok: true,
        message: 'Connected successfully. The model replied: "${reply.trim()}".',
      );
    } on AiNotConfiguredException {
      return const AiTestResult(ok: false, message: 'No API key saved yet.');
    } on AiException catch (e) {
      return AiTestResult(ok: false, message: e.toString());
    } catch (e) {
      return AiTestResult(ok: false, message: 'Unexpected error: $e');
    }
  }

  /// Trims and cleans a user-entered base URL.
  static String normaliseBase(String raw) {
    String base = raw.trim();
    if (base.isEmpty) base = 'https://api.openai.com/v1';
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  Future<String> _complete(String prompt) async {
    final String? key = await _settings.aiApiKey();
    if (key == null || key.isEmpty) {
      throw const AiNotConfiguredException();
    }
    final String baseUrl = normaliseBase(await _settings.aiBaseUrl());
    final String model = (await _settings.aiModel()).trim();

    final Uri uri = Uri.parse('$baseUrl/chat/completions');
    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode(<String, dynamic>{
              'model': model,
              'messages': <Map<String, String>>[
                <String, String>{
                  'role': 'system',
                  'content': 'You are a concise, helpful writing assistant.',
                },
                <String, String>{'role': 'user', 'content': prompt},
              ],
              'temperature': 0.4,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw AiException(
        'The AI service did not respond in time.',
        hint: 'Check your connection, or try a different model/provider in AI settings.',
      );
    } catch (_) {
      throw AiException(
        'Could not reach $baseUrl.',
        hint: 'Check your internet connection and that the Base URL in AI settings is exactly right '
            '(e.g. https://api.openai.com/v1).',
      );
    }

    if (response.statusCode >= 400) {
      final String detail = _providerMessage(response.body);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AiException(
          'The provider rejected the API key (HTTP ${response.statusCode}).',
          hint: 'Open AI settings and check: (1) the key is complete and still active, '
              '(2) the Base URL matches the provider, (3) the key belongs to the same provider.'
              '${detail.isEmpty ? '' : '\nProvider said: $detail'}',
        );
      }
      if (response.statusCode == 404) {
        throw AiException(
          'The model or endpoint was not found (HTTP 404).',
          hint: 'Check the Model name and the Base URL in AI settings — the model must exist on your plan.'
              '${detail.isEmpty ? '' : '\nProvider said: $detail'}',
        );
      }
      if (response.statusCode == 429) {
        throw AiException(
          'The provider is rate-limiting or out of quota (HTTP 429).',
          hint: 'Wait a moment, or check your plan/credits with the provider.'
              '${detail.isEmpty ? '' : '\nProvider said: $detail'}',
        );
      }
      throw AiException(
        'AI request failed (HTTP ${response.statusCode}).',
        hint: detail.isEmpty ? null : 'Provider said: $detail',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiException('The AI service returned an unexpected response.');
    }
    final List<dynamic> choices = (body['choices'] as List<dynamic>?) ?? <dynamic>[];
    if (choices.isEmpty) {
      throw AiException('The AI service returned no result.');
    }
    final Map<String, dynamic> message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
    return (message['content'] as String? ?? '').trim();
  }

  /// Pulls the provider's own error text out of a response body, if present.
  String _providerMessage(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map) {
        final dynamic err = decoded['error'];
        if (err is Map && err['message'] is String) return err['message'] as String;
        if (err is String) return err;
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {
      // Ignore — the raw body is not JSON.
    }
    return '';
  }
}
