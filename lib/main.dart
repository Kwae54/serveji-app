import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/auth_gate.dart';
import 'features/customer/presentation/customer_order_page.dart';

void main() {
  runApp(const ProviderScope(child: ServejiApp()));
}

class ServejiApp extends StatelessWidget {
  const ServejiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serveji',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),

      home: _buildHome(),
    );
  }
}

Widget _buildHome() {
  final sessionToken = Uri.base.queryParameters['sessionToken'];

  if (sessionToken != null && sessionToken.isNotEmpty) {
    return CustomerOrderPage(sessionToken: sessionToken);
  }

  return const AuthGate();
}
