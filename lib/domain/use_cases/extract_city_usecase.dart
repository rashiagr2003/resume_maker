import '../repositories/resume_repository.dart';

class ExtractCityUseCase {
  final ResumeRepository _repository;

  ExtractCityUseCase(this._repository);

  Future<String> call(String text) async {
    if (text.trim().isEmpty) return 'Remote / Flexible';
    return await _repository.extractCity(text);
  }
}
