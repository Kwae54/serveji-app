import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/active_session.dart';
import 'bill_page.dart';
import 'billing_provider.dart';

class BillingManagementPage extends ConsumerWidget {
  final String restaurantId;
  final String restaurantName;

  const BillingManagementPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(activeSessionsProvider(restaurantId));

    return Scaffold(
      appBar: AppBar(
        title: Text('เช็กบิล - $restaurantName'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(activeSessionsProvider(restaurantId));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, stackTrace) => Center(child: Text(_errorMessage(error))),

        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('ไม่มีโต๊ะที่กำลังใช้งาน'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                padding: const EdgeInsets.all(24),

                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: constraints.maxWidth >= 800 ? 320 : 500,

                  mainAxisExtent: 200,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),

                itemCount: sessions.length,

                itemBuilder: (context, index) {
                  return _SessionCard(
                    session: sessions[index],

                    onTap: () async {
                      await Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (_) => BillPage(
                            restaurantId: restaurantId,
                            sessionId: sessions[index].sessionId,
                            tableNo: sessions[index].tableNo,
                          ),
                        ),
                      );

                      ref.invalidate(activeSessionsProvider(restaurantId));
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ActiveSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.table_restaurant)),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      'โต๊ะ ${session.tableNo}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),

                  Chip(
                    label: Text(
                      session.status == 'CHECKOUT_REQUESTED'
                          ? 'รอชำระ'
                          : 'กำลังใช้งาน',
                    ),
                  ),
                ],
              ),

              const Spacer(),

              Text('${session.orderCount} ออเดอร์'),

              const SizedBox(height: 6),

              Text(
                _formatPrice(session.subtotalSatang),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPrice(int satang) {
  final baht = satang ~/ 100;
  final decimal = satang % 100;

  if (decimal == 0) {
    return '฿$baht';
  }

  return '฿$baht.${decimal.toString().padLeft(2, '0')}';
}

String _errorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map) {
      if (data['message'] != null) {
        return data['message'].toString();
      }

      if (data['error'] != null) {
        return data['error'].toString();
      }
    }

    if (error.response?.statusCode != null) {
      return 'HTTP ${error.response!.statusCode}: '
          '${error.response?.data}';
    }

    return error.message ?? 'Network error';
  }

  return error.toString();
}
