import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'printer_device.dart';

class BluetoothPrinterService {
  static const String _printerNameKey = 'serveji_printer_name';
  static const String _printerAddressKey = 'serveji_printer_address';

  Future<bool> requestPermission() async {
    try {
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;

      if (granted) {
        return true;
      }

      await PrintBluetoothThermal.pairedBluetooths;

      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBluetoothEnabled() async {
    return PrintBluetoothThermal.bluetoothEnabled;
  }

  Future<List<PrinterDevice>> getPairedDevices() async {
    final devices = await PrintBluetoothThermal.pairedBluetooths;

    return devices
        .map(
          (device) =>
              PrinterDevice(name: device.name, address: device.macAdress),
        )
        .toList();
  }

  Future<bool> connect(String macAddress) async {
    final connected = await PrintBluetoothThermal.connectionStatus;

    if (connected) {
      await PrintBluetoothThermal.disconnect;
    }

    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<bool> isConnected() async {
    return PrintBluetoothThermal.connectionStatus;
  }

  Future<bool> disconnect() async {
    return PrintBluetoothThermal.disconnect;
  }

  // ===== เพิ่มส่วนนี้ =====

  Future<void> savePrinter(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_printerNameKey, device.name);
    await prefs.setString(_printerAddressKey, device.address);
  }

  Future<PrinterDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString(_printerNameKey);
    final address = prefs.getString(_printerAddressKey);

    if (name == null || address == null || address.isEmpty) {
      return null;
    }

    return PrinterDevice(name: name, address: address);
  }

  Future<bool> ensureConnectedToSavedPrinter() async {
    final savedPrinter = await getSavedPrinter();

    if (savedPrinter == null) {
      throw Exception(
        'ยังไม่ได้ตั้งค่าเครื่องพิมพ์ กรุณาเข้าเมนูตั้งค่าเครื่องพิมพ์ก่อน',
      );
    }

    final permission = await requestPermission();

    if (!permission) {
      throw Exception('ไม่ได้รับอนุญาตให้ใช้งาน Bluetooth');
    }

    final enabled = await isBluetoothEnabled();

    if (!enabled) {
      throw Exception('กรุณาเปิด Bluetooth');
    }

    final connected = await isConnected();

    if (connected) {
      return true;
    }

    return connect(savedPrinter.address);
  }

  Future<bool> writeBytes(List<int> bytes) async {
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<bool> testPrint() async {
    final connected = await PrintBluetoothThermal.connectionStatus;

    if (!connected) {
      throw Exception('Printer is not connected');
    }

    // testPrint เดิมของคุณเก็บไว้ได้
    // ไม่ต้องเปลี่ยนถ้าตอนนี้พิมพ์ Test สำเร็จแล้ว

    return true;
  }
}
