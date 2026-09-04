/// Centralized Destiny media URL resolution and safe path encoding.
///
/// Use for any bymapara (or absolute CDN) image path returned by the API.
/// Does not change the API contract — only how the client builds request URLs.
class DestinyMediaUrl {
  static const String mediaHost = 'bymapara.com';
  static const String mediaOrigin = 'https://$mediaHost';
  static const String placeholder =
      'https://placehold.co/800x600/cccccc/ffffff?text=No+Image';

  /// Resolves a relative upload path or absolute URL into a browser-safe URL.
  ///
  /// - Preserves `https://` / `http://` and `/` separators
  /// - Percent-encodes spaces and other unsafe path characters once
  /// - Does not double-encode already-encoded `%XX` sequences
  /// - Supports future absolute URLs from the API
  static String resolve(String? pathOrUrl) {
    if (pathOrUrl == null) return placeholder;
    final raw = pathOrUrl.trim();
    if (raw.isEmpty) return placeholder;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return _normalizeAbsolute(raw);
    }

    final relative = raw.startsWith('/') ? raw.substring(1) : raw;
    return _normalizeAbsolute('$mediaOrigin/$relative');
  }

  static String _normalizeAbsolute(String absolute) {
    final parsed = Uri.parse(absolute);

    // Uri.parse decodes path segments; rebuilding through [pathSegments]
    // encodes unsafe characters exactly once (no double-encoding).
    final normalized = Uri(
      scheme: parsed.scheme,
      userInfo: parsed.userInfo.isEmpty ? null : parsed.userInfo,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      pathSegments: parsed.pathSegments,
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    );

    return normalized.toString();
  }
}
