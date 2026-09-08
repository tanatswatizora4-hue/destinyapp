import 'package:destiny/config/destiny_media_config.dart';
import 'package:destiny/utils/destiny_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DestinyMediaConfig.debugClearOverrides);

  test('production media resolver maps Destiny refs to public Storage URLs', () {
    expect(
      DestinyMediaUrl.resolve('destiny-media/home/hero/main.webp'),
      'https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/home/hero/main.webp',
    );
    expect(
      DestinyMediaUrl.resolve('uploads/example.jpg'),
      'https://bymapara.com/uploads/example.jpg',
    );
  });
}
