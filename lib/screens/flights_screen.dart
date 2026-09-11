import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/repositories/customer_commerce_repository.dart';
import 'package:destiny/widgets/destiny_discovery.dart';
import 'package:destiny/services/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Agent-assisted flight / trip enquiry — not live fare shopping.
class FlightsScreen extends StatefulWidget {
  const FlightsScreen({super.key});

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _peopleController = TextEditingController(text: '2');
  final List<TextEditingController> _midPlaceControllers = [
    TextEditingController(),
  ];

  DateTime? _departureDate;
  DateTime? _returnDate;
  bool _isRoundTrip = true;
  bool _isLoading = false;
  bool _needsAccommodation = false;
  bool _needsInterchangeAssistance = false;
  bool _needsTaxi = false;

  final EnquiryRepository _enquiries = EnquiryRepository();

  bool get _signedIn => SupabaseAuthService().currentUser != null;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _peopleController.dispose();
    for (final c in _midPlaceControllers) {
      c.dispose();
    }
    super.dispose();
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

  void _addStop() {
    setState(() => _midPlaceControllers.add(TextEditingController()));
  }

  void _removeStop(int index) {
    setState(() {
      _midPlaceControllers[index].dispose();
      _midPlaceControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a departure date.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_isRoundTrip && _returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a return date for round trips.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign in to send your flight enquiry so Destiny agents can follow up.',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final midPlaces = _midPlaceControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await _enquiries.createFlightEnquiry(
        origin: _fromController.text.trim(),
        destination: _toController.text.trim(),
        midPlaces: midPlaces,
        numTravelers: int.tryParse(_peopleController.text.trim()) ?? 1,
        needsAccommodation: _needsAccommodation,
        needsInterchangeAssistance: _needsInterchangeAssistance,
        needsTaxi: _needsTaxi,
        departureDate: _departureDate!,
        returnDate: _returnDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Flight enquiry submitted. Destiny will review and respond — this is not a ticket purchase.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      _fromController.clear();
      _toController.clear();
      _peopleController.text = '2';
      for (final c in _midPlaceControllers) {
        c.clear();
      }
      setState(() {
        _departureDate = null;
        _returnDate = null;
        _needsAccommodation = false;
        _needsInterchangeAssistance = false;
        _needsTaxi = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send enquiry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;
        final pagePad = isDesktop ? 32.0 : 16.0;
        final maxContent =
            isDesktop ? AppTheme.contentMaxWidth : AppTheme.contentMaxWidth;

        // No nested Scaffold — NavigationScreen already provides chrome.
        return ColoredBox(
          color: AppTheme.background,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pagePad, 8, pagePad, isDesktop ? 40 : 100),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DestinyDiscoveryIntro(
                        eyebrow: 'Flights',
                        title: 'Plan air travel with Destiny',
                        subtitle:
                            'Tell us where you need to go. Destiny agents design flight options for you — this is an enquiry, not live ticket shopping or instant fares.',
                        isDesktop: isDesktop,
                        pagePad: 0,
                        maxWidth: maxContent,
                      ),
                      const SizedBox(height: 8),
                      DestinyDestinaAssist(
                        prompt:
                            '“Not sure where to start? Ask Destina to shape a multi-city brief…”',
                        onTap: () => showDestinyPreviewMessage(
                          context,
                          'Destina planning is coming soon — submit an enquiry below meanwhile.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 24 : 18),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.85),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trip enquiry',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No airline inventory is searched in-app. Your request is routed to Destiny agents.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              children: [
                                DestinyFilterChip(
                                  label: 'Round trip',
                                  selected: _isRoundTrip,
                                  onTap: () => setState(() {
                                    _isRoundTrip = true;
                                  }),
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
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'From',
                                hintText: 'City or airport',
                                prefixIcon: Icon(Icons.flight_takeoff_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Origin is required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _toController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'To',
                                hintText: 'City or airport',
                                prefixIcon: Icon(Icons.flight_land_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Destination is required'
                                      : null,
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
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _peopleController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Travellers',
                                prefixIcon: Icon(Icons.group_outlined),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v?.trim() ?? '');
                                if (n == null || n < 1) {
                                  return 'Enter at least 1 traveller';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Stopovers (optional)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0;
                                i < _midPlaceControllers.length;
                                i++) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _midPlaceControllers[i],
                                      decoration: InputDecoration(
                                        hintText: 'Stopover ${i + 1}',
                                        prefixIcon: const Icon(
                                          Icons.connecting_airports_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_midPlaceControllers.length > 1)
                                    IconButton(
                                      tooltip: 'Remove stopover',
                                      onPressed: () => _removeStop(i),
                                      icon: const Icon(Icons.remove_circle_outline),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            TextButton.icon(
                              onPressed: _addStop,
                              icon: const Icon(Icons.add),
                              label: const Text('Add stopover'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Also needed',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _needsAccommodation,
                              onChanged: (v) => setState(
                                () => _needsAccommodation = v ?? false,
                              ),
                              title: const Text('Stay / hotel help'),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _needsInterchangeAssistance,
                              onChanged: (v) => setState(
                                () =>
                                    _needsInterchangeAssistance = v ?? false,
                              ),
                              title: const Text('Airport interchange help'),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _needsTaxi,
                              onChanged: (v) =>
                                  setState(() => _needsTaxi = v ?? false),
                              title: const Text('Ground transfer / taxi'),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                minimumSize: const Size(double.infinity, 52),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Send flight enquiry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
