import 'package:flutter/foundation.dart';

/// Public Destiny media configuration (no secrets).
///
/// Supabase **public** Storage object URLs do not require a service_role key.
/// Pass the project URL at build time:
///
/// ```
/// flutter run --dart-define=DESTINY_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
/// flutter run --dart-define=DESTINY_MEDIA_BUCKET=destiny-media
/// ```
///
/// Never put service_role, database passwords, or admin credentials here.
class DestinyMediaConfig {
  /// Public Supabase project URL, e.g. `https://abcd1234.supabase.co`.
  static const String _supabaseUrlFromEnv = String.fromEnvironment(
    'DESTINY_SUPABASE_URL',
  );

  /// Public marketing media bucket (default: destiny-media).
  static const String _mediaBucketFromEnv = String.fromEnvironment(
    'DESTINY_MEDIA_BUCKET',
    defaultValue: 'destiny-media',
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
      (_supabaseUrlOverride ?? _supabaseUrlFromEnv).trim().replaceAll(RegExp(r'/+$'), '');

  static String get mediaBucket {
    final raw = (_mediaBucketOverride ?? _mediaBucketFromEnv).trim();
    return raw.isEmpty ? 'destiny-media' : raw;
  }

  /// True when a public Supabase project URL is available for media resolution.
  static bool get isSupabaseConfigured => supabaseUrl.isNotEmpty;

  /// Public Storage base: `/storage/v1/object/public/<bucket>`.
  static String get publicStorageBase {
    if (!isSupabaseConfigured) return '';
    return '$supabaseUrl/storage/v1/object/public/$mediaBucket';
  }
}
