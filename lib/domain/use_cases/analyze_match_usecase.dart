import '../entities/analysis_result.dart';
import '../entities/resume_input.dart';
import '../repositories/resume_repository.dart';

class AnalyzeMatchUseCase {
  final ResumeRepository _repository;

  AnalyzeMatchUseCase(this._repository);

  Future<AnalysisResult> call(ResumeInput input) async {
    if (!input.isValid) {
      throw ArgumentError(
        'Both Job Description and Resume must be at least 20 characters long.',
      );
    }
    return await _repository.analyzeResume(input);
  }
}
