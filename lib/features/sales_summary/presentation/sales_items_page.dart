import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/sales_summary.dart';
import 'sales_summary_provider.dart';

class SalesItemsPage extends ConsumerStatefulWidget {
  final String restaurantName;
  final SalesSummaryQuery query;
  final String periodLabel;

  const SalesItemsPage({
    super.key,
    required this.restaurantName,
    required this.query,
    required this.periodLabel,
  });

  @override
  ConsumerState<SalesItemsPage> createState() => _SalesItemsPageState();
}

class _SalesItemsPageState extends ConsumerState<SalesItemsPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(salesItemsProvider(widget.query));

    final bottomSafeArea = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการอาหารที่ขาย'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: () {
              ref.invalidate(salesItemsProvider(widget.query));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.restaurantName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: 4),

                    Text(widget.periodLabel),

                    const SizedBox(height: 16),

                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาเมนู...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          search = value.trim().toLowerCase();
                        });
                      },
                    ),
                  ],
                ),
              ),

              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  error: (error, stackTrace) =>
                      Center(child: Text(error.toString())),

                  data: (items) {
                    final filtered = items.where((item) {
                      if (search.isEmpty) {
                        return true;
                      }

                      return item.name.toLowerCase().contains(search);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('ไม่พบรายการอาหาร'));
                    }

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        12,
                        24,
                        bottomSafeArea + 32,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),

                          leading: CircleAvatar(child: Text('${index + 1}')),

                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),

                          subtitle: Text('ขาย ${item.quantity} รายการ'),

                          trailing: Text(
                            _formatMoney(item.salesSatang),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
