import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resume_maker/main.dart';
import 'package:resume_maker/domain/entities/analysis_result.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';
import 'package:resume_maker/presentation/providers/resume_providers.dart';

class FakeAnalysisNotifier extends StateNotifier<AsyncValue<AnalysisResult?>>
    implements AnalysisNotifier {
  FakeAnalysisNotifier(AnalysisResult? initial) : super(AsyncValue.data(initial));

  @override
  void reset() {
    state = const AsyncValue.data(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTailoredResumeNotifier extends StateNotifier<AsyncValue<TailoredResume?>>
    implements TailoredResumeNotifier {
  FakeTailoredResumeNotifier(TailoredResume? initial) : super(AsyncValue.data(initial));

  @override
  void reset() {
    state = const AsyncValue.data(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final sampleAnalysis = AnalysisResult(
    matchScore: 82.5,
    skillsScore: 85.0,
    experienceScore: 80.0,
    locationScore: 90.0,
    matchedSkills: const ['Flutter', 'Dart', 'REST API', 'Riverpod', 'Git'],
    missingSkills: const ['CI/CD', 'GraphQL', 'Docker'],
    jobCity: 'San Francisco, CA',
    resumeCity: 'Bengaluru, India',
    isCityAligned: false,
    strengths: const ['Deep Flutter framework proficiency', 'Cross-platform mobile architecture'],
    recommendations: const [
      'Emphasize cross-platform state management patterns.',
      'Highlight CI/CD pipeline automation experience.',
    ],
    summary: 'Candidate demonstrates strong core Flutter competence with minor tooling gaps.',
  );

  final sampleTailored = TailoredResume(
    tailoredResume: '''
ALEX MORGAN
Senior Flutter & Mobile Engineer
alex.morgan@example.com | +1 555-0149 | San Francisco, CA (Open to Relocation)
LinkedIn: linkedin.com/in/alexmorgan | GitHub: github.com/alexmorgan | Portfolio: alexmorgan.dev

PROFESSIONAL EXPERIENCE
Senior Flutter Developer | TechNova Solutions | December 2023 - Present
• Architected and shipped scalable enterprise mobile application with 100K+ DAU using Riverpod.
• Integrated REST API endpoints and real-time state synchronization reducing latency by 35%.

PROJECTS
FitFlow | Fitness & Wellness Platform | [Project](https://github.com/alexmorgan/fitflow)
• Developed responsive cross-platform Flutter fitness app with localized offline caching.

TECHNICAL SKILLS
Languages: Dart, JavaScript, Python
Frameworks & Tools: Flutter, Riverpod, Git, Docker, REST API

EDUCATION
Bachelor of Technology in Computer Science | 2019 - 2023
Dr. A.P.J. Abdul Kalam Technical University | CGPA: 8.5/10
''',
    originalResume: 'Original resume content...',
    alignedCity: 'San Francisco, CA',
    cityAlignmentNote: 'Contact header aligned to San Francisco, CA (Open to Relocation / Hybrid).',
    tailoredSummary: 'Senior Flutter Developer with 4+ years of cross-platform engineering experience.',
    addedKeywords: const ['Riverpod', 'CI/CD', 'Docker', 'REST API'],
    modifiedSections: const ['Professional Summary', 'Technical Skills', 'Experience Highlights'],
    generationModel: 'Heuristic Engine (Fast & Resilient)',
    timestamp: DateTime.now(),
    targetPages: 1,
  );

  Future<void> testScreenSize(
    WidgetTester tester, {
    required double width,
    required double height,
    AnalysisResult? analysis,
    TailoredResume? tailored,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    FlutterErrorDetails? errorDetails;
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errorDetails = details;
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (analysis != null)
            analysisProvider.overrideWith((ref) => FakeAnalysisNotifier(analysis)),
          if (tailored != null)
            tailoredResumeProvider.overrideWith((ref) => FakeTailoredResumeNotifier(tailored)),
        ],
        child: const ResumeMakerApp(),
      ),
    );
    await tester.pumpAndSettle();
    FlutterError.onError = prevOnError;

    expect(tester.takeException(), isNull, reason: 'Layout must not throw at $width x $height');
  }

  group('Responsiveness across viewports - Initial State', () {
    testWidgets('Renders cleanly on 360x740 (Small Mobile)', (tester) async {
      await testScreenSize(tester, width: 360, height: 740);
      expect(find.text('ResumeCraft AI'), findsOneWidget);
      expect(find.text('3. Target Document Format'), findsOneWidget);
      expect(find.text('1 Page'), findsOneWidget);
      expect(find.text('2 Pages'), findsOneWidget);
    });

    testWidgets('Renders cleanly on 412x915 (Modern Mobile)', (tester) async {
      await testScreenSize(tester, width: 412, height: 915);
      expect(find.text('ResumeCraft AI'), findsOneWidget);
      expect(find.text('3. Target Document Format'), findsOneWidget);
    });

    testWidgets('Renders cleanly on 768x1024 (Tablet)', (tester) async {
      await testScreenSize(tester, width: 768, height: 1024);
      expect(find.text('ResumeCraft AI'), findsOneWidget);
      expect(find.text('3. Target Document Format'), findsOneWidget);
    });

    testWidgets('Renders cleanly on 960x700 (Desktop Lower Breakpoint)', (tester) async {
      await testScreenSize(tester, width: 960, height: 700);
      expect(find.text('ResumeCraft AI'), findsOneWidget);
      expect(find.text('3. Target Document Format'), findsOneWidget);
    });

    testWidgets('Renders cleanly on 1280x800 (Desktop Standard)', (tester) async {
      await testScreenSize(tester, width: 1280, height: 800);
      expect(find.text('ResumeCraft AI'), findsOneWidget);
      expect(find.text('ATS Optimization Studio'), findsOneWidget);
      expect(find.text('3. Target Document Format'), findsOneWidget);
    });
  });

  group('Responsiveness - Step 2: ATS Scoring & Gate', () {
    testWidgets('Renders ATS analysis on 360x740 (Mobile) without overflow', (tester) async {
      await testScreenSize(tester, width: 360, height: 740, analysis: sampleAnalysis);
      expect(find.text('ATS Compatibility Score'), findsOneWidget);
      expect(find.textContaining('THRESHOLD UNLOCKED'), findsOneWidget);
      expect(find.text('Competency & Skill Gap Analysis'), findsOneWidget);
    });

    testWidgets('Renders ATS analysis on 1280x800 (Desktop) without overflow', (tester) async {
      await testScreenSize(tester, width: 1280, height: 800, analysis: sampleAnalysis);
      expect(find.text('ATS Compatibility Score'), findsOneWidget);
      expect(find.text('City & Location Alignment Engine'), findsOneWidget);
    });
  });

  group('Responsiveness - Step 3 & 4: Tailored Resume View', () {
    testWidgets('Renders Tailored Resume View on 360x740 (Mobile) without overflow', (tester) async {
      await testScreenSize(tester, width: 360, height: 740, tailored: sampleTailored);
      expect(find.text('Tailored & Aligned Resume'), findsOneWidget);
      expect(find.text('Document Preview'), findsOneWidget);
      expect(find.text('ALEX MORGAN'), findsOneWidget);
    });

    testWidgets('Renders Tailored Resume View on 1280x800 (Desktop) without overflow', (tester) async {
      await testScreenSize(tester, width: 1280, height: 800, tailored: sampleTailored);
      expect(find.text('Tailored & Aligned Resume'), findsOneWidget);
      expect(find.text('Document Preview'), findsOneWidget);
      expect(find.text('ALEX MORGAN'), findsOneWidget);
    });
  });
}
