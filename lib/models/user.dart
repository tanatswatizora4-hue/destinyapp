import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? phone;
  final bool isSubscribed;
  final int? sqlId;
  final String? facePhotoUrl;
  final String? passportPhotoUrl;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.phone,
    this.isSubscribed = false,
    this.sqlId,
    this.facePhotoUrl,
    this.passportPhotoUrl,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      phone: data['phone'],
      isSubscribed: data['isSubscribed'] ?? false,
      sqlId: data['sqlId'],
      facePhotoUrl: data['facePhotoUrl'],
      passportPhotoUrl: data['passportPhotoUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'isSubscribed': isSubscribed,
      'sqlId': sqlId,
      'facePhotoUrl': facePhotoUrl,
      'passportPhotoUrl': passportPhotoUrl,
    };
  }
}
