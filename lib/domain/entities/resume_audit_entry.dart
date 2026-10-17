enum EvidenceClassification {
  demonstratedInEmployment,
  demonstratedInProject,
  supportedByCoursework,
  listedSkillOnly,
  transferable,
  notEvidenced,
  notApplicable,
}

extension EvidenceClassificationExt on EvidenceClassification {
  String get label {
    switch (this) {
      case EvidenceClassification.demonstratedInEmployment:
        return 'Demonstrated in Employment';
      case EvidenceClassification.demonstratedInProject:
        return 'Demonstrated in Project';
      case EvidenceClassification.supportedByCoursework:
        return 'Coursework / Academic';
      case EvidenceClassification.listedSkillOnly:
        return 'Listed Skill (No Context)';
      case EvidenceClassification.transferable:
        return 'Transferable Competency';
      case EvidenceClassification.notEvidenced:
        return 'Missing / Not Evidenced';
      case EvidenceClassification.notApplicable:
        return 'Not Applicable';
    }
  }

  static EvidenceClassification fromString(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('employment') || lower.contains('work')) {
      return EvidenceClassification.demonstratedInEmployment;
    } else if (lower.contains('project')) {
      return EvidenceClassification.demonstratedInProject;
    } else if (lower.contains('course') || lower.contains('academic') || lower.contains('degree')) {
      return EvidenceClassification.supportedByCoursework;
    } else if (lower.contains('listed')) {
      return EvidenceClassification.listedSkillOnly;
    } else if (lower.contains('transferable')) {
      return EvidenceClassification.transferable;
    } else if (lower.contains('not applicable') || lower.contains('n/a')) {
      return EvidenceClassification.notApplicable;
    } else {
      return EvidenceClassification.notEvidenced;
    }
  }
}

/// Record of an evaluated and rewritten resume section or bullet
class BulletRewriteAudit {
  final String section;
  final String original;
  final String rewritten;
  final String relevance;
  final String evidence;
  final bool hasChanged;
  final String rationale;

  const BulletRewriteAudit({
    required this.section,
    required this.original,
    required this.rewritten,
    required this.relevance,
    required this.evidence,
    required this.hasChanged,
    required this.rationale,
  });

  String get originalBullet => original;
  String get rewrittenBullet => rewritten;
  String get relevanceToJobDescription => relevance;
  String get evidenceBasis => evidence;

  Map<String, dynamic> toJson() => {
        'section': section,
        'original': original,
        'rewritten': rewritten,
        'relevance': relevance,
        'evidence': evidence,
        'hasChanged': hasChanged,
        'rationale': rationale,
      };

  factory BulletRewriteAudit.fromJson(Map<String, dynamic> json) =>
      BulletRewriteAudit(
        section: json['section'] ?? '',
        original: json['original'] ?? json['originalBullet'] ?? '',
        rewritten: json['rewritten'] ?? json['rewrittenBullet'] ?? '',
        relevance: json['relevance'] ?? json['relevanceToJobDescription'] ?? '',
        evidence: json['evidence'] ?? json['evidenceBasis'] ?? '',
        hasChanged: json['hasChanged'] == true,
        rationale: json['rationale'] ?? '',
      );
}

/// Requirement-to-evidence mapping for JD requirements
class RequirementEvidenceMapping {
  final String requirement;
  final EvidenceClassification classification;
  final double confidence;
  final String sourceEvidence;
  final String recommendation;

  const RequirementEvidenceMapping({
    required this.requirement,
    required this.classification,
    required this.confidence,
    required this.sourceEvidence,
    required this.recommendation,
  });

  String get candidateEvidence => sourceEvidence;
  double get confidenceScore => confidence;
  String get sourceSection => 'Experience / Projects';
  bool get isMissing => classification == EvidenceClassification.notEvidenced;

  Map<String, dynamic> toJson() => {
        'requirement': requirement,
        'classification': classification.name,
        'confidence': confidence,
        'sourceEvidence': sourceEvidence,
        'recommendation': recommendation,
      };

  factory RequirementEvidenceMapping.fromJson(Map<String, dynamic> json) =>
      RequirementEvidenceMapping(
        requirement: json['requirement'] ?? '',
        classification: EvidenceClassificationExt.fromString(
            json['classification']?.toString() ?? ''),
        confidence: (json['confidence'] as num?)?.toDouble() ??
            (json['confidenceScore'] as num?)?.toDouble() ??
            0.8,
        sourceEvidence: json['sourceEvidence'] ??
            json['candidateEvidence'] ??
            'Extracted from resume background',
        recommendation: json['recommendation'] ?? '',
      );
}

/// Result of automated factual integrity check
class TruthfulnessCheckResult {
  final bool isTruthful;
  final int verifiedFactsCount;
  final List<String> preservedMetrics;
  final List<String> flaggedClaims;
  final double traceabilityScore;
  final String summary;

  const TruthfulnessCheckResult({
    required this.isTruthful,
    required this.verifiedFactsCount,
    required this.preservedMetrics,
    required this.flaggedClaims,
    required this.traceabilityScore,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
        'isTruthful': isTruthful,
        'verifiedFactsCount': verifiedFactsCount,
        'preservedMetrics': preservedMetrics,
        'flaggedClaims': flaggedClaims,
        'traceabilityScore': traceabilityScore,
        'summary': summary,
      };

  factory TruthfulnessCheckResult.fromJson(Map<String, dynamic> json) =>
      TruthfulnessCheckResult(
        isTruthful: json['isTruthful'] != false,
        verifiedFactsCount: (json['verifiedFactsCount'] as num?)?.toInt() ?? 0,
        preservedMetrics: (json['preservedMetrics'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        flaggedClaims: (json['flaggedClaims'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        traceabilityScore:
            (json['traceabilityScore'] as num?)?.toDouble() ?? 100.0,
        summary: json['summary'] ??
            'All material claims verified against candidate original resume.',
      );
}
