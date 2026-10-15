import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/restaurant_repository.dart';
import '../model/restaurant.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => RestaurantRepository(),
);

final restaurantProvider =
    AsyncNotifierProvider<RestaurantNotifier, List<Restaurant>>(
      RestaurantNotifier.new,
    );

class RestaurantNotifier extends AsyncNotifier<List<Restaurant>> {
  Timer? _searchTimer;

  String _currentSearch = '';

  RestaurantRepository get repository => ref.read(restaurantRepositoryProvider);

  @override
  Future<List<Restaurant>> build() {
    ref.onDispose(() {
      _searchTimer?.cancel();
    });

    return repository.getRestaurants();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => repository.getRestaurants(search: _currentSearch),
    );
  }

  void search(String keyword) {
    _currentSearch = keyword.trim();

    _searchTimer?.cancel();

    _searchTimer = Timer(const Duration(milliseconds: 1000), () async {
      state = await AsyncValue.guard(
        () => repository.getRestaurants(search: _currentSearch),
      );
    });
  }

  Future<void> createRestaurant({required String name}) async {
    await repository.createRestaurant(name: name);

    await refresh();
  }

  Future<void> updateRestaurant({
    required String restaurantId,
    required String name,
  }) async {
    await repository.updateRestaurant(restaurantId: restaurantId, name: name);

    await refresh();
  }

  Future<void> updateStatus({
    required String restaurantId,
    required String status,
  }) async {
    await repository.updateStatus(restaurantId: restaurantId, status: status);

    await refresh();
  }

  Future<void> uploadImage({
    required String restaurantId,
    required List<int> bytes,
    required String fileName,
  }) async {
    await repository.uploadImage(
      restaurantId: restaurantId,
      bytes: bytes,
      fileName: fileName,
    );

    await refresh();
  }

  Future<void> uploadPaymentQR({
    required String restaurantId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await repository.uploadPaymentQR(
      restaurantId: restaurantId,
      bytes: bytes,
      fileName: fileName,
    );

    await refresh();
  }

  Future<void> deletePaymentQR({required String restaurantId}) async {
    await repository.deletePaymentQR(restaurantId: restaurantId);

    await refresh();
  }
}
