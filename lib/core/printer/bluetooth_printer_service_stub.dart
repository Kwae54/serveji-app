import 'printer_device.dart';

class BluetoothPrinterService {
  Future<bool> requestPermission() async => false;

  Future<bool> isBluetoothEnabled() async => false;

  Future<List<PrinterDevice>> getPairedDevices() async => [];

  Future<bool> connect(String macAddress) async => false;

  Future<bool> isConnected() async => false;

  Future<bool> disconnect() async => false;

  Future<void> savePrinter(PrinterDevice device) async => false;

  Future<bool> testPrint() async {
    throw UnsupportedError('Bluetooth printing is not supported on Web');
  }
}
