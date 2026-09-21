import 'dart:math';

/// Unguessable Destina anonymous session id (never a user_id).
class DestinaSessionStore {
  static String? _id;
  static String? _testOverride;

  static String get current {
    if (_testOverride != null) return _testOverride!;
    return _id ??= _generate();
  }

  static String _generate() {
    final r = Random.secure();
    const hex = '0123456789abcdef';
    return List.generate(32, (_) => hex[r.nextInt(16)]).join();
  }

  static void debugOverride(String id) {
    _testOverride = id;
  }

  static void debugClear() {
    _testOverride = null;
    _id = null;
  }
}
