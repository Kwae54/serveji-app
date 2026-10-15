import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_provider.dart';
import '../core/config/app_config.dart';

import 'restaurant_dashboard_page.dart';

class RestaurantHomePage extends ConsumerWidget {
  const RestaurantHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serveji'),
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
              auth?.user.displayName ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 24),

            const Text('ร้านที่ได้รับสิทธิ์'),

            const SizedBox(height: 12),

            ...?auth?.restaurants.map((restaurant) {
              return Card(
                child: ListTile(
                  leading: _RestaurantLogo(
                    imageUrl: restaurant.imageUrl,
                    size: 52,
                  ),

                  title: Text(restaurant.name),

                  subtitle: Text(restaurant.status),

                  trailing: const Icon(Icons.chevron_right),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RestaurantDashboardPage(restaurant: restaurant),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RestaurantLogo extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _RestaurantLogo({required this.imageUrl, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                AppConfig.imageUrl(imageUrl),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _placeholder();
                },
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      alignment: Alignment.center,
      color: Colors.grey.shade100,
      child: Icon(Icons.storefront, size: size * 0.55),
    );
  }
}
