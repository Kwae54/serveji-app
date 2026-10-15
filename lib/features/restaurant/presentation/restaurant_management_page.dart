import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';

import '../model/restaurant.dart';
import 'restaurant_provider.dart';

class RestaurantManagementPage extends ConsumerWidget {
  const RestaurantManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(restaurantProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('จัดการร้านอาหาร')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateRestaurantDialog(context, ref);
        },
        icon: const Icon(Icons.add_business),
        label: const Text('เพิ่มร้าน'),
      ),

      body: restaurants.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },

        error: (error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_getErrorMessage(error)),

                const SizedBox(height: 16),

                FilledButton(
                  onPressed: () {
                    ref.read(restaurantProvider.notifier).refresh();
                  },
                  child: const Text('ลองใหม่'),
                ),
              ],
            ),
          );
        },

        data: (restaurants) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาชื่อร้าน...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    ref.read(restaurantProvider.notifier).search(value);
                  },
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: restaurants.isEmpty
                    ? const Center(child: Text('ไม่พบร้านอาหาร'))
                    : RefreshIndicator(
                        onRefresh: () {
                          return ref
                              .read(restaurantProvider.notifier)
                              .refresh();
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 900) {
                              return GridView.builder(
                                padding: const EdgeInsets.all(24),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 420,
                                      mainAxisExtent: 300,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: restaurants.length,
                                itemBuilder: (context, index) {
                                  return _RestaurantCard(
                                    restaurant: restaurants[index],
                                    ref: ref,
                                  );
                                },
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: restaurants.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                return _RestaurantCard(
                                  restaurant: restaurants[index],
                                  ref: ref,
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateRestaurantDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();

    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('เพิ่มร้านอาหาร'),

              content: SizedBox(
                width: 420,

                child: TextField(
                  controller: nameController,

                  autofocus: true,

                  enabled: !loading,

                  decoration: const InputDecoration(
                    labelText: 'ชื่อร้าน',
                    hintText: 'เช่น Serveji Cafe',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront),
                  ),

                  onSubmitted: (_) {
                    if (!loading) {
                      _createRestaurant(
                        context,
                        dialogContext,
                        ref,
                        nameController,
                        setState,
                        (value) {
                          loading = value;
                        },
                      );
                    }
                  },
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
                      : () {
                          _createRestaurant(
                            context,
                            dialogContext,
                            ref,
                            nameController,
                            setState,
                            (value) {
                              loading = value;
                            },
                          );
                        },

                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('เพิ่มร้าน'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _createRestaurant(
    BuildContext context,
    BuildContext dialogContext,
    WidgetRef ref,
    TextEditingController controller,
    StateSetter setState,
    ValueChanged<bool> setLoading,
  ) async {
    final name = controller.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อร้าน')));

      return;
    }

    setState(() {
      setLoading(true);
    });

    try {
      await ref.read(restaurantProvider.notifier).createRestaurant(name: name);

      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
    } catch (error) {
      setState(() {
        setLoading(false);
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_getErrorMessage(error))));
      }
    }
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final WidgetRef ref;

  const _RestaurantCard({required this.restaurant, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () {
          _showRestaurantDetail(context);
        },

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,

                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Icon(Icons.storefront, size: 28),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: Theme.of(context).textTheme.titleLarge,
                        ),

                        const SizedBox(height: 4),

                        Text(
                          restaurant.id,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditDialog(context);
                      }

                      if (value == 'image') {
                        _pickRestaurantImage(context);
                      }

                      if (value == 'payment_qr') {
                        _pickPaymentQR(context);
                      }
                    },

                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('แก้ไขชื่อร้าน'),
                          ],
                        ),
                      ),

                      PopupMenuItem(
                        value: 'image',
                        child: Row(
                          children: [
                            Icon(Icons.image),
                            SizedBox(width: 8),
                            Text('เปลี่ยนรูปร้าน'),
                          ],
                        ),
                      ),

                      PopupMenuItem(
                        value: 'payment_qr',
                        child: Row(
                          children: [
                            Icon(Icons.qr_code),
                            SizedBox(width: 8),
                            Text('QR รับชำระเงิน'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 130,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      restaurant.imageUrl != null &&
                          restaurant.imageUrl!.isNotEmpty
                      ? Image.network(
                          AppConfig.imageUrl(restaurant.imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _noRestaurantImage();
                          },
                        )
                      : _noRestaurantImage(),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),

                    decoration: BoxDecoration(
                      color: restaurant.isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.15),

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(restaurant.status),
                  ),

                  const Spacer(),

                  const Text('สถานะ'),

                  const SizedBox(width: 8),

                  Switch(
                    value: restaurant.isActive,

                    onChanged: (value) {
                      _changeStatus(context, value);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, bool active) async {
    try {
      await ref
          .read(restaurantProvider.notifier)
          .updateStatus(
            restaurantId: restaurant.id,
            status: active ? 'ACTIVE' : 'INACTIVE',
          );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_getErrorMessage(error))));
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: restaurant.name);

    bool loading = false;

    await showDialog(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('แก้ไขร้านอาหาร'),

              content: SizedBox(
                width: 420,

                child: TextField(
                  controller: controller,
                  autofocus: true,

                  decoration: const InputDecoration(
                    labelText: 'ชื่อร้าน',
                    border: OutlineInputBorder(),
                  ),
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
                          final name = controller.text.trim();

                          if (name.isEmpty) {
                            return;
                          }

                          setState(() {
                            loading = true;
                          });

                          try {
                            await ref
                                .read(restaurantProvider.notifier)
                                .updateRestaurant(
                                  restaurantId: restaurant.id,
                                  name: name,
                                );

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

    controller.dispose();
  }

  Future<void> _pickRestaurantImage(BuildContext context) async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    final Uint8List bytes = await image.readAsBytes();

    if (!context.mounted) {
      return;
    }

    try {
      await ref
          .read(restaurantProvider.notifier)
          .uploadImage(
            restaurantId: restaurant.id,
            bytes: bytes,
            fileName: image.name,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปโหลดรูปร้านเรียบร้อย')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_getErrorMessage(error))));
    }
  }

  Future<void> _pickPaymentQR(BuildContext context) async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (image == null) {
      return;
    }

    final Uint8List bytes = await image.readAsBytes();

    if (!context.mounted) {
      return;
    }

    try {
      await ref
          .read(restaurantProvider.notifier)
          .uploadPaymentQR(
            restaurantId: restaurant.id,
            bytes: bytes,
            fileName: image.name,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปโหลด QR รับชำระเงินเรียบร้อย')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_getErrorMessage(error))));
    }
  }

  void _showRestaurantDetail(BuildContext context) {
    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.storefront),

              const SizedBox(width: 12),

              Expanded(child: Text(restaurant.name)),
            ],
          ),

          content: SizedBox(
            width: 420,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Restaurant ID',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                SelectableText(restaurant.id),

                const SizedBox(height: 20),

                const Text(
                  'สถานะ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(restaurant.status),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('ปิด'),
            ),

            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);

                _showEditDialog(context);
              },

              icon: const Icon(Icons.edit),

              label: const Text('แก้ไข'),
            ),
          ],
        );
      },
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

Widget _noRestaurantImage() {
  return Container(
    color: Colors.grey.shade100,
    alignment: Alignment.center,
    child: const Icon(Icons.storefront, size: 54),
  );
}
