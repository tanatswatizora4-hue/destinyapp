import 'dart:convert';

import 'package:destiny/config/destiny_payment_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:http/http.dart' as http;

class PaymentApiException implements Exception {
  PaymentApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// Authenticated client for payment-commerce-api.
/// Never sends authoritative amounts, fees, payment_status, or card data.
class PaymentApiClient {
  PaymentApiClient({
    http.Client? httpClient,
    AccessTokenProvider? tokenProvider,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenProvider ?? SupabaseAccessTokenProvider();

  final http.Client _http;
  final AccessTokenProvider _tokens;

  static const _untrusted = {
    'user_id',
    'firebase_uid',
    'legacy_user_id',
    'actor_user_id',
    'quoted_total',
    'payment_status',
    'settlement_status',
    'status',
    'total_price',
    'amount',
    'currency',
    'platform_fee',
    'provider_fee',
    'merchant_net',
    'merchant_amount',
    'gross_amount',
    'booking_total',
    'supplier_payable',
    'role',
    'service_role',
    'card_number',
    'cvv',
    'cvc',
    'pin',
    'pan',
  };

  Future<Map<String, dynamic>> postAction(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw PaymentApiException(
        'Sign in required: Supabase access token is missing',
        statusCode: 401,
        code: 'unauthorized',
      );
    }

    final safeBody = Map<String, dynamic>.from(body);
    for (final key in _untrusted) {
      safeBody.remove(key);
    }
    safeBody['action'] = action;

    final response = await _http.post(
      Uri.parse(DestinyPaymentApiConfig.endpoint),
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
      throw PaymentApiException(
        'Payment API returned non-JSON (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(
        decoded['message']?.toString() ??
            'Payment API error (${response.statusCode})',
        code: decoded['code']?.toString(),
        statusCode: response.statusCode,
      );
    }
    if (decoded['status'] != 'success') {
      throw PaymentApiException(
        decoded['message']?.toString() ?? 'Payment request failed',
        code: decoded['code']?.toString(),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
