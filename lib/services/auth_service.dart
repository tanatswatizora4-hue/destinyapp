import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:destiny/models/user.dart';
import 'package:destiny/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _apiService = ApiService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await _syncAndupdateUser(user);
      }
      return user;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user != null) {
        await _syncAndupdateUser(user);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('Failed to sign in with Email & Password: ${e.message}');
      rethrow;
    }
  }

  Future<User?> createUserWithEmailAndPassword(
      String fullName, String email, String password) async {
    try {
      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(fullName);
        await user.reload();
        final refreshedUser = _auth.currentUser;
        if (refreshedUser != null) {
          await _syncAndupdateUser(refreshedUser);
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('Failed to create user with Email & Password: ${e.message}');
      rethrow;
    }
  }

  Future<void> _syncAndupdateUser(User user) async {
    int? sqlId;
    try {
      final sqlUserData = await _apiService.syncUserWithSql(
          user.uid, user.displayName ?? user.email!, user.email!);
      if (sqlUserData.containsKey('id') && sqlUserData['id'] != null) {
        sqlId = sqlUserData['id'] as int;
      } else {
        print("Warning: SQL Sync succeeded but returned no ID.");
      }
    } catch (e) {
      print("SQL Sync failed. Error: $e");
    }
    await _updateFirestoreUser(user, sqlId: sqlId);
  }

  Future<void> _updateFirestoreUser(User user, {int? sqlId}) {
    final DocumentReference userRef = _db.collection('users').doc(user.uid);
    final appUser = AppUser(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName,
      isSubscribed: false,
      sqlId: sqlId,
    );
    return userRef.set(appUser.toFirestore(), SetOptions(merge: true));
  }

  Future<AppUser?> getAppUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching user from Firestore: $e');
      return null;
    }
  }

  Future<void> updateUserProfile({
    required int sqlId,
    required String fullName,
    required String email,
    required String phone,
    File? facePhotoFile,
    File? passportPhotoFile,
  }) async {
    // Call the API Service to handle the update and photo uploads
    await _apiService.updateUserInSql(
      sqlId: sqlId,
      fullName: fullName,
      email: email,
      phone: phone,
      facePhotoFile: facePhotoFile,
      passportPhotoFile: passportPhotoFile,
    );
    // After successful API update, update the local Firestore copy
    final userRef = _db.collection('users').doc(currentUser!.uid);
    await userRef.set({
      'displayName': fullName,
      'email': email,
      'phone': phone,
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
