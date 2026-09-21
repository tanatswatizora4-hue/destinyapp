import 'package:destiny/models/payment_intent.dart';
import 'package:destiny/services/payment_api_client.dart';

class PaymentCommerceRepository {
  PaymentCommerceRepository({PaymentApiClient? client})
      : _client = client ?? PaymentApiClient();

  final PaymentApiClient _client;

  Future<PaymentIntent> createIntent({required String bookingId}) async {
    final res = await _client.postAction('create_payment_intent', {
      'booking_id': bookingId,
    });
    return PaymentIntent.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<PaymentIntent> getIntent(String paymentIntentId) async {
    final res = await _client.postAction('get_payment_intent', {
      'payment_intent_id': paymentIntentId,
    });
    return PaymentIntent.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<List<PaymentIntent>> listMine() async {
    final res = await _client.postAction('list_my_payments');
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) => PaymentIntent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<PaymentIntent> verify(String paymentIntentId) async {
    final res = await _client.postAction('verify_payment', {
      'payment_intent_id': paymentIntentId,
    });
    return PaymentIntent.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<PaymentIntent> mockSimulate({
    required String paymentIntentId,
    required String result,
  }) async {
    final res = await _client.postAction('mock_simulate_result', {
      'payment_intent_id': paymentIntentId,
      'mock_result': result,
    });
    return PaymentIntent.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<PaymentRefund> requestRefund({
    required String paymentIntentId,
    String reason = '',
  }) async {
    final res = await _client.postAction('request_refund', {
      'payment_intent_id': paymentIntentId,
      'reason': reason,
    });
    return PaymentRefund.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<List<PaymentIntent>> staffListPayments() async {
    final res = await _client.postAction('staff_list_payments');
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) => PaymentIntent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<StaffPaymentDetail> staffGetPayment(String paymentIntentId) async {
    final res = await _client.postAction('staff_get_payment', {
      'payment_intent_id': paymentIntentId,
    });
    return StaffPaymentDetail.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<PaymentRefund> staffRequestRefund({
    required String paymentIntentId,
    String reason = '',
  }) async {
    final res = await _client.postAction('staff_request_refund', {
      'payment_intent_id': paymentIntentId,
      'reason': reason,
    });
    return PaymentRefund.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<PaymentRefund> staffProcessRefund(String refundId) async {
    final res = await _client.postAction('staff_process_refund', {
      'refund_id': refundId,
    });
    return PaymentRefund.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<PaymentIntent> staffReconcile({
    required String paymentIntentId,
    required String settlementStatus,
    String note = '',
  }) async {
    final res = await _client.postAction('staff_reconcile', {
      'payment_intent_id': paymentIntentId,
      'settlement_status': settlementStatus,
      'note': note,
    });
    return PaymentIntent.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }
}
