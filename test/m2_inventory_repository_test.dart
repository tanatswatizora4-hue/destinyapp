import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/composite_inventory_repository.dart';
import 'package:destiny/repositories/inventory_repository.dart';
import 'package:destiny/repositories/supabase_inventory_mappers.dart';
import 'package:destiny/utils/destiny_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements InventoryRepository {
  _FakeRepo({
    this.tours = const [],
    this.throwOnCall = false,
  });

  final List<Tour> tours;
  final bool throwOnCall;

  @override
  Future<List<Tour>> getTours() async {
    if (throwOnCall) throw Exception('primary down');
    return tours;
  }

  @override
  Future<List<Accommodation>> getAccommodations() async {
    if (throwOnCall) throw Exception('primary down');
    return const [];
  }

  @override
  Future<List<Vehicle>> getVehicles() async {
    if (throwOnCall) throw Exception('primary down');
    return const [];
  }

  @override
  Future<List<Award>> getAwards() async {
    if (throwOnCall) throw Exception('primary down');
    return const [];
  }
}

void main() {
  tearDown(() {
    DestinySupabaseConfig.debugClearOverrides();
  });

  group('SupabaseInventoryMappers', () {
    test('prefers owned storage_path over legacy_url and de-dupes primary', () {
      final urls = SupabaseInventoryMappers.imagePaths(
        [
          {
            'storage_path': 'destiny-media/tours/1/gallery-01.webp',
            'legacy_url': 'uploads/old.webp',
            'sort_order': 1,
          },
          {
            'storage_path': 'destiny-media/tours/1/primary.webp',
            'legacy_url': 'uploads/primary.webp',
            'sort_order': 0,
          },
        ],
        primary: 'destiny-media/tours/1/primary.webp',
      );
      expect(urls, [
        'destiny-media/tours/1/primary.webp',
        'destiny-media/tours/1/gallery-01.webp',
      ]);
    });

    test('falls back to legacy_url when storage_path empty', () {
      final urls = SupabaseInventoryMappers.imagePaths([
        {
          'storage_path': '',
          'legacy_url': 'uploads/68c.webp',
          'sort_order': 0,
        },
      ]);
      expect(urls, ['uploads/68c.webp']);
    });

    test('maps tour row with null-safe defaults', () {
      final tour = SupabaseInventoryMappers.tourFromRow({
        'legacy_id': '12',
        'title': null,
        'description': null,
        'price': null,
        'duration': null,
        'is_featured': false,
        'primary_image_path': '',
        'tour_images': const [],
        'tour_amenities': [
          {'name': 'Guide', 'included': true},
        ],
        'tour_itinerary_items': [
          {
            'date_label': 'Day 1',
            'location': 'Victoria Falls',
            'activity': 'Arrival',
            'description': '',
          },
        ],
      });
      expect(tour.id, 12);
      expect(tour.title, 'No Title');
      expect(tour.price, 0);
      expect(tour.amenities.single.name, 'Guide');
      expect(tour.itinerary.single.location, 'Victoria Falls');
    });

    test('maps stay rooms and vehicle features', () {
      final stay = SupabaseInventoryMappers.stayFromRow({
        'legacy_id': 3,
        'name': 'Lodge',
        'type': 'Hotel',
        'description': '',
        'address': '',
        'city': 'Harare',
        'country': 'Zimbabwe',
        'is_featured': true,
        'primary_image_path': 'destiny-media/stays/3/primary.webp',
        'stay_images': const [],
        'stay_amenities': const [],
        'stay_rooms': [
          {'name': 'Deluxe', 'price': '150.00', 'capacity': 2},
        ],
      });
      expect(stay.isFeatured, isTrue);
      expect(stay.roomTypes.single.price, 150);
      expect(stay.imageUrls.first, 'destiny-media/stays/3/primary.webp');

      final vehicle = SupabaseInventoryMappers.vehicleFromRow({
        'legacy_id': 1,
        'make': 'Toyota',
        'model': 'Hilux 4x4',
        'year': '2023',
        'type': 'Truck',
        'price_per_day': '120.00',
        'address': '',
        'city': 'Harare',
        'country': 'Zimbabwe',
        'is_featured': true,
        'primary_image_path': null,
        'vehicle_images': const [],
        'vehicle_features': [
          {'name': 'Air Conditioning', 'included': true},
        ],
      });
      expect(vehicle.pricePerDay, 120);
      expect(vehicle.amenities.single.name, 'Air Conditioning');
    });
  });

  group('CompositeInventoryRepository', () {
    final sampleTour = Tour(
      id: 1,
      title: 'Legacy Tour',
      description: '',
      price: 1,
      duration: '1d',
      isFeatured: false,
      imageUrls: const [],
      amenities: const [],
      itinerary: const [],
    );

    test('uses legacy when Supabase not preferred', () async {
      DestinySupabaseConfig.debugOverride(preferSupabase: false);
      final repo = CompositeInventoryRepository(
        primary: _FakeRepo(throwOnCall: true),
        fallback: _FakeRepo(tours: [sampleTour]),
      );
      final tours = await repo.getTours();
      expect(tours.single.title, 'Legacy Tour');
    });

    test('uses primary when non-empty', () async {
      DestinySupabaseConfig.debugOverride(
        anonKey: 'test-anon',
        preferSupabase: true,
      );
      final primaryTour = Tour(
        id: 2,
        title: 'Supabase Tour',
        description: '',
        price: 2,
        duration: '2d',
        isFeatured: true,
        imageUrls: const ['destiny-media/tours/2/primary.webp'],
        amenities: const [],
        itinerary: const [],
      );
      final repo = CompositeInventoryRepository(
        primary: _FakeRepo(tours: [primaryTour]),
        fallback: _FakeRepo(tours: [sampleTour]),
      );
      final tours = await repo.getTours();
      expect(tours, hasLength(1));
      expect(tours.single.title, 'Supabase Tour');
    });

    test('falls back when primary empty or errors', () async {
      DestinySupabaseConfig.debugOverride(
        anonKey: 'test-anon',
        preferSupabase: true,
      );
      final emptyPrimary = CompositeInventoryRepository(
        primary: _FakeRepo(),
        fallback: _FakeRepo(tours: [sampleTour]),
      );
      expect((await emptyPrimary.getTours()).single.id, 1);

      final errorPrimary = CompositeInventoryRepository(
        primary: _FakeRepo(throwOnCall: true),
        fallback: _FakeRepo(tours: [sampleTour]),
      );
      expect((await errorPrimary.getTours()).single.id, 1);
    });
  });

  test('owned inventory media paths resolve via DestinyMediaUrl', () {
    expect(
      DestinyMediaUrl.resolve('destiny-media/tours/1/primary.webp'),
      contains('/storage/v1/object/public/destiny-media/tours/1/primary.webp'),
    );
  });
}
