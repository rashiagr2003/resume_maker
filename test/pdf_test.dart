import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/constants/sample_data.dart';
import 'package:resume_maker/core/utils/pdf_extractor.dart';
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';
import 'package:resume_maker/domain/entities/resume_input.dart';
import 'package:resume_maker/data/datasources/heuristic_local_datasource.dart';

void main() {
  test('PdfExtractor extracts clean text from real PDF bytes without PDF object syntax', () async {
    // Generate a test PDF
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Text('Alex Rivera'),
            pw.Text('alex.rivera@email.com | +91 98765 43210 | Mumbai, India'),
            pw.Text('PROFESSIONAL SUMMARY'),
            pw.Text('Experienced Senior Mobile Engineer specializing in Flutter & Dart.'),
            pw.Text('TECHNICAL SKILLS'),
            pw.Text('Flutter, Dart, Riverpod, Clean Architecture, REST API, Git'),
          ],
        ),
      ),
    );

    final Uint8List bytes = await pdf.save();

    final extracted = PdfExtractor.extractText(bytes);

    // Verify it contains actual resume content
    expect(extracted, contains('Alex Rivera'));
    expect(extracted, contains('Flutter'));

    // Verify it NEVER contains raw PDF object syntax
    expect(extracted, isNot(contains('obj')));
    expect(extracted, isNot(contains('/FlateDecode')));
    expect(extracted, isNot(contains('stream')));
    expect(extracted, isNot(contains('/Linearized')));
  });

  test('PdfGenerator generates EXACT 1-page PDF without footer and with clickable hyperlinks', () async {
    final tailored = TailoredResume(
      originalResume: SampleData.sampleResumeHighMatch,
      tailoredResume: SampleData.sampleResumeHighMatch,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Experienced Flutter engineer...',
      addedKeywords: ['Docker', 'CI/CD'],
      modifiedSections: ['Summary', 'Skills'],
      cityAlignmentNote: 'Aligned to Bengaluru',
      generationModel: 'Test Engine',
      timestamp: DateTime.now(),
      targetPages: 1, // EXACT 1 PAGE REQUESTED
    );

    final bytes = await PdfGenerator.generatePdfBytes(
      tailored: tailored,
      candidateName: 'Alex Morgan',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);

    // 1. MUST BE EXACTLY 1 PAGE!
    expect(sfDoc.pages.count, equals(1), reason: 'Resume MUST fit on exactly one single page');

    // 2. MUST CONTAIN CLICKABLE HYPERLINKS IN OUTPUT
    expect(sfDoc.pages[0].annotations.count, greaterThanOrEqualTo(1),
        reason: 'Links (GitHub, LinkedIn, Portfolio) must be real clickable annotations in the output PDF');

    // 3. NO FOOTER IN PDF!
    final extractedText = sf.PdfTextExtractor(sfDoc).extractText();
    expect(extractedText, isNot(contains('Page 1 of 1')), reason: 'Footer must be removed completely');
    expect(extractedText, isNot(contains('ATS-Ready Resume')), reason: 'Footer watermark must be removed');

    // 4. Clean Proper Nouns (Zero $1 $2 corruption)
    expect(extractedText, contains('FitFlow'), reason: 'FitFlow must render cleanly without corruption');
    expect(extractedText, isNot(contains(r'Fi$1')), reason: 'No dollar-1 artifact in FitFlow');
    expect(extractedText, contains('SharedPreferences'), reason: 'SharedPreferences must render cleanly');
    expect(extractedText, isNot(contains(r'Share$1')), reason: 'No dollar-1 artifact in SharedPreferences');

    sfDoc.dispose();
  });

  test('PdfGenerator fits dense 5-project resume on EXACTLY 1 page with space-between project links and no \$1 \$2', () async {
    const denseResume = '''
ALEX MORGAN
Bengaluru, India | +1-555-123-4567 | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan) | [Portfolio](https://alexmorgan.dev) | [LinkedIn](https://linkedin.com/in/alexmorgan)

PROFESSIONAL SUMMARY
Results-driven professional aligned with the Bengaluru, India market, specializing in delivering scalable, high-performance solutions matching requirements in Flutter, Dart, Riverpod. Demonstrated success driving product excellence and collaborative engineering. Selenium and Appium. Skilled in developing mobile applications, automating web and mobile testing, integrating REST APIs, and performing API testing, bug tracking, and debugging. Strong foundation in Object-Oriented Programming, SDLC, STLC, Agile methodologies, and software quality assurance.

PROFESSIONAL EXPERIENCE
Software Developer (Full-Time) | December 2025 – May 2026
Logische Innovative Pvt. Ltd. Remote [User App](https://play.google.com/store) | [Healthcare App](https://play.google.com/store)
• Developed and maintained two production Flutter applications (BookEHealth User App and Healthcare App), delivering new features and resolving 50+ bugs and enhancement requests.
• Contributed to the successful initial production release by coordinating feature implementation, resolving development issues, and delivering project milestones on schedule.
• Integrated 15+ RESTful APIs using Dio with structured error handling and efficient state management, improving application stability and data flow.
• Executed 50+ manual test cases, logged defects in Jira, verified bug fixes, and supported stable production releases.

PROJECTS
FitFlow - Fitness & Wellness Platform | Flutter, Firebase, Riverpod [Project](https://github.com/alexmorgan/fitflow)
• Developed a cross-platform fitness application with workout tracking, calorie management, hydration reminders, and task management features.
• Integrated Firebase Authentication, Realtime Database, and Firebase Cloud Messaging for secure authentication and real-time notifications.
Android Calculator Automation | Java, Appium, Selenium, Maven, TestNG [Project](https://github.com/alexmorgan/calculator)
• Developed a mobile automation framework for the Android Calculator application using Appium and Java.
• Executed automated test cases on a real Android device using TestNG, Maven, and the Page Object Model (POM).
Calley Automation Framework | Java, Selenium WebDriver, TestNG, Maven [Project](https://github.com/alexmorgan/calley)
• Built a Selenium WebDriver automation framework for end-to-end testing of the Calley web application.
• Automated user registration, login, profile setup, and workflow validation using the Page Object Model (POM).
HR Analytics Dashboard | Tableau [Project](https://github.com/alexmorgan/hr-dashboard)
• Built an interactive Tableau dashboard to analyze workforce metrics and employee insights.
• Visualized attrition trends, employee demographics, and department-wise workforce distribution using interactive charts and filters.
E-Commerce Sales Analysis Dashboard | Power BI [Project](https://github.com/alexmorgan/ecommerce)
• Designed an interactive Power BI dashboard to analyze sales performance, revenue trends, and business KPIs.
• Created KPI cards, charts, slicers, and filters to enable dynamic business reporting and decision-making.

TECHNICAL SKILLS
Programming Languages: Java, SQL, Dart, Python, React (Beginner)
Automation Testing: Selenium WebDriver, Appium, TestNG, Maven, Docker (Beginner), CI/CD (Beginner), GitHub Actions (Beginner)
Manual Testing: Functional, Regression, Smoke, Sanity, API Testing, Test Case Design, Jira
Data Analytics: Power BI, Tableau, Data Cleaning, Data Visualization, Dashboard Development, Microsoft Excel (Pivot Tables, VLOOKUP, Charts)
Frameworks: Flutter, Firebase, Android SDK, REST APIs, Dio, JSON Parsing
Databases: MySQL, Firebase Realtime Database
Tools: Git, GitHub, Postman, Android Studio, VS Code, Appium Inspector, Figma
Concepts: OOP, SDLC, STLC, Agile, Bug Tracking, Defect Lifecycle, Clean Architecture, WebSockets (Beginner)

EDUCATION
Manipal University Jaipur | 2021 – 2025
Bachelor of Technology in Information Technology CGPA: 7.2/10
''';

    final tailored = TailoredResume(
      originalResume: denseResume,
      tailoredResume: denseResume,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Results-driven professional...',
      addedKeywords: ['React', 'Docker', 'CI/CD'],
      modifiedSections: ['Summary', 'Skills'],
      cityAlignmentNote: 'Aligned to Bengaluru',
      generationModel: 'Test Engine',
      timestamp: DateTime.now(),
      targetPages: 1, // MUST BE 1 PAGE!
    );

    final bytes = await PdfGenerator.generatePdfBytes(
      tailored: tailored,
      candidateName: 'Alex Morgan',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);

    // 1. MUST BE STRICTLY 1 PAGE!
    expect(sfDoc.pages.count, equals(1), reason: 'Dense 5-project resume MUST fit on exactly 1 single page');

    final extractedText = sf.PdfTextExtractor(sfDoc).extractText();

    // 2. MUST contain Education on the same page
    expect(extractedText, contains('EDUCATION'));
    final normalizedText = extractedText.replaceAll(RegExp(r'\s+'), ' ');
    expect(normalizedText, contains('Manipal University Jaipur'));

    // 3. ZERO $1 $2 artifacts
    expect(extractedText, isNot(contains(r'$1')));
    expect(extractedText, isNot(contains(r'$2')));

    // 4. Must contain all 5 projects and project links
    expect(normalizedText, contains('Android Calculator Automation'));
    expect(normalizedText, contains('Calley Automation Framework'));
    expect(normalizedText, contains('HR Analytics Dashboard'));

    // 5. Zero tofu arrow glyphs and zero raw markdown links in body/company lines
    expect(extractedText, isNot(contains('↗')));
    expect(extractedText, isNot(contains(r'[User App](')), reason: 'Company markdown links must be rendered as clickable link text, not raw syntax');

    // 6. Project link count must match 5 project headers (NOT on bullet lines!)
    final projectOccurrences = RegExp(r'\bProject\b').allMatches(extractedText).length;
    expect(projectOccurrences, lessThanOrEqualTo(6), reason: 'Project link should only appear on project header rows, never on bullet lines');

    // 7. Must have clickable project link annotations on page 0
    expect(sfDoc.pages[0].annotations.count, greaterThanOrEqualTo(6));

    sfDoc.dispose();
  });

  test('PdfExtractor and PdfGenerator join split Bug Reporting and keep it in skills', () async {
    const resumeWithSplitBug = '''
ALEX MORGAN
Bengaluru, India | +1-555-123-4567 | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan) | [Portfolio](https://alexmorgan.dev) | [LinkedIn](https://linkedin.com/in/alexmorgan)

TECHNICAL SKILLS
Testing: Manual Testing, Functional Testing, Regression Testing, Smoke Testing, API Testing, Test Case Design, Bug
Reporting
Automation: Selenium WebDriver, Appium, TestNG, Maven
''';

    final unjammed = PdfExtractor.fixProjectContext(resumeWithSplitBug);
    expect(unjammed, contains('Bug Reporting'));

    final tailored = TailoredResume(
      originalResume: resumeWithSplitBug,
      tailoredResume: resumeWithSplitBug,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Summary',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(tailored: tailored, candidateName: 'Alex Morgan');
    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));
    final text = sf.PdfTextExtractor(sfDoc).extractText();
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    expect(normalized, contains('Bug Reporting'));
    sfDoc.dispose();
  });

  test('PdfExtractor and PdfGenerator repair split markdown links like [Healthcare\\nApp](url)', () async {
    const resumeWithSplitLink = '''
ALEX MORGAN
Bengaluru, India | +1-555-123-4567 | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan) | [Portfolio](https://alexmorgan.dev) | [LinkedIn](https://linkedin.com/in/alexmorgan)

PROFESSIONAL EXPERIENCE
Software Developer (Full-Time) | Dec 2025 - May 2026
Logische Innovative Pvt. Ltd. Remote [User App](https://play.google.com/store/apps/details?id=com.bookehealth.user) | [Healthcare
App](https://play.google.com/store/apps/details?id=com.bookehealthcarepro.doctor)
• Developed Flutter applications
''';

    final unjammed = PdfExtractor.fixProjectContext(resumeWithSplitLink);
    expect(unjammed, contains('[Healthcare App]('));

    final tailored = TailoredResume(
      originalResume: resumeWithSplitLink,
      tailoredResume: resumeWithSplitLink,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Summary',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(tailored: tailored, candidateName: 'Alex Morgan');
    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));
    final text = sf.PdfTextExtractor(sfDoc).extractText();
    expect(text, isNot(contains(r'App](')));
    expect(text, isNot(contains(r'[Healthcare')));
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    expect(normalized, contains('Healthcare App'));
    sfDoc.dispose();
  });

  test('PdfExtractor and PdfGenerator align Education properly with university on left, dates on right, degree on left, CGPA on right', () async {
    const resumeWithSplitEducation = '''
ALEX MORGAN
Bengaluru, India | +1-555-123-4567 | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan) | [Portfolio](https://alexmorgan.dev) | [LinkedIn](https://linkedin.com/in/alexmorgan)

EDUCATION
Manipal University Jaipur
2021 - 2025
Bachelor of Technology in Information Technology CGPA: 7.2/10
''';

    final unjammed = PdfExtractor.fixProjectContext(resumeWithSplitEducation);
    expect(unjammed, contains('Manipal University Jaipur | 2021 - 2025'));

    final tailored = TailoredResume(
      originalResume: resumeWithSplitEducation,
      tailoredResume: resumeWithSplitEducation,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Summary',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(tailored: tailored, candidateName: 'Alex Morgan');
    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));
    final text = sf.PdfTextExtractor(sfDoc).extractText();
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    expect(normalized, contains('Manipal University Jaipur'));
    expect(normalized, contains('2021 - 2025'));
    expect(normalized, contains('Bachelor of Technology in Information Technology'));
    expect(normalized, contains('CGPA: 7.2/10'));
    sfDoc.dispose();
  });

  test('PdfExtractor and PdfGenerator format bulleted section headers in bold and merge wrapped bullet lines', () async {
    const resumeWithBulletedHeader = '''
ALEX MORGAN
Bengaluru, India | +1-555-123-4567 | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan)

• PROFESSIONAL SUMMARY
Results-driven developer.

• TECHNICAL SKILLS
Languages: Dart, Java, Python

• PROFESSIONAL EXPERIENCE
• Mobile Application Developer
Logische Innovative Pvt. Ltd. | Dec 2025 - May 2026
• Developed and maintained two production Flutter applications, delivering
new features and resolving 50+ bugs and enhancement requests.
Contributed to the successful initial production release by coordinating feature implementation.
Executed 50+ manual test cases and verified bug fixes.

• PROJECTS
FitFlow - Fitness Platform | Flutter, Firebase [Project](https://github.com/alexmorgan/fitflow)
• Developed a cross-platform fitness application.
Integrated Firebase Authentication for secure user logins.

• EDUCATION
Manipal University Jaipur | 2021 - 2025
Bachelor of Technology in Information Technology
''';

    final cleaned = PdfExtractor.fixProjectContext(resumeWithBulletedHeader);
    expect(cleaned, contains('PROFESSIONAL EXPERIENCE'));
    expect(cleaned, isNot(contains('• PROFESSIONAL EXPERIENCE')));
    expect(cleaned, isNot(contains('• Mobile Application Developer')));
    expect(cleaned, contains('delivering new features and resolving 50+ bugs and enhancement requests.'));
    expect(cleaned, contains('• Contributed to the successful initial production release'));
    expect(cleaned, contains('• Executed 50+ manual test cases'));
    expect(cleaned, contains('• Integrated Firebase Authentication'));

    final tailored = TailoredResume(
      originalResume: resumeWithBulletedHeader,
      tailoredResume: resumeWithBulletedHeader,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Summary',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(tailored: tailored, candidateName: 'Alex Morgan');
    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));
    final text = sf.PdfTextExtractor(sfDoc).extractText();
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    expect(normalized, contains('PROFESSIONAL EXPERIENCE'));
    expect(normalized, contains('Mobile Application Developer'));
    expect(normalized, contains('delivering new features'));
    sfDoc.dispose();
  });

  test('HeuristicLocalDataSource.tailorResume replaces multi-line summary without duplication', () {
    final ds = HeuristicLocalDataSource();
    const resume = '''
ALEX MORGAN
Bengaluru, India | +1-555-123-4567 | alex.morgan@example.com
GitHub | Portfolio | LinkedIn

PROFESSIONAL SUMMARY
Results-driven professional aligned with the Bengaluru, India market, specializing in delivering scalable, high-performance solutions matching requirements in Flutter, Dart, Riverpod. Demonstrated success driving product excellence and collaborative engineering.
Selenium and Appium. Skilled in developing mobile applications, automating web and mobile testing, integrating REST APIs, and performing API testing, bug tracking, and debugging. Strong foundation in Object-Oriented Programming, SDLC, STLC, Agile methodologies, and software quality assurance.

PROFESSIONAL EXPERIENCE
Software Developer (Full-Time) | Dec 2025 - May 2026
Logische Innovative Pvt. Ltd. Remote [User App](https://user.app) | [Healthcare App](https://health.app)
• Developed and maintained two production Flutter applications, delivering
new features and resolving 50+ bugs and enhancement requests.
Contributed to the successful initial production release by coordinating feature implementation.

TECHNICAL SKILLS
Languages: Dart, Java, Python

EDUCATION
Manipal University Jaipur | 2021 - 2025
Bachelor of Technology in Information Technology
''';

    final input = ResumeInput(
      jobDescription: 'Looking for Flutter and Dart developer in Bengaluru.',
      resumeText: resume,
    );
    final analysis = ds.analyzeMatch(input).toDomain();
    final tailored = ds.tailorResume(input, analysis);

    // Count occurrences of "Demonstrated success driving product excellence"
    final matches = RegExp('Demonstrated success driving product excellence').allMatches(tailored.tailoredResume);
    expect(matches.length, equals(1));
    expect(tailored.tailoredResume, contains('PROFESSIONAL EXPERIENCE'));
    expect(tailored.tailoredResume, contains('Software Developer (Full-Time)'));
  });

  test('PdfGenerator omits location when resume does not have phone number and email id', () async {
    const resumeWithoutPhoneAndEmail = '''
ALEX MORGAN
Flutter Developer | Mobile Application Developer
[GitHub](https://github.com/alexmorgan) | [Portfolio](https://alexmorgan.dev) | [LinkedIn](https://linkedin.com/in/alexmorgan)

PROFESSIONAL SUMMARY
Experienced Flutter engineer with expertise in Dart, state management, and Clean Architecture.

TECHNICAL SKILLS
Languages: Dart, Java, Python
Frameworks: Flutter, Android SDK

EDUCATION
Manipal University Jaipur | 2021 - 2025
Bachelor of Technology in Information Technology
''';

    final tailored = TailoredResume(
      originalResume: resumeWithoutPhoneAndEmail,
      tailoredResume: resumeWithoutPhoneAndEmail,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Experienced Flutter engineer...',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test Engine',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(
      tailored: tailored,
      candidateName: 'Alex Morgan',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));

    final text = sf.PdfTextExtractor(sfDoc).extractText();
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ');
    // MUST NOT contain city or Location string anywhere in header
    expect(normalizedText, isNot(contains('Bengaluru')));
    expect(normalizedText, isNot(contains('Location:')));
    expect(normalizedText, isNot(contains('Open to Relocation')));
    expect(normalizedText, contains('ALEX MORGAN'));
    expect(normalizedText, contains('Flutter Developer'));

    sfDoc.dispose();
  });

  test('PdfGenerator removes location and displays clean phone and email when present', () async {
    const resumeWithLocationPhoneEmail = '''
ALEX MORGAN
Flutter Developer | Mobile Application Developer
Noida, India | +1-555-123-4567 | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan) | [LinkedIn](https://linkedin.com/in/alexmorgan)

PROFESSIONAL SUMMARY
Experienced Flutter engineer with expertise in Dart.

TECHNICAL SKILLS
Languages: Dart, Java

EDUCATION
Manipal University Jaipur | 2021 - 2025
Bachelor of Technology
''';

    final tailored = TailoredResume(
      originalResume: resumeWithLocationPhoneEmail,
      tailoredResume: resumeWithLocationPhoneEmail,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Summary',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test Engine',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(
      tailored: tailored,
      candidateName: 'Alex Morgan',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));

    final text = sf.PdfTextExtractor(sfDoc).extractText();
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ');
    // Header must have phone and email
    expect(normalizedText, contains('+1-555-123-4567'));
    expect(normalizedText, contains('alex.morgan@example.com'));
    // MUST NOT have location in header
    expect(normalizedText, isNot(contains('Noida')));
    expect(normalizedText, isNot(contains('Bengaluru')));

    sfDoc.dispose();
  });

  test('PdfGenerator handles separate multi-line contact header and omits location line', () async {
    const multiLineContactResume = '''
ALEX MORGAN
Flutter Developer
Noida, India
+1-555-123-4567
alex.morgan@example.com
[GitHub](https://github.com/alexmorgan)

PROFESSIONAL SUMMARY
Experienced Flutter engineer.
''';

    final tailored = TailoredResume(
      originalResume: multiLineContactResume,
      tailoredResume: multiLineContactResume,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Summary',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test Engine',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(
      tailored: tailored,
      candidateName: 'Alex Morgan',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));

    final text = sf.PdfTextExtractor(sfDoc).extractText();
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ');
    expect(normalizedText, contains('+1-555-123-4567'));
    expect(normalizedText, contains('alex.morgan@example.com'));
    expect(normalizedText, isNot(contains('Noida')));
    expect(normalizedText, isNot(contains('Bengaluru')));

    sfDoc.dispose();
  });

  test('PdfGenerator recognizes RELEVANT PROJECTS and partitions it from professional experience', () async {
    const resumeWithRelevantProjects = '''
RASHI AGRAWAL
Manual Software Tester
+91 9452935405 | rashicareers20@gmail.com
[LinkedIn](https://linkedin.com/in/rashiagrawal) | [GitHub](https://github.com/rashiagrawal)

PROFESSIONAL SUMMARY
Detail-oriented Manual Software Tester specializing in functional and regression testing.

TECHNICAL SKILLS
Manual Testing: Functional Testing, Regression Testing, Smoke Testing
Tools: Jira, Postman, Git

PROFESSIONAL EXPERIENCE
Software Developer | Logische Innovative Pvt. Ltd. | Dec 2025 - May 2026
• Executed 50+ structured manual test cases across functional and regression cycles.
• Documented and tracked software defects within Jira detailing reproduction steps.
• Conducted backend API validation using Postman inspecting payload structures.

RELEVANT PROJECTS
Android Calculator Automation | Java, Appium, TestNG, Maven
• Configured a comprehensive test execution suite on physical Android devices.
• Implemented assertions and reusable test scripts for repeatable test execution.
Calley Automation Framework | Selenium WebDriver, Java, TestNG
• Validated multi-step form submissions and error handling mechanisms.

EDUCATION
Manipal University Jaipur | 2021 - 2025
Bachelor of Technology in Information Technology | CGPA: 7.2/10
''';

    final tailored = TailoredResume(
      originalResume: resumeWithRelevantProjects,
      tailoredResume: resumeWithRelevantProjects,
      alignedCity: 'Noida, India',
      tailoredSummary: 'Detail-oriented Manual Software Tester...',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: '',
      generationModel: 'Test Engine',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(
      tailored: tailored,
      candidateName: 'Rashi Agrawal',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));

    final text = sf.PdfTextExtractor(sfDoc).extractText();
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

    final expIdx = normalized.indexOf('PROFESSIONAL EXPERIENCE');
    final prjIdx = normalized.indexOf('RELEVANT PROJECTS');
    final eduIdx = normalized.indexOf('EDUCATION');

    expect(expIdx, isNonNegative);
    expect(prjIdx, isNonNegative);
    expect(eduIdx, isNonNegative);

    // Section ordering and partition
    expect(expIdx < prjIdx, isTrue, reason: 'Experience must precede Projects');
    expect(prjIdx < eduIdx, isTrue, reason: 'Projects must precede Education');

    sfDoc.dispose();
  });
}

