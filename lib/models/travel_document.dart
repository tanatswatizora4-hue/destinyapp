class TravelDocument {
  final String id;
  final String documentType;
  final String displayName;
  final String mimeType;
  final int fileSize;
  final String? issuingCountry;
  final String? issueDate;
  final String? expiryDate;
  final String verificationStatus;
  final String uploadStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TravelDocument({
    required this.id,
    required this.documentType,
    required this.displayName,
    required this.mimeType,
    required this.fileSize,
    this.issuingCountry,
    this.issueDate,
    this.expiryDate,
    required this.verificationStatus,
    required this.uploadStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory TravelDocument.fromJson(Map<String, dynamic> json) {
    return TravelDocument(
      id: json['id'].toString(),
      documentType: json['document_type']?.toString() ?? 'other',
      displayName: json['display_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      issuingCountry: json['issuing_country']?.toString(),
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      verificationStatus: json['verification_status']?.toString() ?? 'unverified',
      uploadStatus: json['upload_status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  String get typeLabel => documentType.replaceAll('_', ' ');
}

class TravelDocumentSignedAccess {
  final String signedUrl;
  final int expiresIn;
  final TravelDocument document;

  const TravelDocumentSignedAccess({
    required this.signedUrl,
    required this.expiresIn,
    required this.document,
  });
}
