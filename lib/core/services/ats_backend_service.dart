import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/resume_file_extractor.dart';
import '../../data/datasources/ai_remote_datasource.dart';
import '../../data/datasources/heuristic_local_datasource.dart';
import '../../data/datasources/settings_local_datasource.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/resume_input.dart';
import '../../domain/entities/tailored_resume.dart';

/// Reusable ATS Backend Service implementing all required core functions from Section 8
class AtsBackendService {
  final AiRemoteDataSource _remoteDataSource;
  final HeuristicLocalDataSource _localDataSource;
  final SettingsLocalDataSource _settingsDataSource;

  AtsBackendService({
    AiRemoteDataSource? remoteDataSource,
    HeuristicLocalDataSource? localDataSource,
    SettingsLocalDataSource? settingsDataSource,
  })  : _remoteDataSource = remoteDataSource ?? AiRemoteDataSource(),
        _localDataSource = localDataSource ?? HeuristicLocalDataSource(),
        _settingsDataSource = settingsDataSource ?? SettingsLocalDataSource();

  /// 1. extractResumeText(file) - Extracts text from PDF, DOCX, or TXT with validation
  ResumeExtractionResult extractResumeText({
    required List<int> bytes,
    required String fileName,
  }) {
    return ResumeFileExtractor.extract(bytes: bytes, fileName: fileName);
  }

  /// 2. validateResumeAndJD(resumeText, jobDescription) - Strict validation, no fabricated scores
  String? validateResumeAndJD(String resumeText, String jobDescription) {
    final cleanResume = resumeText.trim();
    final cleanJd = jobDescription.trim();

    if (cleanResume.isEmpty && cleanJd.isEmpty) {
      return 'Please upload your resume and provide the target job description to begin analysis.';
    }
    if (cleanResume.length < 20) {
      return 'Resume text is too short or empty (${cleanResume.length} characters). Please upload a readable document or paste your resume.';
    }
    if (cleanJd.length < 20) {
      return 'Job description is too short (${cleanJd.length} characters). Please paste the complete job description.';
    }
    return null;
  }

  /// 3. detectJobDomain(resumeText, jobDescription) - Automatic domain & seniority identification
  Map<String, String> detectJobDomain(String resumeText, String jobDescription) {
    final domain = _localDataSource.detectDomain(jobDescription, resumeText);
    final title = _localDataSource.extractRole(jobDescription);
    final seniority = _localDataSource.detectSeniority(jobDescription);
    final city = _localDataSource.extractCity(jobDescription);
    return {
      'domain': domain,
      'jobTitle': title,
      'seniority': seniority,
      'jobCity': city,
    };
  }

  /// 4. analyzeResumeAgainstJD(resumeText, jobDescription) - AI-powered dynamic evaluation with local fallback
  Future<AnalysisResult> analyzeResumeAgainstJD({
    required ResumeInput input,
    String? explicitApiKey,
  }) async {
    final validationError = validateResumeAndJD(input.resumeText, input.jobDescription);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final savedKey = await _settingsDataSource.getApiKey();
    final apiKey = (explicitApiKey != null && explicitApiKey.isNotEmpty)
        ? explicitApiKey
        : (savedKey ?? '');
    final backendUrl = await _settingsDataSource.getBackendUrl();
    final model = await _settingsDataSource.getSelectedModel();

    try {
      final dto = await _remoteDataSource.analyzeMatch(
        input: input,
        apiKey: apiKey,
        model: model,
        backendUrl: backendUrl,
      );
      final domainResult = dto.toDomain();
      return validateAndNormalizeScore(domainResult);
    } catch (e) {
      debugPrint('Remote AI analysis error: $e. Falling back to local ATS engine.');
      // If remote fails, fallback to intelligent local engine (never random or default)
      final localDto = _localDataSource.analyzeMatch(input);
      return validateAndNormalizeScore(localDto.toDomain());
    }
  }

  /// 5. validateAndNormalizeScore(analysis) - Validates scoring rubric & normalization to 100
  AnalysisResult validateAndNormalizeScore(AnalysisResult analysis) {
    final skills = analysis.skillsScore.clamp(0.0, 30.0);
    final experience = analysis.experienceScore.clamp(0.0, 25.0);
    final keywords = analysis.keywordsScore.clamp(0.0, 15.0);
    final education = analysis.educationScore.clamp(0.0, 10.0);
    final achievements = analysis.achievementsScore.clamp(0.0, 10.0);
    final readability = analysis.readabilityScore.clamp(0.0, 10.0);

    final calculatedSum = skills + experience + keywords + education + achievements + readability;
    final normalizedOverall = calculatedSum.clamp(0.0, 100.0);

    return analysis.copyWith(
      matchScore: normalizedOverall,
      skillsScore: skills,
      experienceScore: experience,
      keywordsScore: keywords,
      educationScore: education,
      achievementsScore: achievements,
      readabilityScore: readability,
    );
  }

  /// 6. generateResumeImprovements(resumeText, jobDescription, analysis) - Optimizes resume (enforcing 70+ threshold)
  Future<TailoredResume> generateResumeImprovements({
    required ResumeInput input,
    required AnalysisResult analysis,
    bool forceOverride = false,
    String? explicitApiKey,
  }) async {
    // Strict Threshold Enforcement (70+ default) on Backend
    if (analysis.matchScore < analysis.threshold && !forceOverride) {
      throw StateError(
        'Resume ATS score (${analysis.matchScore.toStringAsFixed(1)}%) is below the required ${analysis.threshold.toInt()}% threshold. Optimization is locked. Please address missing requirements or enable manual override.',
      );
    }

    final savedKey = await _settingsDataSource.getApiKey();
    final apiKey = (explicitApiKey != null && explicitApiKey.isNotEmpty)
        ? explicitApiKey
        : (savedKey ?? '');
    final backendUrl = await _settingsDataSource.getBackendUrl();
    final model = await _settingsDataSource.getSelectedModel();

    TailoredResume tailored;
    try {
      tailored = await _remoteDataSource.tailorResume(
        input: input,
        analysis: analysis,
        apiKey: apiKey,
        model: model,
        forceOverride: forceOverride,
        backendUrl: backendUrl,
      );
    } catch (e) {
      debugPrint('Remote tailoring failed: $e. Falling back to local engine.');
      tailored = _localDataSource.tailorResume(input, analysis, forceOverride: forceOverride);
    }

    // Reanalyze optimized resume to compute updated score
    final reanalyzed = await reanalyzeOptimizedResume(
      optimizedResume: tailored.tailoredResume,
      jobDescription: input.jobDescription,
      explicitApiKey: apiKey,
    );

    return tailored.copyWith(
      reanalyzedScore: reanalyzed.matchScore,
      reanalyzedResult: reanalyzed,
    );
  }

  /// 7. reanalyzeOptimizedResume(optimizedResume, jobDescription) - Recalculates ATS score after optimization
  Future<AnalysisResult> reanalyzeOptimizedResume({
    required String optimizedResume,
    required String jobDescription,
    String? explicitApiKey,
  }) async {
    final input = ResumeInput(
      jobDescription: jobDescription,
      resumeText: optimizedResume,
    );
    return await analyzeResumeAgainstJD(input: input, explicitApiKey: explicitApiKey);
  }

  /// 8. exportOptimizedResume(resumeData, format) - Exports to PDF or TXT
  Future<List<int>> exportOptimizedResume({
    required TailoredResume tailored,
    required String format,
    String? candidateName,
  }) async {
    if (format.toLowerCase() == 'pdf') {
      return await PdfGenerator.generatePdfBytes(
        tailored: tailored,
        candidateName: candidateName ?? 'Candidate',
      );
    } else {
      // Export as clean UTF-8 text document
      return utf8.encode(tailored.tailoredResume);
    }
  }
}
