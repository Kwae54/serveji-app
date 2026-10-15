import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';

import '../data/menu_repository.dart';
import '../model/menu_category.dart';
import '../model/menu_item.dart';
import 'menu_provider.dart';

class MenuManagementPage extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const MenuManagementPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  ConsumerState<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends ConsumerState<MenuManagementPage> {
  Timer? _searchTimer;

  String search = '';

  String? selectedCategoryId;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void searchMenu(String value) {
    _searchTimer?.cancel();

    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        search = value.trim();
      });
    });
  }

  void refreshAll() {
    ref.invalidate(menuCategoriesProvider(widget.restaurantId));

    ref.invalidate(
      menuItemsProvider(
        MenuItemQuery(restaurantId: widget.restaurantId, search: search),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(
      menuCategoriesProvider(widget.restaurantId),
    );

    final query = MenuItemQuery(
      restaurantId: widget.restaurantId,
      search: search,
    );

    final itemsAsync = ref.watch(menuItemsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Text('เมนู - ${widget.restaurantName}'),
        actions: [
          IconButton(
            tooltip: 'จัดการหมวดหมู่',
            onPressed: () {
              _showCategoryManagement();
            },
            icon: const Icon(Icons.category),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          categoriesAsync.whenData((categories) {
            _showCreateMenuDialog(categories);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มเมนู'),
      ),

      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, stackTrace) =>
            _ErrorView(error: error, onRetry: refreshAll),

        data: (categories) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),

                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาชื่อเมนู...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),

                  onChanged: searchMenu,
                ),
              ),

              _buildCategoryFilter(categories),

              const Divider(height: 1),

              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  error: (error, stackTrace) =>
                      _ErrorView(error: error, onRetry: refreshAll),

                  data: (items) {
                    final filtered = selectedCategoryId == null
                        ? items
                        : items
                              .where(
                                (item) => item.categoryId == selectedCategoryId,
                              )
                              .toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('ไม่พบเมนูอาหาร'));
                    }

                    return _buildMenuGrid(filtered, categories);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilter(List<MenuCategory> categories) {
    return SizedBox(
      height: 64,

      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),

        scrollDirection: Axis.horizontal,

        children: [
          ChoiceChip(
            label: const Text('ทั้งหมด'),
            selected: selectedCategoryId == null,

            onSelected: (_) {
              setState(() {
                selectedCategoryId = null;
              });
            },
          ),

          const SizedBox(width: 8),

          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),

              child: ChoiceChip(
                label: Text(
                  category.active ? category.name : '${category.name} (ปิด)',
                ),

                selected: selectedCategoryId == category.id,

                onSelected: (_) {
                  setState(() {
                    selectedCategoryId = category.id;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(List<MenuItem> items, List<MenuCategory> categories) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.all(24),

          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: constraints.maxWidth >= 800 ? 320 : 500,
            mainAxisExtent: 380,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),

          itemCount: items.length,

          itemBuilder: (context, index) {
            return _MenuItemCard(
              item: items[index],
              categories: categories,

              onChanged: refreshAll,

              repository: ref.read(menuRepositoryProvider),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateMenuDialog(List<MenuCategory> categories) async {
    final activeCategories = categories
        .where((category) => category.active)
        .toList();

    if (activeCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาสร้างหมวดหมู่ที่เปิดใช้งานก่อน')),
      );

      return;
    }

    final nameController = TextEditingController();

    final descriptionController = TextEditingController();

    final priceController = TextEditingController();

    final sortController = TextEditingController(text: '0');

    String categoryId = activeCategories.first.id;

    XFile? selectedImage;

    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('เพิ่มเมนูอาหาร'),

              content: SizedBox(
                width: 500,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                final image = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );

                                if (image != null) {
                                  setDialogState(() {
                                    selectedImage = image;
                                  });
                                }
                              },

                        icon: const Icon(Icons.image),

                        label: Text(
                          selectedImage == null
                              ? 'เลือกรูปอาหาร (ไม่บังคับ)'
                              : selectedImage!.name,
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: categoryId,

                        decoration: const InputDecoration(
                          labelText: 'หมวดหมู่',
                          border: OutlineInputBorder(),
                        ),

                        items: activeCategories.map((category) {
                          return DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          );
                        }).toList(),

                        onChanged: loading
                            ? null
                            : (value) {
                                if (value != null) {
                                  categoryId = value;
                                }
                              },
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: nameController,

                        decoration: const InputDecoration(
                          labelText: 'ชื่อเมนู',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: descriptionController,

                        maxLines: 3,

                        decoration: const InputDecoration(
                          labelText: 'รายละเอียด (ไม่บังคับ)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: priceController,

                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),

                        decoration: const InputDecoration(
                          labelText: 'ราคา (บาท)',
                          hintText: '89 หรือ 89.50',
                          prefixText: '฿ ',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: sortController,

                        keyboardType: TextInputType.number,

                        decoration: const InputDecoration(
                          labelText: 'ลำดับ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
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
                          final name = nameController.text.trim();

                          final price = _bahtToSatang(priceController.text);

                          final sortOrder =
                              int.tryParse(sortController.text.trim()) ?? 0;

                          if (name.isEmpty ||
                              price == null ||
                              price <= 0 ||
                              sortOrder < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('กรุณาตรวจสอบชื่อ ราคา และลำดับ'),
                              ),
                            );

                            return;
                          }

                          setDialogState(() {
                            loading = true;
                          });

                          try {
                            final repository = ref.read(menuRepositoryProvider);

                            final item = await repository.createMenuItem(
                              restaurantId: widget.restaurantId,
                              categoryId: categoryId,
                              name: name,
                              description: descriptionController.text.trim(),
                              priceSatang: price,
                              sortOrder: sortOrder,
                            );

                            if (selectedImage != null) {
                              final bytes = await selectedImage!.readAsBytes();

                              await repository.uploadImage(
                                menuItemId: item.id,
                                bytes: bytes,
                                fileName: selectedImage!.name,
                              );
                            }

                            refreshAll();

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (error) {
                            setDialogState(() {
                              loading = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_errorMessage(error))),
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
                      : const Text('เพิ่มเมนู'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    sortController.dispose();
  }

  Future<void> _showCategoryManagement() async {
    await showDialog(
      context: context,

      builder: (_) => _CategoryManagementDialog(
        restaurantId: widget.restaurantId,

        repository: ref.read(menuRepositoryProvider),

        onChanged: refreshAll,
      ),
    );
  }
}

class _CategoryManagementDialog extends ConsumerWidget {
  final String restaurantId;
  final MenuRepository repository;
  final VoidCallback onChanged;

  const _CategoryManagementDialog({
    required this.restaurantId,
    required this.repository,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(menuCategoriesProvider(restaurantId));

    return AlertDialog(
      title: const Text('จัดการหมวดหมู่'),

      content: SizedBox(
        width: 550,
        height: 450,

        child: categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),

          error: (error, stackTrace) =>
              Center(child: Text(_errorMessage(error))),

          data: (categories) {
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,

                  child: FilledButton.icon(
                    onPressed: () {
                      _showCategoryDialog(context, ref);
                    },

                    icon: const Icon(Icons.add),

                    label: const Text('เพิ่มหมวดหมู่'),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: ListView.separated(
                    itemCount: categories.length,

                    separatorBuilder: (_, __) => const Divider(),

                    itemBuilder: (context, index) {
                      final category = categories[index];

                      return ListTile(
                        title: Text(category.name),

                        subtitle: Text('ลำดับ ${category.sortOrder}'),

                        leading: const Icon(Icons.category),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Switch(
                              value: category.active,

                              onChanged: (value) async {
                                try {
                                  await repository.updateCategoryActive(
                                    categoryId: category.id,
                                    active: value,
                                  );

                                  ref.invalidate(
                                    menuCategoriesProvider(restaurantId),
                                  );

                                  onChanged();
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_errorMessage(error)),
                                    ),
                                  );
                                }
                              },
                            ),

                            IconButton(
                              tooltip: 'แก้ไข',

                              onPressed: () {
                                _showCategoryDialog(
                                  context,
                                  ref,
                                  category: category,
                                );
                              },

                              icon: const Icon(Icons.edit),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),

      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('ปิด'),
        ),
      ],
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    MenuCategory? category,
  }) async {
    final nameController = TextEditingController(text: category?.name ?? '');

    final sortController = TextEditingController(
      text: '${category?.sortOrder ?? 0}',
    );

    await showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text(category == null ? 'เพิ่มหมวดหมู่' : 'แก้ไขหมวดหมู่'),

          content: SizedBox(
            width: 400,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                TextField(
                  controller: nameController,

                  decoration: const InputDecoration(
                    labelText: 'ชื่อหมวดหมู่',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: sortController,

                  keyboardType: TextInputType.number,

                  decoration: const InputDecoration(
                    labelText: 'ลำดับ',
                    border: OutlineInputBorder(),
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
              onPressed: () async {
                final name = nameController.text.trim();

                final sortOrder = int.tryParse(sortController.text.trim()) ?? 0;

                if (name.isEmpty || sortOrder < 0) {
                  return;
                }

                try {
                  if (category == null) {
                    await repository.createCategory(
                      restaurantId: restaurantId,
                      name: name,
                      sortOrder: sortOrder,
                    );
                  } else {
                    await repository.updateCategory(
                      categoryId: category.id,
                      name: name,
                      sortOrder: sortOrder,
                    );
                  }

                  ref.invalidate(menuCategoriesProvider(restaurantId));

                  onChanged();

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
                }
              },

              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    sortController.dispose();
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final List<MenuCategory> categories;
  final MenuRepository repository;
  final VoidCallback onChanged;

  const _MenuItemCard({
    required this.item,
    required this.categories,
    required this.repository,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final category = categories
        .where((category) => category.id == item.categoryId)
        .firstOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: double.infinity,
            height: 150,

            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(
                    AppConfig.imageUrl(item.imageUrl),
                    fit: BoxFit.cover,

                    errorBuilder: (context, error, stackTrace) {
                      return _noMenuImage();
                    },
                  )
                : _noMenuImage(),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),

                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditDialog(context);
                          }

                          if (value == 'image') {
                            _changeImage(context);
                          }
                        },

                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('แก้ไขเมนู'),
                          ),

                          PopupMenuItem(
                            value: 'image',
                            child: Text('เปลี่ยนรูป'),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Text(category?.name ?? '-'),

                  const SizedBox(height: 8),

                  Text(
                    _formatPrice(item.priceSatang),

                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const Spacer(),

                  Row(
                    children: [
                      Chip(label: Text(item.available ? 'พร้อมขาย' : 'ปิดขาย')),

                      const Spacer(),

                      Switch(
                        value: item.available,

                        onChanged: (value) async {
                          try {
                            await repository.updateAvailable(
                              menuItemId: item.id,
                              available: value,
                            );

                            onChanged();
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_errorMessage(error))),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final nameController = TextEditingController(text: item.name);

    final descriptionController = TextEditingController(text: item.description);

    final priceController = TextEditingController(
      text: _priceForInput(item.priceSatang),
    );

    final sortController = TextEditingController(text: '${item.sortOrder}');

    String categoryId = item.categoryId;

    await showDialog(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('แก้ไขเมนู'),

              content: SizedBox(
                width: 500,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      DropdownButtonFormField<String>(
                        value: categoryId,

                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category.id,

                            child: Text(
                              category.active
                                  ? category.name
                                  : '${category.name} (ปิด)',
                            ),
                          );
                        }).toList(),

                        onChanged: (value) {
                          if (value != null) {
                            categoryId = value;
                          }
                        },

                        decoration: const InputDecoration(
                          labelText: 'หมวดหมู่',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: nameController,

                        decoration: const InputDecoration(
                          labelText: 'ชื่อเมนู',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: descriptionController,

                        maxLines: 3,

                        decoration: const InputDecoration(
                          labelText: 'รายละเอียด',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: priceController,

                        decoration: const InputDecoration(
                          labelText: 'ราคา (บาท)',
                          prefixText: '฿ ',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: sortController,

                        decoration: const InputDecoration(
                          labelText: 'ลำดับ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
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
                  onPressed: () async {
                    final price = _bahtToSatang(priceController.text);

                    final sortOrder =
                        int.tryParse(sortController.text.trim()) ?? 0;

                    if (nameController.text.trim().isEmpty ||
                        price == null ||
                        price <= 0 ||
                        sortOrder < 0) {
                      return;
                    }

                    try {
                      await repository.updateMenuItem(
                        menuItemId: item.id,
                        categoryId: categoryId,
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim(),
                        priceSatang: price,
                        sortOrder: sortOrder,
                      );

                      onChanged();

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_errorMessage(error))),
                      );
                    }
                  },

                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    sortController.dispose();
  }

  Future<void> _changeImage(BuildContext context) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    try {
      final Uint8List bytes = await image.readAsBytes();

      await repository.uploadImage(
        menuItemId: item.id,
        bytes: bytes,
        fileName: image.name,
      );

      onChanged();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }
}

Widget _noMenuImage() {
  return Container(
    alignment: Alignment.center,
    color: Colors.grey.shade100,

    child: const Icon(Icons.restaurant_menu, size: 54),
  );
}

int? _bahtToSatang(String value) {
  final text = value.trim().replaceAll(',', '');

  final match = RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text);

  if (!match) {
    return null;
  }

  final parts = text.split('.');

  final baht = int.tryParse(parts[0]);

  if (baht == null) {
    return null;
  }

  int satang = 0;

  if (parts.length == 2) {
    final decimal = parts[1].padRight(2, '0');

    satang = int.parse(decimal.substring(0, 2));
  }

  return (baht * 100) + satang;
}

String _formatPrice(int satang) {
  final baht = satang ~/ 100;

  final decimal = satang % 100;

  if (decimal == 0) {
    return '฿$baht';
  }

  return '฿$baht.${decimal.toString().padLeft(2, '0')}';
}

String _priceForInput(int satang) {
  final baht = satang ~/ 100;

  final decimal = satang % 100;

  if (decimal == 0) {
    return '$baht';
  }

  return '$baht.${decimal.toString().padLeft(2, '0')}';
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
