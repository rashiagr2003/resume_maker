import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_extractor.dart';
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';

List<String> _extractAnnotationUrls(sf.PdfPage page) {
  final urls = <String>[];
  for (int i = 0; i < page.annotations.count; i++) {
    final ann = page.annotations[i];
    if (ann is sf.PdfUriAnnotation) {
      urls.add(ann.uri);
    } else if (ann is sf.PdfTextWebLink) {
      urls.add(ann.url);
    }
  }
  return urls;
}

void main() {
  group('Dynamic Link Extraction & Rendering Suite (Zero Hardcoded Links)', () {
    test('Candidate with only LinkedIn generates PDF with only LinkedIn link', () async {
      const candidateResume = '''
JANE DOE
US IT Recruiter
jane.doe@recruitment.com | +1 555-0192
LinkedIn: linkedin.com/in/janedoe-recruiter

PROFESSIONAL SUMMARY
Experienced IT Recruiter with 3 years of talent sourcing expertise.

TECHNICAL SKILLS
Core Competencies: Candidate Sourcing, Cold Calling, Technical Screening
ATS & Tools: LinkedIn Recruiter, Bullhorn, Monster

PROFESSIONAL EXPERIENCE
Senior Technical Recruiter
Apex Systems | 2022 - Present
• Sourced, screened, and placed over 50 software engineers.

EDUCATION
B.A. in Human Resources | 2018 - 2022
University of Texas
''';

      final tailored = TailoredResume(
        originalResume: candidateResume,
        tailoredResume: candidateResume,
        alignedCity: 'Austin, TX',
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
        candidateName: 'Jane Doe',
      );

      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      final text = sf.PdfTextExtractor(sfDoc).extractText();
      final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

      // Verify candidate info is used
      expect(normalized, contains('JANE DOE'));
      expect(normalized, contains('jane.doe@recruitment.com'));
      expect(normalized, contains('LinkedIn'));

      // Check annotations
      final urls = _extractAnnotationUrls(sfDoc.pages[0]);

      expect(urls.any((u) => u.contains('linkedin.com/in/janedoe-recruiter')), isTrue);
      // STRICT: Must NOT have GitHub or Portfolio or hardcoded URLs
      expect(urls.any((u) => u.contains('rashiagrawal')), isFalse);
      expect(urls.any((u) => u.contains('portfolio.dev')), isFalse);
      expect(urls.any((u) => u.contains('github.com')), isFalse);

      sfDoc.dispose();
    });

    test('Candidate with only GitHub generates PDF with only GitHub link', () async {
      const candidateResume = '''
ALEX DEV
Backend Engineer
alex@backend.io | +1 415-555-8833
GitHub: github.com/alex-backend-pro

PROFESSIONAL SUMMARY
Backend developer specializing in Go and distributed systems.

TECHNICAL SKILLS
Languages: Go, Python, SQL
Infrastructure: Docker, Kubernetes, AWS

PROFESSIONAL EXPERIENCE
Backend Engineer
CloudTech | 2023 - Present
• Built high-throughput microservices.

EDUCATION
B.S. in Computer Science | 2019 - 2023
''';

      final tailored = TailoredResume(
        originalResume: candidateResume,
        tailoredResume: candidateResume,
        alignedCity: 'San Francisco, CA',
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
        candidateName: 'Alex Dev',
      );

      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      final urls = _extractAnnotationUrls(sfDoc.pages[0]);

      expect(urls.any((u) => u.contains('github.com/alex-backend-pro')), isTrue);
      expect(urls.any((u) => u.contains('rashiagrawal')), isFalse);
      expect(urls.any((u) => u.contains('portfolio.dev')), isFalse);
      expect(urls.any((u) => u.contains('linkedin.com')), isFalse);

      sfDoc.dispose();
    });

    test('Candidate with custom personal portfolio uses candidate link and no defaults', () async {
      const candidateResume = '''
SAMUEL GREEN
UI/UX Designer & Frontend Developer
sam@greendesign.tech | +44 7700 900077
Portfolio: https://samuelgreen.design | LinkedIn: linkedin.com/in/samuel-green-design

PROFESSIONAL SUMMARY
Product designer and frontend developer creating responsive user interfaces.

TECHNICAL SKILLS
Design: Figma, Design Systems, Wireframing
Frontend: React, Tailwind CSS, TypeScript

PROFESSIONAL EXPERIENCE
Senior Product Designer
Studio Studio | 2021 - Present
• Led design team for fintech mobile app.

EDUCATION
B.A. in Graphic Design | 2017 - 2021
''';

      final tailored = TailoredResume(
        originalResume: candidateResume,
        tailoredResume: candidateResume,
        alignedCity: 'London, UK',
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
        candidateName: 'Samuel Green',
      );

      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      final urls = _extractAnnotationUrls(sfDoc.pages[0]);

      expect(urls.any((u) => u.contains('samuelgreen.design')), isTrue);
      expect(urls.any((u) => u.contains('linkedin.com/in/samuel-green-design')), isTrue);
      expect(urls.any((u) => u.contains('rashiagrawal')), isFalse);
      expect(urls.any((u) => u.contains('portfolio.dev')), isFalse);

      sfDoc.dispose();
    });

    test('PdfExtractor extracts plain text candidate links without injecting author defaults', () {
      const extractedResume = '''
MICHAEL SCOTT
Branch Manager
mscott@dundermifflin.com | +1 570-555-0100
LinkedIn: linkedin.com/in/michael-scott-mgmt

PROFESSIONAL SUMMARY
Experienced Regional Manager.
''';

      final result = PdfExtractor.extractText(Uint8List.fromList(extractedResume.codeUnits));

      // Must format candidate's actual LinkedIn
      expect(result, contains('[LinkedIn](https://linkedin.com/in/michael-scott-mgmt)'));
      // Must NOT contain author's GitHub or portfolio.dev
      expect(result, isNot(contains('rashiagrawal')));
      expect(result, isNot(contains('portfolio.dev')));
      expect(result, isNot(contains('[GitHub]')));
      expect(result, isNot(contains('[Portfolio]')));
    });

    test('Project with word link but no URL in resume does not inject fallback GitHub URL', () async {
      const candidateResume = '''
DAVID MILLER
Full Stack Developer
david@miller.dev | +1 212-555-0144

PROFESSIONAL SUMMARY
Developer with project experience.

PROJECTS
Inventory Management System | Node.js, React Project
• Built internal stock tracking tool.

EDUCATION
B.S. Software Engineering | 2020 - 2024
''';

      final tailored = TailoredResume(
        originalResume: candidateResume,
        tailoredResume: candidateResume,
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
        candidateName: 'David Miller',
      );

      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      final urls = _extractAnnotationUrls(sfDoc.pages[0]);

      // No fake project URL should be present
      expect(urls.any((u) => u.contains('rashiagrawal')), isFalse);

      sfDoc.dispose();
    });
  });
}
