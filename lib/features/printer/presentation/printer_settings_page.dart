import 'package:flutter/material.dart';

import '../../../core/printer/bluetooth_printer_service.dart';
import '../../../core/printer/printer_device.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();

  List<PrinterDevice> _devices = [];

  PrinterDevice? _selectedDevice;

  bool _loading = false;
  bool _connected = false;

  String? _message;

  @override
  void initState() {
    super.initState();

    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final permission = await _printerService.requestPermission();

      if (!permission) {
        setState(() {
          _message = 'กรุณาอนุญาตสิทธิ์อุปกรณ์ใกล้เคียง';
        });

        return;
      }

      final bluetoothEnabled = await _printerService.isBluetoothEnabled();

      if (!bluetoothEnabled) {
        setState(() {
          _message = 'กรุณาเปิด Bluetooth';
        });

        return;
      }

      final devices = await _printerService.getPairedDevices();

      final connected = await _printerService.isConnected();

      setState(() {
        _devices = devices;
        _connected = connected;

        if (devices.isEmpty) {
          _message = 'ไม่พบอุปกรณ์ Bluetooth ที่จับคู่ไว้';
        }
      });
    } catch (error) {
      setState(() {
        _message = 'โหลดเครื่องพิมพ์ไม่สำเร็จ: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    final device = _selectedDevice;

    if (device == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกเครื่องพิมพ์')));

      return;
    }

    setState(() {
      _loading = true;
      _message = 'กำลังเชื่อมต่อ ${device.name}...';
    });

    try {
      final result = await _printerService.connect(device.address);

      if (result) {
        await _printerService.savePrinter(device);
      }

      setState(() {
        _connected = result;

        _message = result
            ? 'เชื่อมต่อ ${device.name} สำเร็จ'
            : 'เชื่อมต่อไม่สำเร็จ';
      });
    } catch (error) {
      setState(() {
        _connected = false;
        _message = 'เชื่อมต่อไม่สำเร็จ: $error';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _testPrint() async {
    setState(() {
      _loading = true;
    });

    try {
      final result = await _printerService.testPrint();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? 'ส่งงานพิมพ์สำเร็จ' : 'ส่งงานพิมพ์ไม่สำเร็จ'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('พิมพ์ไม่สำเร็จ: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าเครื่องพิมพ์')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'เครื่องพิมพ์ Bluetooth',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<PrinterDevice>(
              value: _selectedDevice,
              decoration: const InputDecoration(
                labelText: 'เลือกเครื่องพิมพ์',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.print_outlined),
              ),
              items: _devices.map((device) {
                return DropdownMenuItem(
                  value: device,
                  child: Text('${device.name}  ${device.address}'),
                );
              }).toList(),
              onChanged: _loading
                  ? null
                  : (device) {
                      setState(() {
                        _selectedDevice = device;
                      });
                    },
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _loading ? null : _loadPrinters,
              icon: const Icon(Icons.refresh),
              label: const Text('ค้นหาเครื่องที่จับคู่ไว้'),
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _loading ? null : _connect,
              icon: const Icon(Icons.bluetooth),
              label: const Text('เชื่อมต่อ'),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Icon(
                  _connected ? Icons.check_circle : Icons.cancel,
                  color: _connected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(_connected ? 'เชื่อมต่อแล้ว' : 'ยังไม่ได้เชื่อมต่อ'),
              ],
            ),

            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],

            const SizedBox(height: 32),

            FilledButton.tonalIcon(
              onPressed: _connected && !_loading ? _testPrint : null,
              icon: const Icon(Icons.receipt_long),
              label: const Text('ทดสอบพิมพ์'),
            ),

            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
