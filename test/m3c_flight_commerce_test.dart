import 'dart:convert';

import 'package:destiny/config/destiny_flight_api_config.dart';
import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/models/flight_offer.dart';
import 'package:destiny/repositories/flight_commerce_repository.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/screens/navigation_screen.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:destiny/services/flight_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    DestinyFlightApiConfig.debugClearOverrides();
  });

  group('Flight domain parsing', () {
    test('parses multi-segment offer, stops, price, and currency', () {
      final offer = FlightOffer.fromJson({
        'id': 'txn-1:o1:p0',
        'provider': {
          'provider': 'travelport',
          'transaction_id': 'txn-1',
          'offer_id': 'o1',
          'product_ids': ['p0'],
          'sequence': 1,
        },
        'itineraries': [
          {
            'origin': {'code': 'HRE'},
            'destination': {'code': 'CPT'},
            'departure': '2026-11-20T08:00:00',
            'arrival': '2026-11-20T13:10:00',
            'duration_minutes': 215,
            'stops': 1,
            'segments': [
              {
                'origin': {'code': 'HRE'},
                'destination': {'code': 'JNB'},
                'departure': '2026-11-20T08:00:00',
                'arrival': '2026-11-20T09:25:00',
                'duration_minutes': 85,
                'carrier': {'code': 'UM', 'name': 'Air Zimbabwe'},
                'flight_number': 'UM201',
                'cabin': 'Economy',
              },
              {
                'origin': {'code': 'JNB'},
                'destination': {'code': 'CPT'},
                'departure': '2026-11-20T11:00:00',
                'arrival': '2026-11-20T13:10:00',
                'duration_minutes': 130,
                'carrier': {'code': 'SA'},
                'flight_number': 'SA54',
                'cabin': 'Economy',
              },
            ],
          }
        ],
        'total_price': {'amount': 412.5, 'currency': 'USD'},
        'cabin': 'Economy',
        'fare_name': 'Eco Lite',
      });
      expect(offer.totalPrice.label, 'USD 412.50');
      expect(offer.itineraries.first.stops, 1);
      expect(offer.itineraries.first.stopsLabel, '1 stop');
      expect(offer.airlineLabel, 'Air Zimbabwe');
      expect(offer.routeLabel, 'HRE → CPT');
      expect(offer.provider.toSelectionJson()['offer_id'], 'o1');
    });

    test('empty offers stay empty — never invent inventory', () {
      final result = FlightSearchResult.fromJson({
        'offers': [],
        'next_leg_required': false,
        'provider': 'travelport',
      });
      expect(result.offers, isEmpty);
    });

    test('validation flags price change and expiry', () {
      final v = FlightOfferValidation.fromJson({
        'offer': {
          'id': 'x',
          'provider': {
            'provider': 'travelport',
            'transaction_id': 't',
            'offer_id': 'o1',
            'product_ids': ['p0'],
          },
          'itineraries': [],
          'total_price': {'amount': 500, 'currency': 'USD'},
        },
        'price_changed': true,
        'previous_price': {'amount': 412.5, 'currency': 'USD'},
        'expired': false,
      });
      expect(v.priceChanged, isTrue);
      expect(v.previousPrice!.amount, 412.5);
      expect(v.expired, isFalse);
    });
  });

  group('FlightApiClient security', () {
    test('search is public and still strips spoof fields', () async {
      DestinyFlightApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sent;
      Map<String, String>? headers;
      final client = FlightApiClient(
        tokenProvider: FakeAccessTokenProvider(null),
        httpClient: MockClient((req) async {
          headers = req.headers;
          sent = json.decode(req.body) as Map<String, dynamic>;
          return http.Response(
            json.encode({
              'status': 'success',
              'data': {
                'offers': [],
                'next_leg_required': false,
                'provider': 'travelport',
              },
            }),
            200,
          );
        }),
      );
      await client.postAction('search_flights', body: {
        'origin': 'HRE',
        'user_id': 'spoof',
        'role': 'admin',
        'quoted_total': 1,
        'validated_amount': 9,
      });
      expect(sent!['action'], 'search_flights');
      expect(sent!.containsKey('user_id'), isFalse);
      expect(sent!.containsKey('role'), isFalse);
      expect(sent!.containsKey('quoted_total'), isFalse);
      expect(sent!.containsKey('validated_amount'), isFalse);
      expect(headers!['authorization'], isNull);
    });

    test('customer-owned action requires a session token', () async {
      DestinyFlightApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = FlightApiClient(
        tokenProvider: FakeAccessTokenProvider(null),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        client.postAction('create_flight_enquiry', requireAuth: true),
        throwsA(
          isA<FlightApiException>().having((e) => e.needsSignIn, 'sign-in', isTrue),
        ),
      );
    });

    test('maps expired and unavailable provider codes', () async {
      DestinyFlightApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final client = FlightApiClient(
        tokenProvider: FakeAccessTokenProvider('tok'),
        httpClient: MockClient(
          (_) async => http.Response(
            json.encode({
              'status': 'error',
              'code': 'offer_expired',
              'message': 'This offer is no longer available. Search again.',
            }),
            409,
          ),
        ),
      );
      try {
        await client.postAction('validate_offer');
        fail('expected exception');
      } on FlightApiException catch (e) {
        expect(e.isExpired, isTrue);
        expect(e.message, contains('no longer available'));
      }
    });
  });

  group('FlightCommerceRepository', () {
    test('search forwards IATA query without client price', () async {
      DestinyFlightApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      Map<String, dynamic>? sent;
      final repo = FlightCommerceRepository(
        client: FlightApiClient(
          tokenProvider: FakeAccessTokenProvider(null),
          httpClient: MockClient((req) async {
            sent = json.decode(req.body) as Map<String, dynamic>;
            return http.Response(
              json.encode({
                'status': 'success',
                'data': {
                  'offers': [],
                  'next_leg_required': true,
                  'provider': 'travelport',
                  'transaction_id': 'txn-1',
                },
              }),
              200,
            );
          }),
        ),
      );
      final result = await repo.search(
        FlightSearchQuery(
          origin: 'HRE',
          destination: 'JNB',
          departureDate: DateTime(2026, 11, 20),
          returnDate: DateTime(2026, 11, 28),
          isReturn: true,
          adults: 1,
          children: 0,
          infants: 0,
          cabinClass: 'economy',
        ),
      );
      expect(sent!['trip_type'], 'return');
      expect(sent!['origin'], 'HRE');
      expect(sent!.containsKey('total_price'), isFalse);
      expect(result.nextLegRequired, isTrue);
      expect(result.offers, isEmpty);
    });

    test('continueAsEnquiry parses Destiny enquiry row', () async {
      DestinyFlightApiConfig.debugOverride(
        baseUrl: 'https://example.test/functions/v1',
      );
      final repo = FlightCommerceRepository(
        client: FlightApiClient(
          tokenProvider: FakeAccessTokenProvider('tok'),
          httpClient: MockClient((req) async {
            expect(req.headers['authorization'], 'Bearer tok');
            return http.Response(
              json.encode({
                'status': 'success',
                'data': {
                  'id': 'e1',
                  'kind': 'flight',
                  'user_id': 'uuid-1',
                  'payload': {'origin': 'HRE', 'destination': 'JNB'},
                  'status': 'received',
                  'validated_amount': 412.5,
                  'validated_currency': 'USD',
                },
              }),
              200,
            );
          }),
        ),
      );
      final offer = FlightOffer.fromJson({
        'id': 'x',
        'provider': {
          'provider': 'travelport',
          'transaction_id': 't',
          'offer_id': 'o1',
          'product_ids': ['p0'],
        },
        'itineraries': [],
        'total_price': {'amount': 412.5, 'currency': 'USD'},
      });
      final enquiry = await repo.continueAsEnquiry(
        query: FlightSearchQuery(
          origin: 'HRE',
          destination: 'JNB',
          departureDate: DateTime(2026, 11, 20),
          isReturn: false,
          adults: 1,
          children: 0,
          infants: 0,
          cabinClass: 'economy',
        ),
        selections: [offer],
      );
      expect(enquiry, isA<CustomerEnquiry>());
      expect(enquiry.kind, 'flight');
      expect(enquiry.validatedAmount, 412.5);
    });
  });

  group('Auth handoff contract', () {
    test('LoginScreen still pops true on success path exists', () {
      expect(LoginScreen.routeName, '/login');
    });

    test('Flights remain a public nav surface', () {
      expect(NavigationScreen.protectedNavIndices.contains(4), isFalse);
    });

    test('product type labels stay human', () {
      expect(destinyProductTypeLabel('flight'), 'Flight');
      expect(destinyProductTypeLabel('accommodation'), 'Stay');
      expect(destinyProductTypeLabel('tour'), 'Tour');
      expect(destinyProductTypeLabel('vehicle'), 'Vehicle');
    });
  });
}
