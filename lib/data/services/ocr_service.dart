import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrException implements Exception {
  OcrException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// On-device OCR via Google ML Kit (Spec §7). Runs locally — the image never
/// leaves the device. Returns the recognised text, or an empty string when
/// nothing readable is found (never fabricated text).
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  TextRecognizer? _recognizer;

  Future<String> extractText(String imagePath) async {
    final TextRecognizer recognizer = _recognizer ??=
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final InputImage input = InputImage.fromFilePath(imagePath);
      final RecognizedText recognised = await recognizer.processImage(input);
      return recognised.text.trim();
    } catch (e) {
      throw OcrException('Could not read text from this image.');
    }
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
