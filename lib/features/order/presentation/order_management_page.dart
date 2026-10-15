import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/restaurant_order.dart';
import 'order_provider.dart';
import '../../../core/printing/thermal_print_service.dart';

class OrderManagementPage extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OrderManagementPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  ConsumerState<OrderManagementPage> createState() =>
      _OrderManagementPageState();
}

class _OrderManagementPageState extends ConsumerState<OrderManagementPage> {
  String selectedStatus = '';

  Timer? refreshTimer;

  OrderQuery get query =>
      OrderQuery(restaurantId: widget.restaurantId, status: selectedStatus);

  @override
  void initState() {
    super.initState();

    // refresh order ทุก 15 วินาที
    // เหมาะกับช่วงแรกก่อนทำ WebSocket
    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(ordersProvider(query));
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  void refresh() {
    ref.invalidate(ordersProvider(query));
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Text('ออเดอร์ - ${widget.restaurantName}'),

        actions: [
          IconButton(
            tooltip: 'Refresh',

            onPressed: refresh,

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Column(
        children: [
          _buildStatusFilter(),

          const Divider(height: 1),

          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),

              error: (error, stackTrace) =>
                  _ErrorView(error: error, onRetry: refresh),

              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(child: Text('ไม่มีออเดอร์'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    refresh();

                    await ref.read(ordersProvider(query).future);
                  },

                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 850) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(24),

                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 420,
                                mainAxisExtent: 260,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),

                          itemCount: orders.length,

                          itemBuilder: (context, index) {
                            return _OrderCard(
                              order: orders[index],
                              restaurantName: widget.restaurantName,
                              onChanged: refresh,
                            );
                          },
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),

                        itemCount: orders.length,

                        separatorBuilder: (_, __) => const SizedBox(height: 8),

                        itemBuilder: (context, index) {
                          return _OrderCard(
                            order: orders[index],
                            restaurantName: widget.restaurantName,
                            onChanged: refresh,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    const statuses = [
      '',
      'PENDING',
      'ACCEPTED',
      'PREPARING',
      'READY',
      'SERVED',
      'CANCELLED',
    ];

    return SizedBox(
      height: 68,

      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),

        scrollDirection: Axis.horizontal,

        itemCount: statuses.length,

        separatorBuilder: (_, __) => const SizedBox(width: 8),

        itemBuilder: (context, index) {
          final status = statuses[index];

          return ChoiceChip(
            label: Text(_statusLabel(status)),

            selected: selectedStatus == status,

            onSelected: (_) {
              setState(() {
                selectedStatus = status;
              });
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final RestaurantOrder order;
  final String restaurantName;
  final VoidCallback onChanged;

  const _OrderCard({
    required this.order,
    required this.restaurantName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () {
          _showDetail(context, ref);
        },

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  _OrderStatusIcon(status: order.status),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          order.orderCode,

                          style: Theme.of(context).textTheme.titleLarge,
                        ),

                        if (order.tableNo != null && order.tableNo!.isNotEmpty)
                          Text('โต๊ะ ${order.tableNo}'),
                      ],
                    ),
                  ),

                  if (order.status != 'CANCELLED')
                    IconButton(
                      tooltip: 'พิมพ์ใบครัว',
                      onPressed: () async {
                        await _printKitchenOrder(context, ref);
                      },
                      icon: const Icon(Icons.print_outlined),
                    ),

                  const SizedBox(width: 4),

                  _StatusBadge(status: order.status),
                ],
              ),

              const SizedBox(height: 16),

              if (order.customerNote != null &&
                  order.customerNote!.trim().isNotEmpty)
                Text(
                  'หมายเหตุ: ${order.customerNote}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const Spacer(),

              Row(
                children: [
                  Text(
                    _formatPrice(order.totalSatang),

                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const Spacer(),

                  Text(_formatTime(order.createdAt)),
                ],
              ),

              const SizedBox(height: 12),

              _OrderActions(
                order: order,

                onChange: (status) async {
                  await _updateStatus(context, ref, status);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printKitchenOrder(BuildContext context, WidgetRef ref) async {
    try {
      // โหลด Order เต็มก่อน
      // เพราะข้อมูลใน Card อาจไม่มี items ครบ
      final detail = await ref.read(orderRepositoryProvider).getOrder(order.id);

      await ThermalPrintService.printKitchenOrder(
        order: detail,
        restaurantName: restaurantName,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งใบสั่งอาหารไปยังเครื่องพิมพ์แล้ว')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('พิมพ์ใบครัวไม่สำเร็จ: ${error.toString()}')),
      );
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    if (status == 'CANCELLED') {
      final confirmed = await showDialog<bool>(
        context: context,

        builder: (context) {
          return AlertDialog(
            title: const Text('ยกเลิกออเดอร์'),

            content: const Text('ยืนยันการยกเลิกออเดอร์นี้หรือไม่?'),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },

                child: const Text('ไม่ยกเลิก'),
              ),

              FilledButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },

                child: const Text('ยืนยัน'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }
    }

    try {
      await ref
          .read(orderRepositoryProvider)
          .updateStatus(orderId: order.id, status: status);

      onChanged();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _showDetail(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return FutureBuilder<RestaurantOrder>(
          future: ref.read(orderRepositoryProvider).getOrder(order.id),

          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AlertDialog(
                content: SizedBox(
                  width: 450,
                  height: 250,

                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                title: const Text('เกิดข้อผิดพลาด'),

                content: Text(_errorMessage(snapshot.error ?? Exception())),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('ปิด'),
                  ),
                ],
              );
            }

            final detail = snapshot.data!;

            return AlertDialog(
              title: Row(
                children: [
                  Expanded(child: Text('Order ${detail.orderCode}')),

                  _StatusBadge(status: detail.status),
                ],
              ),

              content: SizedBox(
                width: 550,

                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    mainAxisSize: MainAxisSize.min,

                    children: [
                      if (detail.tableNo != null)
                        Text(
                          'โต๊ะ ${detail.tableNo}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),

                      const SizedBox(height: 16),

                      const Divider(),

                      if (detail.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('ไม่มีรายละเอียดรายการอาหาร'),
                        ),

                      ...detail.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Container(
                                width: 36,
                                height: 36,

                                alignment: Alignment.center,

                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,

                                  borderRadius: BorderRadius.circular(8),
                                ),

                                child: Text('${item.quantity}x'),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      item.menuItemName,

                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    if (item.note != null &&
                                        item.note!.isNotEmpty)
                                      Text('หมายเหตุ: ${item.note}'),
                                  ],
                                ),
                              ),

                              Text(_formatPrice(item.totalSatang)),
                            ],
                          ),
                        );
                      }),

                      const Divider(),

                      Row(
                        children: [
                          const Text(
                            'รวม',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),

                          const Spacer(),

                          Text(
                            _formatPrice(detail.totalSatang),

                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),

                      if (detail.customerNote != null &&
                          detail.customerNote!.isNotEmpty) ...[
                        const SizedBox(height: 20),

                        Text('หมายเหตุลูกค้า: ${detail.customerNote}'),
                      ],
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _OrderActions extends StatelessWidget {
  final RestaurantOrder order;

  final Future<void> Function(String status) onChange;

  const _OrderActions({required this.order, required this.onChange});

  @override
  Widget build(BuildContext context) {
    switch (order.status) {
      case 'PENDING':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  onChange('CANCELLED');
                },

                child: const Text('ยกเลิก'),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: FilledButton(
                onPressed: () {
                  onChange('ACCEPTED');
                },

                child: const Text('รับออเดอร์'),
              ),
            ),
          ],
        );

      case 'ACCEPTED':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  onChange('CANCELLED');
                },

                child: const Text('ยกเลิก'),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: FilledButton(
                onPressed: () {
                  onChange('PREPARING');
                },

                child: const Text('เริ่มทำ'),
              ),
            ),
          ],
        );

      case 'PREPARING':
        return SizedBox(
          width: double.infinity,

          child: FilledButton(
            onPressed: () {
              onChange('READY');
            },

            child: const Text('อาหารพร้อม'),
          ),
        );

      case 'READY':
        return SizedBox(
          width: double.infinity,

          child: FilledButton(
            onPressed: () {
              onChange('SERVED');
            },

            child: const Text('เสิร์ฟแล้ว'),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _OrderStatusIcon extends StatelessWidget {
  final String status;

  const _OrderStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;

    switch (status) {
      case 'PENDING':
        icon = Icons.notifications_active;
        break;

      case 'ACCEPTED':
        icon = Icons.check_circle;
        break;

      case 'PREPARING':
        icon = Icons.soup_kitchen;
        break;

      case 'READY':
        icon = Icons.room_service;
        break;

      case 'SERVED':
        icon = Icons.done_all;
        break;

      case 'CANCELLED':
        icon = Icons.cancel;
        break;

      default:
        icon = Icons.receipt_long;
    }

    return CircleAvatar(child: Icon(icon));
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(_statusLabel(status)));
  }
}

String _statusLabel(String status) {
  switch (status) {
    case '':
      return 'ทั้งหมด';

    case 'PENDING':
      return 'รอรับ';

    case 'ACCEPTED':
      return 'รับแล้ว';

    case 'PREPARING':
      return 'กำลังทำ';

    case 'READY':
      return 'พร้อมเสิร์ฟ';

    case 'SERVED':
      return 'เสิร์ฟแล้ว';

    case 'CANCELLED':
      return 'ยกเลิก';

    default:
      return status;
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

String _formatTime(DateTime? value) {
  if (value == null) {
    return '';
  }

  final local = value.toLocal();

  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
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

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          Text(_errorMessage(error)),

          const SizedBox(height: 16),

          FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
