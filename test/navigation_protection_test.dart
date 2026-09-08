import 'package:destiny/screens/navigation_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationScreen protected indices', () {
    test('Flights (4) is public; account tabs 5–8 remain protected', () {
      expect(NavigationScreen.protectedNavIndices, [5, 6, 7, 8]);
      expect(NavigationScreen.protectedNavIndices.contains(4), isFalse);
      for (final index in [0, 1, 2, 3, 4, 9]) {
        expect(
          NavigationScreen.protectedNavIndices.contains(index),
          isFalse,
          reason: 'index $index should be public',
        );
      }
      for (final index in [5, 6, 7, 8]) {
        expect(
          NavigationScreen.protectedNavIndices.contains(index),
          isTrue,
          reason: 'index $index should stay protected',
        );
      }
    });
  });
}
