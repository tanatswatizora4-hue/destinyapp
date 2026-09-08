import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:destiny/widgets/destiny_discovery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccommodationDetailsScreen extends StatefulWidget {
  final Accommodation accommodation;
  const AccommodationDetailsScreen({super.key, required this.accommodation});

  @override
  State<AccommodationDetailsScreen> createState() =>
      _AccommodationDetailsScreenState();
}

class _AccommodationDetailsScreenState
    extends State<AccommodationDetailsScreen> {
  void _showBookingCanvas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StayBookingSheet(accommodation: widget.accommodation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.accommodation;
    final currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final from = stay.fromPrice;
    final priceLabel =
        from != null && from > 0 ? currency.format(from) : 'On request';
    final location = stay.locationLabel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final pagePad = isDesktop ? 32.0 : 16.0;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(stay.name),
            backgroundColor: AppTheme.surface,
          ),
          bottomNavigationBar: isDesktop
              ? null
              : DestinyMobileCtaBar(
                  priceCaption: from != null && from > 0
                      ? 'From / night'
                      : 'Stay request',
                  priceLabel: priceLabel,
                  ctaLabel: 'Request stay',
                  onPressed: _showBookingCanvas,
                ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pagePad, 12, pagePad, isDesktop ? 40 : 24),
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
                          Expanded(
                            flex: 7,
                            child: _StayBody(stay: stay, location: location),
                          ),
                          const SizedBox(width: 28),
                          SizedBox(
                            width: 340,
                            child: DestinyDesktopBookingRail(
                              title: 'Request this stay',
                              priceCaption: from != null && from > 0
                                  ? 'From / night'
                                  : 'Pricing',
                              priceLabel: priceLabel,
                              disclaimer:
                                  'This sends a request to Destiny agents. It is not instant hotel confirmation or live inventory.',
                              ctaLabel: 'Request stay',
                              onPressed: _showBookingCanvas,
                              extra: DestinyDestinaAssist(
                                compact: true,
                                prompt: 'Ask Destina to refine this stay brief.',
                                onTap: () => showDestinyPreviewMessage(
                                  context,
                                  'Destina planning is coming soon.',
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _StayBody(
                        stay: stay,
                        location: location,
                        showDestina: true,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StayBody extends StatelessWidget {
  final Accommodation stay;
  final String location;
  final bool showDestina;

  const _StayBody({
    required this.stay,
    required this.location,
    this.showDestina = false,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DestinyMediaGallery(
          imageUrls: stay.resolvedImageUrls,
          heroTag: 'accommodation_image_${stay.id}',
          height: 300,
        ),
        const SizedBox(height: 20),
        if (stay.type.trim().isNotEmpty)
          Text(
            stay.type.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
        const SizedBox(height: 6),
        Text(
          stay.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            location,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
        if (stay.address.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            stay.address.trim(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
        if (showDestina) ...[
          const SizedBox(height: 18),
          DestinyDestinaAssist(
            prompt: '“Compare this stay with quieter options nearby…”',
            onTap: () => showDestinyPreviewMessage(
              context,
              'Destina planning is coming soon.',
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'About this stay',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          stay.description.trim().isEmpty
              ? 'Details for this property will be confirmed by a Destiny agent when you request a stay.'
              : stay.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
        ),
        if (stay.roomTypes.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            'Rooms',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          ...stay.roomTypes.map(
            (room) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.king_bed_outlined, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Sleeps ${room.capacity}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${currency.format(room.price)}/night',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (stay.amenities.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Amenities',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stay.amenities
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

class _StayBookingSheet extends StatefulWidget {
  final Accommodation accommodation;
  const _StayBookingSheet({required this.accommodation});

  @override
  State<_StayBookingSheet> createState() => _StayBookingSheetState();
}

class _StayBookingSheetState extends State<_StayBookingSheet> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isBooking = false;
  DateTimeRange? _selectedDateRange;
  RoomType? _selectedRoom;
  int _numberOfNights = 1;
  int? _sqlId;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.accommodation.roomTypes.isNotEmpty
        ? widget.accommodation.roomTypes.first
        : null;
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
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _numberOfNights = picked.duration.inDays;
        if (_numberOfNights == 0) _numberOfNights = 1;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDateRange == null || _selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select dates and a room type.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_sqlId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to request this stay.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      await _apiService.createBooking(
        sqlId: _sqlId!,
        itemId: widget.accommodation.id,
        itemType: 'accommodation',
        numTravelers: _selectedRoom!.capacity,
        totalPrice: _selectedRoom!.price * _numberOfNights,
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
    final total = (_selectedRoom?.price ?? 0) * _numberOfNights;

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
              'Request this stay',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Agent-assisted request — not instant hotel confirmation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.accommodation.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: const Text('Select dates'),
              subtitle: Text(
                _selectedDateRange == null
                    ? 'Choose check-in and check-out'
                    : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} – ${DateFormat.yMMMd().format(_selectedDateRange!.end)} ($_numberOfNights nights)',
              ),
              onTap: _selectDateRange,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RoomType>(
              initialValue: _selectedRoom,
              decoration: const InputDecoration(
                labelText: 'Room type',
                prefixIcon: Icon(Icons.king_bed_outlined, color: AppTheme.primary),
              ),
              items: widget.accommodation.roomTypes
                  .map(
                    (room) => DropdownMenuItem(
                      value: room,
                      child: Text(
                        '${room.name} (${currency.format(room.price)}/night)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedRoom = value),
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
