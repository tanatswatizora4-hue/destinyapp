import 'dart:convert';

import 'package:destiny/config/destiny_destina_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/destina_chat.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:destiny/services/destina_session_store.dart';
import 'package:http/http.dart' as http;

class DestinaApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final DestinaTurn? turn;

  DestinaApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.turn,
  });

  bool get needsSignIn =>
      code == 'unauthorized' || statusCode == 401 || (turn?.authRequired ?? false);

  @override
  String toString() => message;
}

class DestinaApiClient {
  DestinaApiClient({
    http.Client? httpClient,
    AccessTokenProvider? tokenProvider,
    String Function()? sessionId,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenProvider ?? SupabaseAccessTokenProvider(),
        _sessionId = sessionId ?? (() => DestinaSessionStore.current);

  final http.Client _http;
  final AccessTokenProvider _tokens;
  final String Function() _sessionId;

  Future<DestinaTurn> chat({
    required String message,
    String? conversationId,
    Map<String, dynamic>? seedContext,
  }) async {
    final data = await _post('chat', {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
      if (seedContext != null) 'seed_context': seedContext,
    });
    return DestinaTurn.fromJson(data);
  }

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> body,
  ) async {
    final safeBody = Map<String, dynamic>.from(body)
      ..remove('user_id')
      ..remove('firebase_uid')
      ..remove('legacy_user_id')
      ..remove('quoted_total')
      ..remove('payment_status')
      ..remove('status')
      ..remove('total_price')
      ..remove('validated_amount')
      ..remove('role')
      ..remove('access_token')
      ..remove('DESTINA_API_KEY')
      ..remove('service_role')
      ..['action'] = action;

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'apikey': DestinySupabaseConfig.anonKey,
      'x-destina-session': _sessionId(),
    };
    final token = await _tokens.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _http.post(
      Uri.parse(DestinyDestinaApiConfig.endpoint),
      headers: headers,
      body: json.encode(safeBody),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw DestinaApiException(
        'Destina returned a non-JSON response',
        statusCode: response.statusCode,
      );
    }

    final data = decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : <String, dynamic>{};
    final turn = data.isEmpty ? null : DestinaTurn.fromJson(data);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DestinaApiException(
        decoded['message']?.toString() ??
            'Destina is unavailable (${response.statusCode})',
        code: decoded['code']?.toString(),
        statusCode: response.statusCode,
        turn: turn,
      );
    }
    return data;
  }
}
