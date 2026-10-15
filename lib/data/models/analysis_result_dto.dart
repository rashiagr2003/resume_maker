import '../../domain/entities/analysis_result.dart';

class AnalysisResultDto {
  final double matchScore;
  final double skillsScore;
  final double experienceScore;
  final double keywordsScore;
  final double educationScore;
  final double achievementsScore;
  final double readabilityScore;

  final String detectedJobTitle;
  final String detectedDomain;
  final String detectedSeniority;

  final String jobCity;
  final String? resumeCity;
  final bool isCityAligned;

  final List<String> matchedSkills;
  final List<String> missingSkills;
  final List<String> partiallyMatchedRequirements;
  final List<String> mandatoryGaps;
  final List<String> preferredGaps;
  final List<String> transferableSkills;

  final String keywordAnalysis;
  final String experienceAnalysis;
  final String educationCertificationAnalysis;
  final List<String> parsingIssues;
  final List<String> recommendations;
  final String scoreExplanation;
  final String evidenceAndUncertainties;
  final String summary;
  final double threshold;

  const AnalysisResultDto({
    required this.matchScore,
    required this.skillsScore,
    required this.experienceScore,
    required this.keywordsScore,
    required this.educationScore,
    required this.achievementsScore,
    required this.readabilityScore,
    required this.detectedJobTitle,
    required this.detectedDomain,
    required this.detectedSeniority,
    required this.jobCity,
    this.resumeCity,
    required this.isCityAligned,
    required this.matchedSkills,
    required this.missingSkills,
    this.partiallyMatchedRequirements = const [],
    this.mandatoryGaps = const [],
    this.preferredGaps = const [],
    this.transferableSkills = const [],
    this.keywordAnalysis = '',
    this.experienceAnalysis = '',
    this.educationCertificationAnalysis = '',
    this.parsingIssues = const [],
    required this.recommendations,
    required this.scoreExplanation,
    this.evidenceAndUncertainties = '',
    required this.summary,
    this.threshold = 70.0,
  });

  factory AnalysisResultDto.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? defaultVal;
    }

    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    final breakdown = json['score_breakdown'] is Map ? json['score_breakdown'] as Map : null;

    final overall = parseDouble(
      json['overall_score'] ?? json['matchScore'] ?? json['match_score'],
    );

    // Dimension A: Skills (max 30)
    final skills = parseDouble(
      breakdown?['required_skills_and_qualifications'] ??
          json['skillsScore'] ??
          json['skills_score'],
      (overall * 0.30),
    ).clamp(0.0, 30.0);

    // Dimension B: Experience (max 25)
    final experience = parseDouble(
      breakdown?['relevant_experience_and_responsibilities'] ??
          json['experienceScore'] ??
          json['experience_score'],
      (overall * 0.25),
    ).clamp(0.0, 25.0);

    // Dimension C: Keywords (max 15)
    final keywords = parseDouble(
      breakdown?['job_specific_keywords_and_terminology'] ??
          json['keywordsScore'] ??
          json['keywords_score'],
      (overall * 0.15),
    ).clamp(0.0, 15.0);

    // Dimension D: Education (max 10)
    final education = parseDouble(
      breakdown?['education_and_certifications'] ??
          json['educationScore'] ??
          json['education_score'],
      (overall * 0.10),
    ).clamp(0.0, 10.0);

    // Dimension E: Achievements (max 10)
    final achievements = parseDouble(
      breakdown?['relevant_achievements'] ??
          json['achievementsScore'] ??
          json['achievements_score'],
      (overall * 0.10),
    ).clamp(0.0, 10.0);

    // Dimension F: Readability (max 10)
    final readability = parseDouble(
      breakdown?['resume_readability_and_parsing'] ??
          json['readabilityScore'] ??
          json['readability_score'],
      (overall * 0.10),
    ).clamp(0.0, 10.0);

    return AnalysisResultDto(
      matchScore: overall.clamp(0.0, 100.0),
      skillsScore: skills,
      experienceScore: experience,
      keywordsScore: keywords,
      educationScore: education,
      achievementsScore: achievements,
      readabilityScore: readability,
      detectedJobTitle: (json['detected_job_title'] ?? json['jobTitle'] ?? 'Target Role').toString(),
      detectedDomain: (json['detected_domain'] ?? json['domain'] ?? 'General Professional').toString(),
      detectedSeniority: (json['detected_seniority'] ?? json['seniority'] ?? 'Mid-Level').toString(),
      jobCity: (json['jobCity'] ?? json['job_city'] ?? 'Remote / Unspecified').toString(),
      resumeCity: json['resumeCity']?.toString() ?? json['resume_city']?.toString(),
      isCityAligned: json['isCityAligned'] == true || json['is_city_aligned'] == true,
      matchedSkills: parseList(json['matched_requirements'] ?? json['matchedSkills'] ?? json['matched_skills']),
      missingSkills: parseList(json['missing_requirements'] ?? json['missingSkills'] ?? json['missing_skills']),
      partiallyMatchedRequirements: parseList(json['partially_matched_requirements']),
      mandatoryGaps: parseList(json['mandatory_gaps']),
      preferredGaps: parseList(json['preferred_gaps']),
      transferableSkills: parseList(json['transferable_skills']),
      keywordAnalysis: (json['keyword_analysis'] ?? '').toString(),
      experienceAnalysis: (json['experience_analysis'] ?? '').toString(),
      educationCertificationAnalysis: (json['education_certification_analysis'] ?? '').toString(),
      parsingIssues: parseList(json['parsing_issues']),
      recommendations: parseList(json['improvement_recommendations'] ?? json['recommendations']),
      scoreExplanation: (json['score_explanation'] ?? '').toString(),
      evidenceAndUncertainties: (json['evidence_and_uncertainties'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      threshold: parseDouble(json['threshold'], 70.0),
    );
  }

  AnalysisResult toDomain() {
    return AnalysisResult(
      matchScore: matchScore.clamp(0.0, 100.0),
      skillsScore: skillsScore.clamp(0.0, 30.0),
      experienceScore: experienceScore.clamp(0.0, 25.0),
      keywordsScore: keywordsScore.clamp(0.0, 15.0),
      educationScore: educationScore.clamp(0.0, 10.0),
      achievementsScore: achievementsScore.clamp(0.0, 10.0),
      readabilityScore: readabilityScore.clamp(0.0, 10.0),
      detectedJobTitle: detectedJobTitle,
      detectedDomain: detectedDomain,
      detectedSeniority: detectedSeniority,
      jobCity: jobCity,
      resumeCity: resumeCity,
      isCityAligned: isCityAligned,
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
      partiallyMatchedRequirements: partiallyMatchedRequirements,
      mandatoryGaps: mandatoryGaps,
      preferredGaps: preferredGaps,
      transferableSkills: transferableSkills,
      keywordAnalysis: keywordAnalysis,
      experienceAnalysis: experienceAnalysis,
      educationCertificationAnalysis: educationCertificationAnalysis,
      parsingIssues: parsingIssues,
      recommendations: recommendations,
      scoreExplanation: scoreExplanation,
      evidenceAndUncertainties: evidenceAndUncertainties,
      summary: summary,
      threshold: threshold,
    );
  }
}
