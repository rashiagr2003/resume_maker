import 'user_skill_entry.dart';

class AnalysisResult {
  /// Overall ATS Compatibility Score (0 - 100)
  final double matchScore;

  /// 6 Configurable Evaluation Dimensions (Sum = 100)
  /// A. Required skills and qualifications — 30 points
  final double skillsScore;
  /// B. Relevant experience and responsibilities — 25 points
  final double experienceScore;
  /// C. Job-specific keywords and terminology — 15 points
  final double keywordsScore;
  /// D. Education, certifications, and eligibility requirements — 10 points
  final double educationScore;
  /// E. Relevant achievements and evidence of impact — 10 points
  final double achievementsScore;
  /// F. Resume readability, structure, and parsing compatibility — 10 points
  final double readabilityScore;

  /// Dynamic Role & Domain Detection
  final String detectedJobTitle;
  final String detectedDomain;
  final String detectedSeniority;

  /// Location Alignment
  final String jobCity;
  final String? resumeCity;
  final bool isCityAligned;

  /// Requirements Analysis
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final List<String> partiallyMatchedRequirements;
  final List<String> mandatoryGaps;
  final List<String> preferredGaps;
  final List<String> transferableSkills;

  /// Candidate Explicitly Verified Skills & Proficiencies
  final Map<String, UserSkillEntry> userVerifiedSkills;

  /// Deep Qualitative Insights
  final String keywordAnalysis;
  final String experienceAnalysis;
  final String educationCertificationAnalysis;
  final List<String> parsingIssues;
  final List<String> recommendations;
  final String scoreExplanation;
  final String evidenceAndUncertainties;
  final String summary;

  /// Optimization Unlock Threshold (Default: 70.0)
  final double threshold;

  final double? _locationScore;
  final List<String>? _strengths;

  const AnalysisResult({
    required this.matchScore,
    required this.skillsScore,
    required this.experienceScore,
    this.keywordsScore = 12.0,
    this.educationScore = 8.0,
    this.achievementsScore = 8.0,
    this.readabilityScore = 8.5,
    double? locationScore,
    List<String>? strengths,
    this.detectedJobTitle = 'Target Role',
    this.detectedDomain = 'General Professional',
    this.detectedSeniority = 'Mid-Level',
    required this.jobCity,
    this.resumeCity,
    required this.isCityAligned,
    required this.matchedSkills,
    required this.missingSkills,
    this.partiallyMatchedRequirements = const [],
    this.mandatoryGaps = const [],
    this.preferredGaps = const [],
    this.transferableSkills = const [],
    this.userVerifiedSkills = const {},
    this.keywordAnalysis = '',
    this.experienceAnalysis = '',
    this.educationCertificationAnalysis = '',
    this.parsingIssues = const [],
    required this.recommendations,
    this.scoreExplanation = '',
    this.evidenceAndUncertainties = '',
    required this.summary,
    this.threshold = 70.0,
  })  : _locationScore = locationScore,
        _strengths = strengths;

  /// ATS Optimization unlocks at or above the threshold (70.0 by default)
  bool get isEligibleForUpdate => matchScore >= threshold;

  /// Backward-compatible getters for legacy views and tests
  double get locationScore => _locationScore ?? (isCityAligned ? 95.0 : 60.0);
  List<String> get strengths {
    if (_strengths != null && _strengths!.isNotEmpty) return _strengths!;
    final list = <String>[];
    if (matchedSkills.isNotEmpty) {
      list.add('Demonstrated core competencies: ${matchedSkills.take(4).join(', ')}');
    }
    if (isCityAligned) {
      list.add('Location alignment with target role requirements ($jobCity)');
    }
    if (achievementsScore >= 7.0) {
      list.add('Quantified metrics and measurable career accomplishments identified');
    }
    if (readabilityScore >= 8.0) {
      list.add('Strong ATS document structure and clean section parsing');
    }
    return list;
  }

  factory AnalysisResult.empty() {
    return const AnalysisResult(
      matchScore: 0.0,
      skillsScore: 0.0,
      experienceScore: 0.0,
      keywordsScore: 0.0,
      educationScore: 0.0,
      achievementsScore: 0.0,
      readabilityScore: 0.0,
      detectedJobTitle: '',
      detectedDomain: '',
      detectedSeniority: '',
      jobCity: '',
      resumeCity: null,
      isCityAligned: false,
      matchedSkills: [],
      missingSkills: [],
      userVerifiedSkills: {},
      recommendations: [],
      summary: '',
      threshold: 70.0,
    );
  }

  AnalysisResult copyWith({
    double? matchScore,
    double? skillsScore,
    double? experienceScore,
    double? keywordsScore,
    double? educationScore,
    double? achievementsScore,
    double? readabilityScore,
    double? locationScore,
    List<String>? strengths,
    String? detectedJobTitle,
    String? detectedDomain,
    String? detectedSeniority,
    String? jobCity,
    String? resumeCity,
    bool? isCityAligned,
    List<String>? matchedSkills,
    List<String>? missingSkills,
    List<String>? partiallyMatchedRequirements,
    List<String>? mandatoryGaps,
    List<String>? preferredGaps,
    List<String>? transferableSkills,
    Map<String, UserSkillEntry>? userVerifiedSkills,
    String? keywordAnalysis,
    String? experienceAnalysis,
    String? educationCertificationAnalysis,
    List<String>? parsingIssues,
    List<String>? recommendations,
    String? scoreExplanation,
    String? evidenceAndUncertainties,
    String? summary,
    double? threshold,
  }) {
    return AnalysisResult(
      matchScore: matchScore ?? this.matchScore,
      skillsScore: skillsScore ?? this.skillsScore,
      experienceScore: experienceScore ?? this.experienceScore,
      keywordsScore: keywordsScore ?? this.keywordsScore,
      educationScore: educationScore ?? this.educationScore,
      achievementsScore: achievementsScore ?? this.achievementsScore,
      readabilityScore: readabilityScore ?? this.readabilityScore,
      locationScore: locationScore ?? _locationScore,
      strengths: strengths ?? _strengths,
      detectedJobTitle: detectedJobTitle ?? this.detectedJobTitle,
      detectedDomain: detectedDomain ?? this.detectedDomain,
      detectedSeniority: detectedSeniority ?? this.detectedSeniority,
      jobCity: jobCity ?? this.jobCity,
      resumeCity: resumeCity ?? this.resumeCity,
      isCityAligned: isCityAligned ?? this.isCityAligned,
      matchedSkills: matchedSkills ?? this.matchedSkills,
      missingSkills: missingSkills ?? this.missingSkills,
      partiallyMatchedRequirements: partiallyMatchedRequirements ?? this.partiallyMatchedRequirements,
      mandatoryGaps: mandatoryGaps ?? this.mandatoryGaps,
      preferredGaps: preferredGaps ?? this.preferredGaps,
      transferableSkills: transferableSkills ?? this.transferableSkills,
      userVerifiedSkills: userVerifiedSkills ?? this.userVerifiedSkills,
      keywordAnalysis: keywordAnalysis ?? this.keywordAnalysis,
      experienceAnalysis: experienceAnalysis ?? this.experienceAnalysis,
      educationCertificationAnalysis: educationCertificationAnalysis ?? this.educationCertificationAnalysis,
      parsingIssues: parsingIssues ?? this.parsingIssues,
      recommendations: recommendations ?? this.recommendations,
      scoreExplanation: scoreExplanation ?? this.scoreExplanation,
      evidenceAndUncertainties: evidenceAndUncertainties ?? this.evidenceAndUncertainties,
      summary: summary ?? this.summary,
      threshold: threshold ?? this.threshold,
    );
  }

  /// Recalculates compatibility when candidate verifies actual proficiencies.
  AnalysisResult withVerifiedSkills(Map<String, UserSkillEntry> verified) {
    if (verified.isEmpty) {
      return copyWith(userVerifiedSkills: const {});
    }

    final verifiedActive = verified.values
        .where((v) => v.proficiency != SkillProficiency.learning)
        .map((v) => v.skill)
        .toSet();

    final newMatched = {...matchedSkills, ...verifiedActive}.toList();
    final newMissing = missingSkills
        .where((s) => !verifiedActive.any((v) => v.toLowerCase() == s.toLowerCase()))
        .toList();
    final newPartials = partiallyMatchedRequirements
        .where((s) => !verifiedActive.any((v) => v.toLowerCase() == s.toLowerCase()))
        .toList();
    final newMandatoryGaps = mandatoryGaps
        .where((s) => !verifiedActive.any((v) => v.toLowerCase() == s.toLowerCase()))
        .toList();

    final totalSkillsRequired = (newMatched.length + newMissing.length);
    final skillRatio = totalSkillsRequired > 0 ? (newMatched.length / totalSkillsRequired) : 1.0;

    double proficiencyBonus = 0.0;
    for (final entry in verified.values) {
      if (entry.proficiency == SkillProficiency.advanced) {
        proficiencyBonus += 2.0;
      } else if (entry.proficiency == SkillProficiency.intermediate) {
        proficiencyBonus += 1.2;
      } else if (entry.proficiency == SkillProficiency.beginner) {
        proficiencyBonus += 0.6;
      }
    }

    final newSkillsScore = (skillRatio * 30.0).clamp(0.0, 30.0);
    final newKeywordsScore = (keywordsScore + (verifiedActive.length * 1.0)).clamp(0.0, 15.0);

    final newTotalScore = (
      newSkillsScore +
      experienceScore +
      newKeywordsScore +
      educationScore +
      achievementsScore +
      readabilityScore +
      proficiencyBonus
    ).clamp(0.0, 100.0);

    return copyWith(
      matchScore: double.parse(newTotalScore.toStringAsFixed(1)),
      skillsScore: double.parse(newSkillsScore.toStringAsFixed(1)),
      keywordsScore: double.parse(newKeywordsScore.toStringAsFixed(1)),
      matchedSkills: newMatched,
      missingSkills: newMissing,
      partiallyMatchedRequirements: newPartials,
      mandatoryGaps: newMandatoryGaps,
      userVerifiedSkills: verified,
      scoreExplanation: 'Score dynamically updated with ${verified.length} candidate-verified proficiencies.',
    );
  }
}
