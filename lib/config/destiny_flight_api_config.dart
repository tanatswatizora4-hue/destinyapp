import 'package:flutter/foundation.dart';

/// Public config for M3C flight-commerce-api. Never embeds service_role
/// or Travelport credentials.
class DestinyFlightApiConfig {
  static const String productionFunctionsBase =
      'https://xchddfpfzrzhlbbmyhyn.supabase.co/functions/v1';

  static const String _baseFromEnv =
      String.fromEnvironment('DESTINY_FLIGHT_API_BASE');

  static const String functionName = 'flight-commerce-api';

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
