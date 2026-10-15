import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';
import 'prompt_templates.dart';

class GeminiProvider implements AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiProvider({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Gemini';

  @override
  Future<Map<String, dynamic>> analyzeResume({
    required String resumeText,
    required String jobDescription,
    String? jobTitle,
    String? companyName,
    String? industryDomain,
    String? experienceLevel,
    String? jobLocation,
  }) async {
    if (apiKey.isEmpty) {
      throw AiProviderException(
        provider: name,
        message: 'Gemini API key is not configured on the server.',
        isRecoverable: true,
      );
    }

    final systemPrompt = PromptTemplates.buildAtsSystemPrompt();
    final userContent = PromptTemplates.buildAtsUserContent(
      resumeText: resumeText,
      jobDescription: jobDescription,
      jobTitle: jobTitle,
      companyName: companyName,
      industryDomain: industryDomain,
      experienceLevel: experienceLevel,
      jobLocation: jobLocation,
    );

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": "$systemPrompt\n\n$userContent"},
          ],
        },
      ],
      "generationConfig": {
        "temperature": 0.15,
        "responseMimeType": "application/json",
      },
    };

    return await _callGeminiApi(payload);
  }

  @override
  Future<Map<String, dynamic>> tailorResume({
    required String resumeText,
    required String jobDescription,
    required String detectedJobTitle,
    required String detectedDomain,
    required String targetCity,
    required int targetPages,
    required Map<String, dynamic> verifiedSkills,
  }) async {
    if (apiKey.isEmpty) {
      throw AiProviderException(
        provider: name,
        message: 'Gemini API key is not configured on the server.',
        isRecoverable: true,
      );
    }

    final systemPrompt = PromptTemplates.buildTailoringSystemPrompt(
      targetPages: targetPages,
      targetCity: targetCity,
      verifiedSkills: verifiedSkills,
    );
    final userContent = PromptTemplates.buildTailoringUserContent(
      resumeText: resumeText,
      jobDescription: jobDescription,
      detectedJobTitle: detectedJobTitle,
      detectedDomain: detectedDomain,
    );

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": "$systemPrompt\n\n$userContent"},
          ],
        },
      ],
      "generationConfig": {
        "temperature": 0.2,
        "responseMimeType": "application/json",
      },
    };

    return await _callGeminiApi(payload);
  }

  Future<Map<String, dynamic>> _callGeminiApi(Map<String, dynamic> payload) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final isRecoverable = _isStatusCodeRecoverable(response.statusCode);
        throw AiProviderException(
          provider: name,
          statusCode: response.statusCode,
          message: 'Gemini API returned status ${response.statusCode}: ${_sanitizeErrorBody(response.body)}',
          isRecoverable: isRecoverable,
        );
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text == null || text.toString().trim().isEmpty) {
        throw AiProviderException(
          provider: name,
          statusCode: 200,
          message: 'Gemini returned an empty response body.',
          isRecoverable: true,
        );
      }

      final sanitized = _stripMarkdownFences(text.toString());
      return jsonDecode(sanitized) as Map<String, dynamic>;
    } on TimeoutException {
      throw AiProviderException(
        provider: name,
        message: 'Gemini request timed out after 30 seconds.',
        isRecoverable: true,
      );
    } on SocketException catch (e) {
      throw AiProviderException(
        provider: name,
        message: 'Network connectivity error connecting to Gemini: $e',
        isRecoverable: true,
      );
    } on FormatException catch (e) {
      throw AiProviderException(
        provider: name,
        message: 'Failed to parse JSON response from Gemini: $e',
        isRecoverable: true,
      );
    }
  }

  bool _isStatusCodeRecoverable(int code) {
    // 429 = Rate Limit / Quota Exceeded
    // 500, 502, 503, 504 = Server errors / unavailable
    // 401, 403 = Key expired, bad permissions
    // 404 = Model deprecation / not found
    return code == 429 ||
        code == 500 ||
        code == 502 ||
        code == 503 ||
        code == 504 ||
        code == 401 ||
        code == 403 ||
        code == 404;
  }

  String _sanitizeErrorBody(String body) {
    if (body.length > 200) {
      return '${body.substring(0, 200)}...';
    }
    return body;
  }

  String _stripMarkdownFences(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }
}
