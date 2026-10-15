import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/dining_table.dart';
import 'dining_table_provider.dart';
import '../../session_qr/presentation/session_qr_page.dart';

class DiningTablePage extends ConsumerWidget {
  final String restaurantId;
  final String restaurantName;

  const DiningTablePage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(diningTablesProvider(restaurantId));

    return Scaffold(
      appBar: AppBar(title: Text('โต๊ะ - $restaurantName')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateDialog(context, ref);
        },

        icon: const Icon(Icons.add),

        label: const Text('เพิ่มโต๊ะ'),
      ),

      body: tables.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, stackTrace) => _ErrorView(
          message: _getErrorMessage(error),

          onRetry: () {
            ref.invalidate(diningTablesProvider(restaurantId));
          },
        ),

        data: (tables) {
          if (tables.isEmpty) {
            return const Center(child: Text('ยังไม่มีโต๊ะ'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(diningTablesProvider(restaurantId));

              await ref.read(diningTablesProvider(restaurantId).future);
            },

            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 700) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(24),

                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          mainAxisExtent: 300,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),

                    itemCount: tables.length,

                    itemBuilder: (context, index) {
                      return _TableCard(
                        table: tables[index],
                        restaurantId: restaurantId,
                        restaurantName: restaurantName,
                        allTables: tables,
                      );
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),

                  itemCount: tables.length,

                  separatorBuilder: (_, __) => const SizedBox(height: 8),

                  itemBuilder: (context, index) {
                    return _TableCard(
                      table: tables[index],
                      restaurantId: restaurantId,
                      restaurantName: restaurantName,
                      allTables: tables,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final tableNoController = TextEditingController();

    final tableNameController = TextEditingController();

    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('เพิ่มโต๊ะ'),

              content: SizedBox(
                width: 420,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: tableNoController,

                      autofocus: true,

                      decoration: const InputDecoration(
                        labelText: 'หมายเลขโต๊ะ',
                        hintText: 'เช่น A01',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: tableNameController,

                      decoration: const InputDecoration(
                        labelText: 'ชื่อโต๊ะ (ไม่บังคับ)',
                        hintText: 'เช่น ริมหน้าต่าง',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('ยกเลิก'),
                ),

                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final tableNo = tableNoController.text.trim();

                          if (tableNo.isEmpty) {
                            return;
                          }

                          setState(() {
                            loading = true;
                          });

                          try {
                            final repository = ref.read(
                              diningTableRepositoryProvider,
                            );

                            await repository.createTable(
                              restaurantId: restaurantId,
                              tableNo: tableNo,
                              tableName: tableNameController.text,
                            );

                            ref.invalidate(diningTablesProvider(restaurantId));

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (error) {
                            setState(() {
                              loading = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_getErrorMessage(error)),
                                ),
                              );
                            }
                          }
                        },

                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('เพิ่มโต๊ะ'),
                ),
              ],
            );
          },
        );
      },
    );

    tableNoController.dispose();
    tableNameController.dispose();
  }
}

class _TableCard extends ConsumerWidget {
  final DiningTable table;
  final String restaurantId;
  final String restaurantName;
  final List<DiningTable> allTables;

  const _TableCard({
    required this.table,
    required this.restaurantId,
    required this.restaurantName,
    required this.allTables,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                _TableStatusIcon(status: table.status),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'โต๊ะ ${table.tableNo}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),

                      if (table.tableName != null &&
                          table.tableName!.isNotEmpty)
                        Text(table.tableName!),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, ref);
                    }
                  },

                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',

                      child: Row(
                        children: [
                          Icon(Icons.edit),

                          SizedBox(width: 8),

                          Text('แก้ไขโต๊ะ'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                Row(
                  children: [
                    _StatusBadge(status: table.status),

                    const Spacer(),

                    if (!table.isOccupied)
                      Switch(
                        value: table.isAvailable,

                        onChanged: (active) async {
                          try {
                            final repository = ref.read(
                              diningTableRepositoryProvider,
                            );

                            await repository.updateStatus(
                              tableId: table.id,

                              status: active ? 'AVAILABLE' : 'INACTIVE',
                            );

                            ref.invalidate(diningTablesProvider(restaurantId));
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_getErrorMessage(error))),
                            );
                          }
                        },
                      ),
                  ],
                ),

                if (table.isAvailable) ...[
                  const SizedBox(height: 12),

                  FilledButton.icon(
                    onPressed: () {
                      _openTable(context, ref);
                    },

                    icon: const Icon(Icons.play_arrow),

                    label: const Text('เปิดโต๊ะ'),
                  ),
                ],
              ],
            ),

            if (table.isOccupied) ...[
              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: () {
                  _showSessionQR(context, ref);
                },
                icon: const Icon(Icons.qr_code),
                label: const Text('ดู QR'),
              ),

              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: () {
                  _showMoveTableDialog(context, ref);
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('ย้ายโต๊ะ'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSessionQR(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(diningTableRepositoryProvider);

      final result = await repository.openSession(table.id);

      final qrToken = result['qrToken']?.toString();

      if (qrToken == null || qrToken.isEmpty) {
        throw Exception('QR token not found');
      }

      if (!context.mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionQRPage(
            restaurantName: restaurantName,
            tableNo: table.tableNo,
            sessionToken: qrToken,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_getErrorMessage(error))));
    }
  }

  Future<void> _showMoveTableDialog(BuildContext context, WidgetRef ref) async {
    final availableTables = allTables
        .where((item) => item.id != table.id && item.status == 'AVAILABLE')
        .toList();

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่มีโต๊ะว่างสำหรับย้าย')));

      return;
    }

    String? selectedTableId;

    final targetTableId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('ย้ายโต๊ะ ${table.tableNo}'),
              content: SizedBox(
                width: 420,
                height: MediaQuery.of(context).size.height * 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เลือกโต๊ะปลายทาง'),

                    const SizedBox(height: 12),

                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          itemCount: availableTables.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final targetTable = availableTables[index];

                            return RadioListTile<String>(
                              value: targetTable.id,
                              groupValue: selectedTableId,
                              onChanged: (value) {
                                setState(() {
                                  selectedTableId = value;
                                });
                              },
                              title: Text('โต๊ะ ${targetTable.tableNo}'),
                              subtitle:
                                  targetTable.tableName != null &&
                                      targetTable.tableName!.isNotEmpty
                                  ? Text(targetTable.tableName!)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ยกเลิก'),
                ),

                FilledButton(
                  onPressed: selectedTableId == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, selectedTableId);
                        },
                  child: const Text('ถัดไป'),
                ),
              ],
            );
          },
        );
      },
    );

    if (targetTableId == null) {
      return;
    }

    final targetTable = availableTables.firstWhere(
      (item) => item.id == targetTableId,
    );

    if (!context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ยืนยันการย้ายโต๊ะ'),
          content: Text(
            'ย้ายลูกค้าจากโต๊ะ '
            '${table.tableNo} '
            'ไปโต๊ะ '
            '${targetTable.tableNo} ?\n\n'
            'ออเดอร์และ QR เดิมจะยังใช้งานต่อได้',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('ยกเลิก'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('ยืนยันย้ายโต๊ะ'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final repository = ref.read(diningTableRepositoryProvider);

      await repository.moveSession(
        sourceTableId: table.id,
        targetTableId: targetTableId,
      );

      ref.invalidate(diningTablesProvider(restaurantId));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ย้ายโต๊ะ '
            '${table.tableNo} '
            'ไป '
            '${targetTable.tableNo} '
            'เรียบร้อย',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_getErrorMessage(error))));
    }
  }

  Future<void> _openTable(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text('เปิดโต๊ะ ${table.tableNo}'),

          content: const Text('ยืนยันว่ามีลูกค้าเข้ามาใช้โต๊ะนี้แล้วหรือไม่?'),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('ยกเลิก'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text('เปิดโต๊ะ'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final repository = ref.read(diningTableRepositoryProvider);
      final result = await repository.openSession(table.id);
      final qrToken = result['qrToken']?.toString();

      if (qrToken == null || qrToken.isEmpty) {
        throw Exception('QR token not found');
      }

      ref.invalidate(diningTablesProvider(restaurantId));

      if (!context.mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionQRPage(
            restaurantName: restaurantName,
            tableNo: table.tableNo,
            sessionToken: qrToken,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_getErrorMessage(error))));
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final tableNoController = TextEditingController(text: table.tableNo);

    final tableNameController = TextEditingController(
      text: table.tableName ?? '',
    );

    bool loading = false;

    await showDialog(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('แก้ไขโต๊ะ'),

              content: SizedBox(
                width: 420,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: tableNoController,

                      decoration: const InputDecoration(
                        labelText: 'หมายเลขโต๊ะ',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: tableNameController,

                      decoration: const InputDecoration(
                        labelText: 'ชื่อโต๊ะ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('ยกเลิก'),
                ),

                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final tableNo = tableNoController.text.trim();

                          if (tableNo.isEmpty) {
                            return;
                          }

                          setState(() {
                            loading = true;
                          });

                          try {
                            final repository = ref.read(
                              diningTableRepositoryProvider,
                            );

                            await repository.updateTable(
                              tableId: table.id,
                              tableNo: tableNo,
                              tableName: tableNameController.text,
                            );

                            ref.invalidate(diningTablesProvider(restaurantId));

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (error) {
                            setState(() {
                              loading = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_getErrorMessage(error)),
                                ),
                              );
                            }
                          }
                        },

                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    tableNoController.dispose();
    tableNameController.dispose();
  }
}

class _TableStatusIcon extends StatelessWidget {
  final String status;

  const _TableStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;

    switch (status) {
      case 'OCCUPIED':
        icon = Icons.people;
        break;

      case 'INACTIVE':
        icon = Icons.block;
        break;

      default:
        icon = Icons.table_restaurant;
    }

    return CircleAvatar(radius: 24, child: Icon(icon));
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;

    switch (status) {
      case 'AVAILABLE':
        label = 'ว่าง';
        break;

      case 'OCCUPIED':
        label = 'กำลังใช้งาน';
        break;

      case 'INACTIVE':
        label = 'ปิดใช้งาน';
        break;

      default:
        label = status;
    }

    return Chip(label: Text(label));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),

          const SizedBox(height: 16),

          FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}

String _getErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
  }

  return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
}
