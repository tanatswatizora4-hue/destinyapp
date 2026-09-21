import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/services/staff_api_client.dart';

class StaffUser {
  final String id;
  final String userId;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;

  StaffUser({
    required this.id,
    this.userId = '',
    this.firebaseUid = '',
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'consultant',
      isActive: json['is_active'] == true,
    );
  }
}

class StaffCommerceRepository {
  StaffCommerceRepository({StaffApiClient? client})
      : _client = client ?? StaffApiClient();

  final StaffApiClient _client;

  Future<StaffUser> me() async {
    final res = await _client.postAction('staff_me');
    return StaffUser.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<List<CustomerBooking>> listBookings({String? status}) async {
    final res = await _client.postAction('list_bookings', {
      if (status != null) 'status': status,
    });
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) =>
            CustomerBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<CustomerBooking> getBooking(String bookingId) async {
    final res = await _client.postAction('get_booking', {
      'booking_id': bookingId,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerBooking> quoteBooking({
    required String bookingId,
    required double quotedTotal,
    String currency = 'USD',
    DateTime? quoteExpiresAt,
    String customerQuoteNote = '',
    String internalNote = '',
  }) async {
    final res = await _client.postAction('quote_booking', {
      'booking_id': bookingId,
      'quoted_total': quotedTotal,
      'currency': currency,
      if (quoteExpiresAt != null)
        'quote_expires_at': quoteExpiresAt.toIso8601String(),
      'customer_quote_note': customerQuoteNote,
      'internal_note': internalNote,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerBooking> transitionBooking({
    required String bookingId,
    required String toStatus,
    String reason = '',
  }) async {
    final res = await _client.postAction('transition_booking', {
      'booking_id': bookingId,
      'to_status': toStatus,
      if (reason.isNotEmpty) 'reason': reason,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerBooking> addBookingNote({
    required String bookingId,
    required String note,
    bool customerFacing = false,
  }) async {
    final res = await _client.postAction('add_booking_note', {
      'booking_id': bookingId,
      'note': note,
      'customer_facing': customerFacing,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<List<CustomerEnquiry>> listEnquiries({String? status}) async {
    final res = await _client.postAction('list_enquiries', {
      if (status != null) 'status': status,
    });
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) =>
            CustomerEnquiry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<CustomerEnquiry> updateEnquiry({
    required String enquiryId,
    String? toStatus,
    String? customerResponseNote,
    String? internalNote,
  }) async {
    final res = await _client.postAction('update_enquiry', {
      'enquiry_id': enquiryId,
      if (toStatus != null) 'to_status': toStatus,
      if (customerResponseNote != null)
        'customer_response_note': customerResponseNote,
      if (internalNote != null) 'internal_note': internalNote,
    });
    return CustomerEnquiry.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<Map<String, dynamic>> convertEnquiry(String enquiryId) async {
    final res = await _client.postAction('convert_enquiry', {
      'enquiry_id': enquiryId,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<Map<String, dynamic>> opsDashboard() async {
    final res = await _client.postAction('ops_dashboard');
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> workQueue({
    String? status,
    String? assigned,
  }) async {
    final res = await _client.postAction('work_queue', {
      if (status != null) 'status': status,
      if (assigned != null) 'assigned': assigned,
    });
    final data = Map<String, dynamic>.from(res['data'] as Map);
    final items = data['items'] as List? ?? const [];
    return items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchCustomers({String query = ''}) async {
    final res = await _client.postAction('search_customers', {
      'query': query,
      'page': 1,
      'page_size': 40,
    });
    final data = Map<String, dynamic>.from(res['data'] as Map);
    final items = data['items'] as List? ?? const [];
    return items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getCustomerWorkspace(String customerUserId) async {
    final res = await _client.postAction('get_customer_workspace', {
      'customer_user_id': customerUserId,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<Map<String, dynamic>> addCustomerNote({
    required String customerUserId,
    required String body,
  }) async {
    final res = await _client.postAction('add_customer_note', {
      'customer_user_id': customerUserId,
      'body': body,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<Map<String, dynamic>> assignEnquiry(String enquiryId) async {
    final res = await _client.postAction('assign_enquiry', {
      'enquiry_id': enquiryId,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<Map<String, dynamic>> setEnquiryFollowUp({
    required String enquiryId,
    String? nextFollowUpAt,
    String followUpNote = '',
    bool complete = false,
  }) async {
    final res = await _client.postAction('set_enquiry_follow_up', {
      'enquiry_id': enquiryId,
      if (nextFollowUpAt != null) 'next_follow_up_at': nextFollowUpAt,
      'follow_up_note': followUpNote,
      'complete': complete,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }
}
