import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reebaplus_pos/core/utils/logger.dart';

class PrinterService {
  static const _lastMacKey = 'last_printer_mac';

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

  /// Persists the MAC of the printer the user last successfully connected to
  /// via [PrinterPicker]. Read by [autoConnect] on next launch.
  Future<void> saveLastConnectedMac(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastMacKey, mac);
  }

  Future<bool> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_lastMacKey);
      if (savedMac != null && savedMac.isNotEmpty) {
        final paired = await getPairedDevices();
        final match = paired.where((d) => d.macAdress == savedMac).toList();
        if (match.isNotEmpty) {
          AppLogger.info('Auto-connecting to saved printer ${match.first.name}');
          if (await connect(savedMac)) return true;
        }
      }
      return await _autoConnectByName();
    } catch (e) {
      AppLogger.error('Auto-connect failed: $e');
      return false;
    }
  }

  /// Fallback for first-run / no-saved-MAC state. Matches by substring on the
  /// device name — brittle, but preserved for users who haven't picked a
  /// printer yet.
  Future<bool> _autoConnectByName() async {
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

  /// Writes bytes without attempting auto-connect. Use this after the user
  /// has manually selected a device through the [PrinterPicker].
  Future<bool> printBytesDirectly(List<int> bytes) async {
    try {
      if (!await isConnected) return false;
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      AppLogger.error('Direct printing failed: $e');
      return false;
    }
  }
}

