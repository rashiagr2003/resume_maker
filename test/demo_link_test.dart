import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';

void main() {
  test('Check if project demo links become PDF annotations', () async {
    const resumeText = '''
ALEX MORGAN
Flutter Developer | Mobile Application Developer
Bengaluru, India | +91 98765 43210 | alex.morgan@example.com
[GitHub](https://github.com/alexmorgan) | [LinkedIn](https://linkedin.com/in/alexmorgan)

PROFESSIONAL SUMMARY
Experienced Flutter engineer.

TECHNICAL SKILLS
Languages: Dart, Java, SQL, Python

PROFESSIONAL EXPERIENCE
Mobile Application Developer
Logische Innovative Pvt. Ltd. | Dec 2025 - May 2026
• Developed Flutter applications.

PROJECTS
Career Assistant | Flutter, Riverpod [Demo](https://drive.google.com/drive/folders/12345)
• Built productivity app.
Sprout Kids | Flutter, Python [Demo](https://www.linkedin.com/posts/demo123)
• Built AI app.
FitFlow | Flutter, Firebase [Demo](https://www.linkedin.com/posts/fitflow123)
• Built fitness app.

EDUCATION
B.Tech | 2021 - 2025
''';

    final tailored = TailoredResume(
      originalResume: resumeText,
      tailoredResume: resumeText,
      alignedCity: 'Bengaluru, India',
      tailoredSummary: 'Summary',
      addedKeywords: [],
      modifiedSections: [],
      cityAlignmentNote: 'Note',
      generationModel: 'Model',
      timestamp: DateTime.now(),
      targetPages: 1,
    );

    final bytes = await PdfGenerator.generatePdfBytes(
      tailored: tailored,
      candidateName: 'Alex Morgan',
    );

    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    print('Total annotations on page 0: ${sfDoc.pages[0].annotations.count}');
    for (int i = 0; i < sfDoc.pages[0].annotations.count; i++) {
      final ann = sfDoc.pages[0].annotations[i];
      if (ann is sf.PdfTextWebLink) {
        print('  WebLink $i: url=${ann.url}, bounds=${ann.bounds}');
      } else if (ann is sf.PdfUriAnnotation) {
        print('  UriAnnotation $i: uri=${ann.uri}, bounds=${ann.bounds}');
      } else {
        print('  Annotation $i: type=${ann.runtimeType}');
      }
    }
    sfDoc.dispose();
  });
}
