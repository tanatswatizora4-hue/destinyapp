import 'package:destiny/utils/destiny_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DestinyMediaUrl.resolve', () {
    test('encodes spaces and parentheses in relative paths', () {
      const spaced =
          'uploads/6a4f54675bd28-ChatGPT Image Jul 9, 2026, 09_56_32 AM.png';
      const paren =
          'uploads/6a4e0663112ef-742045552_1817725842533249_6048909638074682386_n (1).jpg';

      expect(
        DestinyMediaUrl.resolve(spaced),
        'https://bymapara.com/uploads/6a4f54675bd28-ChatGPT%20Image%20Jul%209,%202026,%2009_56_32%20AM.png',
      );
      expect(
        DestinyMediaUrl.resolve(paren),
        'https://bymapara.com/uploads/6a4e0663112ef-742045552_1817725842533249_6048909638074682386_n%20(1).jpg',
      );
    });

    test('does not double-encode already encoded absolute URLs', () {
      const encoded =
          'https://bymapara.com/uploads/ChatGPT%20Image%20Jul%209.png';
      expect(DestinyMediaUrl.resolve(encoded), encoded);
    });

    test('supports absolute URLs on other hosts', () {
      expect(
        DestinyMediaUrl.resolve('https://cdn.example.com/a/b c.jpg'),
        'https://cdn.example.com/a/b%20c.jpg',
      );
    });

    test('returns placeholder for empty input', () {
      expect(DestinyMediaUrl.resolve(null), DestinyMediaUrl.placeholder);
      expect(DestinyMediaUrl.resolve(''), DestinyMediaUrl.placeholder);
      expect(DestinyMediaUrl.resolve('   '), DestinyMediaUrl.placeholder);
    });
  });
}
