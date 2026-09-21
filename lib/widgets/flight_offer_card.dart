import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/flight_offer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlightOfferCard extends StatelessWidget {
  final FlightOffer offer;
  final bool selected;
  final VoidCallback? onTap;
  final String? legLabel;
  final bool showPrice;
  final String? priceCaption;

  const FlightOfferCard({
    super.key,
    required this.offer,
    this.selected = false,
    this.onTap,
    this.legLabel,
    this.showPrice = true,
    this.priceCaption,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm();
    final child = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (legLabel != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    legLabel!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  offer.airlineLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (showPrice)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      offer.totalPrice.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                    ),
                    if (priceCaption != null)
                      Text(
                        priceCaption!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          ...offer.itineraries.map(
            (leg) => _LegBlock(leg: leg, time: time),
          ),
          if (offer.cabin != null || offer.fareName != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (offer.cabin != null && offer.cabin!.isNotEmpty) offer.cabin,
                if (offer.fareName != null && offer.fareName!.isNotEmpty)
                  offer.fareName,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Material(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), child: child);
    }
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _LegBlock extends StatelessWidget {
  final FlightItinerary leg;
  final DateFormat time;

  const _LegBlock({required this.leg, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${leg.origin.code} ${leg.departure != null ? time.format(leg.departure!) : '—'}  →  ${leg.destination.code} ${leg.arrival != null ? time.format(leg.arrival!) : '—'}'
            '${leg.durationLabel.isNotEmpty ? '  ·  ${leg.durationLabel}' : ''}'
            '  ·  ${leg.stopsLabel}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          ...leg.segments.map((s) {
            final op = s.operatingCarrier;
            final opNote = op != null &&
                    op.code.isNotEmpty &&
                    op.code != s.carrier.code
                ? ' op ${op.displayName}'
                : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${s.flightNumber}  ${s.origin.code} ${s.departure != null ? time.format(s.departure!) : '—'} → ${s.destination.code} ${s.arrival != null ? time.format(s.arrival!) : '—'}$opNote',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class FlightItinerarySummary extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> passengers;
  final String? providerRef;
  final double? validatedAmount;
  final String? validatedCurrency;

  const FlightItinerarySummary({
    super.key,
    this.snapshot = const {},
    this.payload = const {},
    this.passengers = const {},
    this.providerRef,
    this.validatedAmount,
    this.validatedCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final origin = payload['origin']?.toString() ??
        _codeOf(snapshot['origin']) ??
        '';
    final destination = payload['destination']?.toString() ??
        _codeOf(snapshot['destination']) ??
        '';
    final departure = payload['departure_date']?.toString() ?? '';
    final ret = payload['return_date']?.toString() ?? '';
    final adults = passengers['adults'] ?? payload['adults'];
    final children = passengers['children'] ?? payload['children'];
    final infants = passengers['infants'] ?? payload['infants'];
    final cabin = payload['cabin_class']?.toString() ??
        snapshot['cabin']?.toString();
    final fare = snapshot['fare_name']?.toString();

    final itineraries = snapshot['itineraries'];
    final legs = <String>[];
    if (itineraries is List) {
      for (var i = 0; i < itineraries.length; i++) {
        final first = itineraries[i];
        if (first is! Map) continue;
        final label = i == 0 ? 'Outbound' : 'Return';
        final segs = first['segments'];
        if (segs is List) {
          final flights = segs
              .whereType<Map>()
              .map((s) {
                final fn = s['flight_number']?.toString() ?? '';
                final o = _codeOf(s['origin']) ?? '';
                final d = _codeOf(s['destination']) ?? '';
                return [fn, if (o.isNotEmpty && d.isNotEmpty) '$o→$d']
                    .where((x) => x.isNotEmpty)
                    .join(' ');
              })
              .where((s) => s.isNotEmpty)
              .join(' · ');
          if (flights.isNotEmpty) legs.add('$label: $flights');
        }
      }
    }

    final rows = <String, String>{
      if (origin.isNotEmpty || destination.isNotEmpty)
        'Route': '$origin → $destination',
      if (departure.isNotEmpty)
        'Dates': ret.isEmpty ? departure : '$departure – $ret',
      if (adults != null || children != null || infants != null)
        'Passengers':
            '${adults ?? 0} adult · ${children ?? 0} child · ${infants ?? 0} infant',
      for (final leg in legs) ...{
        if (leg.startsWith('Outbound'))
          'Outbound': leg.replaceFirst('Outbound: ', '')
        else
          'Return': leg.replaceFirst('Return: ', ''),
      },
      if (cabin != null && cabin.isNotEmpty) 'Cabin': cabin,
      if (fare != null && fare.isNotEmpty) 'Fare': fare,
      if (validatedAmount != null)
        'Validated amount':
            '${validatedCurrency ?? 'USD'} ${validatedAmount!.toStringAsFixed(2)}',
      if (providerRef != null && providerRef!.isNotEmpty)
        'Provider reference': providerRef!,
    };

    if (rows.isEmpty) {
      return Text(
        payload.isEmpty ? 'No flight details yet' : payload.toString(),
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static String? _codeOf(dynamic v) {
    if (v is Map) return v['code']?.toString();
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }
}
