import '../../../core/network/api_client.dart';

import '../model/active_session.dart';
import '../model/bill.dart';
import '../model/payment.dart';

class BillingRepository {
  Future<List<ActiveSession>> getActiveSessions(String restaurantId) async {
    final response = await ApiClient.dio.get(
      '/restaurants/$restaurantId/sessions',
    );

    final List data = response.data['data'] ?? [];

    return data
        .map((e) => ActiveSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Bill> getBill(String sessionId) async {
    final response = await ApiClient.dio.get('/sessions/$sessionId/bill');

    return Bill.fromJson(response.data['data']);
  }

  Future<void> checkout(String sessionId) async {
    await ApiClient.dio.post('/sessions/$sessionId/checkout');
  }

  Future<void> addDiscount({
    required String sessionId,
    required String discountName,
    required String discountType,
    required int discountValue,
    String? promotionCode,
  }) async {
    await ApiClient.dio.post(
      '/sessions/$sessionId/discounts',
      data: {
        'name': discountName,
        'type': discountType,
        'value': discountValue,
        'promotionCode': promotionCode?.trim().isEmpty == true
            ? null
            : promotionCode?.trim(),
      },
    );
  }

  Future<void> deleteDiscount({
    required String sessionId,
    required String discountId,
  }) async {
    await ApiClient.dio.delete('/sessions/$sessionId/discounts/$discountId');
  }

  Future<Payment> pay({
    required String sessionId,
    required String method,
    String? transactionRef,
  }) async {
    final response = await ApiClient.dio.post(
      '/sessions/$sessionId/payments',
      data: {
        'method': method,
        'transactionRef': transactionRef?.trim().isEmpty == true
            ? null
            : transactionRef?.trim(),
      },
    );

    return Payment.fromJson(response.data['data']);
  }

  Future<void> createManualOrder({
    required String restaurantId,
    required String sessionId,
    required String name,
    required int quantity,
    required int unitPriceSatang,
    String? note,
  }) async {
    await ApiClient.dio.post(
      '/restaurants/$restaurantId'
      '/sessions/$sessionId/manual-orders',
      data: {
        'customerNote': 'เพิ่มโดยพนักงาน',
        'items': [
          {
            'name': name.trim(),
            'quantity': quantity,
            'unitPriceSatang': unitPriceSatang,
            'note': note?.trim() ?? '',
          },
        ],
      },
    );
  }

  Future<void> cancelOrderItem({
    required String restaurantId,
    required String orderItemId,
    required String reason,
  }) async {
    final path =
        '/restaurants/$restaurantId'
        '/order-items/$orderItemId/cancel';

    await ApiClient.dio.patch(path, data: {'reason': reason.trim()});
  }
}
