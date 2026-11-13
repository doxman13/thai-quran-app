// lib/providers/supabase_provider.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/hifz_repository.dart';

class SupabaseProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  User? _user;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _appLinksSubscription;
  String _guestName = 'Reader';
  bool _isSigningIn = false;
  String? _activeSignInProvider;
  String? _authError;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String get userEmail => _user?.email ?? '';
  String get userId => _user?.id ?? '';
  bool get isSigningIn => _isSigningIn;
  String? get activeSignInProvider => _activeSignInProvider;
  String? get authError => _authError;

  String get displayName {
    if (_user != null) {
      final metaName = _user?.userMetadata?['full_name']?.toString() ??
          _user?.userMetadata?['name']?.toString() ??
          '';
      if (metaName.trim().isNotEmpty) return metaName.trim();
      final email = _user?.email;
      if (email != null && email.isNotEmpty) {
        return email.split('@')[0];
      }
      // Fallback for providers that may return neither a name nor an email
      // (e.g. an Apple account where the user declined to share an email).
      // Keep it provider-neutral.
      return 'Reader';
    }
    return _guestName;
  }

  SupabaseProvider() {
    _user = _client.auth.currentUser;
    _loadGuestName();
    _authSubscription = _client.auth.onAuthStateChange.listen((data) {
      debugPrint('[SupabaseProvider] onAuthStateChange event: ${data.event}, session: ${data.session?.user.email}');
      _user = data.session?.user;
      notifyListeners();
      if (_user != null) {
        bootstrapUser(_user!.id);
      }
    });

    if (!kIsWeb) {
      _initDeepLinkListener();
    }
  }

  void _initDeepLinkListener() async {
    final appLinks = AppLinks();

    // Check initial uri on startup (cold start)
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[SupabaseProvider] Initial deep link detected: $initialUri');
        await _handleIncomingDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('[SupabaseProvider] Error reading initial deep link: $e');
    }

    // Check latest link
    try {
      final latestUri = await appLinks.getLatestLink();
      if (latestUri != null) {
        debugPrint('[SupabaseProvider] Latest deep link detected: $latestUri');
        await _handleIncomingDeepLink(latestUri);
      }
    } catch (e) {
      debugPrint('[SupabaseProvider] Error reading latest deep link: $e');
    }

    // Observe incoming links stream
    _appLinksSubscription = appLinks.uriLinkStream.listen((uri) async {
      debugPrint('[SupabaseProvider] uriLinkStream emitted: $uri');
      await _handleIncomingDeepLink(uri);
    }, onError: (err) {
      debugPrint('[SupabaseProvider] uriLinkStream error: $err');
    });
  }

  Future<void> _handleIncomingDeepLink(Uri uri) async {
    if (uri.scheme != 'io.supabase.thaiquran') return;

    final fragmentParams = Uri.splitQueryString(uri.fragment);
    final hasAuthParams = uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error_description') ||
        fragmentParams.containsKey('code') ||
        fragmentParams.containsKey('access_token') ||
        fragmentParams.containsKey('error_description');

    if (!hasAuthParams) return;

    debugPrint('[SupabaseProvider] Processing auth deep link: $uri');

    // If user is already authenticated with session, sync and return
    if (_client.auth.currentUser != null) {
      _user = _client.auth.currentUser;
      _authError = null;
      notifyListeners();
      return;
    }

    _isSigningIn = true;
    _authError = null;
    notifyListeners();

    try {
      final res = await _client.auth.getSessionFromUrl(uri);
      _user = res.session.user;
      _authError = null;
      notifyListeners();
      await bootstrapUser(_user!.id);
    } catch (e) {
      debugPrint('[SupabaseProvider] Error extracting session from url: $e');
      if (_client.auth.currentUser != null) {
        _user = _client.auth.currentUser;
        _authError = null;
      } else {
        _authError = e.toString().replaceAll('Exception:', '').trim();
      }
      notifyListeners();
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> _loadGuestName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _guestName = prefs.getString('guest_display_name') ?? 'Reader';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading guest name: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _appLinksSubscription?.cancel();
    super.dispose();
  }

  // OTP / Magic Link sign-in request
  Future<void> signInWithOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: kIsWeb
          ? Uri.base.origin
          : 'io.supabase.thaiquran://login-callback',
    );
  }

  static const String _googleWebClientId =
      '1011303318865-jrub1rpu8e661lmo6eunphtrin1alcrl.apps.googleusercontent.com';

  // Apple sign-in request (OAuth on Web, OAuth on Mobile)
  Future<void> signInWithApple() async {
    _authError = null;
    _isSigningIn = true;
    _activeSignInProvider = 'apple';
    notifyListeners();

    try {
      if (kIsWeb) {
        await _client.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: Uri.base.origin,
        );
        return;
      }

      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.thaiquran://login-callback',
      );
    } catch (e) {
      debugPrint('[SupabaseProvider] Apple sign-in error: $e');
      _authError = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      rethrow;
    } finally {
      _isSigningIn = false;
      _activeSignInProvider = null;
      notifyListeners();
    }
  }

  // Google sign-in request (Native Bottom Sheet on Mobile, OAuth on Web)
  Future<void> signInWithGoogle() async {
    _authError = null;
    _isSigningIn = true;
    _activeSignInProvider = 'google';
    notifyListeners();

    try {
      if (kIsWeb) {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        return;
      }

      final googleSignIn = GoogleSignIn(
        serverClientId: _googleWebClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled account picker
        _isSigningIn = false;
        _activeSignInProvider = null;
        notifyListeners();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed to retrieve ID token.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        _user = response.user;
        await bootstrapUser(response.user!.id);
      }
    } catch (e) {
      debugPrint('[SupabaseProvider] Native Google sign-in error: $e');
      debugPrint('[SupabaseProvider] Attempting Web OAuth fallback...');
      try {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.thaiquran://login-callback',
        );
        return;
      } catch (fallbackError) {
        debugPrint('[SupabaseProvider] Web OAuth fallback also failed: $fallbackError');
        _authError = e.toString().replaceAll('Exception:', '').trim();
        notifyListeners();
        rethrow;
      }
    } finally {
      _isSigningIn = false;
      _activeSignInProvider = null;
      notifyListeners();
    }
  }

  // Sign In with Email & Password
  Future<void> signInWithPassword(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Sign Up with Email & Password
  Future<void> signUp(String email, String password, String displayName) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': displayName.trim()},
    );
    if (response.user != null) {
      await bootstrapUser(response.user!.id);
    }
  }

  // Verification of 6-digit OTP code
  Future<void> verifyOtp(String email, String token) async {
    await _client.auth.verifyOTP(
      type: OtpType.magiclink,
      email: email.trim(),
      token: token.trim(),
    );
  }

  // Logout
  Future<void> signOut() async {
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('[SupabaseProvider] Error signing out from GoogleSignIn: $e');
    }
    await _client.auth.signOut();
  }

  // Bootstraps default rows for user if they don't exist
  Future<void> bootstrapUser(String userId) async {
    try {
      final countResult = await _client
          .from('user_reading_profiles')
          .select('id')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final List<Future> futures = [
        _client
            .from('reading_profiles')
            .upsert(
              {
                'user_id': userId,
                'name': 'Free Read',
                'slug': 'free_read',
                'start_surah_id': '1',
                'start_verse_id': '1',
                'current_surah_id': '1',
                'current_verse_id': '1',
                'furthest_unread_index': 1,
                'last_viewed_index': 1,
                'sort_order': 0,
                'is_archived': false,
              },
              onConflict: 'user_id,slug',
              ignoreDuplicates: true,
            ),
        _client
            .from('bookmark_categories')
            .upsert(
              {
                'user_id': userId,
                'name': 'Saved Verses',
                'slug': 'saved_verses',
                'max_items': 9999,
                'sort_order': 0,
              },
              onConflict: 'user_id,slug',
              ignoreDuplicates: true,
            ),
        _client
            .from('user_settings')
            .upsert(
              {'user_id': userId},
              onConflict: 'user_id',
              ignoreDuplicates: true,
            ),
      ];

      // Add Hifz sync
      try {
        futures.add(HifzRepository().syncWithSupabase(userId));
        futures.add(HifzRepository().syncHistoryWithSupabase());
      } catch (e) {
        debugPrint('Error triggering hifz sync: $e');
      }

      if (countResult == null) {
        futures.add(
          _client.from('user_reading_profiles').insert({
            'user_id': userId,
            'profile_name': 'Free Read',
            'current_surah': 1,
            'current_ayah': 1,
            'furthest_unread_index': 1,
            'last_viewed_index': 1,
            'last_read_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
      }

      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error bootstrapping Supabase user defaults: $e');
    }
  }

  // Load User Settings from Supabase
  Future<Map<String, dynamic>?> loadUserSettings(String userId) async {
    try {
      final response = await _client
          .from('user_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error loading user settings from Supabase: $e');
      return null;
    }
  }

  // Save/Upsert Settings to Supabase
  Future<void> saveUserSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _client.from('user_settings').upsert({
        'user_id': userId,
        ...settings,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Error saving user settings to Supabase: $e');
    }
  }

  // Fetch Bookmarks from Supabase
  Future<List<Map<String, dynamic>>> fetchBookmarks(String userId) async {
    try {
      final response = await _client
          .from('bookmarks')
          .select(
            'id, surah_id, verse_id, label, note, sort_order, created_at, category_id',
          )
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching bookmarks from Supabase: $e');
      return [];
    }
  }

  // Save Bookmark to Supabase
  Future<void> saveBookmark(
    String userId,
    String categoryId,
    String surahId,
    String verseId, {
    String? label,
    String? note,
    int sortOrder = 0,
  }) async {
    try {
      // Check if bookmark already exists
      final existing = await _client
          .from('bookmarks')
          .select('id')
          .eq('user_id', userId)
          .eq('category_id', categoryId)
          .eq('surah_id', surahId)
          .eq('verse_id', verseId)
          .maybeSingle();

      if (existing != null) return;

      await _client.from('bookmarks').insert({
        'user_id': userId,
        'category_id': categoryId,
        'surah_id': surahId,
        'verse_id': verseId,
        'label': ?label,
        'note': ?note,
        'sort_order': sortOrder,
      });
    } catch (e) {
      debugPrint('Error saving bookmark to Supabase: $e');
    }
  }

  // Remove Bookmark from Supabase
  Future<void> removeBookmark(
    String userId,
    String surahId,
    String verseId,
  ) async {
    try {
      await _client
          .from('bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('surah_id', surahId)
          .eq('verse_id', verseId);
    } catch (e) {
      debugPrint('Error removing bookmark from Supabase: $e');
    }
  }

  // Helper to get category ID for saved_verses
  Future<String?> getDefaultBookmarkCategoryId(String userId) async {
    try {
      final category = await _client
          .from('bookmark_categories')
          .select('id')
          .eq('user_id', userId)
          .eq('slug', 'saved_verses')
          .maybeSingle();

      if (category != null) {
        return category['id']?.toString();
      }

      // Upsert fallback
      final created = await _client
          .from('bookmark_categories')
          .upsert({
            'user_id': userId,
            'name': 'Saved Verses',
            'slug': 'saved_verses',
            'max_items': 9999,
            'sort_order': 0,
          }, onConflict: 'user_id,slug')
          .select('id')
          .single();

      return created['id']?.toString();
    } catch (e) {
      debugPrint('Error getting default category ID: $e');
      return null;
    }
  }

  Future<void> updateDisplayName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    if (_user != null) {
      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': trimmed}),
      );
      _user = _client.auth.currentUser;
      notifyListeners();
    } else {
      _guestName = trimmed;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('guest_display_name', trimmed);
      } catch (e) {
        debugPrint('Error saving guest name: $e');
      }
    }
  }
}
