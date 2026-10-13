/// Input validation for links, titles and other user content.
class Validators {
  Validators._();

  static final RegExp _urlPattern = RegExp(
    r'^(https?:\/\/)?([\w-]+\.)+[\w-]{2,}(\/[^\s]*)?$',
    caseSensitive: false,
  );

  /// Returns a normalised https URL, or null when the input is not a URL.
  static String? normaliseUrl(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (!_urlPattern.hasMatch(trimmed)) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  static bool isValidUrl(String input) => normaliseUrl(input) != null;

  /// Best-effort host label for a link card.
  static String hostOf(String url) {
    try {
      final Uri uri = Uri.parse(url);
      return uri.host.isEmpty ? url : uri.host;
    } catch (_) {
      return url;
    }
  }

  static String? requiredTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a title';
    }
    return null;
  }
}
