import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sales_summary_repository.dart';
import '../model/sales_summary.dart';

final salesSummaryRepositoryProvider = Provider<SalesSummaryRepository>(
  (ref) => SalesSummaryRepository(),
);

class SalesSummaryQuery {
  final String restaurantId;
  final String period;
  final DateTime selectedDate;

  const SalesSummaryQuery({
    required this.restaurantId,
    required this.period,
    required this.selectedDate,
  });

  @override
  bool operator ==(Object other) {
    return other is SalesSummaryQuery &&
        other.restaurantId == restaurantId &&
        other.period == period &&
        other.selectedDate.year == selectedDate.year &&
        other.selectedDate.month == selectedDate.month &&
        other.selectedDate.day == selectedDate.day;
  }

  @override
  int get hashCode => Object.hash(
    restaurantId,
    period,
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );
}

final salesSummaryProvider = FutureProvider.autoDispose
    .family<SalesSummary, SalesSummaryQuery>((ref, query) {
      return ref
          .read(salesSummaryRepositoryProvider)
          .getSummary(
            restaurantId: query.restaurantId,
            period: query.period,
            selectedDate: query.selectedDate,
          );
    });
