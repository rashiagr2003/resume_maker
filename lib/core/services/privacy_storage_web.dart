import 'package:web/web.dart' as web;

/// Browser-specific implementation of temporary storage and Blob URL cleanup
void clearBrowserWebStorage(List<String> applicationKeys) {
  try {
    // 1. Remove only application-owned keys from localStorage
    for (final key in applicationKeys) {
      web.window.localStorage.removeItem(key);
      web.window.localStorage.removeItem('flutter.$key');
    }

    // 2. Clear entire sessionStorage for this session
    web.window.sessionStorage.clear();
  } catch (_) {
    // Silently handle any browser security restrictions
  }
}

void revokeWebBlobUrl(String url) {
  try {
    if (url.startsWith('blob:')) {
      web.URL.revokeObjectURL(url);
    }
  } catch (_) {}
}
