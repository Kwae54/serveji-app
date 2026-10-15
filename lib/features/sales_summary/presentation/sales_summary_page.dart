import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/sales_summary.dart';
import 'sales_summary_provider.dart';

class SalesSummaryPage extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const SalesSummaryPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  ConsumerState<SalesSummaryPage> createState() => _SalesSummaryPageState();
}

class _SalesSummaryPageState extends ConsumerState<SalesSummaryPage> {
  String period = 'DAILY';

  DateTime selectedDate = DateTime.now();

  SalesSummaryQuery get query => SalesSummaryQuery(
    restaurantId: widget.restaurantId,
    period: period,
    selectedDate: selectedDate,
  );

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(salesSummaryProvider(query));

    final bottomSafeArea = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'สรุปยอดขาย - '
          '${widget.restaurantName}',
        ),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: () {
              ref.invalidate(salesSummaryProvider(query));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),

          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomSafeArea + 32),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'DAILY',
                    label: Text('รายวัน'),
                    icon: Icon(Icons.today),
                  ),
                  ButtonSegment(
                    value: 'MONTHLY',
                    label: Text('รายเดือน'),
                    icon: Icon(Icons.calendar_month),
                  ),
                  ButtonSegment(
                    value: 'YEARLY',
                    label: Text('รายปี'),
                    icon: Icon(Icons.calendar_today),
                  ),
                ],
                selected: {period},
                onSelectionChanged: (values) {
                  setState(() {
                    period = values.first;

                    selectedDate = _normalizeDate(selectedDate);
                  });
                },
              ),

              const SizedBox(height: 24),

              _PeriodSelector(
                label: _periodLabel(),
                onPrevious: () {
                  _movePeriod(-1);
                },
                onNext: () {
                  _movePeriod(1);
                },
                onSelect: _selectDate,
              ),

              const SizedBox(height: 24),

              summary.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),

                error: (error, stackTrace) => _ErrorView(
                  message: _errorMessage(error),
                  onRetry: () {
                    ref.invalidate(salesSummaryProvider(query));
                  },
                ),

                data: (data) => _buildSummary(data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(SalesSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final cardWidth = width >= 900
                ? (width - 48) / 4
                : width >= 600
                ? (width - 16) / 2
                : width;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _SummaryCard(
                  width: cardWidth,
                  title: 'ยอดขายรวม',
                  value: _formatMoney(summary.totalSalesSatang),
                  icon: Icons.attach_money,
                ),
                _SummaryCard(
                  width: cardWidth,
                  title: 'จำนวนบิล',
                  value: '${summary.billCount}',
                  subtitle: 'บิล',
                  icon: Icons.receipt_long,
                ),
                _SummaryCard(
                  width: cardWidth,
                  title: 'เฉลี่ยต่อบิล',
                  value: _formatMoney(summary.averageBillSatang),
                  icon: Icons.calculate,
                ),
                _SummaryCard(
                  width: cardWidth,
                  title: 'จำนวนอาหารที่ขาย',
                  value: '${summary.totalItems}',
                  subtitle: 'รายการ',
                  icon: Icons.restaurant,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 32),

        Text(
          'ช่องทางการชำระเงิน',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        if (summary.paymentMethods.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('ยังไม่มีรายการชำระเงิน')),
            ),
          )
        else
          ...summary.paymentMethods.map(
            (payment) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(_paymentIcon(payment.method)),
                ),
                title: Text(_paymentLabel(payment.method)),
                subtitle: Text('${payment.billCount} บิล'),
                trailing: Text(
                  _formatMoney(payment.amountSatang),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 32),

        Text(
          'เมนูขายดี',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        if (summary.topItems.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('ยังไม่มีข้อมูลเมนูขาย')),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < summary.topItems.length; i++) ...[
                  ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(summary.topItems[i].name),
                    subtitle: Text(
                      'ขาย ${summary.topItems[i].quantity} รายการ',
                    ),
                    trailing: Text(
                      _formatMoney(summary.topItems[i].salesSatang),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  if (i < summary.topItems.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }

  DateTime _normalizeDate(DateTime date) {
    switch (period) {
      case 'MONTHLY':
        return DateTime(date.year, date.month, 1);

      case 'YEARLY':
        return DateTime(date.year, 1, 1);

      default:
        return DateTime(date.year, date.month, date.day);
    }
  }

  void _movePeriod(int offset) {
    setState(() {
      switch (period) {
        case 'DAILY':
          selectedDate = selectedDate.add(Duration(days: offset));
          break;

        case 'MONTHLY':
          selectedDate = DateTime(
            selectedDate.year,
            selectedDate.month + offset,
            1,
          );
          break;

        case 'YEARLY':
          selectedDate = DateTime(selectedDate.year + offset, 1, 1);
          break;
      }
    });
  }

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2200),
    );

    if (result == null) {
      return;
    }

    setState(() {
      selectedDate = _normalizeDate(result);
    });
  }

  String _periodLabel() {
    switch (period) {
      case 'MONTHLY':
        return '${_thaiMonths[selectedDate.month - 1]} '
            '${selectedDate.year}';

      case 'YEARLY':
        return '${selectedDate.year}';

      default:
        return '${selectedDate.day.toString().padLeft(2, '0')}/'
            '${selectedDate.month.toString().padLeft(2, '0')}/'
            '${selectedDate.year}';
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSelect;

  const _PeriodSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSelect,
            icon: const Icon(Icons.date_range),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        IconButton.filledTonal(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;

  const _SummaryCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),

              if (subtitle != null) Text(subtitle!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

const _thaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

String _paymentLabel(String method) {
  switch (method) {
    case 'CASH':
      return 'เงินสด';

    case 'PROMPTPAY':
      return 'PromptPay';

    case 'CREDIT_CARD':
      return 'บัตรเครดิต';

    default:
      return method;
  }
}

IconData _paymentIcon(String method) {
  switch (method) {
    case 'CASH':
      return Icons.payments_outlined;

    case 'PROMPTPAY':
      return Icons.qr_code;

    case 'CREDIT_CARD':
      return Icons.credit_card;

    default:
      return Icons.account_balance_wallet;
  }
}

String _formatMoney(int satang) {
  final value = (satang / 100).toStringAsFixed(2);

  final parts = value.split('.');

  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  return '฿$whole.${parts[1]}';
}

String _errorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
  }

  return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
}
