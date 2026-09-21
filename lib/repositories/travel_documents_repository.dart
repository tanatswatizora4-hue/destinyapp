import 'dart:typed_data';

import 'package:destiny/models/travel_document.dart';
import 'package:destiny/services/customer_api_client.dart';
import 'package:http/http.dart' as http;

class TravelDocumentsRepository {
  TravelDocumentsRepository({
    CustomerApiClient? client,
    http.Client? httpClient,
  })  : _client = client ?? CustomerApiClient(),
        _http = httpClient ?? http.Client();

  final CustomerApiClient _client;
  final http.Client _http;

  Future<List<TravelDocument>> list() async {
    final res = await _client.postAction('list_travel_documents');
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) => TravelDocument.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<TravelDocumentSignedAccess> open(String documentId) async {
    final res = await _client.postAction('get_travel_document_url', {
      'document_id': documentId,
    });
    final data = Map<String, dynamic>.from(res['data'] as Map);
    if (data['public_url'] != null) {
      throw StateError('Public document URLs are not allowed');
    }
    return TravelDocumentSignedAccess(
      signedUrl: data['signed_url'].toString(),
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 0,
      document: TravelDocument.fromJson(
        Map<String, dynamic>.from(data['document'] as Map),
      ),
    );
  }

  Future<void> delete(String documentId) async {
    await _client.postAction('delete_travel_document', {
      'document_id': documentId,
    });
  }

  /// Creates metadata + signed upload, then PUTs bytes to the signed URL.
  Future<TravelDocument> upload({
    required String documentType,
    required String displayName,
    required String mimeType,
    required Uint8List bytes,
    String? issuingCountry,
    String? expiryDate,
  }) async {
    final created = await _client.postAction('create_travel_document_upload', {
      'document_type': documentType,
      'display_name': displayName,
      'mime_type': mimeType,
      'file_size': bytes.length,
      if (issuingCountry != null) 'issuing_country': issuingCountry,
      if (expiryDate != null) 'expiry_date': expiryDate,
    });
    final data = Map<String, dynamic>.from(created['data'] as Map);
    final upload = Map<String, dynamic>.from(data['upload'] as Map);
    final signedUrl = upload['signedUrl']?.toString() ??
        upload['signed_url']?.toString() ??
        '';
    final token = upload['token']?.toString();
    if (signedUrl.isEmpty) {
      throw StateError('Upload URL missing from Destina document API');
    }

    final put = await _http.put(
      Uri.parse(signedUrl),
      headers: {
        'Content-Type': mimeType,
        if (token != null && token.isNotEmpty) 'x-upsert': 'true',
      },
      body: bytes,
    );
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw Exception('Document upload failed (${put.statusCode})');
    }

    final doc = TravelDocument.fromJson(
      Map<String, dynamic>.from(data['document'] as Map),
    );
    await _client.postAction('finalize_travel_document', {
      'document_id': doc.id,
    });
    return doc;
  }
}
