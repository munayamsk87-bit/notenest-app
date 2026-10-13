import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// Thrown when the user hasn't supplied an AI key/endpoint yet. The UI shows a
/// setup message instead of a fabricated result (Spec §7).
class AiNotConfiguredException implements Exception {
  const AiNotConfiguredException();
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Optional AI helpers (summarise / rewrite / checklist). Entirely opt-in and
/// only ever called from an explicit user action. No keys are hardcoded — the
/// key lives in the platform secure store (Spec §7, §11).
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

  Future<String> _complete(String prompt) async {
    final String? key = await _settings.aiApiKey();
    if (key == null || key.isEmpty) {
      throw const AiNotConfiguredException();
    }
    final String baseUrl = await _settings.aiBaseUrl();
    final String model = await _settings.aiModel();

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
    } catch (e) {
      throw AiException('Could not reach the AI service. Check your connection.');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AiException('The AI service rejected the API key.');
    }
    if (response.statusCode >= 400) {
      throw AiException('AI request failed (${response.statusCode}).');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> choices = (body['choices'] as List<dynamic>?) ?? <dynamic>[];
    if (choices.isEmpty) throw AiException('The AI service returned no result.');
    final Map<String, dynamic> message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
    return (message['content'] as String? ?? '').trim();
  }
}
