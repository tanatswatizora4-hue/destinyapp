import 'dart:convert';
import 'dart:io';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/booking.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/user.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/inventory_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String _baseUrl = 'https://bymapara.com';

  /// Optional inventory backend (Supabase composite). When null, uses legacy PHP.
  static InventoryRepository? inventoryRepository;

  // --- BOOKING METHODS ---
  /// Creates a general booking (e.g., for a tour, accommodation, or vehicle).
  Future<void> createBooking({
    required int sqlId,
    required int itemId,
    required String itemType,
    required int numTravelers,
    required double totalPrice,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/destiny_api.php?action=create_booking'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({
        'user_id': sqlId,
        'item_id': itemId,
        'item_type': itemType,
        'num_travelers': numTravelers,
        'total_price': totalPrice,
        'start_date': startDate?.toIso8601String().substring(0, 10),
        'end_date': endDate?.toIso8601String().substring(0, 10),
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response);
    }
    final data = json.decode(response.body);
    if (data['status'] != 'success') {
      throw Exception('API Error: ${data['message']}');
    }
  }

  /// Creates a flight booking request from the user's form.
  Future<void> createFlightBooking({
    required int userId,
    required String origin,
    required String destination,
    List<String> midPlaces = const [],
    required int numTravelers,
    required bool isEnquiry,
    required bool needsAccommodation,
    required bool needsInterchangeAssistance,
    required bool needsTaxi,
    DateTime? departureDate,
    DateTime? returnDate,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/destiny_api.php?action=create_flight_booking'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({
        'user_id': userId,
        'origin': origin,
        'destination': destination,
        'mid_places': midPlaces.join(', '),
        'num_travelers': numTravelers,
        'is_enquiry': isEnquiry,
        'needs_accommodation': needsAccommodation,
        'needs_interchange_assistance': needsInterchangeAssistance,
        'needs_taxi': needsTaxi,
        'departure_date': departureDate?.toIso8601String().substring(0, 10),
        'return_date': returnDate?.toIso8601String().substring(0, 10),
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response);
    }
    final data = json.decode(response.body);
    if (data['status'] != 'success') {
      throw Exception('API Error: ${data['message']}');
    }
  }

  /// Retrieves a list of bookings for a specific user by their SQL ID.
  Future<List<Booking>> getUserBookings(int sqlId) async {
    final response = await http.get(Uri.parse('$_baseUrl/destiny_api.php?action=get_user_bookings&user_id=$sqlId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        List<dynamic> bookingData = data['data'];
        return bookingData.map((json) => Booking.fromJson(json)).toList();
      }
    }
    throw _handleError(response);
  }

  /// Deletes a specific booking.
  Future<void> deleteBooking(int bookingId) async {
    final response = await http.get(Uri.parse('$_baseUrl/destiny_api.php?action=delete_booking&id=$bookingId'));
    if (response.statusCode != 200) {
      throw _handleError(response);
    }
    final data = json.decode(response.body);
    if (data['status'] != 'success') {
      throw Exception('API Error: ${data['message']}');
    }
  }

  // --- USER SYNC & UPDATE ---
  /// Syncs a user's Firebase UID and email with the SQL backend.
  Future<Map<String, dynamic>> syncUserWithSql(String firebaseUid, String fullName, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/destiny_api.php?action=sync_firebase_user'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'firebase_uid': firebaseUid,
          'full_name': fullName,
          'email': email,
        }),
      );
      final responseData = json.decode(response.body);
      if (response.statusCode != 200 || responseData['status'] != 'success') {
        throw Exception('API Error: ${responseData['message']}');
      } else {
        return responseData['data'];
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Updates a user's profile with optional file uploads.
  Future<void> updateUserInSql({
    required int sqlId,
    required String fullName,
    required String email,
    required String phone,
    File? facePhotoFile,
    File? passportPhotoFile,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/destiny_api.php?action=update_user_profile'),
    );
    request.fields['id'] = sqlId.toString();
    request.fields['full_name'] = fullName;
    request.fields['email'] = email;
    request.fields['phone'] = phone;

    if (facePhotoFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'face_photo',
        facePhotoFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    if (passportPhotoFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'passport_photo',
        passportPhotoFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw _handleError(response);
    }
    final data = json.decode(response.body);
    if (data['status'] != 'success') {
      throw Exception('API Error: ${data['message']}');
    }
  }

  /// Fetches a single user's profile by their SQL ID.
  Future<AppUser> getUserProfile(int sqlId) async {
    final response = await http.get(Uri.parse('$_baseUrl/destiny_api.php?action=get_user_profile&id=$sqlId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        return AppUser(
          uid: data['data']['firebase_uid'],
          email: data['data']['email'],
          displayName: data['data']['full_name'],
          phone: data['data']['phone'],
          sqlId: data['data']['id'],
          facePhotoUrl: data['data']['face_photo_url'],
          passportPhotoUrl: data['data']['passport_photo_url'],
        );
      }
    }
    throw _handleError(response);
  }

  // --- FLIGHTS & DOCUMENTS ---
  /// Retrieves a list of flight booking requests for a specific user.
  Future<List<Map<String, dynamic>>> getMyFlightBookings(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/destiny_api.php?action=get_my_flight_bookings&user_id=$userId'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw _handleError(response);
  }

  /// New method to delete a flight booking
  Future<void> deleteFlightBooking(int bookingId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/destiny_api.php?action=delete_flight_booking&id=$bookingId'),
    );
    if (response.statusCode != 200) {
      throw _handleError(response);
    }
    final data = json.decode(response.body);
    if (data['status'] != 'success') {
      throw Exception('API Error: ${data['message']}');
    }
  }

  /// Retrieves a list of travel documents for a specific user.
  Future<List<Map<String, dynamic>>> getTravelDocuments(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/destiny_api.php?action=get_travel_documents&user_id=$userId'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw _handleError(response);
  }

  // --- DATA FETCHING METHODS ---
  /// A private helper function to handle API errors consistently.
  Exception _handleError(http.Response response) {
    if (response.statusCode != 200) {
      return Exception('Failed to connect to the server. Status code: ${response.statusCode}');
    }
    try {
      final data = json.decode(response.body);
      if (data['status'] != 'success') {
        return Exception('API Error: ${data['message']}');
      }
    } catch (e) {
      return Exception('Failed to parse server response. The server may be down or misconfigured.');
    }
    return Exception('An unknown error occurred.');
  }

  /// Fetches tours (Supabase inventory when wired; else legacy PHP).
  Future<List<Tour>> getTours() async {
    final repo = inventoryRepository;
    if (repo != null) return repo.getTours();
    return fetchToursLegacy();
  }

  /// Legacy bymapara tours endpoint.
  Future<List<Tour>> fetchToursLegacy() async {
    final response = await http.get(Uri.parse('$_baseUrl/destiny_api.php?action=get_tours'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        List<dynamic> tourData = data['data'];
        return tourData.map((json) => Tour.fromJson(json)).toList();
      }
    }
    throw _handleError(response);
  }

  /// Fetches accommodations (Supabase inventory when wired; else legacy PHP).
  Future<List<Accommodation>> getAccommodations() async {
    final repo = inventoryRepository;
    if (repo != null) return repo.getAccommodations();
    return fetchAccommodationsLegacy();
  }

  Future<List<Accommodation>> fetchAccommodationsLegacy() async {
    final response = await http.get(Uri.parse('$_baseUrl/destiny_api.php?action=get_accommodations'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        List<dynamic> accommData = data['data'];
        return accommData.map((json) => Accommodation.fromJson(json)).toList();
      }
    }
    throw _handleError(response);
  }

  /// Fetches vehicles (Supabase inventory when wired; else legacy PHP).
  Future<List<Vehicle>> getVehicles() async {
    final repo = inventoryRepository;
    if (repo != null) return repo.getVehicles();
    return fetchVehiclesLegacy();
  }

  Future<List<Vehicle>> fetchVehiclesLegacy() async {
    final response = await http.get(Uri.parse('$_baseUrl/destiny_api.php?action=get_vehicles'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        List<dynamic> vehicleData = data['data'];
        return vehicleData.map((json) => Vehicle.fromJson(json)).toList();
      }
    }
    throw _handleError(response);
  }

  /// Fetches awards (Supabase inventory when wired; else legacy PHP).
  Future<List<Award>> getAwards() async {
    final repo = inventoryRepository;
    if (repo != null) return repo.getAwards();
    return fetchAwardsLegacy();
  }

  Future<List<Award>> fetchAwardsLegacy() async {
    final response = await http.get(Uri.parse('$_baseUrl/destiny_api.php?action=get_awards'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        List<dynamic> awardData = data['data'];
        return awardData.map((json) => Award.fromJson(json)).toList();
      }
    }
    throw _handleError(response);
  }
}
