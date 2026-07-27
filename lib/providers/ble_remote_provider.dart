import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BleRemoteProvider extends ChangeNotifier {
  static const String _bleDevicePrefKey = 'ble_remote_device_id';

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  final List<StreamSubscription<List<int>>> _notificationSubscriptions = [];

  int _clickCount = 0;

  BleConnectionState get connectionState => _connectionState;
  List<ScanResult> get scanResults => _scanResults;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  int get clickCount => _clickCount;

  BleRemoteProvider() {
    _autoConnect();
  }

  Future<void> _autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_bleDevicePrefKey);
    if (deviceId != null) {
      final device = BluetoothDevice.fromId(deviceId);
      await connectToDevice(device);
    }
  }

  Future<void> startScan() async {
    if (_connectionState == BleConnectionState.scanning) return;

    // Ensure Bluetooth is turned on at the system level
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try {
        // Prompt user to enable Bluetooth
        await FlutterBluePlus.turnOn();
      } catch (e) {
        // This can happen if the user denies the request to turn on Bluetooth
        debugPrint('Error turning on Bluetooth: $e');
        return;
      }
    }

    _connectionState = BleConnectionState.scanning;
    _scanResults = [];
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
      );

      FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error starting BLE scan: $e');
    } finally {
      await Future.delayed(const Duration(seconds: 8));
      if (_connectionState == BleConnectionState.scanning) {
        stopScan();
      }
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    if (_connectionState == BleConnectionState.scanning) {
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_connectedDevice != null) {
      await disconnect();
    }

    _connectionState = BleConnectionState.connecting;
    notifyListeners();

    try {
      await device.connect(autoConnect: false);
      _connectionSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          _connectedDevice = device;
          _connectionState = BleConnectionState.connected;
          await _discoverServicesAndListen(device);
          await _saveDevice(device.remoteId.toString());
        } else if (state == BluetoothConnectionState.disconnected) {
          await disconnect();
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> _discoverServicesAndListen(BluetoothDevice device) async {
    try {
      // Clear previous subscriptions before discovering new ones
      for (var sub in _notificationSubscriptions) {
        await sub.cancel();
      }
      _notificationSubscriptions.clear();

      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          // Check if characteristic supports NOTIFY or INDICATE
          if (c.properties.notify || c.properties.indicate) {
            try {
              await c.setNotifyValue(true);
              final subscription = c.lastValueStream.listen((value) {
                _handleNotification(value);
              });
              _notificationSubscriptions.add(subscription);
              debugPrint('Subscribed to characteristic: ${c.uuid}');
            } catch (e) {
              debugPrint('Error subscribing to ${c.uuid}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error discovering services or listening to characteristics: $e');
    }
  }

  void _handleNotification(List<int> value) {
    debugPrint('Received BLE notification: $value');

    if (value.isEmpty) return;

    // BEIQI-S7 frame packet: header 0x06. Ignore reset packet (byte 1 is 0xFF).
    if (value.first == 0x06) {
      if (value.length > 1 && value[1] == 0xFF) {
        debugPrint('Ignoring BEIQI-S7 reset packet.');
        return;
      }
      debugPrint('BEIQI-S7 click detected.');
      _triggerClick();
      return;
    }

    // Fallback: any non-empty packet is a click. This covers simple shutters.
    _triggerClick();
  }

  void _triggerClick() {
    _clickCount++;
    notifyListeners();
  }

  Future<void> disconnect() async {
    for (var sub in _notificationSubscriptions) {
      await sub.cancel();
    }
    _notificationSubscriptions.clear();

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('Error during disconnect: $e');
      }
    }

    _connectedDevice = null;
    _connectionState = BleConnectionState.disconnected;
    await _clearSavedDevice();
    notifyListeners();
  }

  Future<void> _saveDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bleDevicePrefKey, deviceId);
  }

  Future<void> _clearSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bleDevicePrefKey);
  }

  @override
  void dispose() {
    stopScan();
    for (var sub in _notificationSubscriptions) {
      sub.cancel();
    }
    _connectionSubscription?.cancel();
    if (_connectedDevice != null) {
      _connectedDevice!.disconnect();
    }
    super.dispose();
  }
}