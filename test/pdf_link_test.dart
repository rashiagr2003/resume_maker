import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:resume_maker/core/utils/pdf_extractor.dart';

void main() {
  test('PdfExtractor extracts text and captures hyperlinked URLs', () async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Text('ALEX MORGAN'),
            pw.UrlLink(
              destination: 'https://github.com/alexmorgan',
              child: pw.Text('GitHub Profile'),
            ),
            pw.UrlLink(
              destination: 'https://linkedin.com/in/alexmorgan',
              child: pw.Text('LinkedIn Profile'),
            ),
            pw.UrlLink(
              destination: 'mailto:alex.morgan@example.com',
              child: pw.Text('Email Me'),
            ),
          ],
        ),
      ),
    );

    final Uint8List bytes = await pdf.save();
    final result = PdfExtractor.extractText(bytes);

    expect(result, contains('ALEX MORGAN'));
    expect(result, contains('github.com/alexmorgan'));
    expect(result, contains('linkedin.com/in/alexmorgan'));
    expect(result, contains('alex.morgan@example.com'));
  });
}
