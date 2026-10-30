import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ble_remote_provider.dart';
import 'settings_screen.dart';

/// Unified Hifz Settings wrapper that delegates directly to [SettingsScreen]
/// opened at [SettingsCategoryTab.hifz], eliminating duplicate settings UI
/// across the application while keeping [BleDeviceManagementUI] available.
class HifzSettingsScreen extends StatelessWidget {
  final bool isEmbedded;

  const HifzSettingsScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(
      initialCategory: SettingsCategoryTab.hifz,
    );
  }
}

class BleDeviceManagementUI extends StatelessWidget {
  const BleDeviceManagementUI({super.key});

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleRemoteProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    final deviceName = (bleProvider.connectedDevice?.platformName.isNotEmpty == true)
        ? bleProvider.connectedDevice!.platformName
        : (bleProvider.savedDeviceName?.isNotEmpty == true
            ? bleProvider.savedDeviceName
            : null);

    final deviceId = bleProvider.connectedDevice?.remoteId.toString() ??
        bleProvider.savedDeviceId;

    switch (bleProvider.connectionState) {
      case BleConnectionState.disconnected:
        statusText = bleProvider.savedDeviceId != null ? 'Disconnected' : 'Not Connected';
        statusColor = colorScheme.onSurfaceVariant;
        statusIcon = Icons.bluetooth_disabled_rounded;
        break;
      case BleConnectionState.scanning:
        statusText = 'Scanning for rings...';
        statusColor = colorScheme.primary;
        statusIcon = Icons.bluetooth_searching_rounded;
        break;
      case BleConnectionState.connecting:
        statusText = 'Connecting...';
        statusColor = colorScheme.tertiary;
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
      case BleConnectionState.connected:
        statusText = 'Connected to ${deviceName ?? 'Smart Ring'}';
        statusColor = colorScheme.primary;
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Smart Ring Management',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Supported devices: Smart Tasbih, Zikir Ring, Bluetooth Tasbih, iQibla Ring, etc.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: textTheme.bodyMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (deviceId != null && deviceId.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              deviceName != null && bleProvider.connectionState != BleConnectionState.connected
                                  ? 'Saved: $deviceName ($deviceId)'
                                  : 'Device ID: $deviceId',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (bleProvider.connectionState == BleConnectionState.connected)
                      OutlinedButton.icon(
                        onPressed: () => bleProvider.disconnect(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.link_off_rounded, size: 16),
                        label: const Text('Disconnect'),
                      )
                    else ...[
                      if (bleProvider.savedDeviceId != null &&
                          bleProvider.connectionState == BleConnectionState.disconnected) ...[
                        FilledButton.tonalIcon(
                          onPressed: () => bleProvider.connectToSavedDevice(),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Connect Saved'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.icon(
                        onPressed: bleProvider.connectionState == BleConnectionState.scanning
                            ? null
                            : () => bleProvider.startScan(),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: bleProvider.connectionState == BleConnectionState.scanning
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.search_rounded, size: 16),
                        label: Text(
                          bleProvider.connectionState == BleConnectionState.scanning
                              ? 'Scanning'
                              : 'Scan Devices',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (bleProvider.scanResults.isNotEmpty && bleProvider.connectionState != BleConnectionState.connected) ...[
            const SizedBox(height: 12),
            Text(
              'Discovered Devices',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...bleProvider.scanResults.map((result) {
              if (result.device.platformName.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    child: Icon(
                      Icons.watch_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    result.device.platformName,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    result.device.remoteId.toString(),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${result.rssi} dBm',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => bleProvider.connectToDevice(result.device),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
