import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';
import 'prompt_templates.dart';

class GroqProvider implements AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  GroqProvider({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Groq';

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
        message: 'Groq API key is not configured on the server.',
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
      "model": model,
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userContent},
      ],
      "response_format": {"type": "json_object"},
      "temperature": 0.15,
    };

    return await _callGroqApi(payload);
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
        message: 'Groq API key is not configured on the server.',
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
      "model": model,
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userContent},
      ],
      "response_format": {"type": "json_object"},
      "temperature": 0.2,
    };

    return await _callGroqApi(payload);
  }

  Future<Map<String, dynamic>> _callGroqApi(Map<String, dynamic> payload) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final isRecoverable = _isStatusCodeRecoverable(response.statusCode);
        throw AiProviderException(
          provider: name,
          statusCode: response.statusCode,
          message: 'Groq API returned status ${response.statusCode}: ${_sanitizeErrorBody(response.body)}',
          isRecoverable: isRecoverable,
        );
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'];
      if (content == null || content.toString().trim().isEmpty) {
        throw AiProviderException(
          provider: name,
          statusCode: 200,
          message: 'Groq returned an empty response content.',
          isRecoverable: true,
        );
      }

      final sanitized = _stripMarkdownFences(content.toString());
      return jsonDecode(sanitized) as Map<String, dynamic>;
    } on TimeoutException {
      throw AiProviderException(
        provider: name,
        message: 'Groq request timed out after 30 seconds.',
        isRecoverable: true,
      );
    } on SocketException catch (e) {
      throw AiProviderException(
        provider: name,
        message: 'Network connectivity error connecting to Groq: $e',
        isRecoverable: true,
      );
    } on FormatException catch (e) {
      throw AiProviderException(
        provider: name,
        message: 'Failed to parse JSON response from Groq: $e',
        isRecoverable: true,
      );
    }
  }

  bool _isStatusCodeRecoverable(int code) {
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
