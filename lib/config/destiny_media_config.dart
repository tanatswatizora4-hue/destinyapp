import 'package:flutter/foundation.dart';

/// Public Destiny media configuration (no secrets).
///
/// Defaults target the live Destiny OS Supabase project (`destiny-os`) and the
/// public `destiny-media` bucket. Override at build/run time when needed:
///
/// ```
/// flutter run \
///   --dart-define=DESTINY_SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co \
///   --dart-define=DESTINY_MEDIA_BUCKET=destiny-media
/// ```
///
/// Never put service_role, database passwords, or admin credentials here.
class DestinyMediaConfig {
  /// Live Destiny OS public project URL (not a secret).
  static const String productionSupabaseUrl =
      'https://xchddfpfzrzhlbbmyhyn.supabase.co';

  /// Public marketing media bucket name (not a secret).
  static const String productionMediaBucket = 'destiny-media';

  /// Public Supabase project URL. Prefer `--dart-define=DESTINY_SUPABASE_URL=...`
  /// for environment override; falls back to [productionSupabaseUrl].
  static const String _supabaseUrlFromEnv = String.fromEnvironment(
    'DESTINY_SUPABASE_URL',
    defaultValue: productionSupabaseUrl,
  );

  /// Public marketing media bucket. Prefer `--dart-define=DESTINY_MEDIA_BUCKET=...`.
  static const String _mediaBucketFromEnv = String.fromEnvironment(
    'DESTINY_MEDIA_BUCKET',
    defaultValue: productionMediaBucket,
  );

  static String? _supabaseUrlOverride;
  static String? _mediaBucketOverride;

  /// Test-only overrides (compile-time defines are fixed in unit tests).
  @visibleForTesting
  static void debugOverride({String? supabaseUrl, String? mediaBucket}) {
    _supabaseUrlOverride = supabaseUrl;
    _mediaBucketOverride = mediaBucket;
  }

  @visibleForTesting
  static void debugClearOverrides() {
    _supabaseUrlOverride = null;
    _mediaBucketOverride = null;
  }

  static String get supabaseUrl =>
      (_supabaseUrlOverride ?? _supabaseUrlFromEnv)
          .trim()
          .replaceAll(RegExp(r'/+$'), '');

  static String get mediaBucket {
    final raw = (_mediaBucketOverride ?? _mediaBucketFromEnv).trim();
    return raw.isEmpty ? productionMediaBucket : raw;
  }

  /// True when a public Supabase project URL is available for media resolution.
  static bool get isSupabaseConfigured => supabaseUrl.isNotEmpty;

  /// Public Storage base: `/storage/v1/object/public/<bucket>`.
  static String get publicStorageBase {
    if (!isSupabaseConfigured) return '';
    return '$supabaseUrl/storage/v1/object/public/$mediaBucket';
  }
}
