import '../../../core/network/api_client.dart';

import '../model/sales_summary.dart';

class SalesSummaryRepository {
  Future<SalesSummary> getSummary({
    required String restaurantId,
    required String period,
    required DateTime selectedDate,
  }) async {
    final queryParameters = <String, dynamic>{'period': period};

    switch (period) {
      case 'DAILY':
        queryParameters['date'] = _formatDate(selectedDate);
        break;

      case 'MONTHLY':
        queryParameters['month'] = _formatMonth(selectedDate);
        break;

      case 'YEARLY':
        queryParameters['year'] = selectedDate.year.toString();
        break;
    }

    final response = await ApiClient.dio.get(
      '/restaurants/$restaurantId/sales-summary',
      queryParameters: queryParameters,
    );

    return SalesSummary.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _formatMonth(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');

    return '${date.year}-$month';
  }
}
