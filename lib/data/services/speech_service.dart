import 'package:speech_to_text/speech_to_text.dart';

/// Optional speech-to-text for voice notes (Spec §4D). Uses the platform
/// recogniser; when unavailable we report that honestly rather than inventing
/// a transcript.
class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    if (_available) return true;
    try {
      _available = await _speech.initialize();
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  bool get isListening => _speech.isListening;

  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!await init()) return false;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(partialResults: true),
    );
    return true;
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }
}
