import 'dart:convert';

import 'package:destiny/config/destiny_staff_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/repositories/staff_commerce_repository.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:destiny/services/staff_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    DestinyStaffApiConfig.debugClearOverrides();
    DestinySupabaseConfig.debugClearOverrides();
  });

  group('CustomerBooking M3B display', () {
    test('labels and cancel eligibility by status', () {
      CustomerBooking booking({
        required String status,
        double? quoted,
        double? requested,
      }) {
        return CustomerBooking.fromJson({
          'id': '1',
          'firebase_uid': 'u',
          'item_name': 'Tour',
          'item_type': 'tour',
          'num_travelers': 1,
          'currency': 'USD',
          'status': status,
          'payment_status': 'none',
          'customer_notes': '',
          'customer_quote_note': quoted != null ? 'Includes transfers' : '',
          'quote_expires_at':
              quoted != null ? '2026-12-01T00:00:00.000Z' : null,
          'requested_total': requested,
          'quoted_total': quoted,
          'item_image_json': [],
        });
      }

      final submitted = booking(status: 'submitted', requested: 40);
      expect(submitted.hasAuthoritativeQuote, isFalse);
      expect(submitted.statusLabel, 'Request submitted');
      expect(submitted.isCancelableByCustomer, isTrue);

      final quoted = booking(status: 'quoted', requested: 40, quoted: 55);
      expect(quoted.hasAuthoritativeQuote, isTrue);
      expect(quoted.statusLabel, 'Destiny quote');
      expect(quoted.customerQuoteNote, 'Includes transfers');
      expect(quoted.displayAmount, 55);

      final awaiting = booking(status: 'awaiting_payment', quoted: 55);
      expect(awaiting.statusLabel, 'Awaiting payment');
      expect(awaiting.isCancelableByCustomer, isTrue);

      final confirmed = booking(status: 'confirmed', quoted: 55);
      expect(confirmed.isCancelableByCustomer, isFalse);
      expect(confirmed.staffNextStatuses, contains('completed'));
    });
  });

  group('StaffApiClient authorization', () {
    test('requires token', () async {
      DestinyStaffApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = StaffApiClient(
        tokenProvider: FakeIdTokenProvider(null),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        client.postAction('staff_me'),
        throwsA(isA<StaffApiException>()),
      );
    });

    test('maps 403 access denied for non-staff', () async {
      DestinyStaffApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = StaffApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient(
          (_) async => http.Response(
            json.encode({
              'status': 'error',
              'message': 'Not authorized as Destiny staff',
            }),
            403,
          ),
        ),
      );
      try {
        await client.postAction('staff_me');
        fail('expected StaffApiException');
      } on StaffApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.message, contains('Not authorized'));
      }
    });

    test('quote_booking strips actor spoof fields and posts quote', () async {
      DestinyStaffApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sent;
      final client = StaffApiClient(
        tokenProvider: FakeIdTokenProvider('staff-tok'),
        httpClient: MockClient((request) async {
          sent = json.decode(request.body) as Map<String, dynamic>;
          expect(request.headers['Authorization'], 'Bearer staff-tok');
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {
                'id': 'b1',
                'firebase_uid': 'customer',
                'item_name': 'Tour',
                'item_type': 'tour',
                'num_travelers': 1,
                'currency': 'USD',
                'status': 'quoted',
                'payment_status': 'none',
                'customer_notes': '',
                'customer_quote_note': 'OK',
                'quoted_total': 120,
                'requested_total': 100,
                'item_image_json': [],
              },
            }),
            200,
          );
        }),
      );
      final repo = StaffCommerceRepository(client: client);
      final out = await repo.quoteBooking(
        bookingId: 'b1',
        quotedTotal: 120,
        customerQuoteNote: 'OK',
      );
      expect(sent!['action'], 'quote_booking');
      expect(sent!.containsKey('firebase_uid'), isFalse);
      expect(sent!.containsKey('user_id'), isFalse);
      expect(sent!.containsKey('role'), isFalse);
      expect(sent!['quoted_total'], 120);
      expect(out.status, 'quoted');
      expect(out.paymentStatus, 'none');
      expect(out.quotedTotal, 120);
      expect(out.requestedTotal, 100);
    });

    test('illegal transition surfaces 409', () async {
      DestinyStaffApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = StaffApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient(
          (_) async => http.Response(
            json.encode({
              'status': 'error',
              'message': 'Illegal transition submitted -> confirmed',
            }),
            409,
          ),
        ),
      );
      await expectLater(
        StaffCommerceRepository(client: client).transitionBooking(
          bookingId: 'b1',
          toStatus: 'confirmed',
        ),
        throwsA(
          isA<StaffApiException>().having((e) => e.statusCode, 'code', 409),
        ),
      );
    });

    test('convert_enquiry returns booking request linkage', () async {
      DestinyStaffApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = StaffApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient((request) async {
          final body = json.decode(request.body) as Map<String, dynamic>;
          expect(body['action'], 'convert_enquiry');
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {
                'enquiry': {
                  'id': 'e1',
                  'kind': 'flight',
                  'firebase_uid': 'u',
                  'payload': {},
                  'status': 'converted',
                  'converted_booking_id': 'b9',
                },
                'booking': {
                  'id': 'b9',
                  'firebase_uid': 'u',
                  'item_name': 'Flight',
                  'item_type': 'flight',
                  'status': 'submitted',
                  'payment_status': 'none',
                  'num_travelers': 1,
                  'currency': 'USD',
                  'customer_notes': '',
                  'item_image_json': [],
                  'enquiry_id': 'e1',
                },
              },
            }),
            200,
          );
        }),
      );
      final data =
          await StaffCommerceRepository(client: client).convertEnquiry('e1');
      expect(data['booking'], isA<Map>());
      expect((data['booking'] as Map)['status'], 'submitted');
      expect((data['enquiry'] as Map)['status'], 'converted');
    });
  });
}
