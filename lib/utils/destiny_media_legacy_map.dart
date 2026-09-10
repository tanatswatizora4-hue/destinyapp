import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Maps Destiny-owned object refs → legacy bymapara `uploads/...` paths.
///
/// Loaded once at startup from `assets/data/destiny_media_legacy_map.json`
/// so [TravelNetworkImage] can fall back while Storage objects are missing.
class DestinyMediaLegacyMap {
  DestinyMediaLegacyMap._();

  static Map<String, String> _ownedToLegacy = const {};
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  @visibleForTesting
  static void debugReplace(Map<String, String> map) {
    _ownedToLegacy = Map.unmodifiable(map);
    _loaded = true;
  }

  @visibleForTesting
  static void debugClear() {
    _ownedToLegacy = const {};
    _loaded = false;
  }

  static Future<void> load({
    String assetPath = 'assets/data/destiny_media_legacy_map.json',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _ownedToLegacy = const {};
      _loaded = true;
      return;
    }
    final out = <String, String>{};
    decoded.forEach((key, value) {
      final k = '$key'.trim();
      final v = '$value'.trim();
      if (k.isNotEmpty && v.isNotEmpty) out[k] = v;
    });
    _ownedToLegacy = Map.unmodifiable(out);
    _loaded = true;
  }

  /// Legacy `uploads/...` path for a `destiny-media/...` ref, if known.
  static String? legacyUploadFor(String? ownedRef) {
    if (ownedRef == null) return null;
    final key = ownedRef.trim();
    if (key.isEmpty) return null;
    return _ownedToLegacy[key];
  }
}
