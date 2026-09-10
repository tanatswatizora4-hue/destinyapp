import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/repositories/staff_commerce_repository.dart';
import 'package:destiny/services/staff_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Minimal Destiny staff operations UI (M3B). Not in public customer nav.
/// Authorization is enforced by staff-commerce-api (staff_users allowlist).
class StaffOpsScreen extends StatefulWidget {
  static const String routeName = '/staff-ops';

  const StaffOpsScreen({super.key});

  @override
  State<StaffOpsScreen> createState() => _StaffOpsScreenState();
}

class _StaffOpsScreenState extends State<StaffOpsScreen>
    with SingleTickerProviderStateMixin {
  final StaffCommerceRepository _repo = StaffCommerceRepository();
  late final TabController _tabs;
  StaffUser? _staff;
  Object? _authError;
  bool _loadingAuth = true;

  List<CustomerBooking> _bookings = const [];
  List<CustomerEnquiry> _enquiries = const [];
  bool _loadingLists = false;
  Object? _listError;

  CustomerBooking? _selectedBooking;
  CustomerEnquiry? _selectedEnquiry;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingAuth = true;
      _authError = null;
    });
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _loadingAuth = false;
        _authError = 'Sign in required';
      });
      return;
    }
    try {
      final me = await _repo.me();
      setState(() {
        _staff = me;
        _loadingAuth = false;
      });
      await _refreshLists();
    } on StaffApiException catch (e) {
      setState(() {
        _loadingAuth = false;
        _authError = e;
        _staff = null;
      });
    } catch (e) {
      setState(() {
        _loadingAuth = false;
        _authError = e;
        _staff = null;
      });
    }
  }

  Future<void> _refreshLists() async {
    setState(() {
      _loadingLists = true;
      _listError = null;
    });
    try {
      final bookings = await _repo.listBookings();
      final enquiries = await _repo.listEnquiries();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _enquiries = enquiries;
        _loadingLists = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = e;
        _loadingLists = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Destiny Operations'),
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        bottom: _staff == null
            ? null
            : TabBar(
                controller: _tabs,
                indicatorColor: AppTheme.accent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Bookings'),
                  Tab(text: 'Enquiries'),
                ],
              ),
        actions: [
          if (_staff != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_staff!.displayName.isNotEmpty ? _staff!.displayName : _staff!.email} · ${_staff!.role}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingAuth) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_staff == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppTheme.navy),
                const SizedBox(height: 16),
                Text(
                  'Access denied',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _authError is StaffApiException
                      ? (_authError as StaffApiException).message
                      : 'This area is only available to authorized Destiny staff.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                TextButton(onPressed: _bootstrap, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_loadingLists) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_listError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Unable to load queues: $_listError'),
            TextButton(onPressed: _refreshLists, child: const Text('Retry')),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabs,
      children: [
        _bookingsPane(),
        _enquiriesPane(),
      ],
    );
  }

  Widget _bookingsPane() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final list = ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final b = _bookings[i];
            final selected = _selectedBooking?.id == b.id;
            return ListTile(
              selected: selected,
              selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.border,
                ),
              ),
              title: Text(b.itemName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${b.statusLabel} · ${b.itemType}'),
              trailing: Text(b.status),
              onTap: () => setState(() => _selectedBooking = b),
            );
          },
        );

        if (!wide) {
          return Column(
            children: [
              Expanded(child: list),
              if (_selectedBooking != null)
                SizedBox(
                  height: constraints.maxHeight * 0.55,
                  child: _BookingDetailPanel(
                    booking: _selectedBooking!,
                    repo: _repo,
                    onChanged: (b) async {
                      setState(() => _selectedBooking = b);
                      await _refreshLists();
                    },
                  ),
                ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 360, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedBooking == null
                  ? const Center(
                      child: Text(
                        'Select a booking request',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : _BookingDetailPanel(
                      booking: _selectedBooking!,
                      repo: _repo,
                      onChanged: (b) async {
                        setState(() => _selectedBooking = b);
                        await _refreshLists();
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _enquiriesPane() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final list = ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _enquiries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = _enquiries[i];
            final selected = _selectedEnquiry?.id == e.id;
            final route = e.kind == 'flight'
                ? '${e.payload['origin'] ?? ''} → ${e.payload['destination'] ?? ''}'
                : e.kind;
            return ListTile(
              selected: selected,
              selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.border,
                ),
              ),
              title: Text(route.trim().isEmpty ? e.kind : route),
              subtitle: Text(e.statusLabel),
              onTap: () => setState(() => _selectedEnquiry = e),
            );
          },
        );

        final detail = _selectedEnquiry == null
            ? const Center(
                child: Text(
                  'Select an enquiry',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            : _EnquiryDetailPanel(
                enquiry: _selectedEnquiry!,
                repo: _repo,
                onChanged: () async {
                  await _refreshLists();
                },
              );

        if (!wide) {
          return Column(
            children: [
              Expanded(child: list),
              if (_selectedEnquiry != null)
                SizedBox(height: constraints.maxHeight * 0.55, child: detail),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 360, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

class _BookingDetailPanel extends StatefulWidget {
  final CustomerBooking booking;
  final StaffCommerceRepository repo;
  final Future<void> Function(CustomerBooking) onChanged;

  const _BookingDetailPanel({
    required this.booking,
    required this.repo,
    required this.onChanged,
  });

  @override
  State<_BookingDetailPanel> createState() => _BookingDetailPanelState();
}

class _BookingDetailPanelState extends State<_BookingDetailPanel> {
  late final TextEditingController _quoteCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _customerNoteCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _quoteCtrl = TextEditingController(
      text: widget.booking.quotedTotal?.toStringAsFixed(2) ??
          widget.booking.requestedTotal?.toStringAsFixed(2) ??
          '',
    );
    _noteCtrl = TextEditingController();
    _customerNoteCtrl = TextEditingController(
      text: widget.booking.customerQuoteNote,
    );
  }

  @override
  void didUpdateWidget(covariant _BookingDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.id != widget.booking.id) {
      _quoteCtrl.text = widget.booking.quotedTotal?.toStringAsFixed(2) ??
          widget.booking.requestedTotal?.toStringAsFixed(2) ??
          '';
      _customerNoteCtrl.text = widget.booking.customerQuoteNote;
      _noteCtrl.clear();
    }
  }

  @override
  void dispose() {
    _quoteCtrl.dispose();
    _noteCtrl.dispose();
    _customerNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<CustomerBooking> Function() op) async {
    setState(() => _busy = true);
    try {
      final updated = await op();
      await widget.onChanged(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.accent),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.itemName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(b.statusLabel)),
              Chip(label: Text(b.itemType)),
              if (b.requestedTotal != null)
                Chip(
                  label: Text(
                    'Requested estimate ${currency.format(b.requestedTotal)}',
                  ),
                ),
              if (b.quotedTotal != null)
                Chip(
                  label: Text(
                    'Destiny quote ${currency.format(b.quotedTotal)}',
                  ),
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Customer UID: ${b.firebaseUid}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          if (b.customerNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Customer notes: ${b.customerNotes}'),
          ],
          if (b.internalNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Internal notes:\n${b.internalNotes}',
                style: const TextStyle(fontSize: 13)),
          ],
          const Divider(height: 32),
          Text('Authoritative quote',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          TextField(
            controller: _quoteCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quoted total (USD)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customerNoteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Customer-facing quote note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Internal note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () {
                    final amount = double.tryParse(_quoteCtrl.text.trim());
                    if (amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid quote')),
                      );
                      return;
                    }
                    _run(() => widget.repo.quoteBooking(
                          bookingId: b.id,
                          quotedTotal: amount,
                          customerQuoteNote: _customerNoteCtrl.text.trim(),
                          internalNote: _noteCtrl.text.trim(),
                        ));
                  },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Save Destiny quote'),
          ),
          const SizedBox(height: 24),
          Text('Lifecycle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: b.staffNextStatuses.map((to) {
              return OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.repo.transitionBooking(
                          bookingId: b.id,
                          toStatus: to,
                        )),
                child: Text('→ $to'),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment capture is M3D — awaiting_payment does not mean paid.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EnquiryDetailPanel extends StatefulWidget {
  final CustomerEnquiry enquiry;
  final StaffCommerceRepository repo;
  final Future<void> Function() onChanged;

  const _EnquiryDetailPanel({
    required this.enquiry,
    required this.repo,
    required this.onChanged,
  });

  @override
  State<_EnquiryDetailPanel> createState() => _EnquiryDetailPanelState();
}

class _EnquiryDetailPanelState extends State<_EnquiryDetailPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() op) async {
    setState(() => _busy = true);
    try {
      await op();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.accent),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enquiry;
    final next = switch (e.status) {
      'received' => const ['in_review', 'closed'],
      'in_review' => const ['quoted', 'closed'],
      'quoted' => const ['closed'],
      _ => const <String>[],
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${e.kind} · ${e.statusLabel}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
          ),
          const SizedBox(height: 12),
          Text('Customer UID: ${e.firebaseUid}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Text(e.payload.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: next
                .map(
                  (to) => OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await widget.repo.updateEnquiry(
                                enquiryId: e.id,
                                toStatus: to,
                              );
                            }),
                    child: Text('→ $to'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          if (e.status == 'quoted' || e.status == 'in_review')
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await widget.repo.convertEnquiry(e.id);
                      }),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Convert to booking request'),
            ),
          const SizedBox(height: 8),
          const Text(
            'Conversion creates a submitted booking request — not a confirmation.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
