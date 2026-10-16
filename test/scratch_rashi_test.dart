import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';

void main() {
  test('Verify Rashi resume covers whole A4 page', () async {
    const resumeText = '''RASHI AGRAWAL
Microsoft Dynamics Consultant
+91-9452935405 | rashicareers20@gmail.com
GitHub: https://github.com/rashiagr2003 | Portfolio: https://rashiagr2003.github.io | LinkedIn: https://linkedin.com/in/rashiagrawal

PROFESSIONAL SUMMARY
High-performing, target-oriented Microsoft Dynamics Consultant aligned with the Remote / Flexible market, with proven expertise in Salesforce. Adept at managing client pipelines, driving engagement, and exceeding operational goals.

TECHNICAL SKILLS
Programming Languages: Java, Dart, SQL, Python
Software Development: Flutter, Firebase, REST APIs, Dio, JSON Parsing, Android SDK, Clean Architecture
Automation Testing: Selenium WebDriver, Appium, TestNG, Maven, POM
Manual Testing: Functional, Regression, Smoke, Sanity, API Testing, Test Case Design, Jira, Defect Lifecycle
Databases: MySQL, Firebase Realtime Database
Tools: Git, GitHub, Postman, Android Studio, VS Code, Appium Inspector, Figma
Core Concepts: OOP, SDLC, STLC, Agile, Debugging, Bug Tracking, Software Quality Assurance
Data Analytics: Power BI, Tableau, Excel, Data Cleaning, Data Visualization, Dashboard Development
Salesforce (Intermediate)

PROFESSIONAL EXPERIENCE
Software Developer (Full-Time) | Dec 2025 - May 2026
Logische Innovative Pvt. Ltd. | Remote
BookEHealth User App | Healthcare App
• Developed and maintained two production Flutter applications, implementing features and resolving 50+ bugs and enhancement requests.
• Contributed to the initial production release by coordinating feature implementation, resolving development issues, and delivering project milestones on schedule.
• Integrated 15+ RESTful APIs using Dio, with structured error handling and state management to support reliable application data flow.

PROJECTS
FitFlow-Fitness & Wellness Platform Flutter, Firebase, Riverpod | Project
• Developed a cross-platform fitness application with workout tracking, calorie management, hydration reminders, and task management features.
• Integrated Firebase Authentication, Realtime Database, and Firebase Cloud Messaging for authentication, data management, and notifications.

Android Calculator Automation Java, Appium, TestNG, Maven | Project
• Developed a mobile automation framework for the Android Calculator application using Appium and Java.
• Executed automated test cases on a real Android device using TestNG, Maven, and the Page Object Model (POM).

Calley Automation Framework Java, Selenium WebDriver, TestNG, Maven | Project
• Built a Selenium WebDriver framework for end-to-end testing of the Calley web application.
• Automated user registration, login, profile setup, and workflow validation using the Page Object Model (POM).

HR Analytics Dashboard Tableau | Project Link
• Created an interactive dashboard to analyze workforce metrics, employee demographics, attrition trends, and department-wise workforce distribution.

E | Commerce Sales Analysis Dashboard Power BI | Project Link
• Developed an interactive dashboard with KPI cards, charts, slicers, and filters to analyze sales performance, revenue trends, and business metrics.

EDUCATION
Manipal University Jaipur | 2021 - 2025
Bachelor of Technology in Information Technology | CGPA: 7.2/10
''';

    final tailored = TailoredResume(
      originalResume: resumeText,
      tailoredResume: resumeText,
      alignedCity: 'Remote',
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
      candidateName: 'Rashi Agrawal',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    expect(sfDoc.pages.count, equals(1));
    final page = sfDoc.pages[0];
    final extractor = sf.PdfTextExtractor(sfDoc);
    final textLines = extractor.extractTextLines();
    final lastLine = textLines.last;
    print('Rashi Agrawal:');
    print('Total text lines: ${textLines.length}');
    print('First line: "${textLines.first.text}" at y=${textLines.first.bounds.top}');
    print('Last line: "${lastLine.text}" at y=${lastLine.bounds.top}, bottom=${lastLine.bounds.bottom}');
    print('Total page height: ${page.size.height}');
    print('Remaining white space at bottom: ${page.size.height - lastLine.bounds.bottom} pt');
    print('Fraction of page covered: ${(lastLine.bounds.bottom / page.size.height * 100).toStringAsFixed(1)}%');
    
    expect(lastLine.bounds.bottom / page.size.height, greaterThan(0.92));
    expect(lastLine.text, contains('Bachelor of Technology'));
    sfDoc.dispose();
  });

  test('Verify Alex Morgan concise resume covers whole A4 page', () async {
    const conciseResume = '''ALEX MORGAN
Senior Mobile Developer
alex.morgan@tech.dev | +1 (555) 019-2834
GitHub: github.com/alex-morgan | LinkedIn: linkedin.com/in/alex-morgan-dev | Portfolio: alexmorgan.dev

PROFESSIONAL SUMMARY
Results-driven Mobile Engineer with 5+ years of experience architecting scalable Flutter and native Android applications. Proven track record of improving app performance by 35% and mentoring junior engineers.

TECHNICAL SKILLS
Languages: Dart, Kotlin, Java, Swift, Python
Frameworks & State Management: Flutter, BLoC, Riverpod, Provider, Jetpack Compose
Cloud & Architecture: Firebase, AWS, Clean Architecture, REST APIs, GraphQL

PROFESSIONAL EXPERIENCE
Senior Flutter Engineer | 2022 - Present
Apex Tech Solutions
• Architected enterprise mobile banking application serving over 500,000 monthly active users.
• Reduced app startup latency by 42% through optimized dependency injection and deferred widget loading.
• Spearheaded migration from legacy state management to Riverpod with 99.9% crash-free sessions.

Mobile Developer | 2020 - 2022
Innovate Mobility Labs
• Engineered 4 cross-platform client applications from conception to production release on Google Play.
• Integrated secure biometric authentication, offline-first SQLite caching, and real-time push notifications.

PROJECTS
FinTrack Expense Manager | Flutter, SQLite, Charts | 2024
• Open-source budget tracking app with encrypted local storage and customizable analytics dashboards.

EDUCATION
Bachelor of Science in Computer Science | 2016 - 2020
University of Washington | CGPA: 3.8/4.0
''';

    final tailored = TailoredResume(
      originalResume: conciseResume,
      tailoredResume: conciseResume,
      alignedCity: 'Seattle, WA',
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
    final page = sfDoc.pages[0];
    final extractor = sf.PdfTextExtractor(sfDoc);
    final textLines = extractor.extractTextLines();
    final lastLine = textLines.last;
    print('Alex Morgan:');
    print('Total text lines: ${textLines.length}');
    print('Last line: "${lastLine.text}" bottom=${lastLine.bounds.bottom}');
    print('Remaining white space at bottom: ${page.size.height - lastLine.bounds.bottom} pt');
    print('Fraction of page covered: ${(lastLine.bounds.bottom / page.size.height * 100).toStringAsFixed(1)}%');

    expect(lastLine.bounds.bottom / page.size.height, greaterThan(0.90));
    sfDoc.dispose();
  });
}
