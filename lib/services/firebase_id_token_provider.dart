import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Obtains short-lived Firebase ID tokens for M3A customer-api calls.
/// Does not persist tokens; always refreshes via Firebase Auth SDK.
abstract class IdTokenProvider {
  Future<String?> getIdToken({bool forceRefresh = false});
}

class FirebaseIdTokenProvider implements IdTokenProvider {
  FirebaseIdTokenProvider({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  String? get currentUid => _auth.currentUser?.uid;

  bool get isSignedIn => _auth.currentUser != null;
}

/// Test double — never talks to Firebase.
@visibleForTesting
class FakeIdTokenProvider implements IdTokenProvider {
  FakeIdTokenProvider(this.token);
  final String? token;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => token;
}
