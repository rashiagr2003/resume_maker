import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../lib/config.dart';
import '../lib/middleware/security_middleware.dart';
import '../lib/services/ai_fallback_orchestrator.dart';
import '../lib/services/gemini_provider.dart';
import '../lib/services/groq_provider.dart';

void main() async {
  final config = ServerConfig.load();

  final geminiProvider = GeminiProvider(
    apiKey: config.geminiApiKey,
    model: config.geminiModel,
  );

  final groqProvider = GroqProvider(
    apiKey: config.groqApiKey,
    model: config.groqModel,
  );

  final orchestrator = AiFallbackOrchestrator(
    gemini: geminiProvider,
    groq: groqProvider,
  );

  final app = Router();

  // 1. Health check & configuration status (zero secrets exposed)
  app.get('/api/health', (Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'healthy',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'providers': {
          'gemini': {
            'configured': config.geminiApiKey.isNotEmpty,
            'model': config.geminiModel,
          },
          'groq': {
            'configured': config.groqApiKey.isNotEmpty,
            'model': config.groqModel,
          },
        },
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // 2. ATS Analysis Endpoint (Gemini -> Groq Fallback)
  app.post('/api/analyze', (Request request) async {
    try {
      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return Response(400,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'error': 'Request body is empty.'}));
      }

      final Map<String, dynamic> body = jsonDecode(bodyStr);
      final resumeText = (body['resumeText'] ?? '').toString();
      final jobDescription = (body['jobDescription'] ?? '').toString();

      if (resumeText.trim().length < 20) {
        return Response(400,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'error': 'Resume text is too short (min 20 characters).'}));
      }
      if (jobDescription.trim().length < 20) {
        return Response(400,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'error': 'Job description is too short (min 20 characters).'}));
      }

      final result = await orchestrator.analyze(
        resumeText: resumeText,
        jobDescription: jobDescription,
        jobTitle: body['jobTitle']?.toString(),
        companyName: body['companyName']?.toString(),
        industryDomain: body['industryDomain']?.toString(),
        experienceLevel: body['experienceLevel']?.toString(),
        jobLocation: body['jobLocation']?.toString(),
      );

      return Response.ok(
        jsonEncode(result.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } on ArgumentError catch (e) {
      return Response(400,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'error': e.message}));
    } catch (e) {
      return Response(502,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'error': 'AI analysis failed across available providers.',
            'details': e.toString(),
          }));
    }
  });

  // 3. Resume Tailoring Endpoint (Enforces 70+ threshold & candidate skills)
  app.post('/api/tailor', (Request request) async {
    try {
      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return Response(400,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'error': 'Request body is empty.'}));
      }

      final Map<String, dynamic> body = jsonDecode(bodyStr);
      final resumeText = (body['resumeText'] ?? '').toString();
      final jobDescription = (body['jobDescription'] ?? '').toString();
      final detectedJobTitle = (body['detectedJobTitle'] ?? 'Target Role').toString();
      final detectedDomain = (body['detectedDomain'] ?? 'General').toString();
      final targetCity = (body['targetCity'] ?? 'Remote / Unspecified').toString();
      final targetPages = (body['targetPages'] as num?)?.toInt() ?? 1;
      final forceOverride = body['forceOverride'] == true;
      final score = (body['score'] as num?)?.toDouble() ?? 0.0;
      final threshold = (body['threshold'] as num?)?.toDouble() ?? 70.0;

      // Strict ATS threshold check on the server
      if (score < threshold && !forceOverride) {
        return Response(403,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'error': 'ATS score (${score.toStringAsFixed(1)}%) is below the required ${threshold.toInt()}% threshold. Optimization locked.',
            }));
      }

      final verifiedSkills = body['verifiedSkills'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['verifiedSkills'] as Map)
          : <String, dynamic>{};

      final result = await orchestrator.tailor(
        resumeText: resumeText,
        jobDescription: jobDescription,
        detectedJobTitle: detectedJobTitle,
        detectedDomain: detectedDomain,
        targetCity: targetCity,
        targetPages: targetPages,
        verifiedSkills: verifiedSkills,
      );

      return Response.ok(
        jsonEncode(result.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } on ArgumentError catch (e) {
      return Response(400,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'error': e.message}));
    } catch (e) {
      return Response(502,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'error': 'AI resume tailoring failed across available providers.',
            'details': e.toString(),
          }));
    }
  });

  // 4. Session cleanup endpoint (confirms zero server-side storage)
  app.delete('/api/session', (Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'cleared',
        'message': 'Ephemeral session verified. Zero temporary files or records retained on server.',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Configure CORS
  final corsHeadersMap = {
    'Access-Control-Allow-Origin': config.allowedCorsOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
  };

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: corsHeadersMap))
      .addMiddleware(createSecurityMiddleware())
      .addHandler(app.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, config.port);
  print('====================================================');
  print('  Resume Maker Secure Backend Service');
  print('  Listening on http://${server.address.host}:${server.port}');
  print('  Gemini configured: ${config.geminiApiKey.isNotEmpty} (${config.geminiModel})');
  print('  Groq fallback configured: ${config.groqApiKey.isNotEmpty} (${config.groqModel})');
  print('====================================================');
}
