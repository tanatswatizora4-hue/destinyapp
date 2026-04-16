import 'dart:convert';

class Booking {
  final String id;
  final String userId;
  final String itemName;
  final String itemType;
  final String itemImageUrl;
  final DateTime startDate;
  final DateTime? endDate; // Nullable for tours
  final int numberOfTravelers;
  final double totalPrice;
  final String paymentStatus;

  Booking({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.itemType,
    required this.itemImageUrl,
    required this.startDate,
    this.endDate,
    required this.numberOfTravelers,
    required this.totalPrice,
    required this.paymentStatus,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    List<String> imageUrls =
    List<String>.from(jsonDecode(json['item_image_json'] ?? '[]'));
    String mainImageUrl = imageUrls.isNotEmpty
        ? 'https://bymapara.com/${imageUrls.first}'
        : 'https://placehold.co/100x100/cccccc/ffffff?text=No+Image';

    final startDate = DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now();
    final endDate = json['end_date'] != null
        ? DateTime.tryParse(json['end_date'] ?? '')
        : null;

    return Booking(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      itemName: json['item_name'] ?? 'Unknown Booking',
      itemType: json['item_type'] ?? 'unknown',
      itemImageUrl: mainImageUrl,
      startDate: startDate,
      endDate: endDate,
      numberOfTravelers: int.tryParse(json['num_travelers'].toString()) ?? 1,
      totalPrice: double.tryParse(json['total_price'].toString()) ?? 0.0,
      paymentStatus: json['status'] ?? 'Pending',
    );
  }
}
