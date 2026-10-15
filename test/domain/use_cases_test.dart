import 'package:flutter_test/flutter_test.dart';
import 'package:resume_maker/core/constants/sample_data.dart';
import 'package:resume_maker/data/datasources/heuristic_local_datasource.dart';
import 'package:resume_maker/data/repositories/resume_repository_impl.dart';
import 'package:resume_maker/domain/entities/resume_input.dart';
import 'package:resume_maker/domain/use_cases/analyze_match_usecase.dart';
import 'package:resume_maker/domain/use_cases/extract_city_usecase.dart';
import 'package:resume_maker/domain/use_cases/update_resume_usecase.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('Clean Architecture - Resume Match & 75% Gate UseCases', () {
    late ResumeRepositoryImpl repository;
    late AnalyzeMatchUseCase analyzeUseCase;
    late UpdateResumeUseCase updateUseCase;
    late ExtractCityUseCase extractCityUseCase;

    setUp(() {
      repository = ResumeRepositoryImpl(
        localDataSource: HeuristicLocalDataSource(),
      );
      analyzeUseCase = AnalyzeMatchUseCase(repository);
      updateUseCase = UpdateResumeUseCase(repository);
      extractCityUseCase = ExtractCityUseCase(repository);
    });

    test('extractCity detects Bengaluru from job description', () async {
      final city = await extractCityUseCase(SampleData.sampleJdFlutter);
      expect(city, contains('Bengaluru'));
    });

    test('analyzeMatch returns score >= 75% for well-matched candidate', () async {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeHighMatch,
      );

      final result = await analyzeUseCase(input);

      expect(result.matchScore, greaterThanOrEqualTo(75.0));
      expect(result.isEligibleForUpdate, isTrue);
      expect(result.jobCity, contains('Bengaluru'));
    });

    test('analyzeMatch returns score < 75% for poorly-matched candidate', () async {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeLowMatch,
      );

      final result = await analyzeUseCase(input);

      expect(result.matchScore, lessThan(75.0));
      expect(result.isEligibleForUpdate, isFalse);
    });

    test('updateResume throws StateError when score < 75% and override is false', () async {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeLowMatch,
      );

      final analysis = await analyzeUseCase(input);
      expect(analysis.matchScore, lessThan(75.0));

      expect(
        () => updateUseCase(input: input, analysis: analysis, forceOverride: false),
        throwsA(isA<StateError>()),
      );
    });

    test('updateResume succeeds when score >= 75% and aligns city to target city', () async {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeHighMatch,
      );

      final analysis = await analyzeUseCase(input);
      expect(analysis.matchScore, greaterThanOrEqualTo(75.0));

      final tailored = await updateUseCase(
        input: input,
        analysis: analysis,
        forceOverride: false,
      );

      expect(tailored.alignedCity, contains('Bengaluru'));
      expect(tailored.tailoredResume, contains('Bengaluru'));
      expect(tailored.tailoredResume.length, greaterThan(100));
    });

    test('updateResume succeeds when override is true even if score < 75%', () async {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeLowMatch,
      );

      final analysis = await analyzeUseCase(input);

      final tailored = await updateUseCase(
        input: input,
        analysis: analysis,
        forceOverride: true,
      );

      expect(tailored.alignedCity, contains('Bengaluru'));
    });
  });
}
