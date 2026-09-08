import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/utils/destiny_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M1 stay/vehicle helpers', () {
    test('Accommodation.fromPrice uses lowest room nightly rate', () {
      final stay = Accommodation(
        id: 1,
        name: 'Test Lodge',
        type: 'Lodge',
        description: '',
        address: '',
        city: 'Victoria Falls',
        country: 'Zimbabwe',
        isFeatured: true,
        imageUrls: const ['uploads/example.jpg'],
        amenities: const [],
        roomTypes: [
          RoomType(name: 'Standard', price: 180, capacity: 2),
          RoomType(name: 'Suite', price: 320, capacity: 3),
        ],
      );

      expect(stay.fromPrice, 180);
      expect(stay.locationLabel, 'Victoria Falls, Zimbabwe');
      expect(
        stay.mainImageUrl,
        DestinyMediaUrl.resolve('uploads/example.jpg'),
      );
    });

    test('Vehicle.displayName and locationLabel', () {
      final vehicle = Vehicle(
        id: 2,
        make: 'Toyota',
        model: 'Hilux',
        year: 2022,
        type: '4x4',
        pricePerDay: 95,
        address: 'Airport',
        city: 'Harare',
        country: 'Zimbabwe',
        isFeatured: false,
        imageUrls: const [],
        amenities: [Amenity(name: 'AC', included: true)],
      );

      expect(vehicle.displayName, 'Toyota Hilux');
      expect(vehicle.locationLabel, 'Harare, Zimbabwe');
      expect(vehicle.mainImageUrl, DestinyMediaUrl.placeholder);
    });
  });
}
