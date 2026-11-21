import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';

String _buildMockJwt() {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final exp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 3600;
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'user-ios-123',
            'email': 'reader@thaiquran.test',
            'exp': exp,
          }),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tokenRequests = <Map<String, dynamic>>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/v1/token') &&
          request.url.queryParameters['grant_type'] == 'pkce') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        tokenRequests.add(body);
        final jwt = _buildMockJwt();
        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'mock-refresh-token',
            'user': {
              'id': 'user-ios-123',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'reader@thaiquran.test',
              'app_metadata': {'provider': 'google'},
              'user_metadata': {'full_name': 'Thai Quran Reader'},
              'created_at': '2026-11-20T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path.startsWith('/rest/v1/')) {
        final accept = request.headers['Accept'] ?? request.headers['accept'] ?? '';
        if (accept.contains('vnd.pgrst.object+json')) {
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: mockClient,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() {
    tokenRequests.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    const channel = MethodChannel('com.thaiquran.app/oauth_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await Supabase.instance.client.auth.signOut();
  });

  test('iOS signInWithApple completes PKCE session via ASWebAuthenticationSession callback', () async {
    const channel = MethodChannel('com.thaiquran.app/oauth_session');
    final launchedUrls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      launchedUrls.add(args['url'] as String);
      return 'io.supabase.thaiquran://login-callback?code=apple-pkce-code-123';
    });

    final provider = SupabaseProvider();
    addTearDown(provider.dispose);

    final completed = await provider.signInWithApple();

    expect(completed, isTrue);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.userEmail, equals('reader@thaiquran.test'));
    expect(provider.displayName, equals('Thai Quran Reader'));
    expect(provider.authError, isNull);
    expect(provider.isSigningIn, isFalse);

    expect(launchedUrls, hasLength(1));
    final authUri = Uri.parse(launchedUrls.single);
    expect(authUri.queryParameters['provider'], equals('apple'));
    expect(authUri.queryParameters['code_challenge'], isNotEmpty);

    expect(tokenRequests, hasLength(1));
    expect(tokenRequests.single['auth_code'], equals('apple-pkce-code-123'));
    expect(tokenRequests.single['code_verifier'], isNotEmpty);
  });

  test('iOS signInWithGoogle completes PKCE session via ASWebAuthenticationSession callback', () async {
    const channel = MethodChannel('com.thaiquran.app/oauth_session');
    final launchedUrls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      launchedUrls.add(args['url'] as String);
      return 'io.supabase.thaiquran://login-callback?code=google-pkce-code-456';
    });

    final provider = SupabaseProvider();
    addTearDown(provider.dispose);

    final completed = await provider.signInWithGoogle();

    expect(completed, isTrue);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.userEmail, equals('reader@thaiquran.test'));
    expect(provider.authError, isNull);
    expect(provider.isSigningIn, isFalse);

    expect(launchedUrls, hasLength(1));
    final authUri = Uri.parse(launchedUrls.single);
    expect(authUri.queryParameters['provider'], equals('google'));
    expect(authUri.queryParameters['prompt'], equals('select_account'));
    expect(authUri.queryParameters['code_challenge'], isNotEmpty);

    expect(tokenRequests, hasLength(1));
    expect(tokenRequests.single['auth_code'], equals('google-pkce-code-456'));
    expect(tokenRequests.single['code_verifier'], isNotEmpty);
  });

  test('iOS ASWebAuthenticationSession redirect error=access_denied cancels cleanly without throwing', () async {
    const channel = MethodChannel('com.thaiquran.app/oauth_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return 'io.supabase.thaiquran://login-callback?error=access_denied&error_description=User+cancelled';
    });

    final provider = SupabaseProvider();
    addTearDown(provider.dispose);

    final completed = await provider.signInWithGoogle();

    expect(completed, isFalse);
    expect(provider.isLoggedIn, isFalse);
    expect(provider.authError, isNull);
    expect(provider.isSigningIn, isFalse);
    expect(tokenRequests, isEmpty);
  });
}
