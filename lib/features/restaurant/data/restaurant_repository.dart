import 'package:dio/dio.dart';

import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../model/restaurant.dart';

class RestaurantRepository {
  Future<List<Restaurant>> getRestaurants({String search = ''}) async {
    final response = await ApiClient.dio.get(
      '/restaurants',
      queryParameters: {if (search.trim().isNotEmpty) 'search': search.trim()},
    );

    final List data = response.data['data'] ?? [];

    return data
        .map((json) => Restaurant.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Restaurant> getRestaurant(String restaurantId) async {
    final response = await ApiClient.dio.get('/restaurants/$restaurantId');

    return Restaurant.fromJson(response.data['data']);
  }

  Future<Restaurant> createRestaurant({required String name}) async {
    final response = await ApiClient.dio.post(
      '/restaurants',
      data: {'name': name},
    );

    return Restaurant.fromJson(response.data['data']);
  }

  Future<Restaurant> updateRestaurant({
    required String restaurantId,
    required String name,
  }) async {
    final response = await ApiClient.dio.put(
      '/restaurants/$restaurantId',
      data: {'name': name},
    );

    return Restaurant.fromJson(response.data['data']);
  }

  Future<Restaurant> updateStatus({
    required String restaurantId,
    required String status,
  }) async {
    final response = await ApiClient.dio.patch(
      '/restaurants/$restaurantId/status',
      data: {'status': status},
    );

    return Restaurant.fromJson(response.data['data']);
  }

  Future<Restaurant> uploadImage({
    required String restaurantId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final response = await ApiClient.dio.post(
      '/restaurants/$restaurantId/image',
      data: formData,
    );

    return Restaurant.fromJson(response.data['data']);
  }

  Future<Restaurant> uploadPaymentQR({
    required String restaurantId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final response = await ApiClient.dio.post(
      '/restaurants/$restaurantId/payment-qr',
      data: formData,
    );

    return Restaurant.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Restaurant> deletePaymentQR({required String restaurantId}) async {
    final response = await ApiClient.dio.delete(
      '/restaurants/$restaurantId/payment-qr',
    );

    return Restaurant.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
