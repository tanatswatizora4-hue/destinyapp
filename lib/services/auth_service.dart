import 'dart:io';

import 'package:destiny/models/user.dart';
import 'package:destiny/repositories/customer_commerce_repository.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// App-facing auth facade over [SupabaseAuthService].
///
/// Keeps screens off raw Supabase calls. Profile bootstrap goes through
/// customer-api (server-derived user_id). Google OAuth is not reimplemented
/// (see docs/m3b5_auth_migration_audit.md).
class AuthService {
  AuthService({
    SupabaseAuthService? auth,
    CustomerRepository? customerRepository,
    ApiService? apiService,
  })  : _auth = auth ?? SupabaseAuthService(),
        _customers = customerRepository ?? CustomerRepository(),
        _apiService = apiService ?? ApiService();

  final SupabaseAuthService _auth;
  final CustomerRepository _customers;
  final ApiService _apiService;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.userChanges;

  bool get isSignedIn => _auth.isSignedIn;

  String? get currentUserId => _auth.currentUserId;

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final res = await _auth.signIn(email: email, password: password);
      final user = res.user;
      if (user != null) {
        await _bootstrapAfterAuth(user);
      }
      return user;
    } on AuthException {
      rethrow;
    }
  }

  Future<User?> createUserWithEmailAndPassword(
    String fullName,
    String email,
    String password,
  ) async {
    try {
      final res = await _auth.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      final user = res.user;
      if (user != null) {
        await _bootstrapAfterAuth(user, fullName: fullName);
      }
      return user;
    } on AuthException {
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String email) =>
      _auth.requestPasswordReset(email);

  /// Google OAuth deferred — Supabase Google provider not required for M3B.5.
  @Deprecated('Google OAuth deferred until Supabase provider is configured')
  Future<User?> signInWithGoogle() async {
    throw UnsupportedError(
      'Google sign-in is temporarily unavailable. Use email and password.',
    );
  }

  Future<void> _bootstrapAfterAuth(User user, {String? fullName}) async {
    final name = fullName ??
        _auth.displayNameOf(user) ??
        user.email ??
        '';
    final email = user.email ?? '';

    // Destiny customer_profiles via Edge Function (canonical).
    try {
      await _customers.upsertProfile(fullName: name, email: email);
    } catch (e) {
      // Non-fatal: commerce calls can upsert later.
      // ignore: avoid_print
      print('customer profile upsert deferred: $e');
    }

    // Legacy bymapara SQL bridge for Travel Docs / photos until M3E.
    // Identity string is now the Supabase Auth UUID (not Firebase).
    try {
      await _apiService.syncUserWithSql(user.id, name, email);
    } catch (e) {
      // ignore: avoid_print
      print('legacy SQL sync deferred: $e');
    }
  }

  Future<AppUser?> getAppUser(String uid) async {
    try {
      final profile = await _customers.getProfile();
      if (profile != null) {
        return AppUser(
          uid: profile.userId.isNotEmpty ? profile.userId : uid,
          email: profile.email,
          displayName: profile.fullName,
          phone: profile.phone,
          sqlId: profile.legacySqlId,
        );
      }
      final user = _auth.currentUser;
      if (user == null) return null;
      return AppUser(
        uid: user.id,
        email: user.email ?? '',
        displayName: _auth.displayNameOf(user),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching Destiny profile: $e');
      final user = _auth.currentUser;
      if (user == null) return null;
      return AppUser(
        uid: user.id,
        email: user.email ?? '',
        displayName: _auth.displayNameOf(user),
      );
    }
  }

  Future<void> updateUserProfile({
    required String fullName,
    required String email,
    required String phone,
    int? sqlId,
    File? facePhotoFile,
    File? passportPhotoFile,
  }) async {
    await _customers.upsertProfile(
      fullName: fullName,
      email: email,
      phone: phone,
    );

    // Optional legacy photo upload path (bymapara) when sqlId is known.
    if (sqlId != null &&
        (facePhotoFile != null || passportPhotoFile != null)) {
      await _apiService.updateUserInSql(
        sqlId: sqlId,
        fullName: fullName,
        email: email,
        phone: phone,
        facePhotoFile: facePhotoFile,
        passportPhotoFile: passportPhotoFile,
      );
    }
  }

  Future<void> signOut() => _auth.signOut();
}
