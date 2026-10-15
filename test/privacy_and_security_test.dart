import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resume_maker/core/services/privacy_cleanup_service.dart';
import 'package:resume_maker/core/utils/resume_file_extractor.dart';
import 'package:resume_maker/data/datasources/ai_remote_datasource.dart';
import 'package:resume_maker/data/datasources/settings_local_datasource.dart';
import 'package:resume_maker/domain/entities/user_skill_entry.dart';
import 'package:resume_maker/presentation/providers/resume_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('File Upload Security & Magic Bytes Validation', () {
    test('Rejects empty file (0 bytes)', () {
      final result = ResumeFileExtractor.extract(
        bytes: [],
        fileName: 'empty_resume.pdf',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('empty (0 bytes)'));
    });

    test('Rejects oversized file (> 5 MB)', () {
      final oversizedBytes = List<int>.filled(6 * 1024 * 1024, 0x20);
      final result = ResumeFileExtractor.extract(
        bytes: oversizedBytes,
        fileName: 'huge_resume.pdf',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('exceeds the 5 MB limit'));
    });

    test('Rejects spoofed PDF lacking %PDF magic bytes', () {
      final fakeBytes = utf8.encode('This is not a real PDF document but has pdf extension');
      final result = ResumeFileExtractor.extract(
        bytes: fakeBytes,
        fileName: 'malicious_spoof.pdf',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('lacks a valid PDF header (%PDF)'));
    });

    test('Rejects spoofed DOCX lacking PK zip magic bytes', () {
      final fakeBytes = utf8.encode('Fake docx content');
      final result = ResumeFileExtractor.extract(
        bytes: fakeBytes,
        fileName: 'malicious_spoof.docx',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('lacks a valid DOCX package signature'));
    });

    test('Sanitizes path traversal in filenames', () {
      final clean = ResumeFileExtractor.sanitizeFileName('../../etc/passwd.pdf');
      expect(clean, isNot(contains('/')));
      expect(clean, isNot(contains('..')));
      expect(clean, equals('____etc_passwd.pdf'));
    });

    test('Accepts valid plain text resume with sufficient length', () {
      final validText = '''
John Doe - Senior Flutter Developer
Email: john.doe@example.com
Phone: +1 555-0192
Experience: 6 years building mobile applications with Dart and Flutter.
Technical Skills: Flutter, Dart, Riverpod, REST API, Git, CI/CD.
''';
      final result = ResumeFileExtractor.extract(
        bytes: utf8.encode(validText),
        fileName: 'resume.txt',
      );
      expect(result.isSuccess, isTrue);
      expect(result.fileType, 'txt');
      expect(result.text, contains('John Doe'));
    });
  });

  group('Privacy Cleanup Service Lifecycle', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        '_keyApiKey': 'stale_insecure_key',
        'cached_resume_text': 'Sensitive candidate resume data...',
        'unrelated_preference': 'preserve_this',
      });
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('clearResumeData purges all in-memory providers', () {
      // 1. Populate providers with sensitive data
      container.read(resumeInputProvider.notifier).updateResumeText('Candidate Secret Experience');
      container.read(resumeInputProvider.notifier).updateJobDescription('Target Job Description');
      container.read(verifiedSkillsProvider.notifier).setSkill('GraphQL', SkillProficiency.intermediate);

      // Verify populated
      expect(container.read(resumeInputProvider).resumeText, contains('Candidate Secret Experience'));
      expect(container.read(verifiedSkillsProvider).containsKey('GraphQL'), isTrue);

      // 2. Perform in-memory cleanup
      // Create a mock WidgetRef wrapper
      final fakeWidgetRef = _FakeWidgetRef(container);
      PrivacyCleanupService.clearResumeData(fakeWidgetRef);

      // 3. Verify completely wiped
      expect(container.read(resumeInputProvider).resumeText, isEmpty);
      expect(container.read(resumeInputProvider).jobDescription, isEmpty);
      expect(container.read(analysisProvider).valueOrNull, isNull);
      expect(container.read(tailoredResumeProvider).valueOrNull, isNull);
      expect(container.read(verifiedSkillsProvider), isEmpty);
      expect(container.read(forceOverrideProvider), isFalse);
    });

    test('clearTemporaryBrowserStorage purges application keys and preserves unrelated keys', () async {
      await PrivacyCleanupService.clearTemporaryBrowserStorage();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.containsKey('_keyApiKey'), isFalse);
      expect(prefs.containsKey('cached_resume_text'), isFalse);
      expect(prefs.getString('unrelated_preference'), 'preserve_this');
    });

    test('Blob URL tracking and revocation executes safely', () {
      PrivacyCleanupService.trackBlobUrl('blob:http://localhost:8080/uuid-1');
      PrivacyCleanupService.trackBlobUrl('blob:http://localhost:8080/uuid-2');
      PrivacyCleanupService.trackBlobUrl('https://google.com'); // Non-blob should not track

      expect(() => PrivacyCleanupService.revokeTrackedBlobUrls(), returnsNormally);
    });

    test('handlePostDownloadCleanup runs complete flow with zero exceptions', () async {
      container.read(resumeInputProvider.notifier).updateResumeText('Candidate Resume');
      bool uiResetCalled = false;

      final fakeRef = _FakeWidgetRef(container);
      await PrivacyCleanupService.handlePostDownloadCleanup(
        ref: fakeRef,
        onResetUi: () {
          uiResetCalled = true;
        },
        downloadInitDelay: const Duration(milliseconds: 10),
      );

      expect(uiResetCalled, isTrue);
      expect(container.read(resumeInputProvider).resumeText, isEmpty);
    });
  });

  group('Client Secrets Hardening', () {
    test('SettingsLocalDataSource does NOT persist API key to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsLocalDataSource();

      await settings.saveApiKey('temporary_test_key');
      expect(await settings.getApiKey(), 'temporary_test_key');

      // Check that SharedPreferences itself has NO api key stored
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains('ApiKey')), isEmpty);
    });

    test('AiRemoteDataSource envApiKey is deprecated and empty in client builds', () {
      expect(AiRemoteDataSource.envApiKey, isEmpty);
    });
  });
}

class _FakeWidgetRef implements WidgetRef {
  final ProviderContainer container;
  _FakeWidgetRef(this.container);

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
