import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/destina_chat.dart';
import 'package:destiny/models/flight_offer.dart';
import 'package:destiny/repositories/destina_repository.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/services/destina_api_client.dart';
import 'package:destiny/utils/destiny_media_url.dart';
import 'package:destiny/widgets/flight_offer_card.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';

class DestinaScreen extends StatefulWidget {
  static const String routeName = '/destina';

  final String? seedPrompt;
  final Map<String, dynamic>? seedContext;

  const DestinaScreen({super.key, this.seedPrompt, this.seedContext});

  @override
  State<DestinaScreen> createState() => _DestinaScreenState();
}

class _DestinaScreenState extends State<DestinaScreen> {
  final _repo = DestinaRepository();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <DestinaChatMessage>[];
  String? _conversationId;
  DestinaTripState _trip = const DestinaTripState();
  bool _sending = false;
  String? _activity;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _messages.add(const DestinaChatMessage(
      role: 'assistant',
      content:
          "Hello — I'm Destina, Destiny's travel consultant. Where would you like to go?",
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSeed());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _maybeSeed() async {
    if (_seeded) return;
    _seeded = true;
    final prompt = widget.seedPrompt?.trim();
    if (prompt == null || prompt.isEmpty) return;
    _input.text = prompt;
    await _send(prompt);
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _activity = 'Destina is thinking…';
      _messages.add(DestinaChatMessage(role: 'user', content: text));
      _input.clear();
    });
    _jump();
    try {
      final turn = await _repo.send(
        message: text,
        conversationId: _conversationId,
        seedContext: widget.seedContext,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = turn.conversationId;
        _trip = turn.tripState;
        _activity = turn.toolResults.isNotEmpty
            ? turn.toolResults.last.activity
            : null;
        _messages.add(DestinaChatMessage(
          role: 'assistant',
          content: turn.assistantMessage,
          cards: turn.toolResults.expand((t) => t.cards).toList(growable: false),
        ));
        _sending = false;
        _activity = null;
      });
      if (turn.authRequired && mounted) {
        await Navigator.of(context).pushNamed(LoginScreen.routeName);
      }
    } on DestinaApiException catch (e) {
      if (!mounted) return;
      final content = e.turn?.assistantMessage.isNotEmpty == true
          ? e.turn!.assistantMessage
          : e.message;
      setState(() {
        if (e.turn != null) {
          _conversationId = e.turn!.conversationId;
          _trip = e.turn!.tripState;
        }
        _messages.add(DestinaChatMessage(role: 'assistant', content: content));
        _sending = false;
        _activity = null;
      });
      if (e.needsSignIn && mounted) {
        await Navigator.of(context).pushNamed(LoginScreen.routeName);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const DestinaChatMessage(
          role: 'assistant',
          content:
              "I couldn't complete that just now. I can try again, or I can send this to our travel team.",
        ));
        _sending = false;
        _activity = null;
      });
    }
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 960;
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Destina'),
            backgroundColor: AppTheme.navy,
            foregroundColor: Colors.white,
          ),
          body: desktop
              ? Row(
                  children: [
                    SizedBox(width: 280, child: _tripRail()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _chatColumn()),
                  ],
                )
              : _chatColumn(),
        );
      },
    );
  }

  Widget _tripRail() {
    return ColoredBox(
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Trip brief',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  )),
          const SizedBox(height: 12),
          if (_trip.routeLabel.isNotEmpty) Text(_trip.routeLabel),
          if (_trip.departureDate != null) Text('Depart ${_trip.departureDate}'),
          if (_trip.returnDate != null) Text('Return ${_trip.returnDate}'),
          Text(
            '${_trip.adults} adult(s)'
            '${_trip.children > 0 ? ', ${_trip.children} child' : ''}',
          ),
          const SizedBox(height: 16),
          const Text(
            'Live fares are Travelport quotes. Catalog stays and tours are Destiny listings — not a live hold.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _chatColumn() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                return _bubble(
                  DestinaChatMessage(
                    role: 'assistant',
                    content: _activity ?? 'Destina is thinking…',
                  ),
                  pending: true,
                );
              }
              return _bubble(_messages[i]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: 'Ask Destina…',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : () => _send(_input.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    minimumSize: const Size(52, 52),
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(DestinaChatMessage message, {bool pending = false}) {
    final mine = message.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mine ? AppTheme.navy : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: mine ? null : Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    pending ? 'Destina' : 'Destina',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mine ? Colors.white70 : AppTheme.accent,
                    ),
                  ),
                ),
              Text(
                message.content,
                style: TextStyle(
                  color: mine ? Colors.white : AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
              if (pending)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ...message.cards.map((c) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _DestinaResultCard(card: c),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinaResultCard extends StatelessWidget {
  final DestinaCard card;
  const _DestinaResultCard({required this.card});

  @override
  Widget build(BuildContext context) {
    if (card.kind == 'flight_offer') {
      try {
        final offer = FlightOffer.fromJson(card.payload);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Travelport quote',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            FlightOfferCard(offer: offer),
          ],
        );
      } catch (_) {
        return Text(card.payload['fare_name']?.toString() ?? 'Live fare');
      }
    }
    final name = card.payload['name']?.toString() ?? 'Destiny catalog';
    final image = card.payload['image']?.toString();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: image != null && image.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: TravelNetworkImage(
                    imageUrl: DestinyMediaUrl.resolve(image),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : const Icon(Icons.travel_explore_outlined),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          card.availability == 'catalog_not_live_hold'
              ? 'Destiny catalog — not a live hold'
              : (card.payload['location']?.toString() ?? ''),
        ),
      ),
    );
  }
}
