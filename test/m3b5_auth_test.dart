import 'dart:convert';

import 'package:destiny/config/destiny_customer_api_config.dart';
import 'package:destiny/main.dart';
import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/screens/navigation_screen.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:destiny/services/customer_api_client.dart';
import 'package:destiny/services/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    DestinyCustomerApiConfig.debugClearOverrides();
  });

  group('devBypassAuth documentation contract', () {
    test('flag is a compile-time bool (UI only; APIs still require tokens)', () {
      expect(devBypassAuth, isA<bool>());
    });
  });

  group('AccessTokenProvider', () {
    test('fake provider returns configured token', () async {
      final p = FakeAccessTokenProvider('abc');
      expect(await p.getAccessToken(), 'abc');
      expect(await FakeAccessTokenProvider(null).getAccessToken(), isNull);
    });
  });

  group('destinyAuthErrorMessage', () {
    test('maps common failures', () {
      expect(
        destinyAuthErrorMessage('Invalid login credentials'),
        contains('Incorrect email'),
      );
      expect(
        destinyAuthErrorMessage('User already registered'),
        contains('already exists'),
      );
    });
  });

  group('Identity models prefer user_id', () {
    test('CustomerBooking parses user_id', () {
      final b = CustomerBooking.fromJson({
        'id': '1',
        'user_id': 'uuid-1',
        'firebase_uid': 'legacy',
        'item_name': 'Tour',
        'item_type': 'tour',
        'num_travelers': 1,
        'currency': 'USD',
        'status': 'submitted',
        'payment_status': 'none',
        'customer_notes': '',
        'item_image_json': [],
      });
      expect(b.userId, 'uuid-1');
      expect(b.firebaseUid, 'legacy');
    });

    test('CustomerEnquiry / profile parse user_id', () {
      final e = CustomerEnquiry.fromJson({
        'id': 'e1',
        'kind': 'flight',
        'user_id': 'uuid-2',
        'payload': {},
        'status': 'received',
      });
      expect(e.userId, 'uuid-2');
      final p = CustomerProfile.fromJson({
        'id': 'p1',
        'user_id': 'uuid-3',
        'full_name': 'Ada',
        'email': 'a@example.com',
      });
      expect(p.userId, 'uuid-3');
    });
  });

  group('CustomerApiClient auth + spoof stripping', () {
    test('missing token blocks commerce', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = CustomerApiClient(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: FakeAccessTokenProvider(null),
      );
      await expectLater(
        client.postAction('create_booking_request'),
        throwsA(isA<StateError>()),
      );
    });

    test('strips client user_id / firebase_uid / role spoof', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sent;
      final client = CustomerApiClient(
        tokenProvider: FakeAccessTokenProvider('tok'),
        httpClient: MockClient((req) async {
          sent = json.decode(req.body) as Map<String, dynamic>;
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {'id': '1'},
            }),
            200,
          );
        }),
      );
      await client.postAction('upsert_profile', {
        'full_name': 'Ada',
        'user_id': 'spoof',
        'firebase_uid': 'spoof',
        'role': 'admin',
      });
      expect(sent!['action'], 'upsert_profile');
      expect(sent!['full_name'], 'Ada');
      expect(sent!.containsKey('user_id'), isFalse);
      expect(sent!.containsKey('firebase_uid'), isFalse);
      expect(sent!.containsKey('role'), isFalse);
    });
  });

  group('LoginScreen UX', () {
    testWidgets('shows Destiny account copy and forgot password',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      expect(find.textContaining('Destiny'), findsWidgets);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });

  group('Protected nav indices', () {
    test('account tabs are protected; discovery is public', () {
      expect(NavigationScreen.protectedNavIndices, [5, 6, 7, 8]);
    });
  });
}
