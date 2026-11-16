import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_update_dialog.dart';

/// Update status comparing the running app version against remote configuration.
enum AppUpdateStatus {
  upToDate,
  softUpdateAvailable,
  forceUpdateRequired,
}

/// Remote version configuration fetched from Supabase `public.app_version_config`.
class AppVersionConfig {
  final String platform;
  final String minVersion;
  final int minBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final bool isForceUpdate;
  final String updateUrl;
  final String titleTh;
  final String titleEn;
  final String messageTh;
  final String messageEn;
  final String? releaseNotesTh;
  final String? releaseNotesEn;

  const AppVersionConfig({
    required this.platform,
    required this.minVersion,
    required this.minBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.isForceUpdate,
    required this.updateUrl,
    required this.titleTh,
    required this.titleEn,
    required this.messageTh,
    required this.messageEn,
    this.releaseNotesTh,
    this.releaseNotesEn,
  });

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) {
    return AppVersionConfig(
      platform: (json['platform'] ?? '').toString().trim(),
      minVersion: (json['min_version'] ?? '1.0.0').toString().trim(),
      minBuildNumber: _parseInt(json['min_build_number'], fallback: 0),
      latestVersion: (json['latest_version'] ?? '1.0.0').toString().trim(),
      latestBuildNumber: _parseInt(json['latest_build_number'], fallback: 0),
      isForceUpdate: json['is_force_update'] == true,
      updateUrl: (json['update_url'] ?? '').toString().trim(),
      titleTh: _nonEmpty(
        json['title_th'],
        fallback: 'มีเวอร์ชันใหม่พร้อมใช้งาน',
      ),
      titleEn: _nonEmpty(json['title_en'], fallback: 'Update Available'),
      messageTh: _nonEmpty(
        json['message_th'],
        fallback:
            'กรุณาอัปเดตแอปพลิเคชัน Thai Quran เป็นเวอร์ชันล่าสุดเพื่อฟีเจอร์ใหม่และการทำงานที่สมบูรณ์',
      ),
      messageEn: _nonEmpty(
        json['message_en'],
        fallback:
            'Please update Thai Quran to the latest version for new features and improvements.',
      ),
      releaseNotesTh: _nullableNonEmpty(json['release_notes_th']),
      releaseNotesEn: _nullableNonEmpty(json['release_notes_en']),
    );
  }

  /// Localized dialog title.
  String title(bool isThai) => isThai ? titleTh : titleEn;

  /// Localized dialog body message.
  String message(bool isThai) => isThai ? messageTh : messageEn;

  /// Localized release notes, or null when none are provided.
  String? releaseNotes(bool isThai) {
    final primary = isThai ? releaseNotesTh : releaseNotesEn;
    if (primary != null && primary.isNotEmpty) return primary;
    final secondary = isThai ? releaseNotesEn : releaseNotesTh;
    return (secondary != null && secondary.isNotEmpty) ? secondary : null;
  }

  /// Canonical version+build identifier used for dismissal tracking.
  String get versionIdentifier => '$latestVersion+$latestBuildNumber';

  static int _parseInt(Object? raw, {required int fallback}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString().trim() ?? '') ?? fallback;
  }

  static String _nonEmpty(Object? raw, {required String fallback}) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableNonEmpty(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Outcome of evaluating the current installed build against remote config.
class AppUpdateCheckResult {
  final AppUpdateStatus status;
  final String currentVersion;
  final int currentBuildNumber;
  final AppVersionConfig? config;

  const AppUpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.config,
  });

  bool get hasUpdate => status != AppUpdateStatus.upToDate;
  bool get isForced => status == AppUpdateStatus.forceUpdateRequired;
}

/// Checks Supabase `public.app_version_config` for soft or mandatory app updates.
class AppUpdateService {
  static final AppUpdateService instance = AppUpdateService._();

  AppUpdateService._();

  static const String dismissedVersionKey = 'app_update_dismissed_version';
  static const String dismissedAtKey = 'app_update_dismissed_at';
  static const Duration softUpdateCooldown = Duration(hours: 24);
  static const Duration _requestTimeout = Duration(seconds: 6);

  bool _isChecking = false;
  bool _isDialogVisible = false;
  bool _hasAutoChecked = false;

  /// Resets in-memory guard flags for widget and unit tests.
  @visibleForTesting
  void resetForTesting() {
    _isChecking = false;
    _isDialogVisible = false;
    _hasAutoChecked = false;
  }

  /// Resolves the Supabase config platform key for the current runtime.
  static String? resolvePlatformKey({TargetPlatform? platformOverride}) {
    if (kIsWeb && platformOverride == null) return null;
    final target = platformOverride ?? defaultTargetPlatform;
    switch (target) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }

  /// Compares two semantic version strings (ignoring leading `v` or `+build` tags).
  static int compareSemver(String v1, String v2) {
    final parts1 = _parseVersionParts(v1);
    final parts2 = _parseVersionParts(v2);
    final maxLen =
        parts1.length > parts2.length ? parts1.length : parts2.length;

    for (var i = 0; i < maxLen; i++) {
      final a = i < parts1.length ? parts1[i] : 0;
      final b = i < parts2.length ? parts2[i] : 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }

  static List<int> _parseVersionParts(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    if (cleaned.isEmpty) return const [0, 0, 0];
    return cleaned.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  }

  /// Returns true when the running [currentVersion]/[currentBuild] is older than target.
  static bool isVersionOlder({
    required String currentVersion,
    required int currentBuild,
    required String targetVersion,
    required int targetBuild,
  }) {
    final cmp = compareSemver(currentVersion, targetVersion);
    if (cmp < 0) return true;
    if (cmp > 0) return false;
    if (targetBuild <= 0) return false;
    return currentBuild < targetBuild;
  }

  /// Evaluates whether an update is required, optional, or up to date.
  static AppUpdateCheckResult evaluateConfig({
    required String currentVersion,
    required int currentBuildNumber,
    required AppVersionConfig config,
  }) {
    if (!_isValidUpdateUrl(config.updateUrl)) {
      return AppUpdateCheckResult(
        status: AppUpdateStatus.upToDate,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        config: config,
      );
    }

    final belowMin = isVersionOlder(
      currentVersion: currentVersion,
      currentBuild: currentBuildNumber,
      targetVersion: config.minVersion,
      targetBuild: config.minBuildNumber,
    );
    if (belowMin) {
      return AppUpdateCheckResult(
        status: AppUpdateStatus.forceUpdateRequired,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        config: config,
      );
    }

    final belowLatest = isVersionOlder(
      currentVersion: currentVersion,
      currentBuild: currentBuildNumber,
      targetVersion: config.latestVersion,
      targetBuild: config.latestBuildNumber,
    );
    if (belowLatest) {
      return AppUpdateCheckResult(
        status: config.isForceUpdate
            ? AppUpdateStatus.forceUpdateRequired
            : AppUpdateStatus.softUpdateAvailable,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        config: config,
      );
    }

    return AppUpdateCheckResult(
      status: AppUpdateStatus.upToDate,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      config: config,
    );
  }

  static bool _isValidUpdateUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || trimmed.contains('YOUR_')) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty) return false;
    return const {'https', 'http', 'market', 'itms-apps'}.contains(uri.scheme);
  }

  /// Fetches the active update configuration from Supabase and evaluates it.
  Future<AppUpdateCheckResult?> checkForUpdate({
    Future<PackageInfo> Function()? packageInfoLoader,
    Future<AppVersionConfig?> Function(String platform)? configLoader,
    TargetPlatform? platformOverride,
  }) async {
    final platform = resolvePlatformKey(platformOverride: platformOverride);
    if (platform == null) return null;

    final packageInfo =
        await (packageInfoLoader?.call() ?? PackageInfo.fromPlatform());
    final currentVersion = packageInfo.version.split('+').first.trim();
    final currentBuild = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

    final config = await (configLoader?.call(platform) ??
        _fetchRemoteConfig(platform));
    if (config == null) return null;

    return evaluateConfig(
      currentVersion: currentVersion,
      currentBuildNumber: currentBuild,
      config: config,
    );
  }

  Future<AppVersionConfig?> _fetchRemoteConfig(String platform) async {
    final row = await Supabase.instance.client
        .from('app_version_config')
        .select()
        .eq('id', platform)
        .eq('is_active', true)
        .maybeSingle()
        .timeout(_requestTimeout);
    if (row == null) return null;
    return AppVersionConfig.fromJson(Map<String, dynamic>.from(row));
  }

  /// Returns true if a soft update for [config] was recently dismissed by the user.
  Future<bool> isSoftUpdateDismissed(
    AppVersionConfig config, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(dismissedVersionKey);
    if (dismissedVersion != config.versionIdentifier) return false;

    final dismissedAt = DateTime.tryParse(prefs.getString(dismissedAtKey) ?? '');
    if (dismissedAt == null) return false;

    final currentTime = now ?? DateTime.now().toUtc();
    return currentTime.difference(dismissedAt) < softUpdateCooldown;
  }

  /// Records that the user postponed a soft update so they aren't nagged immediately.
  Future<void> dismissSoftUpdate(
    AppVersionConfig config, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dismissedVersionKey, config.versionIdentifier);
    await prefs.setString(
      dismissedAtKey,
      (now ?? DateTime.now().toUtc()).toIso8601String(),
    );
  }

  /// Runs once per app launch to check for updates and display [AppUpdateDialog] if due.
  Future<void> checkAndPromptOnStartup(
    BuildContext context, {
    Future<PackageInfo> Function()? packageInfoLoader,
    Future<AppVersionConfig?> Function(String platform)? configLoader,
    TargetPlatform? platformOverride,
    DateTime? now,
  }) async {
    if (_hasAutoChecked || _isChecking || _isDialogVisible) return;
    _hasAutoChecked = true;
    await _runCheckAndPrompt(
      context,
      ignoreCooldown: false,
      packageInfoLoader: packageInfoLoader,
      configLoader: configLoader,
      platformOverride: platformOverride,
      now: now,
    );
  }

  /// Manually checks for updates (e.g. from Settings) and returns the evaluated result.
  Future<AppUpdateCheckResult?> checkManuallyAndPrompt(
    BuildContext context, {
    Future<PackageInfo> Function()? packageInfoLoader,
    Future<AppVersionConfig?> Function(String platform)? configLoader,
    TargetPlatform? platformOverride,
  }) async {
    return _runCheckAndPrompt(
      context,
      ignoreCooldown: true,
      packageInfoLoader: packageInfoLoader,
      configLoader: configLoader,
      platformOverride: platformOverride,
    );
  }

  Future<AppUpdateCheckResult?> _runCheckAndPrompt(
    BuildContext context, {
    required bool ignoreCooldown,
    Future<PackageInfo> Function()? packageInfoLoader,
    Future<AppVersionConfig?> Function(String platform)? configLoader,
    TargetPlatform? platformOverride,
    DateTime? now,
  }) async {
    if (_isChecking || _isDialogVisible) return null;
    _isChecking = true;
    try {
      final result = await checkForUpdate(
        packageInfoLoader: packageInfoLoader,
        configLoader: configLoader,
        platformOverride: platformOverride,
      );
      if (result == null || !result.hasUpdate || result.config == null) {
        return result;
      }

      final config = result.config!;
      if (!result.isForced && !ignoreCooldown) {
        final dismissed = await isSoftUpdateDismissed(config, now: now);
        if (dismissed) return result;
      }

      if (!context.mounted) return result;
      _isDialogVisible = true;
      try {
        await AppUpdateDialog.show(context, result: result);
      } finally {
        _isDialogVisible = false;
      }
      return result;
    } catch (error) {
      debugPrint('App update check skipped: $error');
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// Opens the configured store or TestFlight URL externally.
  Future<bool> openUpdateStore(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_isValidUpdateUrl(url)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Unable to open store URL $url: $error');
      return false;
    }
  }
}
