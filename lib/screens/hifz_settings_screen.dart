import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../providers/ble_remote_provider.dart';
import '../providers/settings_provider.dart';

class HifzSettingsScreen extends StatelessWidget {
  const HifzSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memorization Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Input Mode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          RadioListTile<HifzInputMode>(
            title: const Text('Bluetooth Remote / Shutter'),
            subtitle: const Text('Uses volume keys. In-app volume control is disabled.'),
            value: HifzInputMode.bluetoothShutter,
            groupValue: settings.hifzInputMode,
            onChanged: (value) {
              if (value != null) {
                settings.setHifzInputMode(value);
              }
            },
          ),
          RadioListTile<HifzInputMode>(
            title: const Text('BLE Smart Ring'),
            subtitle: const Text('Connect to a dedicated BLE device.'),
            value: HifzInputMode.bleSmartRing,
            groupValue: settings.hifzInputMode,
            onChanged: (value) {
              if (value != null) {
                settings.setHifzInputMode(value);
              }
            },
          ),
          if (settings.hifzInputMode == HifzInputMode.bleSmartRing) ...[
            const Divider(height: 32),
            const BleDeviceManagementUI(),
          ],
        ],
      ),
    );
  }
}

class BleDeviceManagementUI extends StatelessWidget {
  const BleDeviceManagementUI({super.key});

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleRemoteProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    String statusText = 'Unknown';
    Color statusColor = Colors.grey;

    switch (bleProvider.connectionState) {
      case BleConnectionState.disconnected:
        statusText = 'Disconnected';
        statusColor = Colors.grey;
        break;
      case BleConnectionState.scanning:
        statusText = 'Scanning...';
        statusColor = Colors.blue;
        break;
      case BleConnectionState.connecting:
        statusText = 'Connecting...';
        statusColor = Colors.orange;
        break;
      case BleConnectionState.connected:
        statusText = 'Connected to ${bleProvider.connectedDevice?.platformName ?? 'Device'}';
        statusColor = Colors.green;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart Ring Management', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, color: statusColor),
                const SizedBox(width: 8),
                Text(statusText, style: textTheme.bodyLarge?.copyWith(color: statusColor)),
              ],
            ),
            if (bleProvider.connectionState == BleConnectionState.connected)
              OutlinedButton(
                onPressed: () => bleProvider.disconnect(),
                child: const Text('Disconnect'),
              )
            else
              FilledButton(
                onPressed: bleProvider.connectionState == BleConnectionState.scanning
                    ? null
                    : () => bleProvider.startScan(),
                child: const Text('Scan'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (bleProvider.connectionState == BleConnectionState.scanning)
          const Center(child: CircularProgressIndicator()),
        if (bleProvider.scanResults.isNotEmpty && bleProvider.connectionState != BleConnectionState.connected)
          ...bleProvider.scanResults.map((result) {
            if (result.device.platformName.isEmpty) return const SizedBox.shrink();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(result.device.platformName),
                subtitle: Text(result.device.remoteId.toString()),
                trailing: Text('${result.rssi} dBm'),
                onTap: () => bleProvider.connectToDevice(result.device),
              ),
            );
          }).toList(),
      ],
    );
  }
}