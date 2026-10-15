class SalesSummary {
  final String period;
  final DateTime? startAt;
  final DateTime? endAt;

  final int totalSalesSatang;
  final int billCount;
  final int averageBillSatang;
  final int totalItems;

  final List<SalesPaymentMethod> paymentMethods;
  final List<SalesTopItem> topItems;

  const SalesSummary({
    required this.period,
    required this.startAt,
    required this.endAt,
    required this.totalSalesSatang,
    required this.billCount,
    required this.averageBillSatang,
    required this.totalItems,
    required this.paymentMethods,
    required this.topItems,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    final rawPaymentMethods = json['paymentMethods'] as List? ?? [];

    final rawTopItems = json['topItems'] as List? ?? [];

    return SalesSummary(
      period: json['period'] ?? '',
      startAt: DateTime.tryParse(json['startAt'] ?? ''),
      endAt: DateTime.tryParse(json['endAt'] ?? ''),
      totalSalesSatang: json['totalSalesSatang'] ?? 0,
      billCount: json['billCount'] ?? 0,
      averageBillSatang: json['averageBillSatang'] ?? 0,
      totalItems: json['totalItems'] ?? 0,
      paymentMethods: rawPaymentMethods
          .map((e) => SalesPaymentMethod.fromJson(e as Map<String, dynamic>))
          .toList(),
      topItems: rawTopItems
          .map((e) => SalesTopItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SalesPaymentMethod {
  final String method;
  final int amountSatang;
  final int billCount;

  const SalesPaymentMethod({
    required this.method,
    required this.amountSatang,
    required this.billCount,
  });

  factory SalesPaymentMethod.fromJson(Map<String, dynamic> json) {
    return SalesPaymentMethod(
      method: json['method'] ?? '',
      amountSatang: json['amountSatang'] ?? 0,
      billCount: json['billCount'] ?? 0,
    );
  }
}

class SalesTopItem {
  final String name;
  final int quantity;
  final int salesSatang;

  const SalesTopItem({
    required this.name,
    required this.quantity,
    required this.salesSatang,
  });

  factory SalesTopItem.fromJson(Map<String, dynamic> json) {
    return SalesTopItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      salesSatang: json['salesSatang'] ?? 0,
    );
  }
}
