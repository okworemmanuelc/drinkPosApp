import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:reebaplus_pos/core/utils/logger.dart';

class PrinterService {
  PrinterService();

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    }
    return true;
  }

  Future<bool> get isConnected async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  Future<List<BluetoothInfo>> getPairedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connect(String macAddress) async {
    try {
      AppLogger.info('Connecting to printer: $macAddress');
      return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    } catch (e) {
      AppLogger.error('Error connecting to printer: $e');
      return false;
    }
  }

  Future<bool> autoConnect() async {
    try {
      final paired = await getPairedDevices();
      final targetPrinters = paired.where((d) {
        final name = d.name.toLowerCase();
        return name.contains('bluetooth_mobile_printer') ||
            name.contains('mp583') ||
            name.contains('thermal') ||
            name.contains('printer');
      }).toList();

      if (targetPrinters.isNotEmpty) {
        final targetPrinter = targetPrinters.first;
        AppLogger.info('Auto-connecting to ${targetPrinter.name}');
        return await connect(targetPrinter.macAdress);
      }
    } catch (e) {
      AppLogger.error('Auto-connect failed: $e');
    }
    return false;
  }

  Future<bool> printBytes(List<int> bytes) async {
    try {
      if (!await isConnected) {
        final connected = await autoConnect();
        if (!connected) return false;
      }
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      AppLogger.error('Printing failed: $e');
      return false;
    }
  }
}

