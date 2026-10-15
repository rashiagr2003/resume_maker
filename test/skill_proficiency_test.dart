import 'package:flutter_test/flutter_test.dart';
import 'package:resume_maker/core/constants/sample_data.dart';
import 'package:resume_maker/data/datasources/heuristic_local_datasource.dart';
import 'package:resume_maker/domain/entities/analysis_result.dart';
import 'package:resume_maker/domain/entities/resume_input.dart';
import 'package:resume_maker/domain/entities/user_skill_entry.dart';

void main() {
  group('Interactive Skill Proficiency & Verification Engine', () {
    late HeuristicLocalDataSource dataSource;

    setUp(() {
      dataSource = HeuristicLocalDataSource();
    });

    test('SkillProficiency enum covers all 4 required levels with metadata', () {
      expect(SkillProficiency.values.length, equals(4));

      final beginner = SkillProficiency.beginner;
      expect(beginner.label, equals('Beginner'));
      expect(beginner.shortLabel, equals('Beginner'));
      expect(beginner.description, contains('Foundational knowledge'));

      final intermediate = SkillProficiency.intermediate;
      expect(intermediate.label, equals('Intermediate'));
      expect(intermediate.shortLabel, equals('Intermediate'));
      expect(intermediate.description, contains('Working competence'));

      final advanced = SkillProficiency.advanced;
      expect(advanced.label, equals('Advanced / Professional'));
      expect(advanced.shortLabel, equals('Advanced'));
      expect(advanced.description, contains('Deep mastery'));

      final learning = SkillProficiency.learning;
      expect(learning.label, equals('Currently Learning'));
      expect(learning.shortLabel, equals('Learning'));
      expect(learning.description, contains('Actively pursuing'));
    });

    test('UserSkillEntry serialization and equality works properly', () {
      final now = DateTime.now();
      final entry = UserSkillEntry(
        skill: 'US IT Recruitment',
        proficiency: SkillProficiency.advanced,
        isCustom: false,
        selectedAt: now,
      );

      final json = entry.toJson();
      expect(json['skill'], equals('US IT Recruitment'));
      expect(json['proficiency'], equals('advanced'));
      expect(json['isCustom'], isFalse);

      final parsed = UserSkillEntry.fromJson(json);
      expect(parsed.skill, equals('US IT Recruitment'));
      expect(parsed.proficiency, equals(SkillProficiency.advanced));
      expect(parsed.isCustom, isFalse);
    });

    test('Selecting proficiency for missing skills moves them to matched and recalculates ATS score', () {
      const usItRecruiterJd = '''
HIRING: US IT Recruiter (IT & Non-IT)
Role: US IT Recruiter
What you'll do:
• Cold calling & US client outreach
• Source, screen & shortlist IT/Non-IT candidates
• Coordinate interviews & manage recruitment pipeline
We're looking for:
• Excellent English communication
• Target-driven & self-motivated
• Comfortable with permanent US night shift
Walk-In Interview: Block, Sector 63, Noida
''';

      const candidateResume = '''
ALEX MORGAN
Noida, India | +91 98765 43210 | alex.morgan@example.com
PROFESSIONAL SUMMARY
Analytical graduate with strong English communication and technical understanding.
SKILLS
Staffing, Candidate Sourcing, Data Analysis
EDUCATION
Manipal University Jaipur | Bachelor of Technology
''';

      final input = ResumeInput(
        jobDescription: usItRecruiterJd,
        resumeText: candidateResume,
      );

      final initialAnalysis = dataSource.analyzeMatch(input).toDomain();
      expect(initialAnalysis.matchScore, lessThan(70.0));
      expect(initialAnalysis.isEligibleForUpdate, isFalse);

      // Verify "Bloc" was NOT detected as a skill from "Block"
      expect(initialAnalysis.missingSkills.contains('Bloc'), isFalse);
      expect(initialAnalysis.missingSkills, contains('Cold Calling'));
      expect(initialAnalysis.missingSkills, contains('US IT Recruitment'));

      // User selectively verifies 3 skills:
      // 1. "US IT Recruitment" at Intermediate
      // 2. "Cold Calling" at Advanced / Professional
      // 3. "US Night Shift" as Currently Learning
      final verifiedSkills = <String, UserSkillEntry>{
        'US IT Recruitment': UserSkillEntry(
          skill: 'US IT Recruitment',
          proficiency: SkillProficiency.intermediate,
          selectedAt: DateTime.now(),
        ),
        'Cold Calling': UserSkillEntry(
          skill: 'Cold Calling',
          proficiency: SkillProficiency.advanced,
          selectedAt: DateTime.now(),
        ),
        'US Night Shift': UserSkillEntry(
          skill: 'US Night Shift',
          proficiency: SkillProficiency.learning,
          selectedAt: DateTime.now(),
        ),
      };

      final updatedAnalysis = initialAnalysis.withVerifiedSkills(verifiedSkills);

      // Verified active skills should now be in matchedSkills
      expect(updatedAnalysis.matchedSkills, contains('US IT Recruitment'));
      expect(updatedAnalysis.matchedSkills, contains('Cold Calling'));
      expect(updatedAnalysis.missingSkills.contains('US IT Recruitment'), isFalse);
      expect(updatedAnalysis.missingSkills.contains('Cold Calling'), isFalse);

      // Score should dynamically increase
      expect(updatedAnalysis.matchScore, greaterThan(initialAnalysis.matchScore));
      expect(updatedAnalysis.userVerifiedSkills.length, equals(3));
    });

    test('Adding custom unlisted skill increases score and reflects custom flag', () {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeLowMatch,
      );

      final initialAnalysis = dataSource.analyzeMatch(input).toDomain();
      final initialScore = initialAnalysis.matchScore;

      // Add custom skill "GraphQL" and "Docker"
      final verified = <String, UserSkillEntry>{
        'GraphQL': UserSkillEntry(
          skill: 'GraphQL',
          proficiency: SkillProficiency.advanced,
          isCustom: true,
          selectedAt: DateTime.now(),
        ),
        'Docker': UserSkillEntry(
          skill: 'Docker',
          proficiency: SkillProficiency.intermediate,
          isCustom: true,
          selectedAt: DateTime.now(),
        ),
      };

      final updated = initialAnalysis.withVerifiedSkills(verified);
      expect(updated.userVerifiedSkills['GraphQL']!.isCustom, isTrue);
      expect(updated.matchScore, greaterThan(initialScore));
      expect(updated.matchedSkills, contains('GraphQL'));
      expect(updated.matchedSkills, contains('Docker'));
    });

    test('Advanced proficiency provides higher bonus than Beginner proficiency', () {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeLowMatch,
      );

      final initial = dataSource.analyzeMatch(input).toDomain();

      final beginnerMap = {
        'Riverpod': UserSkillEntry(
          skill: 'Riverpod',
          proficiency: SkillProficiency.beginner,
          selectedAt: DateTime.now(),
        ),
      };

      final advancedMap = {
        'Riverpod': UserSkillEntry(
          skill: 'Riverpod',
          proficiency: SkillProficiency.advanced,
          selectedAt: DateTime.now(),
        ),
      };

      final withBeginner = initial.withVerifiedSkills(beginnerMap);
      final withAdvanced = initial.withVerifiedSkills(advancedMap);

      expect(withAdvanced.matchScore, greaterThan(withBeginner.matchScore));
    });

    test('Removing verified skills returns them to missing and re-evaluates score', () {
      final input = ResumeInput(
        jobDescription: SampleData.sampleJdFlutter,
        resumeText: SampleData.sampleResumeLowMatch,
      );

      final initial = dataSource.analyzeMatch(input).toDomain();
      final verified = {
        'Riverpod': UserSkillEntry(
          skill: 'Riverpod',
          proficiency: SkillProficiency.intermediate,
          selectedAt: DateTime.now(),
        ),
      };

      final withSkill = initial.withVerifiedSkills(verified);
      expect(withSkill.matchedSkills, contains('Riverpod'));

      // Remove skill by passing empty map
      final withoutSkill = initial.withVerifiedSkills(const {});
      expect(withoutSkill.userVerifiedSkills.isEmpty, isTrue);
      expect(withoutSkill.matchScore, equals(initial.matchScore));
    });

    test('Tailored resume integrates candidate-verified skills with exact proficiencies', () {
      const jd = '''
Role: US IT Recruiter
Responsibilities: Cold Calling, Client Outreach, Candidate Sourcing, Interview Coordination
''';

      const resume = '''
ALEX MORGAN
Noida, India | +91 98765 43210 | alex.morgan@example.com
PROFESSIONAL SUMMARY
Enthusiastic professional with communication skills.
SKILLS
Staffing: Candidate Sourcing
EXPERIENCE
Coordinator | ABC Corp | 2024 - 2025
EDUCATION
Manipal University Jaipur | 2021 - 2025
''';

      final input = ResumeInput(jobDescription: jd, resumeText: resume);
      final analysis = dataSource.analyzeMatch(input).toDomain();

      final verified = {
        'Cold Calling': UserSkillEntry(
          skill: 'Cold Calling',
          proficiency: SkillProficiency.advanced,
          selectedAt: DateTime.now(),
        ),
        'Client Outreach': UserSkillEntry(
          skill: 'Client Outreach',
          proficiency: SkillProficiency.intermediate,
          selectedAt: DateTime.now(),
        ),
      };

      final updatedAnalysis = analysis.withVerifiedSkills(verified);
      final tailored = dataSource.tailorResume(input, updatedAnalysis);

      // Tailored resume must reflect candidate proficiencies
      expect(tailored.tailoredResume, contains('Cold Calling (Advanced)'));
      expect(tailored.tailoredResume, contains('Client Outreach (Intermediate)'));
      // Must preserve old skill from original resume
      expect(tailored.tailoredResume, contains('Candidate Sourcing'));
      // Must NOT contain unchosen missing skills
      expect(tailored.tailoredResume, isNot(contains('Interview Coordination')));
    });

    test('Tailored resume does not inject extra missing skills when candidate chooses none', () {
      const jd = '''
Role: US IT Recruiter
Responsibilities: Cold Calling, Client Outreach, Candidate Sourcing, Interview Coordination
''';

      const resume = '''
ALEX MORGAN
Noida, India | +91 98765 43210 | alex.morgan@example.com
PROFESSIONAL SUMMARY
Enthusiastic professional with communication skills.
SKILLS
Staffing: Candidate Sourcing
EXPERIENCE
Coordinator | ABC Corp | 2024 - 2025
EDUCATION
Manipal University Jaipur | 2021 - 2025
''';

      final input = ResumeInput(jobDescription: jd, resumeText: resume);
      final analysis = dataSource.analyzeMatch(input).toDomain();

      // Candidate verifies NO skills
      final tailored = dataSource.tailorResume(input, analysis);

      // Must preserve old skill from resume
      expect(tailored.tailoredResume, contains('Candidate Sourcing'));
      // Must NOT inject unchosen missing skills
      expect(tailored.tailoredResume, isNot(contains('Cold Calling')));
      expect(tailored.tailoredResume, isNot(contains('Client Outreach')));
      expect(tailored.tailoredResume, isNot(contains('Interview Coordination')));
    });
  });
}
