class CustomerEnquiry {
  final String id;
  final String kind;
  final String firebaseUid;
  final Map<String, dynamic> payload;

  /// received | in_review | quoted | converted | closed
  final String status;
  final DateTime? createdAt;

  CustomerEnquiry({
    required this.id,
    required this.kind,
    required this.firebaseUid,
    required this.payload,
    required this.status,
    this.createdAt,
  });

  factory CustomerEnquiry.fromJson(Map<String, dynamic> json) {
    final raw = json['payload'];
    final Map<String, dynamic> payload = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    return CustomerEnquiry(
      id: json['id'].toString(),
      kind: json['kind']?.toString() ?? 'general',
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      payload: payload,
      status: json['status']?.toString() ?? 'received',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
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
  final String firebaseUid;
  final String fullName;
  final String email;
  final String? phone;
  final int? legacySqlId;

  CustomerProfile({
    required this.id,
    required this.firebaseUid,
    required this.fullName,
    required this.email,
    this.phone,
    this.legacySqlId,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'].toString(),
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
