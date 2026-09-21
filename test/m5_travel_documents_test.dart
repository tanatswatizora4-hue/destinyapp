import 'dart:typed_data';

import 'package:destiny/config/destiny_customer_api_config.dart';
import 'package:destiny/models/travel_document.dart';
import 'package:destiny/repositories/travel_documents_repository.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:destiny/services/customer_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTokens implements AccessTokenProvider {
  @override
  Future<String?> getAccessToken({bool forceRefresh = false}) async =>
      'test-token';
}

void main() {
  tearDown(() {
    DestinyCustomerApiConfig.debugClearOverrides();
  });

  test('TravelDocument parses without requiring storage_path', () {
    final doc = TravelDocument.fromJson({
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'document_type': 'passport',
      'display_name': 'My passport',
      'mime_type': 'image/jpeg',
      'file_size': 1200,
      'verification_status': 'unverified',
      'upload_status': 'ready',
      'created_at': '2026-09-21T10:00:00Z',
    });
    expect(doc.documentType, 'passport');
    expect(doc.typeLabel, 'passport');
  });

  test('repository rejects public_url in signed access payload', () async {
    DestinyCustomerApiConfig.debugOverride(
      baseUrl: 'https://example.test/functions/v1',
      enabled: true,
    );
    final mock = MockClient((request) async {
      return http.Response(
        '''{"status":"success","data":{"signed_url":"https://example.test/signed","expires_in":120,"public_url":"https://example.test/public","document":{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","document_type":"visa","display_name":"Visa","mime_type":"image/png","file_size":10,"verification_status":"unverified","upload_status":"ready"}}}''',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = TravelDocumentsRepository(
      client: CustomerApiClient(
        httpClient: mock,
        tokenProvider: _FakeTokens(),
      ),
      httpClient: mock,
    );

    expect(
      () => repo.open('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
      throwsA(isA<StateError>()),
    );
  });

  test('upload never sends storage_path or ownership fields', () async {
    DestinyCustomerApiConfig.debugOverride(
      baseUrl: 'https://example.test/functions/v1',
      enabled: true,
    );
    var step = 0;
    final seq = MockClient((request) async {
      step += 1;
      if (request.method == 'PUT') {
        return http.Response('', 200);
      }
      final body = request.body;
      if (body.contains('create_travel_document_upload')) {
        expect(body.contains('storage_path'), isFalse);
        expect(body.contains('customer_user_id'), isFalse);
        return http.Response(
          '''{"status":"success","data":{"document":{"id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","document_type":"passport","display_name":"p.jpg","mime_type":"image/jpeg","file_size":3,"verification_status":"unverified","upload_status":"pending"},"upload":{"signedUrl":"https://example.test/upload","token":"tok","path":"x"},"public_url":null}}''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (body.contains('finalize_travel_document')) {
        return http.Response(
          '{"status":"success","data":{"id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","upload_status":"ready"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"status":"error","message":"unexpected"}', 400);
    });

    final repo = TravelDocumentsRepository(
      client: CustomerApiClient(
        httpClient: seq,
        tokenProvider: _FakeTokens(),
      ),
      httpClient: seq,
    );
    final doc = await repo.upload(
      documentType: 'passport',
      displayName: 'p.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(doc.id, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    expect(step >= 2, isTrue);
  });
}
