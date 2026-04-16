// File: tour_package.dart
// Root: destiny/lib/models/
class TourPackage {
  final String title;
  final String description;
  final String price;
  final String imageUrl;
  final List<String> itinerary;

  TourPackage({
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.itinerary,
  });
}

// Mock Data based on the provided company profile and files
final List<TourPackage> tourPackages = [
  TourPackage(
    title: 'Dubai Glamour Tour',
    description: 'Experience the exhilarating glamour of Dubai with our exclusive package.',
    price: '\$1,500',
    imageUrl: 'assets/images/dubai.jpg',
    itinerary: [
      'Arrival and Hotel Check-in',
      'Dubai City Tour & Burj Khalifa',
      'Desert Safari with BBQ Dinner',
      'Dhow Cruise Dinner at the Marina',
      'Shopping at Dubai Mall & Departure'
    ],
  ),
  TourPackage(
    title: 'Mana Pools Safari Adventure',
    description: 'Explore the pristine and untamed wilderness of Mana Pools National Park.',
    price: '\$2,000',
    imageUrl: 'assets/images/mana_pools.jpg',
    itinerary: [
      'Transfer to Mana Pools',
      'Full Day Game Drive',
      'Canoeing on the Zambezi River',
      'Guided Bush Walk',
      'Departure'
    ],
  ),
  TourPackage(
    title: 'Abu Dhabi Grand Prix',
    description: 'Experience the thrill of the Formula 1 Grand Prix in Abu Dhabi.',
    price: '\$3,500',
    imageUrl: 'assets/images/grand_prix.jpg',
    itinerary: [
      'Flight to Abu Dhabi',
      'Hotel Check-in & City Tour',
      'Race Day Experience',
      'Ferrari World Visit',
      'Departure'
    ],
  ),
  TourPackage(
    title: 'Durban Beach Holiday',
    description: 'Relax and unwind on the beautiful golden beaches of Durban.',
    price: '\$1,200',
    imageUrl: 'assets/images/durban.jpg',
    itinerary: [
      'Arrival in Durban',
      'uShaka Marine World',
      'Moses Mabhida Stadium SkyCar',
      'Valley of a Thousand Hills Tour',
      'Departure'
    ],
  ),
];

