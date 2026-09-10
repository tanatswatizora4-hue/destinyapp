import 'dart:convert';

import 'package:destiny/config/destiny_customer_api_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/repositories/customer_commerce_repository.dart';
import 'package:destiny/services/customer_api_client.dart';
import 'package:destiny/services/firebase_id_token_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    DestinyCustomerApiConfig.debugClearOverrides();
    DestinySupabaseConfig.debugClearOverrides();
  });

  group('DestinyCustomerApiConfig', () {
    test('defaults to destiny-os customer-api endpoint', () {
      expect(
        DestinyCustomerApiConfig.endpoint,
        'https://xchddfpfzrzhlbbmyhyn.supabase.co/functions/v1/customer-api',
      );
      expect(DestinyCustomerApiConfig.isEnabled, isTrue);
    });
  });

  group('CustomerBooking model', () {
    test('parses owned booking and cancel eligibility', () {
      final booking = CustomerBooking.fromJson({
        'id': 'b1',
        'firebase_uid': 'uid-1',
        'item_name': 'Kadoma',
        'item_type': 'tour',
        'item_legacy_id': 14,
        'num_travelers': 2,
        'requested_total': 40,
        'quoted_total': null,
        'currency': 'USD',
        'status': 'submitted',
        'payment_status': 'none',
        'customer_notes': '',
        'item_image_json': ['destiny-media/tours/14/primary.jpg'],
        'start_date': '2026-10-01',
      });
      expect(booking.isCancelableByCustomer, isTrue);
      expect(booking.hasAuthoritativeQuote, isFalse);
      expect(booking.displayAmount, 40);
      expect(booking.statusLabel, 'Request submitted');

      final confirmed = CustomerBooking.fromJson({
        ...{
          'id': 'b2',
          'firebase_uid': 'uid-1',
          'item_name': 'X',
          'item_type': 'tour',
          'num_travelers': 1,
          'currency': 'USD',
          'payment_status': 'none',
          'customer_notes': '',
          'item_image_json': [],
        },
        'status': 'confirmed',
        'quoted_total': 100,
        'requested_total': 80,
      });
      expect(confirmed.isCancelableByCustomer, isFalse);
      expect(confirmed.displayAmount, 100);
      expect(confirmed.hasAuthoritativeQuote, isTrue);
    });
  });

  group('CustomerApiClient', () {
    test('requires Firebase ID token', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = CustomerApiClient(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: FakeIdTokenProvider(null),
      );
      await expectLater(
        client.postAction('list_bookings'),
        throwsA(isA<StateError>()),
      );
    });

    test('strips client-authoritative fields before POST', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sentBody;
      final client = CustomerApiClient(
        tokenProvider: FakeIdTokenProvider('fake-firebase-token'),
        httpClient: MockClient((request) async {
          expect(
            request.headers['Authorization'],
            'Bearer fake-firebase-token',
          );
          expect(
            request.headers['apikey'],
            DestinySupabaseConfig.anonKey,
          );
          sentBody = json.decode(request.body) as Map<String, dynamic>;
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {
                'id': 'b1',
                'firebase_uid': 'from-server',
                'item_name': 'Tour',
                'item_type': 'tour',
                'num_travelers': 1,
                'requested_total': 20,
                'quoted_total': null,
                'currency': 'USD',
                'status': 'submitted',
                'payment_status': 'none',
                'customer_notes': '',
                'item_image_json': [],
              },
            }),
            200,
          );
        }),
      );

      final repo = BookingRepository(client: client);
      final booking = await repo.createRequest(
        itemType: 'tour',
        itemLegacyId: 14,
        itemName: 'Tour',
        numTravelers: 1,
        requestedEstimate: 20,
      );

      expect(sentBody!['action'], 'create_booking_request');
      expect(sentBody!.containsKey('firebase_uid'), isFalse);
      expect(sentBody!.containsKey('quoted_total'), isFalse);
      expect(sentBody!.containsKey('status'), isFalse);
      expect(sentBody!.containsKey('payment_status'), isFalse);
      expect(sentBody!.containsKey('total_price'), isFalse);
      expect(sentBody!['requested_estimate'], 20);
      expect(booking.status, 'submitted');
      expect(booking.firebaseUid, 'from-server');
    });

    test('listMine maps bookings owned response', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = CustomerApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient((request) async {
          final body = json.decode(request.body) as Map<String, dynamic>;
          expect(body['action'], 'list_bookings');
          return http.Response(
            json.encode({
              'status': 'success',
              'data': [
                {
                  'id': '1',
                  'firebase_uid': 'u',
                  'item_name': 'A',
                  'item_type': 'tour',
                  'num_travelers': 1,
                  'currency': 'USD',
                  'status': 'submitted',
                  'payment_status': 'none',
                  'customer_notes': '',
                  'item_image_json': [],
                },
              ],
            }),
            200,
          );
        }),
      );
      final list = await BookingRepository(client: client).listMine();
      expect(list, hasLength(1));
      expect(list.single.itemName, 'A');
    });

    test('surfaces API failure states', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = CustomerApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient(
          (_) async => http.Response(
            json.encode({'status': 'error', 'message': 'nope'}),
            401,
          ),
        ),
      );
      await expectLater(
        BookingRepository(client: client).listMine(),
        throwsA(isA<Exception>()),
      );
    });

    test('cancel posts booking_id via cancel_booking action', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sent;
      final client = CustomerApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient((request) async {
          sent = json.decode(request.body) as Map<String, dynamic>;
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {
                'id': 'b1',
                'firebase_uid': 'u',
                'item_name': 'A',
                'item_type': 'tour',
                'num_travelers': 1,
                'currency': 'USD',
                'status': 'cancelled',
                'payment_status': 'none',
                'customer_notes': '',
                'item_image_json': [],
              },
            }),
            200,
          );
        }),
      );
      final out = await BookingRepository(client: client).cancel(
        bookingId: 'b1',
        reason: 'changed plans',
      );
      expect(sent!['action'], 'cancel_booking');
      expect(sent!['booking_id'], 'b1');
      expect(out.status, 'cancelled');
    });

    test('flight enquiry create omits price fields', () async {
      DestinyCustomerApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sent;
      final client = CustomerApiClient(
        tokenProvider: FakeIdTokenProvider('tok'),
        httpClient: MockClient((request) async {
          sent = json.decode(request.body) as Map<String, dynamic>;
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {
                'id': 'e1',
                'kind': 'flight',
                'firebase_uid': 'u',
                'payload': {'origin': 'HRE', 'destination': 'JNB'},
                'status': 'received',
              },
            }),
            200,
          );
        }),
      );
      await EnquiryRepository(client: client).createFlightEnquiry(
        origin: 'HRE',
        destination: 'JNB',
        numTravelers: 2,
        needsAccommodation: false,
        needsInterchangeAssistance: false,
        needsTaxi: false,
      );
      expect(sent!['action'], 'create_flight_enquiry');
      expect(sent!.containsKey('total_price'), isFalse);
      expect(sent!.containsKey('firebase_uid'), isFalse);
    });
  });
}
