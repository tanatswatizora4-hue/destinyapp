import 'package:flutter/foundation.dart';

/// Public Supabase client configuration for Destiny OS (no service_role).
///
/// Uses the **publishable** / anon key only (safe for client apps). Never embed
/// `service_role`.
///
/// Defaults target live destiny-os so a normal `flutter run` uses Supabase
/// inventory without dart-defines. Overrides remain available:
///
/// ```
/// flutter run \
///   --dart-define=DESTINY_SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co \
///   --dart-define=DESTINY_SUPABASE_ANON_KEY=<publishable-or-anon-key>
/// ```
///
/// Alias: `--dart-define=SUPABASE_ANON_KEY=...` (same publishable key).
class DestinySupabaseConfig {
  static const String productionUrl =
      'https://xchddfpfzrzhlbbmyhyn.supabase.co';

  /// Public publishable client key for destiny-os (not a secret; not service_role).
  static const String productionPublishableKey =
      'sb_publishable_tubJvxHM-KyuRGPKFhXjmw_fd7hGXtG';

  static const String _urlFromEnv =
      String.fromEnvironment('DESTINY_SUPABASE_URL');
  static const String _anonFromEnv =
      String.fromEnvironment('DESTINY_SUPABASE_ANON_KEY');
  static const String _anonAliasFromEnv =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static String? _urlOverride;
  static String? _anonOverride;
  static bool? _preferSupabaseOverride;

  @visibleForTesting
  static void debugOverride({
    String? url,
    String? anonKey,
    bool? preferSupabase,
  }) {
    _urlOverride = url;
    _anonOverride = anonKey;
    _preferSupabaseOverride = preferSupabase;
  }

  @visibleForTesting
  static void debugClearOverrides() {
    _urlOverride = null;
    _anonOverride = null;
    _preferSupabaseOverride = null;
  }

  static String get url {
    final override = _urlOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override.replaceAll(RegExp(r'/+$'), '');
    }
    final env = _urlFromEnv.trim();
    if (env.isEmpty) return productionUrl;
    return env.replaceAll(RegExp(r'/+$'), '');
  }

  /// Publishable / anon key for PostgREST reads (never service_role).
  static String get anonKey {
    final override = _anonOverride?.trim();
    if (override != null) return override;
    final primary = _anonFromEnv.trim();
    if (primary.isNotEmpty) return primary;
    final alias = _anonAliasFromEnv.trim();
    if (alias.isNotEmpty) return alias;
    return productionPublishableKey;
  }

  /// True when publishable anon key is present (required for live PostgREST).
  static bool get isConfigured => anonKey.isNotEmpty;

  /// Prefer Supabase PostgREST inventory when anon key is configured.
  /// App inventory does not fall back to bymapara API (see `main.dart`).
  static bool get preferSupabaseInventory {
    if (_preferSupabaseOverride != null) return _preferSupabaseOverride!;
    return isConfigured;
  }
}
