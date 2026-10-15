import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/sample_data.dart';
import '../../core/services/ats_backend_service.dart';
import '../../data/datasources/ai_remote_datasource.dart';
import '../../data/datasources/heuristic_local_datasource.dart';
import '../../data/datasources/settings_local_datasource.dart';
import '../../data/repositories/resume_repository_impl.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/resume_input.dart';
import '../../domain/entities/tailored_resume.dart';
import '../../domain/repositories/resume_repository.dart';
import '../../domain/use_cases/analyze_match_usecase.dart';
import '../../domain/use_cases/extract_city_usecase.dart';
import '../../domain/use_cases/update_resume_usecase.dart';
import '../../domain/entities/user_skill_entry.dart';

// --- Dependency Injection Providers ---

final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((ref) {
  return SettingsLocalDataSource();
});

final atsBackendServiceProvider = Provider<AtsBackendService>((ref) {
  final settings = ref.watch(settingsLocalDataSourceProvider);
  return AtsBackendService(
    remoteDataSource: AiRemoteDataSource(),
    localDataSource: HeuristicLocalDataSource(),
    settingsDataSource: settings,
  );
});

final resumeRepositoryProvider = Provider<ResumeRepository>((ref) {
  final backendService = ref.watch(atsBackendServiceProvider);
  final settings = ref.watch(settingsLocalDataSourceProvider);
  return ResumeRepositoryImpl(
    backendService: backendService,
    settingsDataSource: settings,
  );
});

final analyzeMatchUseCaseProvider = Provider<AnalyzeMatchUseCase>((ref) {
  final repo = ref.watch(resumeRepositoryProvider);
  return AnalyzeMatchUseCase(repo);
});

final updateResumeUseCaseProvider = Provider<UpdateResumeUseCase>((ref) {
  final repo = ref.watch(resumeRepositoryProvider);
  return UpdateResumeUseCase(repo);
});

final extractCityUseCaseProvider = Provider<ExtractCityUseCase>((ref) {
  final repo = ref.watch(resumeRepositoryProvider);
  return ExtractCityUseCase(repo);
});

// --- Settings & API Key Providers ---

class ApiKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  final SettingsLocalDataSource _settings;

  ApiKeyNotifier(this._settings) : super(const AsyncValue.loading()) {
    loadKey();
  }

  Future<void> loadKey() async {
    try {
      final key = await _settings.getApiKey();
      state = AsyncValue.data(key);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setKey(String key) async {
    await _settings.saveApiKey(key);
    state = AsyncValue.data(key.trim().isEmpty ? null : key.trim());
  }
}

final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, AsyncValue<String?>>((ref) {
  final settings = ref.watch(settingsLocalDataSourceProvider);
  return ApiKeyNotifier(settings);
});

final selectedModelProvider = StateProvider<String>((ref) => 'gemini-1.5-flash');

// --- Input State Provider ---

class ResumeInputNotifier extends StateNotifier<ResumeInput> {
  ResumeInputNotifier()
      : super(const ResumeInput(
          jobDescription: '',
          resumeText: '',
          customTargetCity: null,
          targetPages: 1,
        ));

  void updateJobDescription(String jd) {
    state = state.copyWith(jobDescription: jd);
  }

  void updateResumeText(String resume) {
    state = state.copyWith(resumeText: resume);
  }

  void updateTargetCity(String? city) {
    state = state.copyWith(customTargetCity: city);
  }

  void updateTargetPages(int pages) {
    state = state.copyWith(targetPages: pages);
  }

  void updateUploadedFileName(String? fileName) {
    state = state.copyWith(uploadedFileName: fileName);
  }

  void updateOptionalFields({
    String? title,
    String? company,
    String? domain,
    String? level,
    String? location,
  }) {
    state = state.copyWith(
      optionalJobTitle: title,
      optionalCompanyName: company,
      optionalIndustryDomain: domain,
      optionalExperienceLevel: level,
      optionalJobLocation: location,
    );
  }

  void loadSampleData({bool highMatch = true}) {
    state = ResumeInput(
      jobDescription: SampleData.sampleJdFlutter,
      resumeText: highMatch
          ? SampleData.sampleResumeHighMatch
          : SampleData.sampleResumeLowMatch,
      customTargetCity: 'Bengaluru, India',
    );
  }

  void clear() {
    state = const ResumeInput(
      jobDescription: '',
      resumeText: '',
      customTargetCity: null,
      targetPages: 1,
    );
  }
}

final resumeInputProvider =
    StateNotifierProvider<ResumeInputNotifier, ResumeInput>((ref) {
  return ResumeInputNotifier();
});

// --- Force Override Provider (allows testing update even if < 70%) ---
final forceOverrideProvider = StateProvider<bool>((ref) => false);

// --- Verified Skills State Notifier ---

class VerifiedSkillsNotifier extends StateNotifier<Map<String, UserSkillEntry>> {
  VerifiedSkillsNotifier() : super({});

  void setSkill(String skill, SkillProficiency proficiency, {bool isCustom = false}) {
    final cleanSkill = skill.trim();
    if (cleanSkill.isEmpty) return;
    state = {
      ...state,
      cleanSkill: UserSkillEntry(
        skill: cleanSkill,
        proficiency: proficiency,
        isCustom: isCustom,
        selectedAt: DateTime.now(),
      ),
    };
  }

  void removeSkill(String skill) {
    final cleanSkill = skill.trim();
    final updated = Map<String, UserSkillEntry>.from(state);
    if (updated.containsKey(cleanSkill)) {
      updated.remove(cleanSkill);
      state = updated;
      return;
    }
    final key = updated.keys.firstWhere(
      (k) => k.toLowerCase() == cleanSkill.toLowerCase(),
      orElse: () => '',
    );
    if (key.isNotEmpty) {
      updated.remove(key);
      state = updated;
    }
  }

  void clear() {
    state = {};
  }
}

final verifiedSkillsProvider =
    StateNotifierProvider<VerifiedSkillsNotifier, Map<String, UserSkillEntry>>((ref) {
  return VerifiedSkillsNotifier();
});

// --- Analysis State Notifier ---

class AnalysisNotifier extends StateNotifier<AsyncValue<AnalysisResult?>> {
  final AnalyzeMatchUseCase _analyzeUseCase;

  AnalysisNotifier(this._analyzeUseCase) : super(const AsyncValue.data(null));

  Future<void> runAnalysis(ResumeInput input) async {
    state = const AsyncValue.loading();
    try {
      final result = await _analyzeUseCase(input);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void applyVerifiedSkills(Map<String, UserSkillEntry> verifiedSkills) {
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.withVerifiedSkills(verifiedSkills);
      state = AsyncValue.data(updated);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AsyncValue<AnalysisResult?>>((ref) {
  final useCase = ref.watch(analyzeMatchUseCaseProvider);
  return AnalysisNotifier(useCase);
});

// --- Tailored Resume Notifier ---

class TailoredResumeNotifier extends StateNotifier<AsyncValue<TailoredResume?>> {
  final UpdateResumeUseCase _updateUseCase;

  TailoredResumeNotifier(this._updateUseCase) : super(const AsyncValue.data(null));

  Future<void> tailorResume({
    required ResumeInput input,
    required AnalysisResult analysis,
    bool forceOverride = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _updateUseCase(
        input: input,
        analysis: analysis,
        forceOverride: forceOverride,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateTailoredText(String updatedText) {
    if (state.valueOrNull != null) {
      state = AsyncValue.data(
        state.valueOrNull!.copyWith(tailoredResume: updatedText),
      );
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final tailoredResumeProvider =
    StateNotifierProvider<TailoredResumeNotifier, AsyncValue<TailoredResume?>>((ref) {
  final useCase = ref.watch(updateResumeUseCaseProvider);
  return TailoredResumeNotifier(useCase);
});
