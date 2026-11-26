import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/ble_remote_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Standalone Hifz Controls & Bluetooth Devices screen.
class HifzSettingsScreen extends StatelessWidget {
  final bool isEmbedded;

  const HifzSettingsScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isThai = settings.languageCode == 'th';
    final colors = AppTheme.colors(
      isDark: Theme.of(context).brightness == Brightness.dark,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: isEmbedded
          ? null
          : AppBar(
              title: Text(
                isThai ? 'ตั้งค่าฮิฟซ์และรีโมท' : 'Hifz Controls & Devices',
                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
              ),
            ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: HifzControlsContent(),
        ),
      ),
    );
  }
}

/// Modal bottom sheet for configuring Hifz input mode and Bluetooth remotes
/// directly over any screen without navigating away to Profile Settings.
class HifzControlsSheet {
  static Future<void> show(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThai = settings.languageCode == 'th';
    final colors = settings.getAppColors();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isThai
                            ? 'อุปกรณ์ฮิฟซ์ & รีโมทเปลี่ยนหน้า'
                            : 'Hifz Remote & BLE Devices',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colors.textStrong,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: HifzControlsContent(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isThai ? 'เสร็จสิ้น' : 'Done',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Phone-friendly selector for Hifz tally/remote input mode and BLE Smart Ring pairing.
class HifzControlsContent extends StatelessWidget {
  const HifzControlsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final bleProvider = Provider.of<BleRemoteProvider>(context);
    final isThai = settings.languageCode == 'th';
    final colors = AppTheme.colors(
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    final showBlePanel =
        settings.hifzInputMode == HifzInputMode.bleSmartRing ||
        bleProvider.connectionState == BleConnectionState.connected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isThai ? 'วิธีเลื่อนอายะฮฺขณะท่องจำ' : 'Hifz Input Mode',
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        _InputModeTile(
          title: isThai ? 'ปุ่มนับบนหน้าจอ' : 'In-App Tally Button',
          subtitle: isThai
              ? 'แตะปุ่มบนจอเพื่อบันทึกแต่ละรอบ'
              : 'Tap the on-screen tally button',
          icon: Icons.touch_app_rounded,
          iconColor: colors.primary,
          isSelected: settings.hifzInputMode == HifzInputMode.inAppTally,
          colors: colors,
          onTap: () => settings.setHifzInputMode(HifzInputMode.inAppTally),
        ),
        const SizedBox(height: 8),
        _InputModeTile(
          title: isThai
              ? 'รีโมทบลูทูธ / ชัตเตอร์ / ปุ่มเสียง'
              : 'Bluetooth Remote / Shutter',
          subtitle: isThai
              ? 'ใช้รีโมทชัตเตอร์บลูทูธหรือปุ่มปรับเสียงเลื่อนนับรอบ'
              : 'Use a Bluetooth shutter, page turner, or volume key',
          icon: Icons.bluetooth_searching_rounded,
          iconColor: const Color(0xFF0284C7),
          isSelected: settings.hifzInputMode == HifzInputMode.bluetoothShutter,
          colors: colors,
          onTap: () => settings.setHifzInputMode(HifzInputMode.bluetoothShutter),
        ),
        const SizedBox(height: 8),
        _InputModeTile(
          title: isThai ? 'แหวน Smart Ring (BLE)' : 'BLE Smart Ring',
          subtitle: isThai
              ? 'เชื่อมต่อ Smart Tasbih / Zikir Ring / iQibla'
              : 'Connect Smart Tasbih, Zikir Ring, or iQibla',
          icon: Icons.watch_rounded,
          iconColor: const Color(0xFF7C3AED),
          isSelected: settings.hifzInputMode == HifzInputMode.bleSmartRing,
          colors: colors,
          onTap: () => settings.setHifzInputMode(HifzInputMode.bleSmartRing),
        ),
        if (settings.hifzInputMode == HifzInputMode.bluetoothShutter) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isThai
                        ? 'เชื่อมต่อรีโมทชัตเตอร์ในการตั้งค่าบลูทูธของมือถือ แล้วกดปุ่มรีโมทหรือปุ่มเสียงขณะอยู่ในหน้าท่องจำเพื่อเลื่อนนับรอบ'
                        : 'Pair your Bluetooth shutter or page turner in your phone Bluetooth settings, then press it during Hifz memorization to advance.',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: colors.textStrong,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showBlePanel) ...[
          const SizedBox(height: 14),
          const BleDeviceManagementUI(),
        ],
      ],
    );
  }
}

class _InputModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final AppThemeColors colors;
  final VoidCallback onTap;

  const _InputModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: BorderSide(
          color: isSelected ? colors.primary : colors.borderSoft,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: colors.textStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BleDeviceManagementUI extends StatelessWidget {
  const BleDeviceManagementUI({super.key});

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleRemoteProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThai = settings.languageCode == 'th';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    final deviceName = (bleProvider.connectedDevice?.platformName.isNotEmpty == true)
        ? bleProvider.connectedDevice!.platformName
        : (bleProvider.connectedDevice?.advName.isNotEmpty == true
            ? bleProvider.connectedDevice!.advName
            : (bleProvider.savedDeviceName?.isNotEmpty == true
                ? bleProvider.savedDeviceName
                : null));

    final deviceId = bleProvider.connectedDevice?.remoteId.toString() ??
        bleProvider.savedDeviceId;

    final discovered = bleProvider.scanResults.where((result) {
      return BleRemoteProvider.resolveDeviceName(result).isNotEmpty;
    }).toList();

    switch (bleProvider.connectionState) {
      case BleConnectionState.disconnected:
        statusText = bleProvider.savedDeviceId != null
            ? (isThai ? 'ไม่ได้เชื่อมต่อ' : 'Disconnected')
            : (isThai ? 'ยังไม่เชื่อมต่ออุปกรณ์' : 'Not Connected');
        statusColor = colorScheme.onSurfaceVariant;
        statusIcon = Icons.bluetooth_disabled_rounded;
        break;
      case BleConnectionState.scanning:
        statusText = isThai ? 'กำลังค้นหาอุปกรณ์...' : 'Scanning for devices...';
        statusColor = colorScheme.primary;
        statusIcon = Icons.bluetooth_searching_rounded;
        break;
      case BleConnectionState.connecting:
        statusText = isThai ? 'กำลังเชื่อมต่อ...' : 'Connecting...';
        statusColor = colorScheme.tertiary;
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
      case BleConnectionState.connected:
        statusText = isThai
            ? 'เชื่อมต่อกับ ${deviceName ?? 'Smart Ring'} แล้ว'
            : 'Connected to ${deviceName ?? 'Smart Ring'}';
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.watch_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isThai ? 'จัดการแหวน BLE (Smart Ring)' : 'Smart Ring Management',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isThai
                ? 'รองรับ Smart Tasbih, Zikir Ring, Bluetooth Tasbih, iQibla Ring ฯลฯ'
                : 'Supported devices: Smart Tasbih, Zikir Ring, Bluetooth Tasbih, iQibla Ring, etc.',
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
                              deviceName != null &&
                                      bleProvider.connectionState !=
                                          BleConnectionState.connected
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
                if (bleProvider.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    bleProvider.errorMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (bleProvider.connectionState == BleConnectionState.connected)
                      OutlinedButton.icon(
                        onPressed: () => bleProvider.disconnect(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.link_off_rounded, size: 16),
                        label: Text(isThai ? 'ตัดการเชื่อมต่อ' : 'Disconnect'),
                      )
                    else ...[
                      if (bleProvider.savedDeviceId != null &&
                          bleProvider.connectionState ==
                              BleConnectionState.disconnected)
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await bleProvider.connectToSavedDevice();
                            if (bleProvider.connectionState ==
                                BleConnectionState.connected) {
                              await settings.setHifzInputMode(
                                HifzInputMode.bleSmartRing,
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: Text(
                            isThai ? 'เชื่อมต่อเครื่องเดิม' : 'Connect Saved',
                          ),
                        ),
                      if (bleProvider.connectionState ==
                          BleConnectionState.scanning)
                        OutlinedButton.icon(
                          onPressed: () => bleProvider.stopScan(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          label: Text(isThai ? 'หยุดสแกน' : 'Stop Scan'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: bleProvider.connectionState ==
                                  BleConnectionState.connecting
                              ? null
                              : () => bleProvider.startScan(),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 16),
                          label: Text(
                            isThai ? 'สแกนหาอุปกรณ์' : 'Scan Devices',
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (discovered.isNotEmpty &&
              bleProvider.connectionState != BleConnectionState.connected) ...[
            const SizedBox(height: 12),
            Text(
              isThai
                  ? 'อุปกรณ์ที่พบ (${discovered.length})'
                  : 'Discovered Devices (${discovered.length})',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                primary: false,
                itemCount: discovered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final result = discovered[index];
                  final resolvedName =
                      BleRemoteProvider.resolveDeviceName(result);
                  return Material(
                    color: colorScheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            colorScheme.primaryContainer.withValues(alpha: 0.5),
                        child: Icon(
                          Icons.watch_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        resolvedName,
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
                      onTap: () async {
                        await bleProvider.connectToDevice(result.device);
                        if (bleProvider.connectionState ==
                            BleConnectionState.connected) {
                          await settings.setHifzInputMode(
                            HifzInputMode.bleSmartRing,
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
