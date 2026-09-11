import 'dart:convert';

import 'package:destiny/config/destiny_customer_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:http/http.dart' as http;

/// Low-level authenticated client for the customer-api Edge Function.
class CustomerApiClient {
  CustomerApiClient({
    http.Client? httpClient,
    AccessTokenProvider? tokenProvider,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenProvider ?? SupabaseAccessTokenProvider();

  final http.Client _http;
  final AccessTokenProvider _tokens;

  Future<Map<String, dynamic>> postAction(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (!DestinyCustomerApiConfig.isEnabled) {
      throw StateError('Destiny customer API is disabled');
    }

    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Sign in required: Supabase access token is missing',
      );
    }

    // Never allow callers to inject ownership / authority fields.
    final safeBody = Map<String, dynamic>.from(body)
      ..remove('user_id')
      ..remove('firebase_uid')
      ..remove('legacy_user_id')
      ..remove('actor_user_id')
      ..remove('quoted_total')
      ..remove('payment_status')
      ..remove('status')
      ..remove('total_price')
      ..remove('role')
      ..['action'] = action;

    final response = await _http.post(
      Uri.parse(DestinyCustomerApiConfig.endpoint),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
        'apikey': DestinySupabaseConfig.anonKey,
      },
      body: json.encode(safeBody),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Customer API returned non-JSON (${response.statusCode})',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['message']?.toString() ??
            'Customer API error (${response.statusCode})',
      );
    }
    if (decoded['status'] != 'success') {
      throw Exception(
        decoded['message']?.toString() ?? 'Customer API request failed',
      );
    }
    return decoded;
  }
}
