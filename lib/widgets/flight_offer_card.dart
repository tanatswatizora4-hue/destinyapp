import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/flight_offer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlightOfferCard extends StatelessWidget {
  final FlightOffer offer;
  final bool selected;
  final VoidCallback onTap;

  const FlightOfferCard({
    super.key,
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leg = offer.outbound;
    final time = DateFormat.Hm();
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                  Expanded(
                    child: Text(
                      offer.airlineLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    offer.totalPrice.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (leg != null) leg.stopsLabel,
                  if (leg?.durationLabel.isNotEmpty == true) leg!.durationLabel,
                  if (offer.cabin != null && offer.cabin!.isNotEmpty)
                    offer.cabin,
                  if (offer.fareName != null && offer.fareName!.isNotEmpty)
                    offer.fareName,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              if (leg != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${leg.origin.code}  ${leg.departure != null ? time.format(leg.departure!) : '—'}   →   ${leg.destination.code}  ${leg.arrival != null ? time.format(leg.arrival!) : '—'}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  leg.segments
                      .map((s) => s.flightNumber)
                      .where((n) => n.isNotEmpty)
                      .join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
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
    final origin = payload['origin']?.toString() ?? '';
    final destination = payload['destination']?.toString() ?? '';
    final departure = payload['departure_date']?.toString() ?? '';
    final ret = payload['return_date']?.toString() ?? '';
    final adults = passengers['adults'] ?? payload['adults'];
    final children = passengers['children'] ?? payload['children'];
    final infants = passengers['infants'] ?? payload['infants'];
    final cabin = payload['cabin_class']?.toString();
    final fare = snapshot['fare_name']?.toString();
    final itineraries = snapshot['itineraries'];
    String airline = '';
    String flights = '';
    if (itineraries is List && itineraries.isNotEmpty) {
      final first = itineraries.first;
      if (first is Map) {
        final segs = first['segments'];
        if (segs is List && segs.isNotEmpty && segs.first is Map) {
          final carrier = (segs.first as Map)['carrier'];
          if (carrier is Map) {
            airline = (carrier['name'] ?? carrier['code'] ?? '').toString();
          }
          flights = segs
              .whereType<Map>()
              .map((s) => s['flight_number']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .join(' · ');
        }
      }
    }

    final rows = <String, String>{
      if (origin.isNotEmpty || destination.isNotEmpty)
        'Route': '$origin → $destination',
      if (departure.isNotEmpty) 'Dates': ret.isEmpty ? departure : '$departure – $ret',
      if (adults != null || children != null || infants != null)
        'Passengers':
            '${adults ?? 0} adult · ${children ?? 0} child · ${infants ?? 0} infant',
      if (airline.isNotEmpty) 'Airline': airline,
      if (flights.isNotEmpty) 'Flights': flights,
      if (cabin != null && cabin.isNotEmpty) 'Cabin': cabin,
      if (fare != null && fare.isNotEmpty) 'Fare': fare,
      if (validatedAmount != null)
        'Validated quote':
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
}
