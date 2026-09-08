import 'package:destiny/config/destiny_media_config.dart';

/// Centralized Destiny media URL resolution and safe path encoding.
///
/// UI / models should resolve through this layer only:
/// `path or ref → DestinyMediaUrl.resolve → TravelNetworkImage`
///
/// Supports:
/// - Destiny-owned Supabase public Storage references
/// - Absolute HTTPS/HTTP URLs (including already-hosted CDN / Supabase URLs)
/// - Legacy bymapara relative upload paths during migration
/// - Local `assets/...` references (returned unchanged for [Image.asset])
/// - Missing / empty media → intentional placeholder
class DestinyMediaUrl {
  /// Legacy upload host — temporary fallback during media migration.
  static const String mediaHost = 'bymapara.com';
  static const String mediaOrigin = 'https://$mediaHost';

  static const String placeholder =
      'https://placehold.co/800x600/cccccc/ffffff?text=No+Image';

  static const String supabaseScheme = 'supabase:';
  static const String destinyMediaPrefix = 'destiny-media/';

  /// Logical object-path helpers for the `destiny-media` bucket.
  /// These return **storage references**, not fabricated inventory URLs.
  static String homeHeroObject([String fileName = 'primary.webp']) =>
      'home/hero/$fileName';

  static String homeEditorialObject([String fileName = 'travel-partner.webp']) =>
      'home/editorial/$fileName';

  static String homeDestinaObject([String fileName = 'destina.webp']) =>
      'home/editorial/$fileName';

  static String tourPrimaryObject(String tourId, [String fileName = 'primary.webp']) =>
      'tours/$tourId/$fileName';

  static String tourGalleryObject(String tourId, String fileName) =>
      'tours/$tourId/gallery/$fileName';

  static String stayPrimaryObject(String stayId, [String fileName = 'primary.webp']) =>
      'stays/$stayId/$fileName';

  static String stayGalleryObject(String stayId, String fileName) =>
      'stays/$stayId/gallery/$fileName';

  static String vehiclePrimaryObject(
    String vehicleId, [
    String fileName = 'primary.webp',
  ]) =>
      'vehicles/$vehicleId/$fileName';

  static String vehicleGalleryObject(String vehicleId, String fileName) =>
      'vehicles/$vehicleId/gallery/$fileName';

  static String brandingObject(String fileName) => 'branding/$fileName';

  static String placeholderObject(String fileName) => 'placeholders/$fileName';

  /// Builds a Destiny storage reference (`destiny-media/...`) for [objectPath].
  static String destinyRef(String objectPath) {
    final cleaned = objectPath.replaceFirst(RegExp(r'^/+'), '');
    if (cleaned.startsWith(destinyMediaPrefix)) return cleaned;
    return '$destinyMediaPrefix$cleaned';
  }

  /// True when [value] should be loaded with [Image.asset], not the network.
  static bool isAssetRef(String? value) {
    if (value == null) return false;
    final raw = value.trim();
    return raw.startsWith('assets/');
  }

  /// True when [value] targets Destiny-owned Supabase Storage (ref or URL).
  static bool isDestinyOwnedRef(String? value) {
    if (value == null) return false;
    final raw = value.trim();
    if (raw.startsWith(supabaseScheme) || raw.startsWith(destinyMediaPrefix)) {
      return true;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final host = Uri.tryParse(raw)?.host ?? '';
      return host.endsWith('.supabase.co') &&
          raw.contains('/storage/v1/object/public/');
    }
    return false;
  }

  /// Resolves a relative upload path, Destiny media ref, or absolute URL.
  ///
  /// - Preserves `https://` / `http://` and `/` separators
  /// - Percent-encodes spaces and other unsafe path characters once
  /// - Does not double-encode already-encoded `%XX` sequences
  /// - Legacy `uploads/...` continues to resolve against bymapara.com
  /// - `destiny-media/...` / `supabase:...` resolve to Supabase public URLs
  ///   when [DestinyMediaConfig.isSupabaseConfigured]
  static String resolve(String? pathOrUrl) {
    if (pathOrUrl == null) return placeholder;
    final raw = pathOrUrl.trim();
    if (raw.isEmpty) return placeholder;

    if (isAssetRef(raw)) return raw;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return _normalizeAbsolute(raw);
    }

    final destinyObject = _extractDestinyObjectPath(raw);
    if (destinyObject != null) {
      return _resolveDestinyObject(destinyObject);
    }

    // Legacy relative uploads (and any other relative API paths) → bymapara.
    final relative = raw.startsWith('/') ? raw.substring(1) : raw;
    return _normalizeAbsolute('$mediaOrigin/$relative');
  }

  /// Public HTTPS URL for an object inside the Destiny media bucket.
  static String resolveDestinyObject(String objectPath) {
    final cleaned = objectPath.replaceFirst(RegExp(r'^/+'), '');
    final withoutBucket = cleaned.startsWith(destinyMediaPrefix)
        ? cleaned.substring(destinyMediaPrefix.length)
        : cleaned;
    return _resolveDestinyObject(withoutBucket);
  }

  static String? _extractDestinyObjectPath(String raw) {
    if (raw.startsWith(supabaseScheme)) {
      var rest = raw.substring(supabaseScheme.length);
      if (rest.startsWith('//')) rest = rest.substring(2);
      rest = rest.replaceFirst(RegExp(r'^/+'), '');
      if (rest.startsWith('${DestinyMediaConfig.mediaBucket}/')) {
        rest = rest.substring(DestinyMediaConfig.mediaBucket.length + 1);
      } else if (rest.startsWith(destinyMediaPrefix)) {
        rest = rest.substring(destinyMediaPrefix.length);
      }
      return rest.isEmpty ? null : rest;
    }

    if (raw.startsWith(destinyMediaPrefix)) {
      final rest = raw.substring(destinyMediaPrefix.length);
      return rest.isEmpty ? null : rest;
    }

    return null;
  }

  static String _resolveDestinyObject(String objectPath) {
    final cleaned = objectPath.replaceFirst(RegExp(r'^/+'), '');
    if (cleaned.isEmpty) return placeholder;

    if (!DestinyMediaConfig.isSupabaseConfigured) {
      // Owned-media refs require public project URL config; keep placeholder
      // rather than accidentally hitting the legacy host.
      return placeholder;
    }

    final base = DestinyMediaConfig.publicStorageBase;
    return _normalizeAbsolute('$base/$cleaned');
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
