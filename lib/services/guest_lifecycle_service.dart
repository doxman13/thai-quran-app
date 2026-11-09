import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the 30-day guest data lifecycle and warning preferences.
class GuestLifecycleService {
  static const String guestLastActiveKey = 'thai_quran_guest_last_active_at';
  static const String suppressWarningKey = 'suppress_guest_bookmark_warning';
  static const int retentionDays = 30;

  static bool get _hasCurrentUser {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Check whether guest data has exceeded 30 days of inactivity.
  static Future<bool> isGuestInactiveExpired(SharedPreferences prefs) async {
    // Cloud logged-in users are NEVER flushed
    if (_hasCurrentUser) return false;

    final lastActiveStr = prefs.getString(guestLastActiveKey);
    if (lastActiveStr == null) {
      // First run or timestamp not yet set - initialize to now
      await prefs.setString(guestLastActiveKey, DateTime.now().toIso8601String());
      return false;
    }

    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) {
      await prefs.setString(guestLastActiveKey, DateTime.now().toIso8601String());
      return false;
    }

    final difference = DateTime.now().difference(lastActive);
    return difference.inDays >= retentionDays;
  }

  /// Touch/refresh the guest activity timestamp (whenever active).
  static Future<void> touchGuestActivity([SharedPreferences? existingPrefs]) async {
    if (_hasCurrentUser) return;
    try {
      final prefs = existingPrefs ?? await SharedPreferences.getInstance();
      await prefs.setString(guestLastActiveKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[GuestLifecycleService] Error touching activity: $e');
    }
  }

  /// Check if the guest bookmark warning should be presented.
  static Future<bool> shouldPromptGuestBookmarkWarning() async {
    if (_hasCurrentUser) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSuppressed = prefs.getBool(suppressWarningKey) ?? false;
      return !isSuppressed;
    } catch (_) {
      return true;
    }
  }

  /// Suppress future bookmark warning dialogs.
  static Future<void> setSuppressGuestBookmarkWarning(bool suppress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(suppressWarningKey, suppress);
    } catch (e) {
      debugPrint('[GuestLifecycleService] Error setting suppress warning: $e');
    }
  }
}
