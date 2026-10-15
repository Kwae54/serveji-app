import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_provider.dart';
import '../features/restaurant/presentation/restaurant_management_page.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serveji Admin'),

        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),

            child: Center(child: Text(auth?.user.displayName ?? '')),
          ),

          IconButton(
            tooltip: 'ออกจากระบบ',

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
              'Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: 240,
              height: 150,

              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (_) => const RestaurantManagementPage(),
                      ),
                    );
                  },

                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(Icons.storefront, size: 48),

                      SizedBox(height: 12),

                      Text('จัดการร้านอาหาร'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
