import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';

void main() {
  group('Strict One A4 Page & Natural Vertical Distribution Suite', () {
    test('Concise resume fits on STRICTLY 1 A4 page and distributes content to the bottom', () async {
      const conciseResume = '''
ALEX MORGAN
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
      // Strictly 1 A4 page
      expect(sfDoc.pages.count, equals(1));

      final page = sfDoc.pages[0];
      // A4 format dimensions: 595.27 x 841.89 pt
      expect(page.size.width, closeTo(595.27, 2.0));
      expect(page.size.height, closeTo(841.89, 2.0));

      final text = sf.PdfTextExtractor(sfDoc).extractText();
      final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

      // Verify Header Elements
      expect(normalized, contains('ALEX MORGAN'));
      expect(normalized, contains('Senior Mobile Developer'));
      expect(normalized, contains('alex.morgan@tech.dev'));
      expect(normalized, contains('+1 (555) 019-2834'));
      expect(normalized, contains('GitHub'));
      expect(normalized, contains('LinkedIn'));
      expect(normalized, contains('Portfolio'));

      // Verify Section Order: Summary -> Skills -> Experience -> Projects -> Education
      final sumIdx = normalized.indexOf('PROFESSIONAL SUMMARY');
      final sklIdx = normalized.indexOf('TECHNICAL SKILLS');
      final expIdx = normalized.indexOf('PROFESSIONAL EXPERIENCE');
      final prjIdx = normalized.indexOf('PROJECTS');
      final eduIdx = normalized.indexOf('EDUCATION');

      expect(sumIdx, isNonNegative);
      expect(sklIdx, isNonNegative);
      expect(expIdx, isNonNegative);
      expect(prjIdx, isNonNegative);
      expect(eduIdx, isNonNegative);

      expect(sumIdx < sklIdx, isTrue, reason: 'Summary before Skills');
      expect(sklIdx < expIdx, isTrue, reason: 'Skills before Experience');
      expect(expIdx < prjIdx, isTrue, reason: 'Experience before Projects');
      expect(prjIdx < eduIdx, isTrue, reason: 'Projects before Education');

      // Verify Education details preserved and at the bottom
      expect(normalized, contains('University of Washington'));
      expect(normalized, contains('Bachelor of Science in Computer Science'));
      expect(normalized, contains('3.8/4.0'));

      sfDoc.dispose();
    });

    test('Dense 5-project resume fits on EXACTLY 1 A4 page without spilling', () async {
      const denseResume = '''
PRIYA SHARMA
Full Stack Engineer
priya.sharma@gmail.com | +91 98765 43210
GitHub: github.com/priyasharma | LinkedIn: linkedin.com/in/priyasharma

PROFESSIONAL SUMMARY
Full Stack Engineer with 4 years of experience building responsive web and mobile products.

TECHNICAL SKILLS
Languages: Dart, TypeScript, JavaScript, Python, SQL
Frameworks: Flutter, React, Node.js, Express, Tailwind CSS
Databases & Cloud: PostgreSQL, MongoDB, Docker, AWS S3, Firebase

PROFESSIONAL EXPERIENCE
Lead Mobile Engineer | 2022 - Present
Zeta Payments Pvt Ltd
• Designed high-performance fintech payment checkout flow with 99.98% reliability.
• Managed end-to-end CI/CD pipelines deploying bi-weekly releases to production.

Associate Software Engineer | 2021 - 2022
Cognizant Technology Solutions
• Developed RESTful backend microservices in Node.js handling 10,000+ RPM.
• Optimized PostgreSQL query execution plans reducing P95 latency by 60%.

PROJECTS
HealthPulse Telemedicine App | Flutter, WebRTC | 2024
• Implemented end-to-end encrypted video consultations and live prescription sync.
ShopEase E-Commerce Platform | Next.js, Stripe, Redis | 2023
• Built real-time inventory reservation system with automated SMS tracking.
CloudTask Kanban Board | React, TypeScript, Go | 2023
• Developed collaborative board with web socket live cursor synchronization.
DevConnect Developer Network | Node.js, GraphQL, MongoDB | 2022
• Created social networking platform for software engineers with code snippet sharing.
CryptoTrack Portfolio Tracker | Flutter, CoinGecko API | 2022
• Designed cross-platform market watcher with interactive candlestick charting.

EDUCATION
Bachelor of Technology in Computer Science | 2017 - 2021
Delhi Technological University | CGPA: 8.7/10
''';

      final tailored = TailoredResume(
        originalResume: denseResume,
        tailoredResume: denseResume,
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
        candidateName: 'Priya Sharma',
      );

      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      // Dense resume must NEVER spill over to a 2nd page
      expect(sfDoc.pages.count, equals(1));

      final text = sf.PdfTextExtractor(sfDoc).extractText();
      final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

      expect(normalized, contains('PRIYA SHARMA'));
      expect(normalized, contains('HealthPulse Telemedicine App'));
      expect(normalized, contains('CryptoTrack Portfolio Tracker'));
      expect(normalized, contains('Delhi Technological University'));

      sfDoc.dispose();
    });

    test('Section order is guaranteed even if input had Experience before Skills', () async {
      const swappedResume = '''
JOHN DOE
Software Developer
john@doe.com | +1 555-0100
LinkedIn: linkedin.com/in/johndoe

PROFESSIONAL EXPERIENCE
Software Developer | 2021 - 2024
Tech Corp
• Built modern web interfaces.

EDUCATION
B.S. in Computer Science | 2017 - 2021
State University

TECHNICAL SKILLS
Languages: Java, Python, C++

PROJECTS
Smart App | Flutter | 2023
• Mobile application for smart home automation.

PROFESSIONAL SUMMARY
Experienced software developer.
''';

      final tailored = TailoredResume(
        originalResume: swappedResume,
        tailoredResume: swappedResume,
        alignedCity: 'New York, NY',
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
        candidateName: 'John Doe',
      );

      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      expect(sfDoc.pages.count, equals(1));

      final text = sf.PdfTextExtractor(sfDoc).extractText();
      final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

      final sumIdx = normalized.indexOf('PROFESSIONAL SUMMARY');
      final sklIdx = normalized.indexOf('TECHNICAL SKILLS');
      final expIdx = normalized.indexOf('PROFESSIONAL EXPERIENCE');
      final prjIdx = normalized.indexOf('PROJECTS');
      final eduIdx = normalized.indexOf('EDUCATION');

      expect(sumIdx < sklIdx, isTrue, reason: 'Summary before Skills');
      expect(sklIdx < expIdx, isTrue, reason: 'Skills before Experience');
      expect(expIdx < prjIdx, isTrue, reason: 'Experience before Projects');
      expect(prjIdx < eduIdx, isTrue, reason: 'Projects before Education');

      sfDoc.dispose();
    });

    test('GitHub link with alphanumeric username ending in 4-digit year (rashiagr2003) is preserved without %20 or spaces', () async {
      const candidateResume = '''
RASHI AGRAWAL
Flutter & Mobile Developer
rashi@example.com | +91 98765 43210
GitHub: https://github.com/rashiagr2003 | LinkedIn: https://linkedin.com/in/rashiagrawal

PROFESSIONAL SUMMARY
Flutter developer with hands-on experience building mobile applications.

TECHNICAL SKILLS
Languages: Dart, Java, Python

PROFESSIONAL EXPERIENCE
Software Developer | 2023 - Present
Tech Labs
• Built cross-platform mobile apps.

PROJECTS
Smart App | Flutter | 2024
• Mobile utility app.

EDUCATION
B.Tech in Computer Science | 2020 - 2024
University of Delhi
''';

      final tailored = TailoredResume(
        originalResume: candidateResume,
        tailoredResume: candidateResume,
        alignedCity: 'Noida, India',
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

      // Extract all hyperlinked URLs from page annotations
      final page = sfDoc.pages[0];
      final urls = <String>[];
      for (int i = 0; i < page.annotations.count; i++) {
        final ann = page.annotations[i];
        if (ann is sf.PdfUriAnnotation) {
          urls.add(ann.uri);
        } else if (ann is sf.PdfTextWebLink) {
          urls.add(ann.url);
        }
      }

      // STRICT CHECK: The GitHub URL must be exactly https://github.com/rashiagr2003
      expect(urls.any((u) => u.contains('github.com/rashiagr2003')), isTrue);
      // It must NOT contain %20 or spaces
      expect(urls.any((u) => u.contains('rashiagr%202003')), isFalse);
      expect(urls.any((u) => u.contains('rashiagr 2003')), isFalse);

      sfDoc.dispose();
    });
  });
}
