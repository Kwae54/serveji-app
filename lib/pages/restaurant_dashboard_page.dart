import 'package:flutter/material.dart';

import '../features/auth/model/auth_restaurant.dart';
import '../features/dining_table/presentation/dining_table_page.dart';
import '../features/menu/presentation/menu_management_page.dart';
import '../features/order/presentation/order_management_page.dart';
import '../features/billing/presentation/billing_management_page.dart';
import '../features/printer/presentation/printer_settings_page.dart';
import '../features/sales_summary/presentation/sales_summary_page.dart';
import '../core/config/app_config.dart';

class RestaurantDashboardPage extends StatelessWidget {
  final AuthRestaurant restaurant;

  const RestaurantDashboardPage({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _RestaurantHeader(restaurant: restaurant),

            // Text(
            //   'Restaurant Dashboard',
            //   style: Theme.of(context).textTheme.headlineMedium,
            // ),

            // const SizedBox(height: 8),

            // Text(
            //   restaurant.name,
            //   style: Theme.of(context).textTheme.titleLarge,
            // ),
            const SizedBox(height: 32),

            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 900
                    ? 240.0
                    : constraints.maxWidth >= 600
                    ? 220.0
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _DashboardCard(
                      width: cardWidth,
                      title: 'จัดการโต๊ะ',
                      subtitle: 'โต๊ะและสถานะการใช้งาน',
                      icon: Icons.table_restaurant,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiningTablePage(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name,
                            ),
                          ),
                        );
                      },
                    ),

                    _DashboardCard(
                      width: cardWidth,
                      title: 'จัดการเมนู',
                      subtitle: 'หมวดหมู่และอาหาร',
                      icon: Icons.restaurant_menu,

                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => MenuManagementPage(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name,
                            ),
                          ),
                        );
                      },
                    ),

                    _DashboardCard(
                      width: cardWidth,
                      title: 'ออเดอร์',
                      subtitle: 'ติดตามรายการสั่งอาหาร',
                      icon: Icons.receipt_long,

                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => OrderManagementPage(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name,
                            ),
                          ),
                        );
                      },
                    ),

                    _DashboardCard(
                      width: cardWidth,
                      title: 'เช็กบิล',
                      subtitle: 'Billing และ Payment',
                      icon: Icons.payments,

                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => BillingManagementPage(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name,
                            ),
                          ),
                        );
                      },
                    ),

                    _DashboardCard(
                      width: cardWidth,
                      title: 'ตั้งค่าเครื่องพิมพ์',
                      subtitle: 'Bluetooth / เครื่องพิมพ์ใบเสร็จ',
                      icon: Icons.print,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrinterSettingsPage(),
                          ),
                        );
                      },
                    ),

                    _DashboardCard(
                      width: cardWidth,
                      title: 'สรุปยอดขาย',
                      subtitle: 'รายวัน รายเดือน และรายปี',
                      icon: Icons.bar_chart,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalesSummaryPage(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('กำลังทำส่วนนี้ต่อ')));
  }
}

class _DashboardCard extends StatelessWidget {
  final double width;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 170,

      child: Card(
        clipBehavior: Clip.antiAlias,

        child: InkWell(
          onTap: onTap,

          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(
                  icon,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const Spacer(),

                Text(title, style: Theme.of(context).textTheme.titleLarge),

                const SizedBox(height: 4),

                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantHeader extends StatelessWidget {
  final AuthRestaurant restaurant;

  const _RestaurantHeader({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,

            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),

              child:
                  restaurant.imageUrl != null && restaurant.imageUrl!.isNotEmpty
                  ? Image.network(
                      AppConfig.imageUrl(restaurant.imageUrl),

                      fit: BoxFit.cover,

                      errorBuilder: (context, error, stackTrace) {
                        return _logoPlaceholder();
                      },
                    )
                  : _logoPlaceholder(),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  restaurant.name,

                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.circle, size: 10),

                    const SizedBox(width: 6),

                    Text(restaurant.status),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  'Restaurant Dashboard',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,

      child: const Icon(Icons.storefront, size: 44),
    );
  }
}
