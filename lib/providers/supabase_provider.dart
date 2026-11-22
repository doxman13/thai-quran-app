// lib/providers/supabase_provider.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/hifz_repository.dart';

class OAuthDeepLinkParseResult {
  final bool hasAuthParams;
  final String? error;
  final String? errorCode;
  final String? errorDescription;
  final bool hasSessionCodeOrToken;

  const OAuthDeepLinkParseResult({
    required this.hasAuthParams,
    required this.error,
    required this.errorCode,
    required this.errorDescription,
    required this.hasSessionCodeOrToken,
  });

  bool get hasError =>
      (error != null && error!.isNotEmpty) ||
      (errorCode != null && errorCode!.isNotEmpty) ||
      (errorDescription != null && errorDescription!.isNotEmpty);

  bool get isCancellation => SupabaseProvider._isOAuthValuesCancellation(
    error: error,
    errorCode: errorCode,
    errorDescription: errorDescription,
  );
}

class SupabaseProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _client = Supabase.instance.client;
  User? _user;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _appLinksSubscription;
  String? _lastHandledDeepLink;
  bool _isHandlingDeepLink = false;
  String _guestName = 'Reader';
  bool _isSigningIn = false;
  String? _activeSignInProvider;
  String? _authError;
  bool _disposed = false;
  Future<void>? _bootstrapFuture;
  String? _bootstrappingUserId;
  DateTime? _lastUserRefreshAt;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  User? get user => _user ?? _client.auth.currentUser;
  bool get isLoggedIn => user != null;
  String get userId => user?.id ?? '';
  String get userEmail {
    final u = user;
    if (u == null) return '';
    if (u.email != null && u.email!.isNotEmpty) return u.email!;
    final metaEmail = u.userMetadata?['email']?.toString() ?? '';
    if (metaEmail.isNotEmpty) return metaEmail;
    for (final identity in u.identities ?? const <UserIdentity>[]) {
      final idEmail = identity.identityData?['email']?.toString() ?? '';
      if (idEmail.isNotEmpty) return idEmail;
    }
    return '';
  }
  bool get isSigningIn => _isSigningIn;
  String? get activeSignInProvider => _activeSignInProvider;
  String? get authError => _authError;

  String get displayName {
    final u = user;
    if (u != null) {
      final candidates = [
        u.userMetadata?['custom_display_name']?.toString(),
        u.userMetadata?['display_name']?.toString(),
        u.userMetadata?['full_name']?.toString(),
        u.userMetadata?['name']?.toString(),
      ];
      for (final candidate in candidates) {
        final trimmed = candidate?.trim() ?? '';
        if (trimmed.isNotEmpty) return trimmed;
      }
      final email = userEmail;
      if (email.isNotEmpty) {
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
    WidgetsBinding.instance.addObserver(this);
    _user = _client.auth.currentUser;
    _loadGuestName();
    if (_user != null) {
      unawaited(refreshCurrentUser());
    }
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (data) {
        debugPrint('[SupabaseProvider] onAuthStateChange event: ${data.event}, session: ${data.session?.user.email}');
        _user = data.session?.user ?? _client.auth.currentUser;
        if (data.event == AuthChangeEvent.signedOut) {
          _user = null;
          unawaited(
            HifzRepository.instance.clearAllLocalData().catchError((Object e) {
              debugPrint('[SupabaseProvider] Error clearing Hifz data on sign out: $e');
            }),
          );
        } else if (_user != null) {
          _authError = null;
          _isSigningIn = false;
          _activeSignInProvider = null;
          final hasCustomDisplayName =
              (_user!.userMetadata?['custom_display_name']?.toString().trim() ?? '')
                  .isNotEmpty;
          if (!hasCustomDisplayName &&
              _guestName.trim().isNotEmpty &&
              _guestName != 'Reader' &&
              _guestName != 'Local reader') {
            unawaited(
              updateDisplayName(_guestName).catchError((Object e) {
                debugPrint('[SupabaseProvider] Error preserving guest display name: $e');
              }),
            );
          }
        }
        notifyListeners();
        if (_user != null) {
          unawaited(bootstrapUser(_user!.id));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[SupabaseProvider] onAuthStateChange error: $error');
        if (isAuthCancellation(error)) {
          _authError = null;
          _isSigningIn = false;
          _activeSignInProvider = null;
          notifyListeners();
        }
      },
    );

    if (!kIsWeb) {
      _initDeepLinkListener();
    }
  }

  Future<void> refreshCurrentUser({bool force = false}) async {
    try {
      if (_client.auth.currentSession == null) return;
      if (!force &&
          _lastUserRefreshAt != null &&
          DateTime.now().difference(_lastUserRefreshAt!) <
              const Duration(seconds: 15)) {
        return;
      }
      _lastUserRefreshAt = DateTime.now();
      final res = await _client.auth.getUser();
      if (res.user != null) {
        _user = res.user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SupabaseProvider] Error refreshing current user: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final current = _client.auth.currentUser;
      if (_user?.id != current?.id) {
        _user = current;
        notifyListeners();
        if (_user != null) {
          unawaited(bootstrapUser(_user!.id));
        }
      }
      if (current != null) {
        unawaited(refreshCurrentUser());
      }
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

  static Map<String, String> _safeSplitQueryString(String raw) {
    if (raw.isEmpty) return const {};
    try {
      return Uri.splitQueryString(raw);
    } catch (_) {
      return const {};
    }
  }

  @visibleForTesting
  static OAuthDeepLinkParseResult parseOAuthErrorParams(Uri uri) {
    final fragmentParams = _safeSplitQueryString(uri.fragment);
    final queryParams = uri.queryParameters;

    final error = queryParams['error'] ?? fragmentParams['error'];
    final errorCode = queryParams['error_code'] ?? fragmentParams['error_code'];
    final errorDescription =
        queryParams['error_description'] ?? fragmentParams['error_description'];
    final hasSessionCodeOrToken =
        queryParams.containsKey('code') ||
        queryParams.containsKey('access_token') ||
        fragmentParams.containsKey('code') ||
        fragmentParams.containsKey('access_token');
    final hasAuthParams =
        hasSessionCodeOrToken ||
        queryParams.containsKey('error') ||
        queryParams.containsKey('error_code') ||
        queryParams.containsKey('error_description') ||
        fragmentParams.containsKey('error') ||
        fragmentParams.containsKey('error_code') ||
        fragmentParams.containsKey('error_description');

    return OAuthDeepLinkParseResult(
      hasAuthParams: hasAuthParams,
      error: error,
      errorCode: errorCode,
      errorDescription: errorDescription,
      hasSessionCodeOrToken: hasSessionCodeOrToken,
    );
  }

  static bool _isOAuthValuesCancellation({
    String? error,
    String? errorCode,
    String? errorDescription,
  }) {
    final values = [error, errorCode, errorDescription]
        .whereType<String>()
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty);

    const exactMatches = {
      'access_denied',
      'user_cancelled_authorize',
      'user_cancelled',
      'user_canceled',
      'canceled',
      'cancelled',
      'cancel',
      'dismissed',
      'popup_closed',
      'popup_closed_by_user',
      'sign_in_canceled',
      'sign_in_cancelled',
    };

    const substrings = [
      'access_denied',
      'user_cancelled_authorize',
      'user_cancelled',
      'user_canceled',
      'user cancelled',
      'user canceled',
      'cancelled',
      'canceled',
      'dismissed',
      'popup_closed',
    ];

    for (final v in values) {
      if (exactMatches.contains(v)) return true;
      for (final sub in substrings) {
        if (v.contains(sub)) return true;
      }
    }
    return false;
  }

  static bool _isAppleNativeCancellationText(String text) {
    if ((text.contains('asauthorizationerror') ||
            text.contains('webauthenticationsession')) &&
        text.contains('1001')) {
      return true;
    }
    return text.contains(
          'com.apple.authenticationservices.webauthenticationsession',
        ) &&
        text.contains('error 1');
  }

  static bool isAuthCancellation(Object error) {
    if (error is PlatformException) {
      final code = error.code.trim().toLowerCase();
      final message = (error.message ?? '').trim().toLowerCase();
      final details = (error.details?.toString() ?? '').trim().toLowerCase();

      const cancelCodes = {
        'sign_in_canceled',
        'sign_in_cancelled',
        'canceled',
        'cancelled',
        'user_canceled',
        'user_cancelled',
        'user_cancelled_authorize',
        'err_canceled',
        'error_canceled',
        'authorizationerror_canceled',
        '1001',
        '12501',
      };
      if (cancelCodes.contains(code)) return true;

      for (final text in [code, message, details]) {
        if (_isOAuthValuesCancellation(error: text)) return true;
        if (_isAppleNativeCancellationText(text)) return true;
      }
      return false;
    }

    if (error is AuthException) {
      return _isOAuthValuesCancellation(
        error: error.message,
        errorCode: error.code,
      );
    }

    final raw = error.toString().toLowerCase();
    if (_isAppleNativeCancellationText(raw)) {
      return true;
    }
    return _isOAuthValuesCancellation(error: raw);
  }

  static bool _isNetworkError(Object error) {
    final String code;
    final String message;
    if (error is PlatformException) {
      code = error.code.toLowerCase();
      message = (error.message ?? '').toLowerCase();
    } else if (error is AuthException) {
      code = (error.code ?? '').toLowerCase();
      message = error.message.toLowerCase();
    } else {
      code = '';
      message = error.toString().toLowerCase();
    }

    final combined = '$code $message';
    return combined.contains('network_error') ||
        combined.contains('socketexception') ||
        combined.contains('failed host lookup') ||
        combined.contains('clientexception') ||
        combined.contains('connection') ||
        combined.contains('internet') ||
        combined.contains('offline') ||
        combined.contains('timeout') ||
        combined.contains('timed out');
  }

  static String formatAuthError(Object error, {required bool isThai}) {
    if (isAuthCancellation(error)) {
      return isThai ? 'ยกเลิกการเข้าสู่ระบบ' : 'Sign-in was cancelled.';
    }

    if (_isNetworkError(error)) {
      return isThai
          ? 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาลองใหม่อีกครั้ง'
          : 'Unable to connect to the network. Please try again.';
    }

    final String code;
    final String message;
    if (error is PlatformException) {
      code = error.code.toLowerCase();
      message = (error.message ?? '').toLowerCase();
    } else if (error is AuthException) {
      code = (error.code ?? '').toLowerCase();
      message = error.message.toLowerCase();
    } else {
      code = '';
      message = error.toString().toLowerCase();
    }

    final combined = '$code $message';

    if (combined.contains('invalid_credentials') ||
        combined.contains('invalid login credentials') ||
        combined.contains('invalid email or password')) {
      return isThai
          ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'
          : 'Invalid email or password.';
    }

    if (combined.contains('email_not_confirmed') ||
        combined.contains('email not confirmed')) {
      return isThai
          ? 'กรุณายืนยันอีเมลของคุณก่อนเข้าสู่ระบบ'
          : 'Please confirm your email address before signing in.';
    }

    if (combined.contains('user_already_exists') ||
        combined.contains('already registered') ||
        combined.contains('email_exists')) {
      return isThai
          ? 'อีเมลนี้ถูกใช้งานแล้ว กรุณาเข้าสู่ระบบแทน'
          : 'This email is already registered. Please sign in instead.';
    }

    if (combined.contains('weak_password') ||
        combined.contains('password should be at least')) {
      return isThai
          ? 'รหัสผ่านสั้นเกินไป กรุณาตั้งรหัสผ่านให้ปลอดภัยขึ้น'
          : 'Password is too weak. Please choose a stronger password.';
    }

    if (combined.contains('invalid_email') ||
        combined.contains('unable to validate email')) {
      return isThai
          ? 'รูปแบบอีเมลไม่ถูกต้อง'
          : 'Please enter a valid email address.';
    }

    if (combined.contains('over_request_rate_limit') ||
        combined.contains('rate limit') ||
        combined.contains('too many requests')) {
      return isThai
          ? 'มีการทำรายการบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่'
          : 'Too many attempts. Please wait a moment and try again.';
    }

    if (combined.contains('sign_in_failed') ||
        combined.contains('id token') ||
        combined.contains('oauth') ||
        combined.contains('developer_error') ||
        combined.contains('invalid_audience') ||
        combined.contains('unacceptable audience') ||
        combined.contains('nonce') ||
        combined.contains('code verifier') ||
        combined.contains('client_id')) {
      return isThai
          ? 'ไม่สามารถเข้าสู่ระบบด้วยบัญชีที่เลือกได้ กรุณาลองใหม่อีกครั้ง'
          : 'Could not complete sign-in with this account. Please try again.';
    }

    return isThai
        ? 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ กรุณาลองใหม่อีกครั้ง'
        : 'Sign-in failed. Please try again.';
  }

  Future<void> _closeInAppWebViewIfSupported() async {
    if (kIsWeb) return;
    try {
      await closeInAppWebView();
    } catch (_) {
      // Ignore when no in-app web view is open or on test platforms.
    }
  }

  @visibleForTesting
  Future<void> handleIncomingDeepLinkForTest(Uri uri) =>
      _handleIncomingDeepLink(uri);

  Future<void> _handleIncomingDeepLink(Uri uri) async {
    final uriStr = uri.toString();
    if (_isHandlingDeepLink || _lastHandledDeepLink == uriStr) return;

    if (uri.scheme != 'io.supabase.thaiquran') return;

    final parsed = parseOAuthErrorParams(uri);
    if (!parsed.hasAuthParams) return;

    debugPrint('[SupabaseProvider] Processing auth deep link: $uri');
    unawaited(_closeInAppWebViewIfSupported());

    if (parsed.isCancellation) {
      _lastHandledDeepLink = uriStr;
      _isHandlingDeepLink = false;
      _isSigningIn = false;
      _activeSignInProvider = null;
      _authError = null;
      notifyListeners();
      return;
    }

    if (parsed.hasError && !parsed.hasSessionCodeOrToken) {
      _lastHandledDeepLink = uriStr;
      _isHandlingDeepLink = false;
      _isSigningIn = false;
      _activeSignInProvider = null;
      _authError = formatAuthError(
        AuthException(
          parsed.errorDescription ?? parsed.error ?? 'OAuth sign-in failed',
          code: parsed.errorCode ?? parsed.error,
        ),
        isThai: false,
      );
      notifyListeners();
      return;
    }

    // If user is already authenticated with session, sync and return
    if (_client.auth.currentUser != null) {
      _lastHandledDeepLink = uriStr;
      _user = _client.auth.currentUser;
      _authError = null;
      _isSigningIn = false;
      _activeSignInProvider = null;
      notifyListeners();
      return;
    }

    _lastHandledDeepLink = uriStr;
    _isHandlingDeepLink = true;
    _isSigningIn = true;
    _authError = null;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (_client.auth.currentUser != null) {
        _user = _client.auth.currentUser;
        _authError = null;
        _isSigningIn = false;
        _activeSignInProvider = null;
        _isHandlingDeepLink = false;
        notifyListeners();
        return;
      }

      final res = await _client.auth.getSessionFromUrl(uri);
      _user = res.session.user;
      _authError = null;
      notifyListeners();
      await bootstrapUser(_user!.id);
    } catch (e) {
      debugPrint('[SupabaseProvider] Error extracting session from url: $e');
      if (_client.auth.currentUser == null) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (_client.auth.currentUser != null) {
        _user = _client.auth.currentUser;
        _authError = null;
      } else if (isAuthCancellation(e)) {
        _authError = null;
      } else {
        _authError = formatAuthError(e, isThai: false);
      }
      notifyListeners();
    } finally {
      _isHandlingDeepLink = false;
      _isSigningIn = false;
      _activeSignInProvider = null;
      _user = _client.auth.currentUser ?? _user;
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
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
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

  static const MethodChannel _iosOAuthChannel = MethodChannel(
    'com.thaiquran.app/oauth_session',
  );
  static const String _mobileRedirectUrl =
      'io.supabase.thaiquran://login-callback';
  static const String _googleWebClientId =
      '913097538260-shpuvop6pckuu7id8ig8mq954adleqhc.apps.googleusercontent.com';

  Future<bool> _signInWithIosWebAuthSession(
    OAuthProvider provider, {
    Map<String, String>? queryParams,
  }) async {
    final oauthResponse = await _client.auth.getOAuthSignInUrl(
      provider: provider,
      redirectTo: _mobileRedirectUrl,
      queryParams: queryParams,
    );

    String? callbackUrl;
    try {
      callbackUrl = await _iosOAuthChannel.invokeMethod<String>(
        'authenticate',
        <String, dynamic>{
          'url': oauthResponse.url,
          'callbackURLScheme': 'io.supabase.thaiquran',
          'prefersEphemeralWebBrowserSession': false,
        },
      );
    } on MissingPluginException {
      return await _client.auth.signInWithOAuth(
        provider,
        redirectTo: _mobileRedirectUrl,
        queryParams: queryParams,
      );
    }

    if (callbackUrl == null || callbackUrl.trim().isEmpty) {
      _authError = null;
      return false;
    }

    final callbackUri = Uri.parse(callbackUrl);
    final parsed = parseOAuthErrorParams(callbackUri);

    if (parsed.isCancellation) {
      _authError = null;
      return false;
    }

    if (parsed.hasError && !parsed.hasSessionCodeOrToken) {
      throw AuthException(
        parsed.errorDescription ?? parsed.error ?? 'OAuth sign-in failed',
        code: parsed.errorCode ?? parsed.error,
      );
    }

    if (!parsed.hasSessionCodeOrToken) {
      throw AuthException(
        'OAuth callback did not return a valid session.',
        code: 'oauth_missing_session',
      );
    }

    _lastHandledDeepLink = callbackUrl;
    final res = await _client.auth.getSessionFromUrl(callbackUri);
    _user = res.session.user;
    _authError = null;
    notifyListeners();
    await bootstrapUser(_user!.id);
    return true;
  }

  // Apple sign-in request (OAuth on Web, ASWebAuthenticationSession on iOS, OAuth on Android)
  Future<bool> signInWithApple() async {
    _authError = null;
    _isSigningIn = true;
    _activeSignInProvider = 'apple';
    notifyListeners();

    try {
      if (kIsWeb) {
        return await _client.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: Uri.base.origin,
        );
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _signInWithIosWebAuthSession(OAuthProvider.apple);
      }

      return await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _mobileRedirectUrl,
      );
    } catch (e) {
      debugPrint('[SupabaseProvider] Apple sign-in error: $e');
      if (isAuthCancellation(e)) {
        _authError = null;
        notifyListeners();
        return false;
      }
      _authError = formatAuthError(e, isThai: false);
      notifyListeners();
      rethrow;
    } finally {
      _isSigningIn = false;
      _activeSignInProvider = null;
      notifyListeners();
    }
  }

  // Google sign-in request (ASWebAuthenticationSession on iOS, Native Bottom Sheet on Android, OAuth on Web)
  Future<bool> signInWithGoogle() async {
    _authError = null;
    _isSigningIn = true;
    _activeSignInProvider = 'google';
    notifyListeners();

    try {
      if (kIsWeb) {
        return await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _signInWithIosWebAuthSession(
          OAuthProvider.google,
          queryParams: const {'prompt': 'select_account'},
        );
      }

      final googleSignIn = GoogleSignIn(
        serverClientId: _googleWebClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled account picker
        _authError = null;
        return false;
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
      return true;
    } catch (e) {
      debugPrint('[SupabaseProvider] Google sign-in error: $e');
      if (isAuthCancellation(e)) {
        _authError = null;
        notifyListeners();
        return false;
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          !_isNetworkError(e)) {
        debugPrint('[SupabaseProvider] Falling back to Supabase OAuth on Android...');
        try {
          return await _client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: _mobileRedirectUrl,
            authScreenLaunchMode: LaunchMode.externalApplication,
          );
        } catch (fallbackError) {
          debugPrint(
            '[SupabaseProvider] Android OAuth fallback also failed: $fallbackError',
          );
          _authError = formatAuthError(fallbackError, isThai: false);
          notifyListeners();
          rethrow;
        }
      }
      _authError = formatAuthError(e, isThai: false);
      notifyListeners();
      rethrow;
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
    final trimmedName = displayName.trim();
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': trimmedName,
        if (trimmedName.isNotEmpty) 'custom_display_name': trimmedName,
      },
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

  /// Deletes the current user account completely on Supabase and cleans up local auth state.
  Future<bool> deleteAccount() async {
    try {
      await _client.rpc('delete_own_account');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('guest_display_name');
      await signOut();
      return true;
    } catch (e) {
      debugPrint('[SupabaseProvider] Error deleting account: $e');
      return false;
    }
  }

  // Bootstraps default rows for user if they don't exist
  Future<void> bootstrapUser(String userId) {
    if (_bootstrapFuture != null && _bootstrappingUserId == userId) {
      return _bootstrapFuture!;
    }
    _bootstrappingUserId = userId;
    final future = _runBootstrapUser(userId);
    _bootstrapFuture = future;
    return future.whenComplete(() {
      if (identical(_bootstrapFuture, future)) {
        _bootstrapFuture = null;
        _bootstrappingUserId = null;
      }
    });
  }

  Future<void> _runBootstrapUser(String userId) async {
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

      // Stage 1: Default user rows + current user metadata refresh
      futures.add(refreshCurrentUser());

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

      // Stage 2: Sequential Hifz syncs to avoid PostgREST connection spikes
      try {
        await HifzRepository().syncWithSupabase(userId);
        await HifzRepository().syncHistoryWithSupabase();
      } catch (e) {
        debugPrint('Error triggering hifz sync: $e');
      }
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
      final response = await _client.auth.updateUser(
        UserAttributes(
          data: {
            'custom_display_name': trimmed,
            'display_name': trimmed,
            'full_name': trimmed,
          },
        ),
      );
      _user = response.user ?? _client.auth.currentUser;
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
