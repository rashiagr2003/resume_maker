import 'dart:developer' as developer;
import 'ai_provider.dart';

class FallbackResult {
  final Map<String, dynamic> data;
  final String providerUsed;
  final bool fallbackTriggered;
  final String? fallbackReason;

  FallbackResult({
    required this.data,
    required this.providerUsed,
    required this.fallbackTriggered,
    this.fallbackReason,
  });

  Map<String, dynamic> toJson() {
    return {
      ...data,
      '_providerMetadata': {
        'provider': providerUsed,
        'fallbackTriggered': fallbackTriggered,
        if (fallbackReason != null) 'fallbackReason': fallbackReason,
      },
    };
  }
}

class AiFallbackOrchestrator {
  final AiProvider gemini;
  final AiProvider groq;

  AiFallbackOrchestrator({
    required this.gemini,
    required this.groq,
  });

  Future<FallbackResult> analyze({
    required String resumeText,
    required String jobDescription,
    String? jobTitle,
    String? companyName,
    String? industryDomain,
    String? experienceLevel,
    String? jobLocation,
  }) async {
    // 1. Validate inputs before calling any AI provider
    _validateInputs(resumeText, jobDescription);

    // 2. Try Gemini first
    try {
      final raw = await gemini.analyzeResume(
        resumeText: resumeText,
        jobDescription: jobDescription,
        jobTitle: jobTitle,
        companyName: companyName,
        industryDomain: industryDomain,
        experienceLevel: experienceLevel,
        jobLocation: jobLocation,
      );
      final normalized = normalizeAtsResponse(raw);
      return FallbackResult(
        data: normalized,
        providerUsed: gemini.name,
        fallbackTriggered: false,
      );
    } catch (e) {
      if (e is AiProviderException && !e.isRecoverable) {
        // Non-recoverable error (e.g. invalid request); do not retry
        rethrow;
      }

      final errorMsg = e.toString();
      developer.log(
        'Gemini ATS analysis failed: $errorMsg. Executing automatic fallback to Groq...',
        name: 'AiFallbackOrchestrator',
      );

      // 3. Fallback to Groq
      try {
        final groqRaw = await groq.analyzeResume(
          resumeText: resumeText,
          jobDescription: jobDescription,
          jobTitle: jobTitle,
          companyName: companyName,
          industryDomain: industryDomain,
          experienceLevel: experienceLevel,
          jobLocation: jobLocation,
        );
        final normalized = normalizeAtsResponse(groqRaw);
        return FallbackResult(
          data: normalized,
          providerUsed: groq.name,
          fallbackTriggered: true,
          fallbackReason: errorMsg,
        );
      } catch (groqErr) {
        developer.log(
          'Groq fallback also failed: $groqErr',
          name: 'AiFallbackOrchestrator',
          error: groqErr,
        );
        throw Exception(
          'Both AI providers failed. Gemini: $errorMsg | Groq: $groqErr',
        );
      }
    }
  }

  Future<FallbackResult> tailor({
    required String resumeText,
    required String jobDescription,
    required String detectedJobTitle,
    required String detectedDomain,
    required String targetCity,
    required int targetPages,
    required Map<String, dynamic> verifiedSkills,
  }) async {
    _validateInputs(resumeText, jobDescription);

    // Try Gemini first
    try {
      final raw = await gemini.tailorResume(
        resumeText: resumeText,
        jobDescription: jobDescription,
        detectedJobTitle: detectedJobTitle,
        detectedDomain: detectedDomain,
        targetCity: targetCity,
        targetPages: targetPages,
        verifiedSkills: verifiedSkills,
      );
      final normalized = normalizeTailoringResponse(raw, targetCity, targetPages);
      return FallbackResult(
        data: normalized,
        providerUsed: gemini.name,
        fallbackTriggered: false,
      );
    } catch (e) {
      if (e is AiProviderException && !e.isRecoverable) {
        rethrow;
      }

      final errorMsg = e.toString();
      developer.log(
        'Gemini resume tailoring failed: $errorMsg. Executing automatic fallback to Groq...',
        name: 'AiFallbackOrchestrator',
      );

      try {
        final groqRaw = await groq.tailorResume(
          resumeText: resumeText,
          jobDescription: jobDescription,
          detectedJobTitle: detectedJobTitle,
          detectedDomain: detectedDomain,
          targetCity: targetCity,
          targetPages: targetPages,
          verifiedSkills: verifiedSkills,
        );
        final normalized = normalizeTailoringResponse(groqRaw, targetCity, targetPages);
        return FallbackResult(
          data: normalized,
          providerUsed: groq.name,
          fallbackTriggered: true,
          fallbackReason: errorMsg,
        );
      } catch (groqErr) {
        developer.log(
          'Groq tailoring fallback also failed: $groqErr',
          name: 'AiFallbackOrchestrator',
          error: groqErr,
        );
        throw Exception(
          'Both AI providers failed tailoring. Gemini: $errorMsg | Groq: $groqErr',
        );
      }
    }
  }

  void _validateInputs(String resumeText, String jobDescription) {
    if (resumeText.trim().length < 20) {
      throw ArgumentError('Resume text is too short or empty (min 20 characters required).');
    }
    if (jobDescription.trim().length < 20) {
      throw ArgumentError('Job description is too short or empty (min 20 characters required).');
    }
    if (resumeText.length > 200000 || jobDescription.length > 200000) {
      throw ArgumentError('Input exceeds maximum allowed size (200,000 characters).');
    }
  }

  static Map<String, dynamic> normalizeAtsResponse(Map<String, dynamic> raw) {
    final breakdown = raw['score_breakdown'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw['score_breakdown'] as Map)
        : <String, dynamic>{};

    final skills = ((breakdown['required_skills_and_qualifications'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 30.0);
    final exp = ((breakdown['relevant_experience_and_responsibilities'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 25.0);
    final kw = ((breakdown['job_specific_keywords_and_terminology'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 15.0);
    final edu = ((breakdown['education_and_certifications'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 10.0);
    final ach = ((breakdown['relevant_achievements'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 10.0);
    final read = ((breakdown['resume_readability_and_parsing'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 10.0);

    final calculatedSum = skills + exp + kw + edu + ach + read;
    final overallScore = ((raw['overall_score'] as num?)?.toDouble() ?? calculatedSum).clamp(0.0, 100.0);

    return {
      'detected_job_title': (raw['detected_job_title'] ?? 'Target Role').toString(),
      'detected_domain': (raw['detected_domain'] ?? 'General').toString(),
      'detected_seniority': (raw['detected_seniority'] ?? 'Mid-Level').toString(),
      'overall_score': double.parse(overallScore.toStringAsFixed(1)),
      'score_breakdown': {
        'required_skills_and_qualifications': double.parse(skills.toStringAsFixed(1)),
        'relevant_experience_and_responsibilities': double.parse(exp.toStringAsFixed(1)),
        'job_specific_keywords_and_terminology': double.parse(kw.toStringAsFixed(1)),
        'education_and_certifications': double.parse(edu.toStringAsFixed(1)),
        'relevant_achievements': double.parse(ach.toStringAsFixed(1)),
        'resume_readability_and_parsing': double.parse(read.toStringAsFixed(1)),
      },
      'job_city': (raw['job_city'] ?? 'Remote / Unspecified').toString(),
      'resume_city': raw['resume_city']?.toString(),
      'is_city_aligned': raw['is_city_aligned'] == true,
      'matched_requirements': _toStringList(raw['matched_requirements']),
      'partially_matched_requirements': _toStringList(raw['partially_matched_requirements']),
      'missing_requirements': _toStringList(raw['missing_requirements']),
      'mandatory_gaps': _toStringList(raw['mandatory_gaps']),
      'preferred_gaps': _toStringList(raw['preferred_gaps']),
      'transferable_skills': _toStringList(raw['transferable_skills']),
      'keyword_analysis': (raw['keyword_analysis'] ?? '').toString(),
      'experience_analysis': (raw['experience_analysis'] ?? '').toString(),
      'education_certification_analysis': (raw['education_certification_analysis'] ?? '').toString(),
      'parsing_issues': _toStringList(raw['parsing_issues']),
      'improvement_recommendations': _toStringList(raw['improvement_recommendations']),
      'score_explanation': (raw['score_explanation'] ?? 'Transparent ATS evaluation based on matched competencies.').toString(),
      'evidence_and_uncertainties': (raw['evidence_and_uncertainties'] ?? '').toString(),
      'summary': (raw['summary'] ?? '').toString(),
    };
  }

  static Map<String, dynamic> normalizeTailoringResponse(
    Map<String, dynamic> raw,
    String targetCity,
    int targetPages,
  ) {
    var rawTailoredText = (raw['tailoredResume'] ?? '').toString();
    rawTailoredText = rawTailoredText
        .split('\n')
        .where(
          (l) =>
              !l.toLowerCase().contains('newly integrated') &&
              !l.toLowerCase().contains('newly aligned'),
        )
        .join('\n');

    return {
      'tailoredResume': rawTailoredText,
      'alignedCity': (raw['alignedCity'] ?? targetCity).toString(),
      'tailoredSummary': (raw['tailoredSummary'] ?? '').toString(),
      'addedKeywords': _toStringList(raw['addedKeywords']),
      'modifiedSections': _toStringList(raw['modifiedSections']).isNotEmpty
          ? _toStringList(raw['modifiedSections'])
          : ['Professional Summary', 'Skills Organization', 'Experience Enhancements', 'ATS Layout Formatting'],
      'cityAlignmentNote': (raw['cityAlignmentNote'] ?? 'Market relevance aligned to $targetCity in professional summary.').toString(),
      'targetPages': targetPages,
    };
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }
}
