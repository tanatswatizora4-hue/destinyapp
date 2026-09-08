import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:destiny/widgets/destiny_discovery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final Vehicle vehicle;
  const VehicleDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  void _showBookingCanvas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleBookingSheet(vehicle: widget.vehicle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final priceLabel = currency.format(vehicle.pricePerDay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final pagePad = isDesktop ? 32.0 : 16.0;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(vehicle.displayName),
            backgroundColor: AppTheme.surface,
          ),
          bottomNavigationBar: isDesktop
              ? null
              : DestinyMobileCtaBar(
                  priceCaption: 'Per day',
                  priceLabel: priceLabel,
                  ctaLabel: 'Request vehicle',
                  onPressed: _showBookingCanvas,
                ),
          body: SingleChildScrollView(
            padding:
                EdgeInsets.fromLTRB(pagePad, 12, pagePad, isDesktop ? 40 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop
                      ? AppTheme.contentWideMaxWidth
                      : AppTheme.contentMaxWidth,
                ),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _VehicleBody(vehicle: vehicle)),
                          const SizedBox(width: 28),
                          SizedBox(
                            width: 340,
                            child: DestinyDesktopBookingRail(
                              title: 'Request this vehicle',
                              priceCaption: 'Per day',
                              priceLabel: priceLabel,
                              disclaimer:
                                  'This sends a request to Destiny agents. It is not instant confirmed rental inventory.',
                              ctaLabel: 'Request vehicle',
                              onPressed: _showBookingCanvas,
                              extra: DestinyDestinaAssist(
                                compact: true,
                                prompt: 'Ask Destina to refine this transport brief.',
                                onTap: () => showDestinyPreviewMessage(
                                  context,
                                  'Destina planning is coming soon.',
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _VehicleBody(vehicle: vehicle, showDestina: true),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VehicleBody extends StatelessWidget {
  final Vehicle vehicle;
  final bool showDestina;

  const _VehicleBody({required this.vehicle, this.showDestina = false});

  @override
  Widget build(BuildContext context) {
    final location = vehicle.locationLabel;
    final pickup = [
      if (vehicle.address.trim().isNotEmpty) vehicle.address.trim(),
      if (location.isNotEmpty) location,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DestinyMediaGallery(
          imageUrls: vehicle.resolvedImageUrls,
          heroTag: 'vehicle_image_${vehicle.id}',
          height: 280,
        ),
        const SizedBox(height: 20),
        if (vehicle.type.trim().isNotEmpty)
          Text(
            vehicle.type.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
        const SizedBox(height: 6),
        Text(
          vehicle.displayName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaPill(label: '${vehicle.year}'),
            if (location.isNotEmpty) _MetaPill(label: location),
          ],
        ),
        if (showDestina) ...[
          const SizedBox(height: 18),
          DestinyDestinaAssist(
            prompt: '“Need a driver and airport pickup with this hire…”',
            onTap: () => showDestinyPreviewMessage(
              context,
              'Destina planning is coming soon.',
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        _DetailRow(label: 'Year', value: '${vehicle.year}'),
        if (pickup.isNotEmpty)
          _DetailRow(label: 'Pickup', value: pickup),
        if (vehicle.amenities.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Features',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: vehicle.amenities
                .where((a) => a.included)
                .map(
                  (a) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      a.name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleBookingSheet extends StatefulWidget {
  final Vehicle vehicle;
  const _VehicleBookingSheet({required this.vehicle});

  @override
  State<_VehicleBookingSheet> createState() => _VehicleBookingSheetState();
}

class _VehicleBookingSheetState extends State<_VehicleBookingSheet> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isBooking = false;
  DateTimeRange? _selectedDateRange;
  int _numberOfDays = 1;
  int? _sqlId;

  @override
  void initState() {
    super.initState();
    _getSqlId();
  }

  Future<void> _getSqlId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final appUser = await _authService.getAppUser(user.uid);
      if (appUser != null && appUser.sqlId != null && mounted) {
        setState(() => _sqlId = appUser.sqlId);
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _numberOfDays = picked.duration.inDays;
        if (_numberOfDays == 0) _numberOfDays = 1;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select hire dates.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_sqlId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to request this vehicle.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      await _apiService.createBooking(
        sqlId: _sqlId!,
        itemId: widget.vehicle.id,
        itemType: 'vehicle',
        numTravelers: 1,
        totalPrice: widget.vehicle.pricePerDay * _numberOfDays,
        startDate: _selectedDateRange!.start,
        endDate: _selectedDateRange!.end,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request received. A Destiny agent will contact you. Complete your profile details if needed.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final total = widget.vehicle.pricePerDay * _numberOfDays;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request this vehicle',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Agent-assisted request — not instant rental confirmation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.vehicle.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: const Text('Select hire dates'),
              subtitle: Text(
                _selectedDateRange == null
                    ? 'Choose pick-up and return dates'
                    : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} – ${DateFormat.yMMMd().format(_selectedDateRange!.end)} ($_numberOfDays days)',
              ),
              onTap: _selectDateRange,
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Estimated total',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  currency.format(total),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isBooking ? null : _confirmBooking,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _isBooking
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}
