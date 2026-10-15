import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';

class CustomerEntryPage extends StatefulWidget {
  final String tableToken;

  const CustomerEntryPage({super.key, required this.tableToken});

  @override
  State<CustomerEntryPage> createState() => _CustomerEntryPageState();
}

class _CustomerEntryPageState extends State<CustomerEntryPage> {
  bool loading = true;

  String? error;

  Map<String, dynamic>? tableInfo;

  @override
  void initState() {
    super.initState();

    _loadTable();
  }

  Future<void> _loadTable() async {
    try {
      final response = await ApiClient.dio.get(
        '/public/table',
        queryParameters: {'tableToken': widget.tableToken},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        tableInfo = Map<String, dynamic>.from(response.data['data']);

        loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }

      final data = e.response?.data;

      setState(() {
        error = data is Map && data['message'] != null
            ? data['message'].toString()
            : 'ไม่สามารถโหลดข้อมูลโต๊ะได้';

        loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = 'เกิดข้อผิดพลาด กรุณาลองใหม่';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final restaurantName = tableInfo?['restaurantName'] ?? '';

    final tableNo = tableInfo?['tableNo'] ?? '';

    final tableName = tableInfo?['tableName'];

    return Scaffold(
      appBar: AppBar(title: const Text('Serveji')),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(Icons.restaurant, size: 72),

              const SizedBox(height: 24),

              Text(
                restaurantName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 12),

              Text(
                'โต๊ะ $tableNo',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              if (tableName != null && tableName.toString().isNotEmpty) ...[
                const SizedBox(height: 4),

                Text(tableName.toString()),
              ],

              const SizedBox(height: 32),

              const Text('QR Code ใช้งานได้แล้ว'),

              const SizedBox(height: 8),

              const Text(
                'ขั้นต่อไปจะเพิ่มรายการอาหารและตะกร้าสั่งอาหารตรงหน้านี้',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
