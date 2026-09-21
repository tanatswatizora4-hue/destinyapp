import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/flight_offer.dart';
import 'package:destiny/repositories/flight_commerce_repository.dart';
import 'package:destiny/screens/destina_launch.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/services/supabase_auth_service.dart';
import 'package:destiny/widgets/destiny_discovery.dart';
import 'package:destiny/widgets/flight_offer_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Live flight shopping via Destiny flight-commerce-api / Travelport.
class FlightsScreen extends StatefulWidget {
  const FlightsScreen({super.key});

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

enum _FlightUiPhase { form, outbound, inbound, review, priced }

class _FlightsScreenState extends State<FlightsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _repo = FlightCommerceRepository();

  DateTime? _departureDate;
  DateTime? _returnDate;
  bool _isRoundTrip = true;
  int _adults = 1;
  int _children = 0;
  int _infants = 0;
  String _cabin = 'economy';

  bool _needsAccommodation = false;
  bool _needsInterchangeAssistance = false;
  bool _needsTaxi = false;

  _FlightUiPhase _phase = _FlightUiPhase.form;
  bool _loading = false;
  String? _error;
  String? _errorCode;
  FlightSearchResult? _results;
  FlightSearchResult? _inbound;
  FlightOffer? _outbound;
  FlightOffer? _inboundOffer;
  FlightOfferValidation? _validated;
  bool _priceChanged = false;

  bool get _signedIn => SupabaseAuthService().currentUser != null;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  FlightSearchQuery? _queryFromForm() {
    if (!_formKey.currentState!.validate()) return null;
    if (_departureDate == null) {
      _toast('Please choose a departure date.', Colors.orange);
      return null;
    }
    if (_isRoundTrip && _returnDate == null) {
      _toast('Please choose a return date.', Colors.orange);
      return null;
    }
    return FlightSearchQuery(
      origin: _fromController.text.trim().toUpperCase(),
      destination: _toController.text.trim().toUpperCase(),
      departureDate: _departureDate!,
      returnDate: _isRoundTrip ? _returnDate : null,
      isReturn: _isRoundTrip,
      adults: _adults,
      children: _children,
      infants: _infants,
      cabinClass: _cabin,
    );
  }

  Future<void> _search() async {
    final query = _queryFromForm();
    if (query == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _errorCode = null;
      _results = null;
      _inbound = null;
      _outbound = null;
      _inboundOffer = null;
      _validated = null;
      _priceChanged = false;
      _phase = _FlightUiPhase.outbound;
    });
    try {
      final result = await _repo.search(query);
      if (!mounted) return;
      setState(() {
        _results = result;
        _loading = false;
      });
    } on FlightApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _errorCode = e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to search flights right now.';
      });
    }
  }

  Future<void> _selectOffer(FlightOffer offer) async {
    final query = _queryFromForm();
    if (query == null) return;
    final needsNext = _results?.nextLegRequired == true && query.isReturn;
    final mixedInbound =
        query.isReturn && (_results?.hasSeparateInboundSequence == true);
    setState(() {
      _outbound = offer;
      _inboundOffer = null;
      _validated = null;
      _error = null;
      _errorCode = null;
    });
    if (needsNext) {
      setState(() => _loading = true);
      try {
        final inbound = await _repo.nextLeg(offer);
        if (!mounted) return;
        setState(() {
          _inbound = inbound;
          _phase = _FlightUiPhase.inbound;
          _loading = false;
        });
      } on FlightApiException catch (e) {
        _handleApi(e);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Unable to load return itineraries.';
        });
      }
      return;
    }
    if (mixedInbound) {
      setState(() => _phase = _FlightUiPhase.inbound);
      return;
    }
    setState(() => _phase = _FlightUiPhase.review);
  }

  Future<void> _selectInbound(FlightOffer offer) async {
    if (_outbound == null) return;
    setState(() {
      _inboundOffer = offer;
      _validated = null;
      _phase = _FlightUiPhase.review;
    });
  }

  Future<void> _validate(List<FlightOffer> selections) async {
    setState(() {
      _loading = true;
      _error = null;
      _errorCode = null;
    });
    try {
      final displayed =
          selections.length == 1 ? selections.first.totalPrice : null;
      final validation = await _repo.validate(
        selections: selections,
        displayedPrice: displayed,
      );
      if (!mounted) return;
      setState(() {
        _validated = validation;
        _priceChanged = validation.priceChanged;
        _phase = _FlightUiPhase.priced;
        _loading = false;
        if (validation.expired) {
          _error = 'This offer expired. Search again for current fares.';
          _errorCode = 'offer_expired';
        }
      });
    } on FlightApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _errorCode = e.code;
        _phase = _FlightUiPhase.review;
        if (e.isExpired) {
          _validated = null;
        }
      });
    }
  }

  void _handleApi(FlightApiException e) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = e.message;
      _errorCode = e.code;
      if (e.isExpired) {
        _validated = null;
        _phase = _FlightUiPhase.outbound;
      }
    });
  }

  Future<void> _continueEnquiry() async {
    final query = _queryFromForm();
    final offer = _validated?.offer;
    if (query == null || offer == null || _validated!.expired) return;
    if (!_signedIn) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _loading = true);
    try {
      final selections = <FlightOffer>[
        if (_outbound != null) _outbound!,
        if (_inboundOffer != null) _inboundOffer!,
      ];
      if (selections.isEmpty) selections.add(offer);
      await _repo.continueAsEnquiry(
        query: query,
        selections: selections,
        needsAccommodation: _needsAccommodation,
        needsInterchangeAssistance: _needsInterchangeAssistance,
        needsTaxi: _needsTaxi,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(
        'Itinerary sent to Destiny. This is not a ticket — a consultant will continue the booking.',
        Colors.green,
      );
    } on FlightApiException catch (e) {
      if (e.needsSignIn && mounted) {
        setState(() => _loading = false);
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      _handleApi(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Unable to save this itinerary: $e', Colors.red);
    }
  }

  Future<void> _selectDates() async {
    final now = DateTime.now();
    if (_isRoundTrip) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: now,
        lastDate: DateTime(now.year + 5),
        initialDateRange: _departureDate != null && _returnDate != null
            ? DateTimeRange(start: _departureDate!, end: _returnDate!)
            : null,
      );
      if (picked != null) {
        setState(() {
          _departureDate = picked.start;
          _returnDate = picked.end;
        });
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: _departureDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _departureDate = picked;
        _returnDate = null;
      });
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String get _dateLabel {
    final fmt = DateFormat.yMMMd();
    if (_departureDate == null) {
      return _isRoundTrip ? 'Select travel dates' : 'Select departure date';
    }
    if (_isRoundTrip && _returnDate != null) {
      return '${fmt.format(_departureDate!)} – ${fmt.format(_returnDate!)}';
    }
    return fmt.format(_departureDate!);
  }

  String? _iataValidator(String? v) {
    final code = v?.trim().toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
      return 'Use a 3-letter airport code (e.g. HRE)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;
        final pagePad = isDesktop ? 32.0 : 16.0;
        const maxContent = AppTheme.contentMaxWidth;

        return ColoredBox(
          color: AppTheme.background,
          child: SingleChildScrollView(
            padding:
                EdgeInsets.fromLTRB(pagePad, 8, pagePad, isDesktop ? 40 : 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DestinyDiscoveryIntro(
                      eyebrow: 'Flights',
                      title: 'Search live airfares with Destiny',
                      subtitle:
                          'Shop real itineraries, then continue with Destiny to complete the booking. Fares are provider quotes — not a ticket until Destiny confirms.',
                      isDesktop: isDesktop,
                      pagePad: 0,
                      maxWidth: maxContent,
                    ),
                    const SizedBox(height: 8),
                    DestinyDestinaAssist(
                      prompt:
                          '“Not sure of airport codes? Ask Destina for HRE, JNB, LHR…”',
                      onTap: () => openDestinaChat(
                        context,
                        seedPrompt:
                            'Help me choose flights. I am not sure of airport codes.',
                        seedContext: const {'product_type': 'flight'},
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildForm(isDesktop),
                    const SizedBox(height: 20),
                    _buildResults(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.85)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                DestinyFilterChip(
                  label: 'Return',
                  selected: _isRoundTrip,
                  onTap: () => setState(() => _isRoundTrip = true),
                ),
                DestinyFilterChip(
                  label: 'One way',
                  selected: !_isRoundTrip,
                  onTap: () => setState(() {
                    _isRoundTrip = false;
                    _returnDate = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fromController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'From',
                hintText: 'HRE',
                prefixIcon: Icon(Icons.flight_takeoff_outlined),
              ),
              validator: _iataValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _toController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'To',
                hintText: 'JNB',
                prefixIcon: Icon(Icons.flight_land_outlined),
              ),
              validator: _iataValidator,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDates,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Dates',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(_dateLabel),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DestinyFilterChip(
                  label: 'Economy',
                  selected: _cabin == 'economy',
                  onTap: () => setState(() => _cabin = 'economy'),
                ),
                DestinyFilterChip(
                  label: 'Premium economy',
                  selected: _cabin == 'premium_economy',
                  onTap: () => setState(() => _cabin = 'premium_economy'),
                ),
                DestinyFilterChip(
                  label: 'Business',
                  selected: _cabin == 'business',
                  onTap: () => setState(() => _cabin = 'business'),
                ),
                DestinyFilterChip(
                  label: 'First',
                  selected: _cabin == 'first',
                  onTap: () => setState(() => _cabin = 'first'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _paxRow('Adults', _adults, 1, 9, (v) {
              setState(() {
                _adults = v;
                if (_infants > _adults) _infants = _adults;
              });
            }),
            _paxRow('Children', _children, 0, 8, (v) {
              setState(() => _children = v);
            }),
            _paxRow('Infants', _infants, 0, _adults, (v) {
              setState(() => _infants = v);
            }),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _search,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _loading && _phase == _FlightUiPhase.form
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Search flights'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paxRow(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_phase == _FlightUiPhase.form && !_loading) {
      return const SizedBox.shrink();
    }
    if (_loading &&
        _phase != _FlightUiPhase.review &&
        _phase != _FlightUiPhase.priced) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }
    if (_error != null &&
        _phase != _FlightUiPhase.review &&
        _phase != _FlightUiPhase.priced) {
      return _statusBox(
        title: _errorCode == 'offer_expired'
            ? 'Offer expired'
            : _errorCode == 'not_configured' ||
                    _errorCode == 'provider_unavailable'
                ? 'Flights unavailable'
                : 'Search problem',
        body: _error!,
        action: TextButton(
          onPressed: _search,
          child: const Text('Search again'),
        ),
      );
    }

    if (_phase == _FlightUiPhase.priced && _validated != null) {
      return _pricedPanel(_validated!);
    }
    if (_phase == _FlightUiPhase.review) {
      return _reviewPanel();
    }

    final isInbound = _phase == _FlightUiPhase.inbound;
    final list = isInbound
        ? (_inbound?.offers.isNotEmpty == true
            ? _inbound!.offers
            : _results?.inboundOffers ?? const <FlightOffer>[])
        : (_results?.hasSeparateInboundSequence == true
            ? _results!.outboundOffers
            : _results?.offers ?? const <FlightOffer>[]);
    if (list.isEmpty) {
      return _statusBox(
        title: 'No flights found',
        body:
            'Destiny did not receive available itineraries for this search. Try different dates or airports — we never invent fares.',
        action: TextButton(
          onPressed: _search,
          child: const Text('Search again'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isInbound
              ? 'Choose your return'
              : (_isRoundTrip ? 'Choose outbound' : 'Choose an itinerary'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          isInbound
              ? 'Return fares shown here are not a guaranteed combined total until Destiny validates the trip.'
              : (_isRoundTrip
                  ? 'Select an outbound itinerary first. Combined price is confirmed only after validation.'
                  : 'Select an itinerary, then Destiny will reprice it with the provider.'),
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        ...list.map(
          (offer) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FlightOfferCard(
              offer: offer,
              legLabel: isInbound ? 'Return' : (_isRoundTrip ? 'Outbound' : null),
              selected: offer.id == _outbound?.id ||
                  offer.id == _inboundOffer?.id,
              priceCaption: _isRoundTrip ? 'Itinerary fare' : null,
              onTap: () {
                if (isInbound) {
                  _selectInbound(offer);
                } else {
                  _selectOffer(offer);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewPanel() {
    final outbound = _outbound;
    if (outbound == null) {
      return _statusBox(
        title: 'Select a flight',
        body: 'Choose an itinerary to continue.',
      );
    }
    final inbound = _inboundOffer;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'These itinerary fares are not a guaranteed combined total. Destiny will reprice the trip with the provider before you continue.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          FlightOfferCard(
            offer: outbound,
            legLabel: inbound != null ? 'Outbound' : null,
            priceCaption: inbound != null ? 'Itinerary fare' : null,
          ),
          if (inbound != null) ...[
            const SizedBox(height: 10),
            FlightOfferCard(
              offer: inbound,
              legLabel: 'Return',
              priceCaption: 'Itinerary fare',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.accent)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading
                ? null
                : () {
                    final selections = <FlightOffer>[
                      outbound,
                      if (inbound != null) inbound,
                    ];
                    _validate(selections);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.navy,
              minimumSize: const Size(double.infinity, 52),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Validate fare'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _phase = inbound != null
                  ? _FlightUiPhase.inbound
                  : _FlightUiPhase.outbound;
              _validated = null;
            }),
            child: Text(
              inbound != null ? 'Change return' : 'Choose another itinerary',
            ),
          ),
          if (inbound != null)
            TextButton(
              onPressed: () => setState(() {
                _phase = _FlightUiPhase.outbound;
                _inboundOffer = null;
                _validated = null;
              }),
              child: const Text('Change outbound'),
            ),
        ],
      ),
    );
  }

  Widget _pricedPanel(FlightOfferValidation validation) {
    final offer = validation.offer;
    final canContinue = !validation.expired;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validated itinerary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_outbound != null)
            FlightOfferCard(
              offer: _outbound!,
              legLabel: _inboundOffer != null ? 'Outbound' : null,
              showPrice: false,
            ),
          if (_inboundOffer != null) ...[
            const SizedBox(height: 10),
            FlightOfferCard(
              offer: _inboundOffer!,
              legLabel: 'Return',
              showPrice: false,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            offer.totalPrice.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
          ),
          const Text(
            'Provider-validated trip total',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (_priceChanged && validation.previousPrice != null) ...[
            const SizedBox(height: 8),
            Text(
              'Price updated from ${validation.previousPrice!.label} to ${offer.totalPrice.label}. The new amount is shown — Destiny does not silently replace fares.',
              style: const TextStyle(color: AppTheme.accent, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Continuing sends this itinerary to Destiny as an enquiry. It is not a paid ticket.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _needsAccommodation,
            onChanged: (v) => setState(() => _needsAccommodation = v ?? false),
            title: const Text('Also need a stay'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _needsInterchangeAssistance,
            onChanged: (v) =>
                setState(() => _needsInterchangeAssistance = v ?? false),
            title: const Text('Airport interchange help'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _needsTaxi,
            onChanged: (v) => setState(() => _needsTaxi = v ?? false),
            title: const Text('Ground transfer / taxi'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_loading || !canContinue) ? null : _continueEnquiry,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              _signedIn ? 'Continue with Destiny' : 'Sign in to continue',
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _phase = _FlightUiPhase.review;
              _validated = null;
            }),
            child: const Text('Back to summary'),
          ),
        ],
      ),
    );
  }

  Widget _statusBox({
    required String title,
    required String body,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.45)),
          if (action != null) action,
        ],
      ),
    );
  }
}
