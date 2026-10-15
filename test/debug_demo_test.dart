import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_extractor.dart';
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';

void main() {
  test('Test _mergeRemainingLinks with demo links', () async {
    const raw = '''
PROJECTS
CareerAssistant-Career&ProductivityApp | Flutter, Riverpod [Demo](https://drive.google.com/drive/folders/1RcHTc8m51iyusnl8xN6gGgiVaSX0hPKF?usp=sharing)
SproutKids-AI-PoweredLearningApp | Flutter, Python (FastAPI), Groq API
[Demo](https://www.linkedin.com/posts/developer-showcase-flutter-fastapi-activity-123456789)
FitFlow-Fitness&WellnessApp | Flutter, Firebase, Riverpod
[Demo](https://www.linkedin.com/posts/developer-showcase-fitness-app-activity-987654321)
''';

    final urls = [
      'https://linkedin.com/in/alexmorgan',
      'https://github.com/alexmorgan',
      'https://alexmorgan.dev',
      'https://drive.google.com/drive/folders/1RcHTc8m51iyusnl8xN6gGgiVaSX0hPKF?usp=sharing',
      'https://www.linkedin.com/posts/developer-showcase-flutter-fastapi-activity-123456789',
      'https://www.linkedin.com/posts/developer-showcase-fitness-app-activity-987654321',
    ];

    final tailored = TailoredResume(
      originalResume: 'ALEX MORGAN\n+1 555-0149\nalex.morgan@example.com',
      tailoredResume: 'ALEX MORGAN\n+1 555-0149\nalex.morgan@example.com',
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
    final text = sf.PdfTextExtractor(sfDoc).extractText();
    print('DEBUG EXTRACTED: "$text"');
  });
}
