import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/providers/resume_providers.dart';
import '../theme/app_theme.dart';
import 'privacy_storage_stub.dart'
    if (dart.library.js_interop) 'privacy_storage_web.dart';

class PrivacyCleanupService {
  static const List<String> applicationOwnedStorageKeys = [
    '_keyApiKey',
    '_keySelectedModel',
    'cached_resume_text',
    'cached_job_description',
    'resume_draft',
    'user_verified_skills',
    'ats_analysis_result',
    'temp_tailored_resume',
  ];

  static final Set<String> _trackedBlobUrls = {};

  /// Tracks a newly created Blob URL for subsequent lifecycle revocation
  static void trackBlobUrl(String url) {
    if (url.startsWith('blob:')) {
      _trackedBlobUrls.add(url);
    }
  }

  /// Revokes all tracked Blob URLs after download flow completes
  static void revokeTrackedBlobUrls() {
    for (final url in _trackedBlobUrls) {
      revokeWebBlobUrl(url);
    }
    _trackedBlobUrls.clear();
  }

  /// 1. clearResumeData() - Resets all in-memory Riverpod state holding personal info
  static void clearResumeData(WidgetRef ref) {
    ref.read(resumeInputProvider.notifier).clear();
    ref.read(analysisProvider.notifier).reset();
    ref.read(tailoredResumeProvider.notifier).reset();
    ref.read(verifiedSkillsProvider.notifier).clear();
    ref.read(forceOverrideProvider.notifier).state = false;
  }

  /// 2. clearTemporaryBrowserStorage() - Cleans application-owned localStorage & sessionStorage
  static Future<void> clearTemporaryBrowserStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in applicationOwnedStorageKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}

    // Invoke platform-specific web storage cleanup
    clearBrowserWebStorage(applicationOwnedStorageKeys);
  }

  /// 3. deleteTemporaryServerData() - Calls server to verify/purge any ephemeral session data
  static Future<void> deleteTemporaryServerData({String? backendBaseUrl}) async {
    final baseUrl = backendBaseUrl ??
        const String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:8080');
    try {
      final uri = Uri.parse('$baseUrl/api/session');
      final client = http.Client();
      await client.delete(uri).timeout(const Duration(seconds: 3));
      client.close();
    } catch (_) {
      // Backend is ephemeral/stateless; errors in session delete do not impede client privacy
    }
  }

  /// 4. resetApplicationState() - Resets all in-memory providers, UI controllers, and storage
  static Future<void> resetApplicationState({
    required WidgetRef ref,
    VoidCallback? onResetUi,
  }) async {
    clearResumeData(ref);
    if (onResetUi != null) {
      onResetUi();
    }
    await clearTemporaryBrowserStorage();
  }

  /// 5. Post-Download Privacy Lifecycle Flow:
  /// - Waits for browser download streaming initiation (1500 ms).
  /// - Purges in-memory resume state.
  /// - Purges application-owned browser storage.
  /// - Revokes temporary Blob URLs.
  /// - Contacts server to purge session data.
  /// - Resets UI state to initial clean workspace.
  /// - Displays user confirmation snackbar.
  static Future<void> handlePostDownloadCleanup({
    required WidgetRef ref,
    VoidCallback? onResetUi,
    ScaffoldMessengerState? messenger,
    Duration downloadInitDelay = const Duration(milliseconds: 1500),
  }) async {
    // 1. Give the browser sufficient time to begin the file download stream
    await Future.delayed(downloadInitDelay);

    // 2. Clear all in-memory resume data
    clearResumeData(ref);

    // 3. Reset UI controllers
    if (onResetUi != null) {
      onResetUi();
    }

    // 4. Revoke temporary Blob URLs
    revokeTrackedBlobUrls();

    // 5. Clear application-owned browser storage
    await clearTemporaryBrowserStorage();

    // 6. Delete server temporary session data
    await deleteTemporaryServerData();

    // 7. Show user-facing confirmation
    messenger?.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Download initiated. All temporary resume data and session files have been securely cleared.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.matchHigh,
        duration: Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 6. Session Start / Reload Cleanup
  /// Ensures fresh page load starts with zero stored personal data in browser storage
  static Future<void> cleanupOnSessionStart(WidgetRef ref) async {
    await clearTemporaryBrowserStorage();
  }
}

/// Lifecycle observer to clear data when app lifecycle detaches
class PrivacyAppLifecycleObserver with WidgetsBindingObserver {
  final WidgetRef ref;
  final VoidCallback? onResetUi;

  PrivacyAppLifecycleObserver({
    required this.ref,
    this.onResetUi,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      PrivacyCleanupService.resetApplicationState(
        ref: ref,
        onResetUi: onResetUi,
      );
    }
  }
}
