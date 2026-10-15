import '../../core/services/ats_backend_service.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/resume_input.dart';
import '../../domain/entities/tailored_resume.dart';
import '../../domain/repositories/resume_repository.dart';
import '../datasources/ai_remote_datasource.dart';
import '../datasources/heuristic_local_datasource.dart';
import '../datasources/settings_local_datasource.dart';

class ResumeRepositoryImpl implements ResumeRepository {
  final AtsBackendService _backendService;
  final SettingsLocalDataSource _settingsDataSource;
  final HeuristicLocalDataSource _localDataSource;

  ResumeRepositoryImpl({
    AtsBackendService? backendService,
    AiRemoteDataSource? remoteDataSource,
    HeuristicLocalDataSource? localDataSource,
    SettingsLocalDataSource? settingsDataSource,
  })  : _localDataSource = localDataSource ?? HeuristicLocalDataSource(),
        _settingsDataSource = settingsDataSource ?? SettingsLocalDataSource(),
        _backendService = backendService ??
            AtsBackendService(
              remoteDataSource: remoteDataSource,
              localDataSource: localDataSource,
              settingsDataSource: settingsDataSource,
            );

  AtsBackendService get backendService => _backendService;

  @override
  Future<AnalysisResult> analyzeResume(ResumeInput input) async {
    return await _backendService.analyzeResumeAgainstJD(input: input);
  }

  @override
  Future<TailoredResume> updateResume(
    ResumeInput input,
    AnalysisResult analysis, {
    bool forceOverride = false,
  }) async {
    return await _backendService.generateResumeImprovements(
      input: input,
      analysis: analysis,
      forceOverride: forceOverride,
    );
  }

  @override
  Future<String> extractCity(String text) async {
    return _localDataSource.extractCity(text);
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    await _settingsDataSource.saveApiKey(apiKey);
  }

  @override
  Future<String?> getApiKey() async {
    return await _settingsDataSource.getApiKey();
  }
}
