import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';
import 'package:thai_quran_app/theme/app_theme.dart';
import 'package:thai_quran_app/widgets/auth_bottom_sheet.dart';

class _FakeAuthSupabaseProvider extends SupabaseProvider {
  Future<bool> Function()? googleHandler;
  Future<bool> Function()? appleHandler;
  bool _fakeSigningIn = false;

  @override
  bool get isSigningIn => _fakeSigningIn || super.isSigningIn;

  void setFakeSigningIn(bool value) {
    _fakeSigningIn = value;
    notifyListeners();
  }

  @override
  Future<bool> signInWithGoogle() async {
    if (googleHandler != null) return googleHandler!();
    return false;
  }

  @override
  Future<bool> signInWithApple() async {
    if (appleHandler != null) return appleHandler!();
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        publishableKey: 'test-anon-key',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // Ignore if already initialized in test isolate.
    }
  });

  group('SupabaseProvider auth cancellation & error formatting', () {
    test('isAuthCancellation recognizes Google and Apple cancellation errors', () {
      expect(
        SupabaseProvider.isAuthCancellation(
          PlatformException(code: 'sign_in_canceled'),
        ),
        isTrue,
      );
      expect(
        SupabaseProvider.isAuthCancellation(
          PlatformException(code: '12501', message: 'User cancelled'),
        ),
        isTrue,
      );
      expect(
        SupabaseProvider.isAuthCancellation(
          PlatformException(code: '1001', message: 'ASAuthorizationError 1001'),
        ),
        isTrue,
      );
      expect(
        SupabaseProvider.isAuthCancellation(
          PlatformException(code: 'canceled'),
        ),
        isTrue,
      );
      expect(
        SupabaseProvider.isAuthCancellation(
          const AuthException('access_denied'),
        ),
        isTrue,
      );
      expect(
        SupabaseProvider.isAuthCancellation(
          const AuthException('User cancelled', code: 'user_cancelled_authorize'),
        ),
        isTrue,
      );
    });

    test('isAuthCancellation returns false for real non-cancel errors', () {
      expect(
        SupabaseProvider.isAuthCancellation(
          PlatformException(
            code: 'network_error',
            message: 'Network connection failed',
          ),
        ),
        isFalse,
      );
      expect(
        SupabaseProvider.isAuthCancellation(
          const AuthException(
            'Invalid login credentials',
            code: 'invalid_credentials',
          ),
        ),
        isFalse,
      );
    });

    test('formatAuthError returns localized friendly messages without raw exception boilerplate', () {
      final netErr = PlatformException(
        code: 'network_error',
        message: 'SocketException: Failed host lookup',
      );
      final enNet = SupabaseProvider.formatAuthError(netErr, isThai: false);
      final thNet = SupabaseProvider.formatAuthError(netErr, isThai: true);
      expect(enNet, contains('Unable to connect to the network'));
      expect(thNet, contains('ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้'));
      expect(enNet, isNot(contains('PlatformException')));
      expect(thNet, isNot(contains('PlatformException')));

      const credErr = AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      final enCred = SupabaseProvider.formatAuthError(credErr, isThai: false);
      final thCred = SupabaseProvider.formatAuthError(credErr, isThai: true);
      expect(enCred, equals('Invalid email or password.'));
      expect(thCred, equals('อีเมลหรือรหัสผ่านไม่ถูกต้อง'));
      expect(enCred, isNot(contains('AuthException')));

      final genericErr = Exception('Something unexpected');
      final enGen = SupabaseProvider.formatAuthError(genericErr, isThai: false);
      expect(enGen, equals('Sign-in failed. Please try again.'));
      expect(enGen, isNot(contains('Exception:')));
    });

    test('deep link query cancellation clears authError and isSigningIn', () async {
      final provider = SupabaseProvider();
      addTearDown(provider.dispose);

      await provider.handleIncomingDeepLinkForTest(
        Uri.parse(
          'io.supabase.thaiquran://login-callback?error=access_denied&error_description=User+cancelled',
        ),
      );

      expect(provider.authError, isNull);
      expect(provider.isSigningIn, isFalse);
    });

    test('deep link fragment cancellation clears authError and isSigningIn', () async {
      final provider = SupabaseProvider();
      addTearDown(provider.dispose);

      await provider.handleIncomingDeepLinkForTest(
        Uri.parse(
          'io.supabase.thaiquran://login-callback#error=access_denied&error_code=user_cancelled_authorize&error_description=User+canceled',
        ),
      );

      expect(provider.authError, isNull);
      expect(provider.isSigningIn, isFalse);
    });

    test('deep link real OAuth error stores friendly formatted error without raw AuthException', () async {
      final provider = SupabaseProvider();
      addTearDown(provider.dispose);

      await provider.handleIncomingDeepLinkForTest(
        Uri.parse(
          'io.supabase.thaiquran://login-callback?error=server_error&error_description=OAuth+provider+failure',
        ),
      );

      expect(provider.authError, isNotNull);
      expect(provider.authError, isNot(contains('AuthException')));
      expect(provider.isSigningIn, isFalse);
    });
  });

  group('AuthBottomSheetContent cancellation & busy-state tests', () {
    Widget buildSheet(_FakeAuthSupabaseProvider provider, {bool isThai = false}) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<SupabaseProvider>.value(
            value: provider,
            child: AuthBottomSheetContent(
              colors: AppThemeColors.teal(isDark: false),
              isThai: isThai,
            ),
          ),
        ),
      );
    }

    testWidgets('Google sign-in returning false stays open without error banner', (tester) async {
      final provider = _FakeAuthSupabaseProvider()
        ..googleHandler = () async => false;

      await tester.pumpWidget(buildSheet(provider));
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthBottomSheetContent), findsOneWidget);
      expect(find.textContaining('Sign-in failed'), findsNothing);
      expect(find.textContaining('cancelled'), findsNothing);
    });

    testWidgets('Google sign-in throwing sign_in_canceled stays open without error banner', (tester) async {
      final provider = _FakeAuthSupabaseProvider()
        ..googleHandler = () async {
          throw PlatformException(code: 'sign_in_canceled');
        };

      await tester.pumpWidget(buildSheet(provider));
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthBottomSheetContent), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('Sign-in failed'), findsNothing);
    });

    testWidgets('Apple sign-in cancellation stays open without error banner', (tester) async {
      final provider = _FakeAuthSupabaseProvider()
        ..appleHandler = () async {
          throw const AuthException(
            'User cancelled',
            code: 'user_cancelled_authorize',
          );
        };

      await tester.pumpWidget(buildSheet(provider));
      await tester.tap(find.text('Sign in with Apple'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthBottomSheetContent), findsOneWidget);
      expect(find.textContaining('AuthException'), findsNothing);
      expect(find.textContaining('Sign-in failed'), findsNothing);
    });

    testWidgets('Google sign-in real error renders formatted message without raw PlatformException', (tester) async {
      final provider = _FakeAuthSupabaseProvider()
        ..googleHandler = () async {
          throw PlatformException(
            code: 'network_error',
            message: 'SocketException',
          );
        };

      await tester.pumpWidget(buildSheet(provider));
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to connect to the network. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PlatformException'), findsNothing);
    });

    testWidgets('Google sign-in returning true pops the modal route', (tester) async {
      final provider = _FakeAuthSupabaseProvider()
        ..googleHandler = () async => true;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => ChangeNotifierProvider<SupabaseProvider>.value(
                      value: provider,
                      child: AuthBottomSheetContent(
                        colors: AppThemeColors.teal(isDark: false),
                        isThai: false,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthBottomSheetContent), findsOneWidget);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthBottomSheetContent), findsNothing);
    });

    testWidgets('OAuth and submit buttons are disabled while auth request is in progress', (tester) async {
      final completer = Completer<bool>();
      final provider = _FakeAuthSupabaseProvider()
        ..googleHandler = () => completer.future;

      await tester.pumpWidget(buildSheet(provider));
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      final googleBtn = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Sign in with Google'),
          matching: find.byType(OutlinedButton),
        ),
      );
      final appleBtn = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Sign in with Apple'),
          matching: find.byType(OutlinedButton),
        ),
      );
      final emailBtn = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );

      expect(googleBtn.onPressed, isNull);
      expect(appleBtn.onPressed, isNull);
      expect(emailBtn.onPressed, isNull);

      completer.complete(false);
      await tester.pumpAndSettle();
    });
  });
}
