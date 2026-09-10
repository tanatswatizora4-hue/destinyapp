import 'package:destiny/utils/destiny_media_url.dart';

/// Destiny-owned booking request (M3A). Distinct from legacy bymapara [Booking].
class CustomerBooking {
  final String id;
  final String firebaseUid;
  final String itemName;
  final String itemType;
  final String? itemId;
  final int? itemLegacyId;
  final List<String> imageRefs;
  final DateTime? startDate;
  final DateTime? endDate;
  final int numberOfTravelers;

  /// Customer-facing estimate only (never payment authority).
  final double? requestedTotal;

  /// Authoritative quote when set by Destiny (M3B+).
  final double? quotedTotal;
  final String currency;

  /// Lifecycle: draft|submitted|quoted|awaiting_payment|confirmed|cancelled|completed
  final String status;
  final String paymentStatus;
  final String customerNotes;
  final DateTime? createdAt;

  CustomerBooking({
    required this.id,
    required this.firebaseUid,
    required this.itemName,
    required this.itemType,
    this.itemId,
    this.itemLegacyId,
    required this.imageRefs,
    this.startDate,
    this.endDate,
    required this.numberOfTravelers,
    this.requestedTotal,
    this.quotedTotal,
    required this.currency,
    required this.status,
    required this.paymentStatus,
    required this.customerNotes,
    this.createdAt,
  });

  bool get isCancelableByCustomer =>
      const {'draft', 'submitted', 'quoted', 'awaiting_payment'}
          .contains(status);

  /// Prefer quoted amount when Destiny has quoted; else show estimate.
  double? get displayAmount => quotedTotal ?? requestedTotal;

  bool get hasAuthoritativeQuote => quotedTotal != null;

  String get mainImageUrl => DestinyMediaUrl.resolve(
        imageRefs.isNotEmpty ? imageRefs.first : null,
      );

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Request submitted';
      case 'quoted':
        return 'Quoted';
      case 'awaiting_payment':
        return 'Awaiting payment';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  factory CustomerBooking.fromJson(Map<String, dynamic> json) {
    List<String> images = const [];
    final rawImages = json['item_image_json'];
    if (rawImages is List) {
      images = rawImages.map((e) => e.toString()).toList(growable: false);
    } else if (rawImages is String && rawImages.isNotEmpty) {
      try {
        final decoded = rawImages; // already string path list unlikely
        images = [decoded];
      } catch (_) {}
    }

    double? asDouble(dynamic v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    DateTime? asDate(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      return DateTime.tryParse(v.toString());
    }

    return CustomerBooking(
      id: json['id'].toString(),
      firebaseUid: (json['firebase_uid'] ?? '').toString(),
      itemName: json['item_name']?.toString() ?? 'Booking request',
      itemType: json['item_type']?.toString() ?? 'unknown',
      itemId: json['item_id']?.toString(),
      itemLegacyId: json['item_legacy_id'] == null
          ? null
          : int.tryParse(json['item_legacy_id'].toString()),
      imageRefs: images,
      startDate: asDate(json['start_date']),
      endDate: asDate(json['end_date']),
      numberOfTravelers:
          int.tryParse(json['num_travelers']?.toString() ?? '1') ?? 1,
      requestedTotal: asDouble(json['requested_total']),
      quotedTotal: asDouble(json['quoted_total']),
      currency: json['currency']?.toString() ?? 'USD',
      status: json['status']?.toString() ?? 'submitted',
      paymentStatus: json['payment_status']?.toString() ?? 'none',
      customerNotes: json['customer_notes']?.toString() ?? '',
      createdAt: asDate(json['created_at']),
    );
  }
}
