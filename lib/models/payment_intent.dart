/// Server-authoritative payment intent (M3D). Amounts come from the backend.
class PaymentIntent {
  final String id;
  final String bookingId;
  final String? customerUserId;
  final String currency;
  final double grossAmount;
  final double platformFee;
  final double providerFee;
  final double merchantNet;
  final String provider;
  final String? providerReference;
  final String? checkoutUrl;
  final String paymentStatus;
  final String settlementStatus;
  final bool isMock;
  final DateTime? expiresAt;
  final DateTime? confirmedAt;
  final DateTime? createdAt;
  final String reconciliationNote;

  PaymentIntent({
    required this.id,
    required this.bookingId,
    this.customerUserId,
    required this.currency,
    required this.grossAmount,
    required this.platformFee,
    required this.providerFee,
    required this.merchantNet,
    required this.provider,
    this.providerReference,
    this.checkoutUrl,
    required this.paymentStatus,
    required this.settlementStatus,
    this.isMock = false,
    this.expiresAt,
    this.confirmedAt,
    this.createdAt,
    this.reconciliationNote = '',
  });

  bool get isSucceeded => paymentStatus == 'succeeded';
  bool get isFailed => paymentStatus == 'failed';
  bool get isPending =>
      const {'created', 'pending', 'requires_action', 'processing'}
          .contains(paymentStatus);
  bool get isExpired => paymentStatus == 'expired';
  bool get isCancelled => paymentStatus == 'cancelled';

  String get statusLabel {
    switch (paymentStatus) {
      case 'created':
      case 'pending':
      case 'requires_action':
        return 'Awaiting checkout';
      case 'processing':
        return 'Processing';
      case 'succeeded':
        return 'Paid';
      case 'failed':
        return 'Payment failed';
      case 'cancelled':
        return 'Checkout cancelled';
      case 'expired':
        return 'Payment expired';
      case 'refunded':
        return 'Refunded';
      case 'partially_refunded':
        return 'Partially refunded';
      default:
        return paymentStatus;
    }
  }

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v == null) return 0;
      return double.tryParse(v.toString()) ?? 0;
    }

    DateTime? asDate(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      return DateTime.tryParse(v.toString());
    }

    return PaymentIntent(
      id: json['id'].toString(),
      bookingId: json['booking_id']?.toString() ?? '',
      customerUserId: json['customer_user_id']?.toString(),
      currency: json['currency']?.toString() ?? 'USD',
      grossAmount: asDouble(json['gross_amount']),
      platformFee: asDouble(json['platform_fee']),
      providerFee: asDouble(json['provider_fee']),
      merchantNet: asDouble(json['merchant_net']),
      provider: json['provider']?.toString() ?? '',
      providerReference: json['provider_reference']?.toString(),
      checkoutUrl: json['checkout_url']?.toString(),
      paymentStatus: json['payment_status']?.toString() ?? 'created',
      settlementStatus: json['settlement_status']?.toString() ?? 'unsettled',
      isMock: json['is_mock'] == true || json['provider'] == 'mock',
      expiresAt: asDate(json['expires_at']),
      confirmedAt: asDate(json['confirmed_at']),
      createdAt: asDate(json['created_at']),
      reconciliationNote: json['reconciliation_note']?.toString() ?? '',
    );
  }
}

class PaymentRefund {
  final String id;
  final String paymentIntentId;
  final double amount;
  final String currency;
  final String status;
  final String reason;
  final String? providerReference;
  final DateTime? createdAt;

  PaymentRefund({
    required this.id,
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
    required this.status,
    this.reason = '',
    this.providerReference,
    this.createdAt,
  });

  factory PaymentRefund.fromJson(Map<String, dynamic> json) {
    return PaymentRefund(
      id: json['id'].toString(),
      paymentIntentId: json['payment_intent_id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      status: json['status']?.toString() ?? 'requested',
      reason: json['reason']?.toString() ?? '',
      providerReference: json['provider_reference']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class PaymentLedgerEntry {
  final String id;
  final String entryType;
  final String account;
  final String direction;
  final double amount;
  final String currency;
  final String description;
  final DateTime? createdAt;

  PaymentLedgerEntry({
    required this.id,
    required this.entryType,
    required this.account,
    required this.direction,
    required this.amount,
    required this.currency,
    this.description = '',
    this.createdAt,
  });

  factory PaymentLedgerEntry.fromJson(Map<String, dynamic> json) {
    return PaymentLedgerEntry(
      id: json['id'].toString(),
      entryType: json['entry_type']?.toString() ?? '',
      account: json['account']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      description: json['description']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class StaffPaymentDetail {
  final PaymentIntent intent;
  final Map<String, dynamic> booking;
  final List<PaymentLedgerEntry> ledger;
  final List<PaymentRefund> refunds;
  final List<Map<String, dynamic>> events;

  StaffPaymentDetail({
    required this.intent,
    required this.booking,
    required this.ledger,
    required this.refunds,
    required this.events,
  });

  factory StaffPaymentDetail.fromJson(Map<String, dynamic> json) {
    final intentMap = Map<String, dynamic>.from(json['intent'] as Map);
    final booking = json['booking'] is Map
        ? Map<String, dynamic>.from(json['booking'] as Map)
        : <String, dynamic>{};
    final ledger = (json['ledger'] as List? ?? const [])
        .map((e) => PaymentLedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
    final refunds = (json['refunds'] as List? ?? const [])
        .map((e) => PaymentRefund.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
    final events = (json['events'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
    return StaffPaymentDetail(
      intent: PaymentIntent.fromJson(intentMap),
      booking: booking,
      ledger: ledger,
      refunds: refunds,
      events: events,
    );
  }
}
