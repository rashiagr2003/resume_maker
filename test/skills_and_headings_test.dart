import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_extractor.dart';
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/data/datasources/heuristic_local_datasource.dart';
import 'package:resume_maker/domain/entities/analysis_result.dart';
import 'package:resume_maker/domain/entities/resume_input.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';
import 'package:resume_maker/domain/entities/user_skill_entry.dart';

void main() {
  group('Skills Section & Heading Spacing Suite', () {
    const rawResumeWithoutSkillsSection = '''
ALEX MORGAN
US IT Recruiter
+1 555-0149 | alex.morgan@example.com
[LinkedIn](https://linkedin.com/in/alexmorgan)

PROFESSIONAL SUMMARY
Dynamic, results-driven US IT Recruiter.

PROFESSIONAL EXPERIENCE
MobileApplicationDeveloper Dec 2025 - May 2026
Logische Innovative Pvt. Ltd.
• Worked with business and technical requirements to understand project needs.
• Worked with REST APIs, structured application data, and technical documentation.

FlutterDeveloperIntern Aug 2025 - Oct 2025
Bharat TeleClinic
• Worked with application requirements, structured data, API responses.
• Collaborated with team members and support timely task com- pletion.
• Performed application testing and data validation to identify inconsistencies.

PROJECTS
HRAnalytics Dashboard-Tableau Project
• Analyzed employee data and developed an interactive dashboard.
E-CommerceSalesAnalysis Dashboard-PowerBI Project
• Analyzed sales data and created KPI reports using charts, filters, and slicers.
VrindaStoreSalesAnalysis-Excel Project
• Used Excel Pivot Tables, Charts, and Slicers to analyze customer data.

EDUCATION
B.TechinInformationTechnology2021-2025
Manipal University Jaipur
''';

    test('PdfExtractor fixes word jamming in job roles, project headings, and education', () {
      final unjammed = PdfExtractor.fixProjectContext(rawResumeWithoutSkillsSection);

      // Verify job roles have proper spaces
      expect(unjammed, contains('Mobile Application Developer'));
      expect(unjammed, contains('Flutter Developer Intern'));

      // Verify hyphenated line break word is repaired
      expect(unjammed, contains('completion'));
      expect(unjammed, isNot(contains('com- pletion')));

      // Verify projects have proper spaces and pipes
      expect(unjammed, contains('HR Analytics Dashboard | Tableau'));
      expect(unjammed, contains('E-Commerce Sales Analysis Dashboard | Power BI'));
      expect(unjammed, contains('Vrinda Store Sales Analysis | Excel'));

      // Verify education has proper spaces and separated date
      expect(unjammed, contains('B.Tech in Information Technology | 2021 - 2025'));
    });

    test('HeuristicLocalDataSource synthesizes guaranteed SKILLS section preserving previous skills and adding candidate preferences', () {
      final ds = HeuristicLocalDataSource();

      final candidateVerifiedSkills = <String, UserSkillEntry>{
        'US IT Recruitment': UserSkillEntry(
          skill: 'US IT Recruitment',
          proficiency: SkillProficiency.advanced,
          selectedAt: DateTime(2026, 1, 1),
        ),
        'Candidate Sourcing': UserSkillEntry(
          skill: 'Candidate Sourcing',
          proficiency: SkillProficiency.intermediate,
          selectedAt: DateTime(2026, 1, 1),
        ),
        'Screening & Shortlisting': UserSkillEntry(
          skill: 'Screening & Shortlisting',
          proficiency: SkillProficiency.intermediate,
          selectedAt: DateTime(2026, 1, 1),
        ),
        'Interview Coordination': UserSkillEntry(
          skill: 'Interview Coordination',
          proficiency: SkillProficiency.beginner,
          selectedAt: DateTime(2026, 1, 1),
        ),
        'US Night Shift': UserSkillEntry(
          skill: 'US Night Shift',
          proficiency: SkillProficiency.learning,
          selectedAt: DateTime(2026, 1, 1),
        ),
      };

      final analysis = AnalysisResult(
        matchScore: 82.0,
        skillsScore: 28.0,
        experienceScore: 22.0,
        keywordsScore: 13.0,
        educationScore: 9.0,
        achievementsScore: 7.0,
        readabilityScore: 8.0,
        detectedJobTitle: 'US IT Recruiter',
        detectedDomain: 'US IT Recruitment & Staffing',
        detectedSeniority: 'Entry-Level / Fresher (0–1 Year)',
        jobCity: 'Noida, India',
        resumeCity: 'Noida, India',
        isCityAligned: true,
        matchedSkills: ['Candidate Sourcing'],
        missingSkills: ['US IT Recruitment', 'Screening & Shortlisting', 'Interview Coordination', 'Cold Calling'],
        userVerifiedSkills: candidateVerifiedSkills,
        mandatoryGaps: [],
        preferredGaps: [],
        transferableSkills: [],
        parsingIssues: [],
        recommendations: [],
        scoreExplanation: 'Great match',
        summary: 'Qualified candidate',
        threshold: 70.0,
      );

      final tailored = ds.tailorResume(
        const ResumeInput(
          jobDescription: 'US IT Recruiter with candidate sourcing, screening, interview coordination, cold calling',
          resumeText: rawResumeWithoutSkillsSection,
        ),
        analysis,
      );

      // 1. MUST contain TECHNICAL SKILLS section header
      expect(tailored.tailoredResume, contains('TECHNICAL SKILLS'));

      // 2. Candidate preferences must be included with their proficiency labels
      expect(tailored.tailoredResume, contains('US IT Recruitment (Advanced)'));
      expect(tailored.tailoredResume, contains('Candidate Sourcing (Intermediate)'));
      expect(tailored.tailoredResume, contains('Screening & Shortlisting (Intermediate)'));
      expect(tailored.tailoredResume, contains('Interview Coordination (Beginner)'));

      // 3. Learning skills must be in In-Progress / Currently Learning
      expect(tailored.tailoredResume, contains('In-Progress / Currently Learning: US Night Shift (In Progress)'));

      // 4. Candidate previous skills (from projects and experience) must be preserved
      expect(tailored.tailoredResume, contains('Tableau'));
      expect(tailored.tailoredResume, contains('Power BI'));
      expect(tailored.tailoredResume, contains('Advanced Excel (Pivot Tables & Slicers)'));
      expect(tailored.tailoredResume, contains('REST APIs'));
      expect(tailored.tailoredResume, contains('Flutter'));

      // 5. Unchosen missing skills MUST NOT be injected
      expect(tailored.tailoredResume, isNot(contains('Cold Calling')));
    });

    test('PdfGenerator renders guaranteed SKILLS section in PDF with unjammed headings and exact 1-page fit', () async {
      final ds = HeuristicLocalDataSource();

      final candidateVerifiedSkills = <String, UserSkillEntry>{
        'US IT Recruitment': UserSkillEntry(
          skill: 'US IT Recruitment',
          proficiency: SkillProficiency.advanced,
          selectedAt: DateTime(2026, 1, 1),
        ),
        'Candidate Sourcing': UserSkillEntry(
          skill: 'Candidate Sourcing',
          proficiency: SkillProficiency.intermediate,
          selectedAt: DateTime(2026, 1, 1),
        ),
        'Screening & Shortlisting': UserSkillEntry(
          skill: 'Screening & Shortlisting',
          proficiency: SkillProficiency.intermediate,
          selectedAt: DateTime(2026, 1, 1),
        ),
        'Interview Coordination': UserSkillEntry(
          skill: 'Interview Coordination',
          proficiency: SkillProficiency.beginner,
          selectedAt: DateTime(2026, 1, 1),
        ),
      };

      final analysis = AnalysisResult(
        matchScore: 85.0,
        skillsScore: 28.0,
        experienceScore: 22.0,
        keywordsScore: 13.0,
        educationScore: 9.0,
        achievementsScore: 7.0,
        readabilityScore: 8.0,
        detectedJobTitle: 'US IT Recruiter',
        detectedDomain: 'US IT Recruitment & Staffing',
        detectedSeniority: 'Entry-Level / Fresher (0–1 Year)',
        jobCity: 'Noida, India',
        resumeCity: 'Noida, India',
        isCityAligned: true,
        matchedSkills: ['Candidate Sourcing'],
        missingSkills: ['US IT Recruitment', 'Screening & Shortlisting', 'Interview Coordination'],
        userVerifiedSkills: candidateVerifiedSkills,
        mandatoryGaps: [],
        preferredGaps: [],
        transferableSkills: [],
        parsingIssues: [],
        recommendations: [],
        scoreExplanation: 'Great match',
        summary: 'Qualified candidate',
        threshold: 70.0,
      );

      final tailored = ds.tailorResume(
        const ResumeInput(
          jobDescription: 'US IT Recruiter with candidate sourcing, screening, interview coordination',
          resumeText: rawResumeWithoutSkillsSection,
        ),
        analysis,
      );

      final pdfBytes = await PdfGenerator.generatePdfBytes(
        tailored: tailored,
        candidateName: 'Alex Morgan',
      );

      final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);

      // Verify exact 1-page fit
      expect(sfDoc.pages.count, equals(1), reason: 'Resume MUST fit on exactly one page');

      // Verify extracted text from PDF
      final pdfText = sf.PdfTextExtractor(sfDoc).extractText();
      final normalizedPdfText = pdfText.replaceAll(RegExp(r'\s+'), ' ');

      // 1. MUST have Skills section
      expect(normalizedPdfText, contains('TECHNICAL SKILLS'));
      expect(normalizedPdfText, contains('US IT Recruitment'));
      expect(normalizedPdfText, contains('Candidate Sourcing'));
      expect(normalizedPdfText, contains('Tableau'));
      expect(normalizedPdfText, contains('Power BI'));

      // 2. Headings must have spaces in PDF text
      expect(normalizedPdfText, contains('Mobile Application Developer'));
      expect(normalizedPdfText, contains('Flutter Developer Intern'));
      expect(normalizedPdfText, contains('HR Analytics Dashboard'));
      expect(normalizedPdfText, contains('E-Commerce Sales Analysis Dashboard'));
      expect(normalizedPdfText, contains('Vrinda Store Sales Analysis'));
      expect(normalizedPdfText, contains('B.Tech in Information Technology'));
      expect(normalizedPdfText, contains('2021 - 2025'));

      sfDoc.dispose();
    });
  });
}
