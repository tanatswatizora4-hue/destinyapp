import 'package:destiny/config/destiny_media_config.dart';
import 'package:destiny/utils/destiny_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DestinyMediaConfig.debugClearOverrides);

  group('DestinyMediaUrl.resolve', () {
    test('encodes spaces and parentheses in relative legacy uploads paths', () {
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

    test('supports absolute HTTPS URLs on other hosts', () {
      expect(
        DestinyMediaUrl.resolve('https://cdn.example.com/a/b c.jpg'),
        'https://cdn.example.com/a/b%20c.jpg',
      );
    });

    test('returns placeholder for null or empty media', () {
      expect(DestinyMediaUrl.resolve(null), DestinyMediaUrl.placeholder);
      expect(DestinyMediaUrl.resolve(''), DestinyMediaUrl.placeholder);
      expect(DestinyMediaUrl.resolve('   '), DestinyMediaUrl.placeholder);
    });

    test('preserves local asset references', () {
      expect(
        DestinyMediaUrl.resolve('assets/images/legend.jpg'),
        'assets/images/legend.jpg',
      );
      expect(DestinyMediaUrl.isAssetRef('assets/images/legend.jpg'), isTrue);
    });

    test('resolves Supabase public media references when configured', () {
      DestinyMediaConfig.debugOverride(
        supabaseUrl: 'https://abcxyz.supabase.co',
        mediaBucket: 'destiny-media',
      );

      expect(
        DestinyMediaUrl.resolve('destiny-media/tours/42/primary.webp'),
        'https://abcxyz.supabase.co/storage/v1/object/public/destiny-media/tours/42/primary.webp',
      );
      expect(
        DestinyMediaUrl.resolve('supabase:tours/42/gallery/01.webp'),
        'https://abcxyz.supabase.co/storage/v1/object/public/destiny-media/tours/42/gallery/01.webp',
      );
      expect(
        DestinyMediaUrl.resolve(
          DestinyMediaUrl.destinyRef(
            DestinyMediaUrl.tourPrimaryObject('7', 'main.webp'),
          ),
        ),
        'https://abcxyz.supabase.co/storage/v1/object/public/destiny-media/tours/7/main.webp',
      );
    });

    test('encodes spaces in Destiny object paths once', () {
      DestinyMediaConfig.debugOverride(
        supabaseUrl: 'https://abcxyz.supabase.co',
        mediaBucket: 'destiny-media',
      );

      expect(
        DestinyMediaUrl.resolve('destiny-media/tours/1/ChatGPT Image.png'),
        'https://abcxyz.supabase.co/storage/v1/object/public/destiny-media/tours/1/ChatGPT%20Image.png',
      );
    });

    test('does not double-encode already percent-encoded Destiny paths', () {
      DestinyMediaConfig.debugOverride(
        supabaseUrl: 'https://abcxyz.supabase.co',
        mediaBucket: 'destiny-media',
      );

      const encodedRef = 'destiny-media/tours/1/ChatGPT%20Image.png';
      expect(
        DestinyMediaUrl.resolve(encodedRef),
        'https://abcxyz.supabase.co/storage/v1/object/public/destiny-media/tours/1/ChatGPT%20Image.png',
      );
    });

    test('Destiny refs without Supabase config use placeholder (not bymapara)',
        () {
      DestinyMediaConfig.debugOverride(supabaseUrl: '');
      expect(
        DestinyMediaUrl.resolve('destiny-media/tours/1/primary.webp'),
        DestinyMediaUrl.placeholder,
      );
    });

    test('absolute Supabase public URLs normalize without rewriting host', () {
      const url =
          'https://abcxyz.supabase.co/storage/v1/object/public/destiny-media/home/hero/primary.webp';
      expect(DestinyMediaUrl.resolve(url), url);
      expect(DestinyMediaUrl.isDestinyOwnedRef(url), isTrue);
    });
  });
}
