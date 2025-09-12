class StringUtils {
  // Returns a single uppercase initial or fallback
  static String safeInitial(String? text, {String fallback = '?'}) {
    if (text == null || text.isEmpty) return fallback;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return fallback;
    // Use substring for first character; avoid external deps
    // Ensure we have at least one character before using substring
    return trimmed.length > 0 ? trimmed.substring(0, 1).toUpperCase() : fallback;
  }
}
