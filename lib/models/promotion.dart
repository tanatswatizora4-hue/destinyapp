// File: promotion.dart
// Root: destiny/lib/models/
import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  final String id;
  final String code;
  final String description;
  final double discountPercentage;
  final DateTime validUntil;

  Promotion({
    required this.id,
    required this.code,
    required this.description,
    required this.discountPercentage,
    required this.validUntil,
  });

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Promotion(
      id: doc.id,
      code: data['code'] ?? '',
      description: data['description'] ?? '',
      discountPercentage: data['discountPercentage'] ?? 0.0,
      validUntil: (data['validUntil'] as Timestamp).toDate(),
    );
  }
}
