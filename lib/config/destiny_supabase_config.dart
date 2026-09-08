import 'package:flutter/foundation.dart';

/// Public Supabase client configuration for Destiny OS (no service_role).
///
/// ```
/// flutter run \
///   --dart-define=DESTINY_SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co \
///   --dart-define=DESTINY_SUPABASE_ANON_KEY=eyJ...
/// ```
class DestinySupabaseConfig {
  static const String productionUrl =
      'https://xchddfpfzrzhlbbmyhyn.supabase.co';

  static const String _urlFromEnv =
      String.fromEnvironment('DESTINY_SUPABASE_URL');
  static const String _anonFromEnv =
      String.fromEnvironment('DESTINY_SUPABASE_ANON_KEY');

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

  static String get anonKey {
    final override = _anonOverride?.trim();
    if (override != null) return override;
    return _anonFromEnv.trim();
  }

  /// True when publishable anon key is present (required for live reads).
  static bool get isConfigured => anonKey.isNotEmpty;

  /// Prefer Supabase PostgREST inventory when anon key is configured.
  /// App inventory chain does not fall back to bymapara API (see `main.dart`).
  static bool get preferSupabaseInventory {
    if (_preferSupabaseOverride != null) return _preferSupabaseOverride!;
    return isConfigured;
  }
}
