import 'package:destiny/config/destiny_media_config.dart';
import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/inventory_repository.dart';
import 'package:destiny/repositories/supabase_inventory_mappers.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/utils/destiny_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingRepo implements InventoryRepository {
  @override
  Future<List<Tour>> getTours() async => throw Exception('supabase down');

  @override
  Future<List<Accommodation>> getAccommodations() async =>
      throw Exception('supabase down');

  @override
  Future<List<Vehicle>> getVehicles() async =>
      throw Exception('supabase down');

  @override
  Future<List<Award>> getAwards() async => throw Exception('supabase down');
}

class _OkRepo implements InventoryRepository {
  @override
  Future<List<Tour>> getTours() async => [
        Tour(
          id: 14,
          title: 'Kadoma Music Festival 2025',
          description: 'Live',
          price: 20,
          duration: '1 Night',
          isFeatured: true,
          imageUrls: const [
            'destiny-media/tours/14/primary.jpg',
            'destiny-media/tours/14/gallery-01.webp',
          ],
          amenities: const [],
          itinerary: const [],
        ),
      ];

  @override
  Future<List<Accommodation>> getAccommodations() async => const [];

  @override
  Future<List<Vehicle>> getVehicles() async => [
        Vehicle(
          id: 2,
          make: 'Toyota',
          model: 'Corolla',
          year: 2022,
          type: 'Sedan',
          pricePerDay: 60,
          address: '',
          city: 'Harare',
          country: 'Zimbabwe',
          isFeatured: true,
          imageUrls: const ['destiny-media/vehicles/2/primary.webp'],
          amenities: const [],
        ),
        Vehicle(
          id: 3,
          make: 'Mercedes-Benz',
          model: 'Sprinter',
          year: 2021,
          type: 'Shuttle',
          pricePerDay: 150,
          address: '',
          city: 'Harare',
          country: 'Zimbabwe',
          isFeatured: true,
          imageUrls: const ['destiny-media/vehicles/3/primary.webp'],
          amenities: const [],
        ),
      ];

  @override
  Future<List<Award>> getAwards() async => const [];
}

void main() {
  tearDown(() {
    DestinySupabaseConfig.debugClearOverrides();
    DestinyMediaConfig.debugClearOverrides();
    ApiService.inventoryRepository = null;
  });

  group('DestinySupabaseConfig defaults (M2 cutover)', () {
    test('is ready without dart-defines', () {
      expect(
        DestinySupabaseConfig.url,
        DestinySupabaseConfig.productionUrl,
      );
      expect(
        DestinySupabaseConfig.anonKey,
        DestinySupabaseConfig.productionPublishableKey,
      );
      expect(DestinySupabaseConfig.isConfigured, isTrue);
      expect(DestinySupabaseConfig.preferSupabaseInventory, isTrue);
      expect(
        DestinySupabaseConfig.productionPublishableKey,
        startsWith('sb_publishable_'),
      );
      expect(
        DestinySupabaseConfig.productionPublishableKey.toLowerCase(),
        isNot(contains('service_role')),
      );
    });
  });

  group('DestinyMediaConfig inventory live default', () {
    test('inventory media resolves to destiny-media by default', () {
      expect(DestinyMediaConfig.inventoryMediaLive, isTrue);
      expect(DestinyMediaConfig.preferLegacyInventoryMedia, isFalse);
      expect(
        DestinyMediaUrl.resolve('destiny-media/tours/14/gallery-01.webp'),
        'https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/'
        'destiny-media/tours/14/gallery-01.webp',
      );
      expect(
        DestinyMediaUrl.resolve('destiny-media/vehicles/2/primary.webp'),
        contains(
          '/storage/v1/object/public/destiny-media/vehicles/2/primary.webp',
        ),
      );
      expect(
        DestinyMediaUrl.resolve('destiny-media/vehicles/3/primary.webp'),
        contains(
          '/storage/v1/object/public/destiny-media/vehicles/3/primary.webp',
        ),
      );
    });
  });

  group('ApiService inventory cutover', () {
    test('throws when repository is unset (no bymapara inventory fallback)',
        () async {
      ApiService.inventoryRepository = null;
      final api = ApiService();
      await expectLater(api.getTours(), throwsStateError);
      await expectLater(api.getAccommodations(), throwsStateError);
      await expectLater(api.getVehicles(), throwsStateError);
      await expectLater(api.getAwards(), throwsStateError);
    });

    test('surfaces repository failures without legacy inventory fallback',
        () async {
      ApiService.inventoryRepository = _ThrowingRepo();
      final api = ApiService();
      await expectLater(api.getTours(), throwsA(isA<Exception>()));
      await expectLater(api.getAccommodations(), throwsA(isA<Exception>()));
      await expectLater(api.getVehicles(), throwsA(isA<Exception>()));
      await expectLater(api.getAwards(), throwsA(isA<Exception>()));
    });

    test('reads through wired Supabase-primary repository', () async {
      ApiService.inventoryRepository = _OkRepo();
      final api = ApiService();
      final tours = await api.getTours();
      final vehicles = await api.getVehicles();
      expect(tours.single.id, 14);
      expect(
        tours.single.imageUrls,
        contains('destiny-media/tours/14/gallery-01.webp'),
      );
      expect(vehicles, hasLength(2));
      expect(
        vehicles.map((v) => v.imageUrls.first),
        everyElement(startsWith('destiny-media/vehicles/')),
      );
    });
  });

  group('Representative Supabase row parsing', () {
    test('parses tour / stay / vehicle with owned storage_path', () {
      final tour = SupabaseInventoryMappers.tourFromRow({
        'legacy_id': 14,
        'title': 'Kadoma Music Festival 2025',
        'description': 'Festival',
        'price': 20,
        'duration': '1 Night',
        'is_featured': true,
        'primary_image_path': 'destiny-media/tours/14/primary.jpg',
        'tour_images': [
          {
            'storage_path': 'destiny-media/tours/14/gallery-01.webp',
            'legacy_url': 'uploads/68e49c71927a8-kadoma2.gif',
            'sort_order': 1,
          },
        ],
        'tour_amenities': const [],
        'tour_itinerary_items': const [],
      });
      expect(tour.id, 14);
      expect(tour.imageUrls, [
        'destiny-media/tours/14/primary.jpg',
        'destiny-media/tours/14/gallery-01.webp',
      ]);

      final stay = SupabaseInventoryMappers.stayFromRow({
        'legacy_id': 1,
        'name': 'Sample Stay',
        'type': 'Lodge',
        'description': '',
        'address': '',
        'city': 'Harare',
        'country': 'Zimbabwe',
        'is_featured': false,
        'primary_image_path': 'destiny-media/stays/1/primary.webp',
        'stay_images': const [],
        'stay_amenities': const [],
        'stay_rooms': const [],
      });
      expect(stay.imageUrls.first, 'destiny-media/stays/1/primary.webp');

      final vehicle = SupabaseInventoryMappers.vehicleFromRow({
        'legacy_id': 2,
        'make': 'Toyota',
        'model': 'Corolla',
        'year': 2022,
        'type': 'Sedan',
        'price_per_day': 60,
        'address': '',
        'city': 'Harare',
        'country': 'Zimbabwe',
        'is_featured': true,
        'primary_image_path': 'destiny-media/vehicles/2/primary.webp',
        'vehicle_images': [
          {
            'storage_path': 'destiny-media/vehicles/2/primary.webp',
            'sort_order': 0,
          },
        ],
        'vehicle_features': const [],
      });
      expect(
        vehicle.imageUrls.first,
        'destiny-media/vehicles/2/primary.webp',
      );
    });
  });
}
