import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Obtains short-lived Supabase Auth access tokens for Edge Function calls.
abstract class AccessTokenProvider {
  Future<String?> getAccessToken({bool forceRefresh = false});
}

/// Reads the current session access token from the Supabase client.
class SupabaseAccessTokenProvider implements AccessTokenProvider {
  SupabaseAccessTokenProvider({SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client =>
      _clientOverride ?? Supabase.instance.client;

  @override
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      final refreshed = await _client.auth.refreshSession();
      return refreshed.session?.accessToken;
    }
    return _client.auth.currentSession?.accessToken;
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  bool get isSignedIn => _client.auth.currentSession != null;
}

/// Alias kept for existing test/call sites that used IdTokenProvider naming.
typedef IdTokenProvider = AccessTokenProvider;

@visibleForTesting
class FakeAccessTokenProvider implements AccessTokenProvider {
  FakeAccessTokenProvider(this.token);
  final String? token;

  @override
  Future<String?> getAccessToken({bool forceRefresh = false}) async => token;
}

/// Back-compat name used by older tests.
@visibleForTesting
typedef FakeIdTokenProvider = FakeAccessTokenProvider;
