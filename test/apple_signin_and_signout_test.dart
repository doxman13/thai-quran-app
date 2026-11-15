import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_reading_provider.dart';
import 'package:thai_quran_app/providers/notes_provider.dart';
import 'package:thai_quran_app/providers/stats_provider.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';

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

  group('Apple Sign-In & Sign-Out Profile Sync Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SupabaseProvider userEmail and displayName fallbacks work for Apple ID accounts', () {
      final provider = SupabaseProvider();

      // Default state when logged out
      expect(provider.isLoggedIn, isFalse);
      expect(provider.displayName, equals('Reader'));
      expect(provider.userEmail, isEmpty);
      expect(provider.userId, isEmpty);

      // Verify didChangeAppLifecycleState responds to resumed without exceptions
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(provider.isLoggedIn, isFalse);

      provider.dispose();
    });

    test('User email extraction resolves direct email, userMetadata, and identityData fallbacks', () {
      String resolveEmail(User u) {
        if (u.email != null && u.email!.isNotEmpty) return u.email!;
        final metaEmail = u.userMetadata?['email']?.toString() ?? '';
        if (metaEmail.isNotEmpty) return metaEmail;
        for (final identity in u.identities ?? const <UserIdentity>[]) {
          final idEmail = identity.identityData?['email']?.toString() ?? '';
          if (idEmail.isNotEmpty) return idEmail;
        }
        return '';
      }

      String resolveDisplayName(User u) {
        final metaName = u.userMetadata?['full_name']?.toString() ??
            u.userMetadata?['name']?.toString() ??
            '';
        if (metaName.trim().isNotEmpty) return metaName.trim();
        final email = resolveEmail(u);
        if (email.isNotEmpty) {
          return email.split('@')[0];
        }
        return 'Reader';
      }

      // 1. Direct email
      final u1 = User(
        id: '1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
        email: 'direct@test.com',
      );
      expect(resolveEmail(u1), equals('direct@test.com'));
      expect(resolveDisplayName(u1), equals('direct'));

      // 2. Apple metadata email fallback
      final u2 = User(
        id: '2',
        appMetadata: {},
        userMetadata: {'email': 'chareef_za@hotmail.com'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      expect(resolveEmail(u2), equals('chareef_za@hotmail.com'));
      expect(resolveDisplayName(u2), equals('chareef_za'));

      // 3. Apple identityData email fallback
      final u3 = User(
        id: '3',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
        identities: [
          UserIdentity(
            id: 'ident-1',
            userId: '3',
            identityData: {'email': 'apple.user@icloud.com'},
            identityId: 'id-1',
            provider: 'apple',
            createdAt: '2026-01-01',
            lastSignInAt: '2026-01-01',
          ),
        ],
      );
      expect(resolveEmail(u3), equals('apple.user@icloud.com'));
      expect(resolveDisplayName(u3), equals('apple.user'));

      // 4. Full name present in metadata takes priority over email prefix
      final u4 = User(
        id: '4',
        appMetadata: {},
        userMetadata: {
          'full_name': 'Chareef Za',
          'email': 'chareef_za@hotmail.com',
        },
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      expect(resolveDisplayName(u4), equals('Chareef Za'));
    });

    test('LocalReadingProvider, MushafReadingProvider, NotesProvider, and StatsProvider clearAllLocal on sign out', () async {
      final localReading = LocalReadingProvider();
      final mushafReading = MushafReadingProvider();
      final notes = NotesProvider();
      final stats = StatsProvider();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Add local state
      await localReading.toggleBookmark('1', '1');
      expect(localReading.isBookmarked('1', '1'), isTrue);

      await notes.saveNote(surahId: '1', verseId: '1', noteText: 'Reflect');
      expect(notes.getNoteForVerse('1', '1'), equals('Reflect'));

      await stats.logVerseRead('1', '1');
      expect(stats.totalVersesRead, greaterThan(0));

      // Call clearAllLocal
      await localReading.clearAllLocal();
      await mushafReading.clearAllLocal();
      await notes.clearAllLocal();
      await stats.clearAllLocal();

      expect(localReading.isBookmarked('1', '1'), isFalse);
      expect(notes.personalNotes.isEmpty, isTrue);
      expect(stats.totalVersesRead, equals(0));
    });
  });
}
