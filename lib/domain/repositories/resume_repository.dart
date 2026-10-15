import '../entities/analysis_result.dart';
import '../entities/resume_input.dart';
import '../entities/tailored_resume.dart';

abstract class ResumeRepository {
  Future<AnalysisResult> analyzeResume(ResumeInput input);

  Future<TailoredResume> updateResume(
    ResumeInput input,
    AnalysisResult analysis, {
    bool forceOverride = false,
  });

  Future<String> extractCity(String text);

  Future<void> saveApiKey(String apiKey);

  Future<String?> getApiKey();
}
