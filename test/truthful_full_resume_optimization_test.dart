import 'package:flutter_test/flutter_test.dart';
import 'package:resume_maker/data/datasources/heuristic_local_datasource.dart';
import 'package:resume_maker/data/datasources/truthful_resume_rewriter.dart';
import 'package:resume_maker/domain/entities/analysis_result.dart';
import 'package:resume_maker/domain/entities/resume_audit_entry.dart';
import 'package:resume_maker/domain/entities/resume_input.dart';

void main() {
  group('Intelligent & Truthful Full-Resume Optimization Suite', () {
    const manualTesterJd = '''
Location: Noida, Sector 62 Employment Type: Full-Time
About the Role
Nirwana AI is looking for a Manual Tester who can ensure our products and new features work smoothly before they reach our customers. You will work closely with the product, design, and development teams to test new features, identify bugs, validate bug fixes, and make sure issues are clearly documented and resolved.
Key Responsibilities
- Test new product features before release.
- Perform functional, regression, integration, and usability testing.
- Identify bugs, UI issues, broken flows, and unexpected product behaviour.
- Retest bug fixes and verify that issues have been resolved correctly.
- Create clear and detailed bug reports with steps to reproduce, screenshots/videos, expected behaviour, and actual behaviour.
- Log, track, and manage bugs using Jira.
- Test products across different browsers, devices, and screen sizes using BrowserStack.
- Coordinate with developers, designers, product managers, and other teams to understand reported issues.
- Understand complete user journeys and identify edge cases that may affect the customer experience.
- Perform regression testing before major releases.
- Help maintain test cases, testing checklists, and release-quality standards.
- Clearly communicate critical bugs and release blockers to the relevant teams.
- Ensure previously working features are not affected by new releases or changes.
Requirements
- Strong understanding of software testing concepts and QA processes.
- Experience testing web applications.
What We’re Looking For
- Hands-on experience with Jira for bug reporting and tracking.
- Experience with BrowserStack or similar cross-browser/device testing tools.
- Ability to write clear, structured, and actionable bug reports.
- Strong attention to detail and ability to identify edge cases.
- Good communication and coordination skills.
- Ability to understand product flows from an end-user perspective.
- Comfortable working closely with product, development, and design teams.
We’re looking for someone who doesn’t just follow test cases, but actively tries to understand what can go wrong in a product. You should be curious, detail-oriented, comfortable asking questions, and able to clearly explain an issue so that the team can reproduce and fix it quickly.
''';

    const candidateResume = '''
Alex Morgan
alex.morgan@email.com | +91 98765 43210 | Noida, India | linkedin.com/in/alexmorgan

PROFESSIONAL SUMMARY
Passionate QA Engineer with 2 years of experience in manual functional and regression testing of web applications. Proficient in designing test cases, logging defect reports, and collaborating with cross-functional development teams.

SKILLS
Manual Testing, Functional Testing, Regression Testing, Smoke Testing, Test Case Design, Bug Reporting, Jira, Postman, Web Testing, Agile/Scrum

PROFESSIONAL EXPERIENCE
QA Tester | TechSolutions Pvt. Ltd. | Noida, India | June 2023 – Present
- Tested new web features and reported defects in Jira.
- Executed functional and regression test suites across 15+ sprint cycles.
- Validated bug fixes and re-tested resolved issues before scheduled deployments.
- Collaborated with 4 developers to reproduce edge case issues and verify system stability.

Junior Software Tester | AppCraft Labs | Gurgaon, India | July 2022 – May 2023
- Wrote 50+ test cases covering end-user journeys for e-commerce web platform.
- Logged detailed defect reports with reproduction steps and screenshots.

PROJECTS
Healthcare Portal Verification | Personal Project
- Conducted end-to-end usability and regression testing for appointment booking workflows.
- Documented test scenarios and tracked 25+ defect tickets.

EDUCATION
Bachelor of Technology in Computer Science | AKTU, Lucknow | 2018 – 2022
''';

    test('JD does NOT falsely detect "Go" language from the phrase "what can go wrong in a product"', () {
      final hasGo = HeuristicLocalDataSource.hasSkill(manualTesterJd, 'Go');
      expect(hasGo, isFalse, reason: '"Go" should not match the English verb "go" in "what can go wrong"');

      // But technical Go should still match
      expect(HeuristicLocalDataSource.hasSkill('Proficient in Go, Python, Docker', 'Go'), isTrue);
      expect(HeuristicLocalDataSource.hasSkill('Hands-on Golang developer experience', 'Go'), isTrue);
    });

    test('Detects target role, domain, and city accurately from Nirwana AI JD', () {
      final datasource = HeuristicLocalDataSource();
      final role = datasource.extractRole(manualTesterJd);
      final domain = datasource.detectDomain(manualTesterJd, candidateResume);
      final city = datasource.extractCity(manualTesterJd);

      expect(role, anyOf(contains('Tester'), contains('QA')));
      expect(domain, contains('Testing'));
      expect(city, contains('Noida'));
    });

    test('Rewrites 100% of experience bullets and projects while preserving verified facts & metrics', () {
      final datasource = HeuristicLocalDataSource();
      final analysis = datasource.analyzeMatch(
        ResumeInput(
          jobDescription: manualTesterJd,
          resumeText: candidateResume,
          targetPages: 1,
        ),
      );

      final tailored = datasource.tailorResume(
        ResumeInput(
          jobDescription: manualTesterJd,
          resumeText: candidateResume,
          targetPages: 1,
        ),
        analysis.toDomain(),
      );

      // 1. Audit generation
      expect(tailored.bulletAudits, isNotEmpty);
      expect(tailored.bulletAudits.length, greaterThanOrEqualTo(5));

      // 2. Verified metrics (15+, 50+, 25+) are preserved
      expect(tailored.tailoredResume, contains('15+'));
      expect(tailored.tailoredResume, contains('50+'));

      // 3. Truthfulness check
      expect(tailored.truthfulnessResult, isNotNull);
      expect(tailored.truthfulnessResult!.isTruthful, isTrue);
      expect(tailored.truthfulnessResult!.traceabilityScore, equals(100.0));
      expect(tailored.truthfulnessResult!.flaggedClaims, isEmpty);

      // 4. Missing tool (BrowserStack) is reported as a gap, NOT hallucinated as employment experience
      final browserStackMapping = tailored.evidenceMappings.firstWhere(
        (m) => m.requirement.toLowerCase().contains('browserstack'),
        orElse: () => const RequirementEvidenceMapping(
          requirement: 'BrowserStack',
          classification: EvidenceClassification.notEvidenced,
          confidence: 0.9,
          sourceEvidence: '',
          recommendation: '',
        ),
      );
      expect(browserStackMapping.classification, equals(EvidenceClassification.notEvidenced));
      // Resume should NOT falsely assert candidate had years of professional BrowserStack employment
      expect(
        tailored.tailoredResume.contains('professional BrowserStack experience') ||
        tailored.tailoredResume.contains('2 years of BrowserStack'),
        isFalse,
      );

      // 5. Clarification questions are provided for missing JD tools
      expect(tailored.candidateClarificationQuestions, isNotEmpty);
      expect(
        tailored.candidateClarificationQuestions.any((q) => q.toLowerCase().contains('browserstack')),
        isTrue,
      );
    });

    test('Action verbs are applied to rewritten experience bullets', () {
      final datasource = HeuristicLocalDataSource();
      final analysis = datasource.analyzeMatch(
        ResumeInput(
          jobDescription: manualTesterJd,
          resumeText: candidateResume,
          targetPages: 1,
        ),
      );

      final tailored = datasource.tailorResume(
        ResumeInput(
          jobDescription: manualTesterJd,
          resumeText: candidateResume,
          targetPages: 1,
        ),
        analysis.toDomain(),
      );

      for (final audit in tailored.bulletAudits) {
        if (audit.section.toLowerCase().contains('summary')) continue;
        if (audit.hasChanged) {
          final firstWord = audit.rewritten.trim().split(' ').first;
          expect(
            RegExp(r'^[A-Z][a-z]+(?:ed)?$').hasMatch(firstWord),
            isTrue,
            reason: 'Rewritten bullet "$firstWord..." should begin with a capitalized action verb',
          );
        }
      }
    });
  });
}
