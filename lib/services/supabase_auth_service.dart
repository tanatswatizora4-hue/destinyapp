import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase Auth for Destiny OS.
///
/// Screens must not call `Supabase.instance.client.auth` directly for
/// sign-in/up/out/reset — use this service (or [AuthService] facade).
class SupabaseAuthService {
  SupabaseAuthService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client =>
      _clientOverride ?? Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  bool get isSignedIn => currentSession != null;

  String? get currentUserId => currentUser?.id;

  String? get currentEmail => currentUser?.email;

  bool get emailConfirmed {
    final user = currentUser;
    if (user == null) return false;
    // When email confirmation is disabled, confirmed_at may still be set.
    return user.emailConfirmedAt != null;
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Maps auth stream to nullable [User] for UI StreamBuilders.
  Stream<User?> get userChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session?.user);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Sends a password-reset email. Redirect must be allowlisted in Supabase Auth.
  Future<void> requestPasswordReset(String email, {String? redirectTo}) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo ?? DestinySupabaseConfig.passwordResetRedirectUrl,
    );
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      final refreshed = await _client.auth.refreshSession();
      return refreshed.session?.accessToken;
    }
    return currentSession?.accessToken;
  }

  String? displayNameOf(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final full = meta['full_name'] ?? meta['name'];
    if (full is String && full.trim().isNotEmpty) return full.trim();
    return user.email;
  }
}

/// Initialize once from [main]. Safe to call only after WidgetsFlutterBinding.
Future<void> initializeDestinySupabase() {
  return Supabase.initialize(
    url: DestinySupabaseConfig.url,
    publishableKey: DestinySupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

@visibleForTesting
class DestinyAuthException implements Exception {
  DestinyAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Maps Supabase Auth errors to short Destiny-facing copy.
String destinyAuthErrorMessage(Object error) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('invalid login credentials') ||
      raw.contains('invalid_credentials')) {
    return 'Incorrect email or password.';
  }
  if (raw.contains('user already registered') ||
      raw.contains('already been registered')) {
    return 'An account with this email already exists. Sign in instead.';
  }
  if (raw.contains('email not confirmed')) {
    return 'Please confirm your email before signing in.';
  }
  if (raw.contains('password')) {
    return 'Password does not meet requirements.';
  }
  if (raw.contains('rate') || raw.contains('too many')) {
    return 'Too many attempts. Please wait and try again.';
  }
  return 'Authentication failed. Please try again.';
}
