import 'analysis_result.dart';

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
    );
  }
}
