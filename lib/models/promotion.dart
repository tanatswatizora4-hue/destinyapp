/// Legacy Firestore Promotion model — unused after M3B.5 auth cutover.
/// Retained as a plain DTO in case marketing content is wired later.
/// Do not reintroduce cloud_firestore for this.
class Promotion {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;

  Promotion({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
  });

  factory Promotion.fromJson(Map<String, dynamic> data, {String? id}) {
    return Promotion(
      id: id ?? data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
    );
  }
}
