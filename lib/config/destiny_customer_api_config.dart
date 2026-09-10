import 'package:flutter/foundation.dart';

/// Public config for the M3A customer commerce Edge Function.
///
/// Never embeds service_role. The function verifies Firebase ID tokens and
/// performs privileged DB writes server-side.
class DestinyCustomerApiConfig {
  static const String productionFunctionsBase =
      'https://xchddfpfzrzhlbbmyhyn.supabase.co/functions/v1';

  static const String _baseFromEnv =
      String.fromEnvironment('DESTINY_CUSTOMER_API_BASE');

  static const String functionName = 'customer-api';

  static String? _baseOverride;
  static bool? _enabledOverride;

  /// When false, Flutter keeps legacy bymapara for customer commerce
  /// (emergency rollback). Default: use secure Edge Function.
  static const bool _enabledFromEnv = bool.fromEnvironment(
    'DESTINY_CUSTOMER_API_ENABLED',
    defaultValue: true,
  );

  @visibleForTesting
  static void debugOverride({String? baseUrl, bool? enabled}) {
    _baseOverride = baseUrl;
    _enabledOverride = enabled;
  }

  @visibleForTesting
  static void debugClearOverrides() {
    _baseOverride = null;
    _enabledOverride = null;
  }

  static bool get isEnabled {
    if (_enabledOverride != null) return _enabledOverride!;
    return _enabledFromEnv;
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
