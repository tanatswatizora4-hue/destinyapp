import 'package:destiny/models/destina_chat.dart';
import 'package:destiny/screens/destina_screen.dart';
import 'package:destiny/screens/navigation_screen.dart';
import 'package:destiny/services/access_token_provider.dart';
import 'package:destiny/services/destina_api_client.dart';
import 'package:destiny/services/destina_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    DestinaSessionStore.debugOverride('destina-session-test-aaaaaaaa');
  });
  tearDown(DestinaSessionStore.debugClear);

  test('DestinaTurn parses structured response', () {
    final turn = DestinaTurn.fromJson({
      'conversation_id': 'c1',
      'message': {'role': 'assistant', 'content': 'When are you hoping to travel?'},
      'trip_state': {'destination': 'ZNZ', 'adults': 2},
      'tool_results': [
        {
          'name': 'search_stays',
          'status': 'ok',
          'activity': 'Checking Destiny stays…',
          'summary': 'Catalog is not a live hold.',
          'cards': [
            {
              'kind': 'stay',
              'source': 'destiny_catalog',
              'availability': 'catalog_not_live_hold',
              'item': {'name': 'Lodge'},
            }
          ],
        }
      ],
      'suggested_actions': [
        {'id': 'handoff', 'label': 'Send to consultant'}
      ],
      'handoff': null,
      'auth_required': false,
      'model': {'provider': 'gemini', 'name': 'gemini-2.5-flash', 'configured': true},
    });
    expect(turn.assistantMessage, contains('hoping to travel'));
    expect(turn.tripState.destination, 'ZNZ');
    expect(turn.toolResults.first.cards.first.availability, 'catalog_not_live_hold');
    expect(turn.modelConfigured, isTrue);
  });

  test('DestinaApiClient strips spoof fields and sends session header', () async {
    Map<String, String>? headers;
    String? body;
    final client = DestinaApiClient(
      httpClient: MockClient((req) async {
        headers = req.headers;
        body = req.body;
        return http.Response(
          '{"status":"success","data":{"conversation_id":"c1","message":{"role":"assistant","content":"Hello"},"trip_state":{},"tool_results":[],"suggested_actions":[],"handoff":null,"auth_required":false,"model":{"configured":true}}}',
          200,
        );
      }),
      tokenProvider: FakeAccessTokenProvider('tok'),
      sessionId: () => 'destina-session-test-aaaaaaaa',
    );
    final turn = await client.chat(
      message: 'hi',
      seedContext: {'user_id': 'spoof'},
    );
    expect(turn.assistantMessage, 'Hello');
    expect(headers?['x-destina-session'], 'destina-session-test-aaaaaaaa');
    expect(headers?['Authorization'], 'Bearer tok');
    expect(body, isNot(contains('quoted_total')));
    expect(body!.contains('"action":"chat"'), isTrue);
  });

  test('DestinaApiClient never treats HTTP success without payload as paid booking', () async {
    final client = DestinaApiClient(
      httpClient: MockClient((req) async {
        return http.Response(
          '{"status":"success","data":{"conversation_id":"c1","message":{"content":"Request sent"},"trip_state":{},"tool_results":[],"auth_required":false,"model":{"configured":true}}}',
          200,
        );
      }),
      tokenProvider: FakeAccessTokenProvider(null),
    );
    final turn = await client.chat(message: 'book it');
    expect(turn.enquiryId, isNull);
    expect(turn.assistantMessage, isNot(contains('confirmed booking')));
  });

  test('Destina is a public route, not a protected nav index', () {
    expect(DestinaScreen.routeName, '/destina');
    expect(NavigationScreen.protectedNavIndices.contains(4), isFalse);
  });

  testWidgets('Destina screen shows consultant greeting', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DestinaScreen()));
    expect(find.textContaining("I'm Destina"), findsOneWidget);
    expect(find.text('Ask Destina…'), findsOneWidget);
  });
}
