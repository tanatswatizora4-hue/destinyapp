import 'dart:convert';

import 'package:destiny/config/destiny_payment_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/models/payment_intent.dart';
import 'package:destiny/repositories/payment_commerce_repository.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:destiny/services/payment_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    DestinyPaymentApiConfig.debugClearOverrides();
    DestinySupabaseConfig.debugClearOverrides();
  });

  group('DestinyPaymentApiConfig', () {
    test('defaults to destiny-os payment-commerce-api endpoint', () {
      expect(
        DestinyPaymentApiConfig.endpoint,
        'https://xchddfpfzrzhlbbmyhyn.supabase.co/functions/v1/payment-commerce-api',
      );
    });
  });

  group('CustomerBooking payment UX', () {
    CustomerBooking booking({
      required String status,
      String paymentStatus = 'awaiting_payment',
      double? quoted,
    }) {
      return CustomerBooking.fromJson({
        'id': 'b1',
        'user_id': 'user-1',
        'item_name': 'Tour',
        'item_type': 'tour',
        'num_travelers': 1,
        'currency': 'USD',
        'status': status,
        'payment_status': paymentStatus,
        'customer_notes': '',
        'quoted_total': quoted,
        'item_image_json': [],
      });
    }

    test('only awaiting_payment with quote is payable', () {
      expect(booking(status: 'quoted', quoted: 55).isPayable, isFalse);
      expect(
        booking(status: 'awaiting_payment', quoted: 55).isPayable,
        isTrue,
      );
      expect(
        booking(
          status: 'awaiting_payment',
          quoted: 55,
          paymentStatus: 'paid',
        ).isPayable,
        isFalse,
      );
      expect(booking(status: 'confirmed', quoted: 55).isPayable, isFalse);
    });
  });

  group('PaymentApiClient never sends client money authority', () {
    test('requires token', () async {
      DestinyPaymentApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = PaymentApiClient(
        tokenProvider: FakeIdTokenProvider(null),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        client.postAction('create_payment_intent', {'booking_id': 'b'}),
        throwsA(isA<PaymentApiException>()),
      );
    });

    test('strips amount, currency, fees, status, user_id, cards', () async {
      DestinyPaymentApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      DestinySupabaseConfig.debugOverride(anonKey: 'anon');
      Map<String, dynamic>? sent;
      final client = PaymentApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient((request) async {
          sent = json.decode(request.body) as Map<String, dynamic>;
          expect(request.headers['Authorization'], 'Bearer tok');
          expect(request.url.path, contains('payment-commerce-api'));
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {
                'id': 'p1',
                'booking_id': 'b1',
                'currency': 'USD',
                'gross_amount': 55,
                'platform_fee': 0,
                'provider_fee': 0,
                'merchant_net': 55,
                'provider': 'mock',
                'payment_status': 'requires_action',
                'settlement_status': 'unsettled',
                'is_mock': true,
              },
            }),
            200,
          );
        }),
      );

      await client.postAction('create_payment_intent', {
        'booking_id': 'b1',
        'amount': 1,
        'currency': 'ZAR',
        'platform_fee': 99,
        'quoted_total': 1,
        'payment_status': 'paid',
        'user_id': 'other-user',
        'card_number': '4111111111111111',
        'cvv': '123',
      });

      expect(sent, isNotNull);
      expect(sent!['action'], 'create_payment_intent');
      expect(sent!['booking_id'], 'b1');
      expect(sent!.containsKey('amount'), isFalse);
      expect(sent!.containsKey('currency'), isFalse);
      expect(sent!.containsKey('platform_fee'), isFalse);
      expect(sent!.containsKey('quoted_total'), isFalse);
      expect(sent!.containsKey('payment_status'), isFalse);
      expect(sent!.containsKey('user_id'), isFalse);
      expect(sent!.containsKey('card_number'), isFalse);
      expect(sent!.containsKey('cvv'), isFalse);
    });

    test('staff 403 is surfaced for non-staff payment ops', () async {
      DestinyPaymentApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = PaymentApiClient(
        tokenProvider: FakeIdTokenProvider('customer-tok'),
        httpClient: MockClient(
          (_) async => http.Response(
            json.encode({
              'status': 'error',
              'code': 'forbidden',
              'message': 'Not authorized as Destiny staff',
            }),
            403,
          ),
        ),
      );
      try {
        await client.postAction('staff_list_payments');
        fail('expected PaymentApiException');
      } on PaymentApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.message, contains('Not authorized'));
      }
    });

    test('does not treat client success as paid without backend payload', () {
      final intent = PaymentIntent.fromJson({
        'id': 'p1',
        'booking_id': 'b1',
        'currency': 'USD',
        'gross_amount': '55.00',
        'platform_fee': '0.00',
        'provider_fee': 0,
        'merchant_net': 55,
        'provider': 'mock',
        'payment_status': 'requires_action',
        'settlement_status': 'unsettled',
        'is_mock': true,
      });
      expect(intent.isSucceeded, isFalse);
      expect(intent.isMock, isTrue);
      expect(intent.platformFee, 0);
    });
  });

  group('PaymentCommerceRepository', () {
    test('createIntent posts booking_id only', () async {
      DestinyPaymentApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sent;
      final repo = PaymentCommerceRepository(
        client: PaymentApiClient(
          tokenProvider: FakeIdTokenProvider('tok'),
          httpClient: MockClient((request) async {
            sent = json.decode(request.body) as Map<String, dynamic>;
            return http.Response(
              json.encode({
                'status': 'success',
                'data': {
                  'id': 'p1',
                  'booking_id': 'b1',
                  'currency': 'USD',
                  'gross_amount': 120.5,
                  'platform_fee': 0,
                  'provider_fee': 0,
                  'merchant_net': 120.5,
                  'provider': 'mock',
                  'payment_status': 'requires_action',
                  'settlement_status': 'unsettled',
                  'is_mock': true,
                },
              }),
              200,
            );
          }),
        ),
      );
      final intent = await repo.createIntent(bookingId: 'b1');
      expect(sent!['action'], 'create_payment_intent');
      expect(sent!.keys, containsAll(['action', 'booking_id']));
      expect(intent.grossAmount, 120.5);
      expect(intent.platformFee, 0);
    });
  });
}
