import 'package:test/test.dart';
import '../lib/services/ai_provider.dart';
import '../lib/services/ai_fallback_orchestrator.dart';
import '../lib/middleware/security_middleware.dart';

class MockAiProvider implements AiProvider {
  @override
  final String name;
  bool shouldFail;
  bool isRecoverable;
  int callCount = 0;
  Map<String, dynamic>? customResponse;

  MockAiProvider({
    required this.name,
    this.shouldFail = false,
    this.isRecoverable = true,
    this.customResponse,
  });

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
    callCount++;
    if (shouldFail) {
      throw AiProviderException(
        provider: name,
        statusCode: 429,
        message: 'Rate limit exceeded on $name',
        isRecoverable: isRecoverable,
      );
    }
    return customResponse ?? {
      'detected_job_title': 'Flutter Engineer',
      'detected_domain': 'Software',
      'detected_seniority': 'Senior',
      'overall_score': 85.0,
      'score_breakdown': {
        'required_skills_and_qualifications': 25.0,
        'relevant_experience_and_responsibilities': 22.0,
        'job_specific_keywords_and_terminology': 14.0,
        'education_and_certifications': 8.0,
        'relevant_achievements': 8.0,
        'resume_readability_and_parsing': 8.0,
      },
      'job_city': 'Bengaluru',
      'resume_city': 'Bengaluru',
      'is_city_aligned': true,
      'matched_requirements': ['Flutter', 'Dart', 'Riverpod'],
      'partially_matched_requirements': ['GraphQL'],
      'missing_requirements': ['Kubernetes'],
      'mandatory_gaps': [],
      'preferred_gaps': ['Kubernetes'],
      'transferable_skills': ['Mobile Architecture'],
      'keyword_analysis': 'High alignment',
      'experience_analysis': 'Solid background',
      'education_certification_analysis': 'B.Tech CS verified',
      'parsing_issues': [],
      'improvement_recommendations': ['Highlight GraphQL experience'],
      'score_explanation': 'Strong candidate with direct match for core stack.',
      'evidence_and_uncertainties': 'None',
      'summary': 'Candidate is an excellent match.',
    };
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
    callCount++;
    if (shouldFail) {
      throw AiProviderException(
        provider: name,
        statusCode: 503,
        message: 'Service unavailable on $name',
        isRecoverable: isRecoverable,
      );
    }
    return {
      'tailoredResume': '# Tailored Resume Content\n• Experience item',
      'alignedCity': targetCity,
      'tailoredSummary': 'Experienced Flutter Engineer...',
      'addedKeywords': ['Flutter', 'Dart'],
      'modifiedSections': ['Professional Summary', 'Skills'],
      'cityAlignmentNote': 'Aligned to $targetCity',
    };
  }
}

void main() {
  group('AI Fallback Orchestrator', () {
    test('Gemini succeeds without invoking Groq', () async {
      final gemini = MockAiProvider(name: 'Gemini');
      final groq = MockAiProvider(name: 'Groq');
      final orchestrator = AiFallbackOrchestrator(gemini: gemini, groq: groq);

      final result = await orchestrator.analyze(
        resumeText: 'Experienced Flutter engineer with 5 years experience...',
        jobDescription: 'Looking for a senior Flutter developer with Dart skills...',
      );

      expect(gemini.callCount, 1);
      expect(groq.callCount, 0);
      expect(result.providerUsed, 'Gemini');
      expect(result.fallbackTriggered, false);
      expect(result.data['overall_score'], 85.0);
    });

    test('Gemini failure triggers automatic Groq fallback', () async {
      final gemini = MockAiProvider(name: 'Gemini', shouldFail: true);
      final groq = MockAiProvider(name: 'Groq');
      final orchestrator = AiFallbackOrchestrator(gemini: gemini, groq: groq);

      final result = await orchestrator.analyze(
        resumeText: 'Experienced Flutter engineer with 5 years experience...',
        jobDescription: 'Looking for a senior Flutter developer with Dart skills...',
      );

      expect(gemini.callCount, 1);
      expect(groq.callCount, 1);
      expect(result.providerUsed, 'Groq');
      expect(result.fallbackTriggered, true);
      expect(result.fallbackReason, contains('Rate limit exceeded on Gemini'));
      expect(result.data['overall_score'], 85.0);
    });

    test('Both providers failing throws actionable exception', () async {
      final gemini = MockAiProvider(name: 'Gemini', shouldFail: true);
      final groq = MockAiProvider(name: 'Groq', shouldFail: true);
      final orchestrator = AiFallbackOrchestrator(gemini: gemini, groq: groq);

      expect(
        () => orchestrator.analyze(
          resumeText: 'Experienced Flutter engineer with 5 years experience...',
          jobDescription: 'Looking for a senior Flutter developer with Dart skills...',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Both AI providers failed'),
        )),
      );
    });

    test('Non-recoverable errors do not trigger fallback retry', () async {
      final gemini = MockAiProvider(name: 'Gemini', shouldFail: true, isRecoverable: false);
      final groq = MockAiProvider(name: 'Groq');
      final orchestrator = AiFallbackOrchestrator(gemini: gemini, groq: groq);

      expect(
        () => orchestrator.analyze(
          resumeText: 'Experienced Flutter engineer with 5 years experience...',
          jobDescription: 'Looking for a senior Flutter developer with Dart skills...',
        ),
        throwsA(isA<AiProviderException>()),
      );
      expect(groq.callCount, 0); // Must NOT call Groq on non-recoverable error
    });

    test('Input validation rejects empty or too short input', () async {
      final gemini = MockAiProvider(name: 'Gemini');
      final groq = MockAiProvider(name: 'Groq');
      final orchestrator = AiFallbackOrchestrator(gemini: gemini, groq: groq);

      expect(
        () => orchestrator.analyze(resumeText: 'short', jobDescription: 'valid job description with length'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ATS score normalization clamps out-of-range scores to rubric limits', () {
      final raw = {
        'overall_score': 150.0,
        'score_breakdown': {
          'required_skills_and_qualifications': 50.0, // max 30
          'relevant_experience_and_responsibilities': 40.0, // max 25
          'job_specific_keywords_and_terminology': 30.0, // max 15
          'education_and_certifications': 20.0, // max 10
          'relevant_achievements': 20.0, // max 10
          'resume_readability_and_parsing': 20.0, // max 10
        },
      };

      final normalized = AiFallbackOrchestrator.normalizeAtsResponse(raw);
      final breakdown = normalized['score_breakdown'] as Map<String, dynamic>;

      expect(breakdown['required_skills_and_qualifications'], 30.0);
      expect(breakdown['relevant_experience_and_responsibilities'], 25.0);
      expect(breakdown['job_specific_keywords_and_terminology'], 15.0);
      expect(breakdown['education_and_certifications'], 10.0);
      expect(breakdown['relevant_achievements'], 10.0);
      expect(breakdown['resume_readability_and_parsing'], 10.0);
      expect(normalized['overall_score'], 100.0);
    });
  });

  group('RateLimiter', () {
    test('Allows requests up to limit and blocks subsequent requests', () {
      final limiter = RateLimiter(maxRequests: 3, window: const Duration(seconds: 10));
      expect(limiter.isAllowed('192.168.1.1'), isTrue);
      expect(limiter.isAllowed('192.168.1.1'), isTrue);
      expect(limiter.isAllowed('192.168.1.1'), isTrue);
      expect(limiter.isAllowed('192.168.1.1'), isFalse);

      // Separate IP should be allowed
      expect(limiter.isAllowed('192.168.1.2'), isTrue);
    });
  });
}
