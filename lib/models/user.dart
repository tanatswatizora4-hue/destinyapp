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

  factory AppUser.fromJson(Map<String, dynamic> data) {
    return AppUser(
      uid: (data['user_id'] ?? data['uid'] ?? '').toString(),
      email: data['email']?.toString() ?? '',
      displayName: data['full_name']?.toString() ?? data['displayName']?.toString(),
      phone: data['phone']?.toString(),
      isSubscribed: data['isSubscribed'] == true,
      sqlId: data['legacy_sql_id'] == null && data['sqlId'] == null
          ? null
          : int.tryParse((data['legacy_sql_id'] ?? data['sqlId']).toString()),
      facePhotoUrl: data['facePhotoUrl']?.toString(),
      passportPhotoUrl: data['passportPhotoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
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
