import 'package:flutter_test/flutter_test.dart';
import 'package:resume_maker/core/utils/pdf_extractor.dart';
import 'package:resume_maker/data/datasources/heuristic_local_datasource.dart';
import 'package:resume_maker/domain/entities/analysis_result.dart';
import 'package:resume_maker/domain/entities/resume_input.dart';
import 'package:resume_maker/domain/entities/user_skill_entry.dart';

void main() {
  test('PdfExtractor fixes project context and broken demo links', () {
    const raw = '''
PROJECTS
CareerAssistant-Career&ProductivityApp | Flutter, Riverpod [Demo](https://drive.google.com/drive/folders/1RcHTc8m51iyusnl8xN6gGgiVaSX0hPKF?usp=sharing)
SproutKids-AI-PoweredLearningApp | Flutter, Python (FastAPI), Groq API
[Demo](https://www.linkedin).com/posts/developer-showcase-flutter-fastapi-activity-123456789)
BuiltanAI-poweredlearningappusingFlutter,FastAPI,andGroq'sLlama4ScoutVisionforimage-basedinteractive learning.
FitFlow-Fitness&WellnessApp | Flutter, Firebase, Riverpod
[Demo](https://www.linkedin).com/posts/developer-showcase-fitness-app-activity-987654321)
''';

    final fixed = PdfExtractor.fixProjectContext(raw);

    // Verify title spacing (no hyphens)
    expect(fixed, contains('Career Assistant | Career & Productivity App'));
    expect(fixed, contains('Sprout Kids | AI-Powered Learning App'));
    expect(fixed, contains('FitFlow | Fitness & Wellness App'));

    // Verify words unjammed
    expect(fixed, contains('Built an AI-powered learning app using Flutter, FastAPI, and Groq\'s Llama 4 Scout Vision for image-based interactive learning.'));

    // Verify demo links repaired without broken .com prefix
    expect(fixed, isNot(contains('[Demo](https://www.linkedin).com')));
    expect(fixed, contains('https://www.linkedin.com/posts/developer-showcase-flutter-fastapi-activity-123456789'));
    expect(fixed, contains('https://www.linkedin.com/posts/developer-showcase-fitness-app-activity-987654321'));
  });

  test('HeuristicLocalDatasource adds candidate-chosen skills with old skills and excludes unchosen skills', () {
    const resume = '''
ALEX MORGAN
Flutter Developer
Bengaluru, India | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan) | [LinkedIn](https://linkedin.com/in/alexmorgan)

TECHNICAL SKILLS
Languages: Dart, Java, SQL, Python
Mobile Development: Flutter, Android SDK
Tools: Git, Postman, Android Studio, VS Code, Figma
''';

    final ds = HeuristicLocalDataSource();
    final verified = {
      'React': UserSkillEntry(
        skill: 'React',
        proficiency: SkillProficiency.beginner,
        selectedAt: DateTime(2026, 1, 1),
      ),
      'Docker': UserSkillEntry(
        skill: 'Docker',
        proficiency: SkillProficiency.intermediate,
        selectedAt: DateTime(2026, 1, 1),
      ),
    };

    final tailored = ds.tailorResume(
      const ResumeInput(
        jobDescription: 'Looking for React, Docker, CI/CD, GitHub Actions, WebSockets',
        resumeText: resume,
      ),
      AnalysisResult(
        matchScore: 80.0,
        skillsScore: 80.0,
        experienceScore: 80.0,
        locationScore: 80.0,
        resumeCity: 'Noida, India',
        jobCity: 'Bengaluru, India',
        matchedSkills: const ['Flutter', 'Dart'],
        missingSkills: const ['React', 'Docker', 'CI/CD', 'GitHub Actions', 'WebSockets'],
        userVerifiedSkills: verified,
        isCityAligned: false,
        strengths: const [],
        recommendations: const [],
        summary: 'Good match',
      ),
    );

    // Verify NO Newly Integrated line
    expect(tailored.tailoredResume, isNot(contains('Newly Integrated')));
    expect(tailored.tailoredResume, isNot(contains('Newly Integrated & Aligned')));

    // Candidate-chosen skills are present with their proficiency
    expect(tailored.tailoredResume, contains('React (Beginner)'));
    expect(tailored.tailoredResume, contains('Docker (Intermediate)'));

    // Old skills are preserved
    expect(tailored.tailoredResume, contains('Dart'));
    expect(tailored.tailoredResume, contains('Flutter'));
    expect(tailored.tailoredResume, contains('Postman'));

    // Unchosen missing skills MUST NOT be present
    expect(tailored.tailoredResume, isNot(contains('CI/CD')));
    expect(tailored.tailoredResume, isNot(contains('GitHub Actions')));
    expect(tailored.tailoredResume, isNot(contains('WebSockets')));

    // Verify Tools line contains Docker (Intermediate)
    expect(tailored.tailoredResume, contains('Tools: Git, Postman, Android Studio, VS Code, Figma, Docker (Intermediate)'));
  });

  test('PdfExtractor eliminates lone bullet symbols and joins with sentence', () {
    const rawWithLoneBullets = '''
PROJECTS
Android Calculator Automation | Java, Appium, Maven Project
•
Developed a mobile automation framework for the Android Calculator.
• Executed automated test cases.
HR Analytics Dashboard | Tableau Project
•
Built an interactive Tableau dashboard.
''';

    final fixed = PdfExtractor.fixProjectContext(rawWithLoneBullets);

    // Verify lone bullets are joined with sentences
    expect(fixed, isNot(contains('\n•\n')));
    expect(fixed, contains('• Developed a mobile automation framework'));
    expect(fixed, contains('• Built an interactive Tableau dashboard'));
  });
}
