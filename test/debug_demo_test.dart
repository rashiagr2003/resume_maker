import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_generator.dart';
import 'package:resume_maker/core/utils/pdf_extractor.dart';
import 'package:resume_maker/domain/entities/tailored_resume.dart';

import 'package:resume_maker/core/constants/sample_data.dart';

void main() {
  test('Test sampleResumeHighMatch', () async {
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
    print('PAGE COUNT: ${sfDoc.pages.count}');
    final text = sf.PdfTextExtractor(sfDoc).extractText();
    print('EXTRACTED:\n$text');
    expect(sfDoc.pages.count, equals(1));
  });
}
