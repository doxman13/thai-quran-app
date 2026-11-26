import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BleRemoteProvider extends ChangeNotifier {
  static const String _bleDevicePrefKey = 'ble_remote_device_id';
  static const String _bleDeviceNamePrefKey = 'ble_remote_device_name';

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  final List<StreamSubscription<List<int>>> _notificationSubscriptions = [];

  String? _savedDeviceId;
  String? _savedDeviceName;
  String? _errorMessage;

  int _clickCount = 0;
  int? _lastMode;
  final Map<int, int> _lastCounts = {};
  List<int>? _lastNotificationValue;
  DateTime? _lastNotificationTime;
  DateTime? _lastClickTime;

  BleConnectionState get connectionState => _connectionState;
  List<ScanResult> get scanResults => _scanResults;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  int get clickCount => _clickCount;
  String? get savedDeviceId => _savedDeviceId;
  String? get savedDeviceName => _savedDeviceName;
  String? get errorMessage => _errorMessage;

  static String resolveDeviceName(ScanResult result) {
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.advName.isNotEmpty) {
      return result.device.advName;
    }
    return '';
  }

  BleRemoteProvider({bool autoConnect = true}) {
    _loadAndMaybeAutoConnect(autoConnect: autoConnect);
  }

  Future<void> _loadAndMaybeAutoConnect({required bool autoConnect}) async {
    final prefs = await SharedPreferences.getInstance();
    _savedDeviceId = prefs.getString(_bleDevicePrefKey);
    _savedDeviceName = prefs.getString(_bleDeviceNamePrefKey);
    notifyListeners();
    if (autoConnect && !kIsWeb && _savedDeviceId != null) {
      final device = BluetoothDevice.fromId(_savedDeviceId!);
      await connectToDevice(device, isAutoConnect: true);
    }
  }

  Future<void> connectToSavedDevice() async {
    if (_savedDeviceId != null) {
      final device = BluetoothDevice.fromId(_savedDeviceId!);
      await connectToDevice(device);
    }
  }

  Future<BluetoothAdapterState> _waitForAdapterState() async {
    try {
      return await FlutterBluePlus.adapterState
          .where((state) => state != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      try {
        return await FlutterBluePlus.adapterState.first;
      } catch (_) {
        return BluetoothAdapterState.unknown;
      }
    }
  }

  Future<void> startScan() async {
    if (_connectionState == BleConnectionState.scanning) return;

    _errorMessage = null;
    if (kIsWeb) {
      _errorMessage = 'Bluetooth scanning is not supported on web.';
      notifyListeners();
      return;
    }

    var adapterState = await _waitForAdapterState();
    if (adapterState != BluetoothAdapterState.on) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await FlutterBluePlus.turnOn();
          adapterState = await _waitForAdapterState();
        } catch (e) {
          debugPrint('Error turning on Bluetooth: $e');
        }
      }
      if (adapterState != BluetoothAdapterState.on) {
        _errorMessage = adapterState == BluetoothAdapterState.unauthorized
            ? 'Bluetooth permission is required. Please enable it in Settings.'
            : 'Please turn on Bluetooth to scan for devices.';
        notifyListeners();
        return;
      }
    }

    await _scanResultsSubscription?.cancel();
    await _isScanningSubscription?.cancel();

    _connectionState = BleConnectionState.scanning;
    _scanResults = [];
    notifyListeners();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      final sorted = List<ScanResult>.from(results)
        ..sort((a, b) {
          final aNamed = resolveDeviceName(a).isNotEmpty ? 0 : 1;
          final bNamed = resolveDeviceName(b).isNotEmpty ? 0 : 1;
          if (aNamed != bNamed) return aNamed.compareTo(bNamed);
          return b.rssi.compareTo(a.rssi);
        });
      _scanResults = sorted;
      notifyListeners();
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _connectionState == BleConnectionState.scanning) {
        _connectionState = BleConnectionState.disconnected;
        notifyListeners();
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('Error starting BLE scan: $e');
      _errorMessage = 'Unable to start Bluetooth scan.';
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping BLE scan: $e');
    }
    if (_connectionState == BleConnectionState.scanning) {
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> connectToDevice(
    BluetoothDevice device, {
    bool isAutoConnect = false,
  }) async {
    _errorMessage = null;
    if (_connectionState == BleConnectionState.scanning) {
      await stopScan();
    }

    await _cleanupActiveConnection(clearSaved: false);

    _connectionState = BleConnectionState.connecting;
    notifyListeners();

    var hasSeenConnected = false;
    try {
      _connectionSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          hasSeenConnected = true;
          _connectedDevice = device;
          _connectionState = BleConnectionState.connected;

          String name = device.platformName;
          if (name.isEmpty && device.advName.isNotEmpty) {
            name = device.advName;
          }
          if (name.isEmpty) {
            for (final r in _scanResults) {
              if (r.device.remoteId == device.remoteId) {
                final resolved = resolveDeviceName(r);
                if (resolved.isNotEmpty) {
                  name = resolved;
                  break;
                }
              }
            }
          }
          if (name.isEmpty &&
              _savedDeviceName != null &&
              _savedDeviceName!.isNotEmpty) {
            name = _savedDeviceName!;
          }

          await _discoverServicesAndListen(device);
          await _saveDevice(device.remoteId.toString(), name: name);
          notifyListeners();
        } else if (state == BluetoothConnectionState.disconnected &&
            hasSeenConnected) {
          await _cleanupActiveConnection(clearSaved: false);
          notifyListeners();
        }
      });

      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 12),
      );
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      await _cleanupActiveConnection(clearSaved: false);
      if (!isAutoConnect) {
        _errorMessage = 'Could not connect to device. Make sure it is awake and nearby.';
      }
      notifyListeners();
    }
  }

  Future<void> _discoverServicesAndListen(BluetoothDevice device) async {
    try {
      for (var sub in _notificationSubscriptions) {
        await sub.cancel();
      }
      _notificationSubscriptions.clear();

      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error discovering services or listening to characteristics: $e');
    }
  }

  bool _canCountClick() {
    if (_lastClickTime == null) return true;
    return DateTime.now().difference(_lastClickTime!).inMilliseconds >= 150;
  }

  void _handleNotification(List<int> value) {
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMilliseconds < 100 &&
        _listEquals(_lastNotificationValue, value)) {
      debugPrint('Ignoring duplicate BLE notification: $value');
      return;
    }
    _lastNotificationTime = now;
    _lastNotificationValue = List<int>.from(value);

    debugPrint('Received BLE notification: $value');

    if (value.isEmpty) return;

    if (value.first == 0x06) {
      if (value.length <= 4) {
        if (value.length > 1) {
          final mode = value[1];
          if (mode != _lastMode) {
            _lastMode = mode;
            _lastCounts[mode] = 0;
            debugPrint('BEIQI-S7 mode sync: $mode');
          }
        }
        return;
      }

      final mode = value[1];
      final count = value[4];

      if (mode != _lastMode) {
        _lastMode = mode;
        _lastCounts[mode] = count;
        debugPrint('BEIQI-S7 mode changed to $mode, baseline count set to $count.');
        return;
      }

      if (count == 0x00) {
        _lastCounts[mode] = 0;
        debugPrint('BEIQI-S7 counter reset to 0 for mode $mode.');
        return;
      }

      if (count > (_lastCounts[mode] ?? 0)) {
        if (!_canCountClick()) {
          debugPrint('BEIQI-S7 click ignored (cooldown). Mode: $mode, Count: $count.');
          return;
        }
        _lastCounts[mode] = count;
        _clickCount++;
        _lastClickTime = now;
        notifyListeners();
        debugPrint('BEIQI-S7 click counted. Mode: $mode, Count: $count.');
      }
      return;
    }

    if (!_canCountClick()) {
      debugPrint('Fallback click ignored (cooldown).');
      return;
    }
    _triggerClick();
    _lastClickTime = now;
  }

  bool _listEquals(List<int>? a, List<int> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _triggerClick() {
    _clickCount++;
    notifyListeners();
  }

  @visibleForTesting
  void handleNotificationForTest(List<int> value) => _handleNotification(value);

  Future<void> _cleanupActiveConnection({required bool clearSaved}) async {
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
    _lastMode = null;
    _lastCounts.clear();
    _lastNotificationValue = null;
    _lastNotificationTime = null;
    _lastClickTime = null;
    if (clearSaved) {
      await _clearSavedDevice();
    }
  }

  Future<void> disconnect({bool forgetDevice = true}) async {
    await _cleanupActiveConnection(clearSaved: forgetDevice);
    notifyListeners();
  }

  Future<void> _saveDevice(String deviceId, {String? name}) async {
    _savedDeviceId = deviceId;
    if (name != null && name.isNotEmpty) {
      _savedDeviceName = name;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bleDevicePrefKey, deviceId);
    if (_savedDeviceName != null && _savedDeviceName!.isNotEmpty) {
      await prefs.setString(_bleDeviceNamePrefKey, _savedDeviceName!);
    }
  }

  Future<void> _clearSavedDevice() async {
    _savedDeviceId = null;
    _savedDeviceName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bleDevicePrefKey);
    await prefs.remove(_bleDeviceNamePrefKey);
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
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