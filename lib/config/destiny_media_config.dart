import 'package:flutter/foundation.dart';

/// Public Destiny media configuration (no secrets).
///
/// Defaults target the live Destiny OS Supabase project (`destiny-os`) and the
/// public `destiny-media` bucket. Override at build/run time when needed:
///
/// ```
/// flutter run \
///   --dart-define=DESTINY_SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co \
///   --dart-define=DESTINY_MEDIA_BUCKET=destiny-media \
///   --dart-define=DESTINY_INVENTORY_MEDIA_LIVE=false
/// ```
///
/// Empty dart-defines fall back to production defaults (an explicit empty
/// `--dart-define=DESTINY_SUPABASE_URL=` must not wipe the live project URL).
///
/// Never put service_role, database passwords, or admin credentials here.
class DestinyMediaConfig {
  /// Live Destiny OS public project URL (not a secret).
  static const String productionSupabaseUrl =
      'https://xchddfpfzrzhlbbmyhyn.supabase.co';

  /// Public marketing media bucket name (not a secret).
  static const String productionMediaBucket = 'destiny-media';

  /// Optional compile-time override. Prefer non-empty values only.
  static const String _supabaseUrlFromEnv = String.fromEnvironment(
    'DESTINY_SUPABASE_URL',
  );

  static const String _mediaBucketFromEnv = String.fromEnvironment(
    'DESTINY_MEDIA_BUCKET',
  );

  /// When true (M2 default), inventory `destiny-media/...` refs resolve to
  /// public Storage. Set false only for local debugging against legacy uploads.
  static const bool inventoryMediaLive = bool.fromEnvironment(
    'DESTINY_INVENTORY_MEDIA_LIVE',
    defaultValue: true,
  );

  static String? _supabaseUrlOverride;
  static String? _mediaBucketOverride;
  static bool? _inventoryMediaLiveOverride;

  /// Test-only overrides (compile-time defines are fixed in unit tests).
  @visibleForTesting
  static void debugOverride({
    String? supabaseUrl,
    String? mediaBucket,
    bool? inventoryMediaLive,
  }) {
    _supabaseUrlOverride = supabaseUrl;
    _mediaBucketOverride = mediaBucket;
    _inventoryMediaLiveOverride = inventoryMediaLive;
  }

  @visibleForTesting
  static void debugClearOverrides() {
    _supabaseUrlOverride = null;
    _mediaBucketOverride = null;
    _inventoryMediaLiveOverride = null;
  }

  static bool get preferLegacyInventoryMedia {
    if (_inventoryMediaLiveOverride != null) {
      return !_inventoryMediaLiveOverride!;
    }
    return !inventoryMediaLive;
  }

  static String get supabaseUrl {
    final override = _supabaseUrlOverride?.trim();
    if (override != null) {
      return override.replaceAll(RegExp(r'/+$'), '');
    }
    final env = _supabaseUrlFromEnv.trim();
    if (env.isEmpty) return productionSupabaseUrl;
    return env.replaceAll(RegExp(r'/+$'), '');
  }

  static String get mediaBucket {
    final override = _mediaBucketOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    final env = _mediaBucketFromEnv.trim();
    if (env.isEmpty) return productionMediaBucket;
    return env;
  }

  /// True when a public Supabase project URL is available for media resolution.
  static bool get isSupabaseConfigured => supabaseUrl.isNotEmpty;

  /// Public Storage base: `/storage/v1/object/public/<bucket>`.
  static String get publicStorageBase {
    if (!isSupabaseConfigured) return '';
    return '$supabaseUrl/storage/v1/object/public/$mediaBucket';
  }
}
