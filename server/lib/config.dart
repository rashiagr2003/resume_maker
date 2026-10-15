import 'dart:io';

class ServerConfig {
  final int port;
  final String geminiApiKey;
  final String groqApiKey;
  final String geminiModel;
  final String groqModel;
  final String allowedCorsOrigin;

  ServerConfig({
    required this.port,
    required this.geminiApiKey,
    required this.groqApiKey,
    required this.geminiModel,
    required this.groqModel,
    required this.allowedCorsOrigin,
  });

  factory ServerConfig.load() {
    final env = _loadEnvMap();

    final port = int.tryParse(env['PORT'] ?? Platform.environment['PORT'] ?? '8080') ?? 8080;
    final geminiApiKey = (env['GEMINI_API_KEY'] ?? Platform.environment['GEMINI_API_KEY'] ?? '').trim();
    final groqApiKey = (env['GROQ_API_KEY'] ?? Platform.environment['GROQ_API_KEY'] ?? '').trim();
    final geminiModel = (env['GEMINI_MODEL'] ?? Platform.environment['GEMINI_MODEL'] ?? 'gemini-1.5-flash').trim();
    final groqModel = (env['GROQ_MODEL'] ?? Platform.environment['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile').trim();
    final allowedCorsOrigin = (env['ALLOWED_CORS_ORIGIN'] ?? Platform.environment['ALLOWED_CORS_ORIGIN'] ?? '*').trim();

    return ServerConfig(
      port: port,
      geminiApiKey: geminiApiKey,
      groqApiKey: groqApiKey,
      geminiModel: geminiModel,
      groqModel: groqModel,
      allowedCorsOrigin: allowedCorsOrigin,
    );
  }

  static Map<String, String> _loadEnvMap() {
    final map = <String, String>{};
    final candidates = [
      File('.env'),
      File('server/.env'),
      File('../.env'),
    ];

    for (final file in candidates) {
      if (file.existsSync()) {
        try {
          final lines = file.readAsLinesSync();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
            final idx = trimmed.indexOf('=');
            if (idx > 0) {
              final key = trimmed.substring(0, idx).trim();
              var val = trimmed.substring(idx + 1).trim();
              if ((val.startsWith('"') && val.endsWith('"')) ||
                  (val.startsWith("'") && val.endsWith("'"))) {
                val = val.substring(1, val.length - 1);
              }
              map[key] = val;
            }
          }
          break;
        } catch (_) {}
      }
    }
    return map;
  }
}
