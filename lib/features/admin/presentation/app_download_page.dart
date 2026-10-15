import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDownloadPage extends StatelessWidget {
  const AppDownloadPage({super.key});

  static const String _apkUrl =
      'https://213.35.114.21/downloads/serveji-latest.apk';

  Future<void> _download(BuildContext context) async {
    final uri = Uri.parse(_apkUrl);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถดาวน์โหลด APK ได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ดาวน์โหลดแอป Serveji')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.android, size: 72),

                    const SizedBox(height: 20),

                    Text(
                      'Serveji สำหรับ Android',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'สำหรับติดตั้งบน Tablet หรืออุปกรณ์ Android',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _download(context),
                        icon: const Icon(Icons.download),
                        label: const Text('ดาวน์โหลด APK'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
