/// Stub implementation of browser-specific storage cleaner for VM / unit tests
void clearBrowserWebStorage(List<String> applicationKeys) {
  // No-op in non-web environments
}

void revokeWebBlobUrl(String url) {
  // No-op in non-web environments
}
