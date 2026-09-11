import 'dart:convert';

import 'package:destiny/config/destiny_staff_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:http/http.dart' as http;

class StaffApiException implements Exception {
  StaffApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Authenticated client for staff-commerce-api.
class StaffApiClient {
  StaffApiClient({
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
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StaffApiException(
        'Sign in required: Supabase access token is missing',
        statusCode: 401,
      );
    }

    final safeBody = Map<String, dynamic>.from(body)
      ..remove('user_id')
      ..remove('firebase_uid')
      ..remove('actor_user_id')
      ..remove('actor_firebase_uid')
      ..remove('role')
      ..remove('is_active')
      ..remove('service_role')
      ..['action'] = action;

    final response = await _http.post(
      Uri.parse(DestinyStaffApiConfig.endpoint),
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
      throw StaffApiException(
        'Staff API returned non-JSON (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StaffApiException(
        decoded['message']?.toString() ?? 'Access denied',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 409) {
      throw StaffApiException(
        decoded['message']?.toString() ?? 'Conflict',
        statusCode: 409,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffApiException(
        decoded['message']?.toString() ??
            'Staff API error (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (decoded['status'] != 'success') {
      throw StaffApiException(
        decoded['message']?.toString() ?? 'Staff API request failed',
      );
    }
    return decoded;
  }
}
