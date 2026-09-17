class CustomerEnquiry {
  final String id;
  final String kind;
  final String userId;
  final String firebaseUid;
  final Map<String, dynamic> payload;

  /// received | in_review | quoted | converted | closed
  final String status;
  final String customerResponseNote;
  final DateTime? createdAt;
  final String? provider;
  final String? providerOfferRef;
  final Map<String, dynamic> itinerarySnapshot;
  final double? validatedAmount;
  final String? validatedCurrency;
  final Map<String, dynamic> passengerSummary;

  CustomerEnquiry({
    required this.id,
    required this.kind,
    this.userId = '',
    this.firebaseUid = '',
    required this.payload,
    required this.status,
    this.customerResponseNote = '',
    this.createdAt,
    this.provider,
    this.providerOfferRef,
    this.itinerarySnapshot = const {},
    this.validatedAmount,
    this.validatedCurrency,
    this.passengerSummary = const {},
  });

  factory CustomerEnquiry.fromJson(Map<String, dynamic> json) {
    final raw = json['payload'];
    final Map<String, dynamic> payload = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final snap = json['itinerary_snapshot'];
    final pax = json['passenger_summary'];

    return CustomerEnquiry(
      id: json['id'].toString(),
      kind: json['kind']?.toString() ?? 'general',
      userId: json['user_id']?.toString() ?? '',
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      payload: payload,
      status: json['status']?.toString() ?? 'received',
      customerResponseNote:
          json['customer_response_note']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      provider: json['provider']?.toString(),
      providerOfferRef: json['provider_offer_ref']?.toString(),
      itinerarySnapshot: snap is Map
          ? Map<String, dynamic>.from(snap)
          : const <String, dynamic>{},
      validatedAmount: json['validated_amount'] == null
          ? null
          : double.tryParse(json['validated_amount'].toString()),
      validatedCurrency: json['validated_currency']?.toString(),
      passengerSummary: pax is Map
          ? Map<String, dynamic>.from(pax)
          : const <String, dynamic>{},
    );
  }

  String get statusLabel {
    switch (status) {
      case 'received':
        return 'Received';
      case 'in_review':
        return 'In review';
      case 'quoted':
        return 'Quoted';
      case 'converted':
        return 'Converted';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }
}

class CustomerProfile {
  final String id;
  final String userId;
  final String firebaseUid;
  final String fullName;
  final String email;
  final String? phone;
  final int? legacySqlId;

  CustomerProfile({
    required this.id,
    this.userId = '',
    this.firebaseUid = '',
    required this.fullName,
    required this.email,
    this.phone,
    this.legacySqlId,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      legacySqlId: json['legacy_sql_id'] == null
          ? null
          : int.tryParse(json['legacy_sql_id'].toString()),
    );
  }
}
