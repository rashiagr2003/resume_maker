import '../entities/analysis_result.dart';
import '../entities/resume_input.dart';
import '../entities/tailored_resume.dart';
import '../repositories/resume_repository.dart';

class UpdateResumeUseCase {
  final ResumeRepository _repository;

  UpdateResumeUseCase(this._repository);

  Future<TailoredResume> call({
    required ResumeInput input,
    required AnalysisResult analysis,
    bool forceOverride = false,
  }) async {
    // Core Business Rule: Must have >= 70% match to unlock tailoring (unless explicitly overridden)
    if (analysis.matchScore < analysis.threshold && !forceOverride) {
      throw StateError(
        'Resume match score (${analysis.matchScore.toStringAsFixed(1)}%) is below the required ${analysis.threshold.toInt()}% threshold. Please enhance your resume with missing requirements or enable manual override.',
      );
    }

    return await _repository.updateResume(
      input,
      analysis,
      forceOverride: forceOverride,
    );
  }
}
