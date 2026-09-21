import 'package:flutter/foundation.dart';

/// Public config for destina-api. Never embeds DESTINA_API_KEY or service_role.
class DestinyDestinaApiConfig {
  static const String productionFunctionsBase =
      'https://xchddfpfzrzhlbbmyhyn.supabase.co/functions/v1';

  static const String _baseFromEnv =
      String.fromEnvironment('DESTINY_DESTINA_API_BASE');

  static const String functionName = 'destina-api';

  static String? _baseOverride;

  @visibleForTesting
  static void debugOverride({String? baseUrl}) {
    _baseOverride = baseUrl;
  }

  @visibleForTesting
  static void debugClearOverrides() {
    _baseOverride = null;
  }

  static String get functionsBase {
    final override = _baseOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override.replaceAll(RegExp(r'/+$'), '');
    }
    final env = _baseFromEnv.trim();
    if (env.isNotEmpty) return env.replaceAll(RegExp(r'/+$'), '');
    return productionFunctionsBase;
  }

  static String get endpoint => '$functionsBase/$functionName';
}
