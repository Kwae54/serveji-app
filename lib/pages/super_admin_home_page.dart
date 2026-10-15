import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_provider.dart';
import '../features/user/presentation/user_management_page.dart';
import '../features/restaurant/presentation/restaurant_management_page.dart';
import '../features/admin/presentation/app_download_page.dart';

class SuperAdminHomePage extends ConsumerWidget {
  const SuperAdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serveji Admin'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'สวัสดี ${auth?.user.displayName ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 16,

              children: [
                _MenuCard(
                  title: 'จัดการผู้ใช้งาน',
                  icon: Icons.people,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserManagementPage(),
                      ),
                    );
                  },
                ),

                _MenuCard(
                  title: 'จัดการร้าน',
                  icon: Icons.storefront,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RestaurantManagementPage(),
                      ),
                    );
                  },
                ),

                _MenuCard(
                  title: 'ดาวน์โหลดแอป',
                  icon: Icons.android,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppDownloadPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 150,

      child: Card(
        child: InkWell(
          onTap: onTap,

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(icon, size: 48),

              const SizedBox(height: 12),

              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
