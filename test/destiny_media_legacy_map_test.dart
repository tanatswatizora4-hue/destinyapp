import 'package:destiny/utils/destiny_media_legacy_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DestinyMediaLegacyMap.debugClear);

  test('legacyUploadFor returns mapped uploads path', () {
    DestinyMediaLegacyMap.debugReplace({
      'destiny-media/tours/39/primary.jpg':
          'uploads/6a4f9a97e9470-example.jpg',
    });
    expect(
      DestinyMediaLegacyMap.legacyUploadFor(
        'destiny-media/tours/39/primary.jpg',
      ),
      'uploads/6a4f9a97e9470-example.jpg',
    );
    expect(
      DestinyMediaLegacyMap.legacyUploadFor('destiny-media/missing.jpg'),
      isNull,
    );
  });

  test('load from bundled asset map', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await DestinyMediaLegacyMap.load();
    expect(DestinyMediaLegacyMap.isLoaded, isTrue);
    expect(
      DestinyMediaLegacyMap.legacyUploadFor(
        'destiny-media/tours/39/primary.jpg',
      ),
      isNotNull,
    );
  });
}
