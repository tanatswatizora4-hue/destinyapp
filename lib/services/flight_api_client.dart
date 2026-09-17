import 'dart:convert';

import 'package:destiny/config/destiny_flight_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/flight_offer.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:http/http.dart' as http;

/// Client for flight-commerce-api.
/// Search/validate are public; create_flight_enquiry sends a Supabase JWT.
class FlightApiClient {
  FlightApiClient({
    http.Client? httpClient,
    AccessTokenProvider? tokenProvider,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenProvider ?? SupabaseAccessTokenProvider();

  final http.Client _http;
  final AccessTokenProvider _tokens;

  Future<Map<String, dynamic>> postAction(
    String action, {
    Map<String, dynamic> body = const {},
    bool requireAuth = false,
  }) async {
    final safeBody = Map<String, dynamic>.from(body)
      ..remove('user_id')
      ..remove('firebase_uid')
      ..remove('legacy_user_id')
      ..remove('actor_user_id')
      ..remove('quoted_total')
      ..remove('payment_status')
      ..remove('status')
      ..remove('total_price')
      ..remove('validated_amount')
      ..remove('role')
      ..remove('access_token')
      ..['action'] = action;

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'apikey': DestinySupabaseConfig.anonKey,
    };

    final token = await _tokens.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (requireAuth) {
      throw FlightApiException(
        'Sign in required to continue this itinerary',
        code: 'unauthorized',
        statusCode: 401,
      );
    }

    final response = await _http.post(
      Uri.parse(DestinyFlightApiConfig.endpoint),
      headers: headers,
      body: json.encode(safeBody),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw FlightApiException(
        'Flight service returned a non-JSON response',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FlightApiException(
        decoded['message']?.toString() ??
            'Flight service error (${response.statusCode})',
        code: decoded['code']?.toString(),
        statusCode: response.statusCode,
      );
    }
    if (decoded['status'] != 'success') {
      throw FlightApiException(
        decoded['message']?.toString() ?? 'Flight request failed',
        code: decoded['code']?.toString(),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
