import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/core/utils/validators.dart';

void main() {
  group('Validators.normaliseUrl', () {
    test('adds https when the scheme is missing', () {
      expect(Validators.normaliseUrl('example.com'), 'https://example.com');
    });

    test('keeps an explicit scheme', () {
      expect(Validators.normaliseUrl('http://example.com/x'),
          'http://example.com/x');
    });

    test('rejects nonsense', () {
      expect(Validators.normaliseUrl('not a url'), isNull);
      expect(Validators.normaliseUrl(''), isNull);
    });
  });
}
