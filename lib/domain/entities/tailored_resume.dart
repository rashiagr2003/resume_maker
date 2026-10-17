import 'analysis_result.dart';
import 'resume_audit_entry.dart';

class TailoredResume {
  final String originalResume;
  final String tailoredResume;
  final String alignedCity;
  final String? originalCity;
  final String tailoredSummary;
  final List<String> addedKeywords;
  final List<String> modifiedSections;
  final String cityAlignmentNote;
  final String generationModel;
  final DateTime timestamp;
  final int targetPages;

  /// Post-optimization verification score
  final double? reanalyzedScore;
  final AnalysisResult? reanalyzedResult;

  /// Audit breakdown of every reviewed and rewritten bullet/section
  final List<BulletRewriteAudit> bulletAudits;

  /// Requirement-to-evidence mapping for the target JD
  final List<RequirementEvidenceMapping> evidenceMappings;

  /// Automated factual integrity and traceability validation
  final TruthfulnessCheckResult? truthfulnessResult;

  /// Targeted questions for unevidenced high-priority requirements
  final List<String> candidateClarificationQuestions;

  const TailoredResume({
    required this.originalResume,
    required this.tailoredResume,
    required this.alignedCity,
    this.originalCity,
    required this.tailoredSummary,
    required this.addedKeywords,
    required this.modifiedSections,
    required this.cityAlignmentNote,
    required this.generationModel,
    required this.timestamp,
    this.targetPages = 1,
    this.reanalyzedScore,
    this.reanalyzedResult,
    this.bulletAudits = const [],
    this.evidenceMappings = const [],
    this.truthfulnessResult,
    this.candidateClarificationQuestions = const [],
  });

  TailoredResume copyWith({
    String? originalResume,
    String? tailoredResume,
    String? alignedCity,
    String? originalCity,
    String? tailoredSummary,
    List<String>? addedKeywords,
    List<String>? modifiedSections,
    String? cityAlignmentNote,
    String? generationModel,
    DateTime? timestamp,
    int? targetPages,
    double? reanalyzedScore,
    AnalysisResult? reanalyzedResult,
    List<BulletRewriteAudit>? bulletAudits,
    List<RequirementEvidenceMapping>? evidenceMappings,
    TruthfulnessCheckResult? truthfulnessResult,
    List<String>? candidateClarificationQuestions,
  }) {
    return TailoredResume(
      originalResume: originalResume ?? this.originalResume,
      tailoredResume: tailoredResume ?? this.tailoredResume,
      alignedCity: alignedCity ?? this.alignedCity,
      originalCity: originalCity ?? this.originalCity,
      tailoredSummary: tailoredSummary ?? this.tailoredSummary,
      addedKeywords: addedKeywords ?? this.addedKeywords,
      modifiedSections: modifiedSections ?? this.modifiedSections,
      cityAlignmentNote: cityAlignmentNote ?? this.cityAlignmentNote,
      generationModel: generationModel ?? this.generationModel,
      timestamp: timestamp ?? this.timestamp,
      targetPages: targetPages ?? this.targetPages,
      reanalyzedScore: reanalyzedScore ?? this.reanalyzedScore,
      reanalyzedResult: reanalyzedResult ?? this.reanalyzedResult,
      bulletAudits: bulletAudits ?? this.bulletAudits,
      evidenceMappings: evidenceMappings ?? this.evidenceMappings,
      truthfulnessResult: truthfulnessResult ?? this.truthfulnessResult,
      candidateClarificationQuestions: candidateClarificationQuestions ??
          this.candidateClarificationQuestions,
    );
  }
}
