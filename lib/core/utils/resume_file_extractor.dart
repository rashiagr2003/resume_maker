import 'dart:convert';
import 'package:archive/archive.dart';
import 'pdf_extractor.dart';

class ResumeExtractionResult {
  final String text;
  final String fileName;
  final String fileType; // 'pdf', 'docx', 'txt'
  final int fileSize;
  final bool isSuccess;
  final String? errorMessage;

  const ResumeExtractionResult({
    required this.text,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.isSuccess,
    this.errorMessage,
  });

  factory ResumeExtractionResult.failure({
    required String fileName,
    required String fileType,
    required int fileSize,
    required String errorMessage,
  }) {
    return ResumeExtractionResult(
      text: '',
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }
}

class ResumeFileExtractor {
  static const int maxFileSize = 5 * 1024 * 1024; // Strict 5 MB limit against resource exhaustion
  static const int maxUncompressedDocxBytes = 25 * 1024 * 1024; // 25 MB zip-bomb defense
  static const int maxDocxArchiveEntries = 100;

  /// Sanitizes file name by eliminating directory traversal paths, control characters, and null bytes
  static String sanitizeFileName(String raw) {
    var clean = raw.replaceAll(RegExp(r'[/\\]'), '_');
    clean = clean.replaceAll('..', '_');
    clean = clean.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    return clean.trim().isEmpty ? 'resume_document' : clean.trim();
  }

  /// Validates and extracts readable resume text from PDF, DOCX, or TXT file bytes.
  static ResumeExtractionResult extract({
    required List<int> bytes,
    required String fileName,
  }) {
    final safeFileName = sanitizeFileName(fileName);
    final lowerName = safeFileName.toLowerCase();

    // 1. File Size Validation
    if (bytes.isEmpty) {
      return ResumeExtractionResult.failure(
        fileName: safeFileName,
        fileType: 'unknown',
        fileSize: 0,
        errorMessage: 'The selected file is empty (0 bytes). Please upload a valid resume.',
      );
    }

    if (bytes.length > maxFileSize) {
      return ResumeExtractionResult.failure(
        fileName: safeFileName,
        fileType: 'unknown',
        fileSize: bytes.length,
        errorMessage: 'File size (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB) exceeds the 5 MB limit. Please upload a smaller document.',
      );
    }

    // 2. Magic Bytes Inspection (Prevents extension spoofing)
    final hasPdfMagicBytes = bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F

    final hasDocxMagicBytes = bytes.length >= 4 &&
        bytes[0] == 0x50 && // P
        bytes[1] == 0x4B && // K
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;

    // Detect file type strictly validating signature
    final isPdfExtension = lowerName.endsWith('.pdf');
    final isDocxExtension = lowerName.endsWith('.docx');
    final isTxtExtension = lowerName.endsWith('.txt') || lowerName.endsWith('.md');

    if (isPdfExtension && !hasPdfMagicBytes) {
      return ResumeExtractionResult.failure(
        fileName: safeFileName,
        fileType: 'pdf',
        fileSize: bytes.length,
        errorMessage: 'Security verification failed: File "$safeFileName" has a .pdf extension but lacks a valid PDF header (%PDF). Possible corrupt or spoofed file.',
      );
    }

    if (isDocxExtension && !hasDocxMagicBytes) {
      return ResumeExtractionResult.failure(
        fileName: safeFileName,
        fileType: 'docx',
        fileSize: bytes.length,
        errorMessage: 'Security verification failed: File "$safeFileName" has a .docx extension but lacks a valid DOCX package signature. Possible corrupt or spoofed file.',
      );
    }

    final isPdf = hasPdfMagicBytes || isPdfExtension;
    final isDocx = hasDocxMagicBytes || isDocxExtension;
    final isTxt = isTxtExtension;

    if (!isPdf && !isDocx && !isTxt) {
      return ResumeExtractionResult.failure(
        fileName: safeFileName,
        fileType: 'unsupported',
        fileSize: bytes.length,
        errorMessage: 'Unsupported file format. Please upload a valid PDF (.pdf), Word document (.docx), or plain text (.txt) file.',
      );
    }

    try {
      String extracted = '';
      String fileType = 'txt';

      if (isPdf) {
        fileType = 'pdf';
        extracted = PdfExtractor.extractText(bytes);
      } else if (isDocx) {
        fileType = 'docx';
        extracted = _extractDocxText(bytes);
      } else {
        fileType = 'txt';
        extracted = _extractPlainText(bytes);
      }

      final trimmed = extracted.trim();

      // 3. Extraction Quality Validation
      if (trimmed.length < 20) {
        return ResumeExtractionResult.failure(
          fileName: safeFileName,
          fileType: fileType,
          fileSize: bytes.length,
          errorMessage: 'Could not extract readable text from "$safeFileName". The document appears to be empty or scanned as an image. Please upload a text-based resume.',
        );
      }

      // Check for binary corruption / binary junk
      final printableCount = trimmed.runes.where((r) => (r >= 32 && r <= 126) || r == 10 || r == 13 || r >= 160).length;
      if (printableCount / trimmed.length < 0.70) {
        return ResumeExtractionResult.failure(
          fileName: safeFileName,
          fileType: fileType,
          fileSize: bytes.length,
          errorMessage: 'The extracted text contains unreadable binary encoding. Please upload a clean PDF, DOCX, or TXT resume.',
        );
      }

      return ResumeExtractionResult(
        text: trimmed,
        fileName: safeFileName,
        fileType: fileType,
        fileSize: bytes.length,
        isSuccess: true,
      );
    } catch (e) {
      return ResumeExtractionResult.failure(
        fileName: safeFileName,
        fileType: isPdf ? 'pdf' : (isDocx ? 'docx' : 'txt'),
        fileSize: bytes.length,
        errorMessage: 'Failed to process "$safeFileName": $e. Please verify the file is not corrupted.',
      );
    }
  }

  static String _extractDocxText(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // Zip-bomb protection: Check archive entry count
      if (archive.files.length > maxDocxArchiveEntries) {
        throw const FormatException('DOCX package exceeds archive entry count safety limit (>100). Possible zip bomb.');
      }

      // Zip-bomb protection: Check total uncompressed size
      var totalUncompressedBytes = 0;
      for (final f in archive.files) {
        totalUncompressedBytes += f.size;
        if (totalUncompressedBytes > maxUncompressedDocxBytes) {
          throw const FormatException('DOCX package exceeds maximum uncompressed size limit (25 MB). Possible zip bomb.');
        }
      }

      final documentFile = archive.findFile('word/document.xml');
      if (documentFile == null) {
        throw const FormatException('word/document.xml missing in docx package');
      }

      final contentBytes = documentFile.content as List<int>;
      final xmlString = utf8.decode(contentBytes, allowMalformed: true);

      // Parse paragraphs <w:p>
      final pRegex = RegExp(r'<w:p(?:\s+[^>]*)?>(.*?)</w:p>', dotAll: true);
      final tRegex = RegExp(r'<w:t(?:\s+[^>]*)?>(.*?)</w:t>', dotAll: true);
      final brRegex = RegExp(r'<w:br(?:\s+[^>]*)?/?>');
      final tabRegex = RegExp(r'<w:tab(?:\s+[^>]*)?/?>');

      final buffer = StringBuffer();
      final paragraphs = pRegex.allMatches(xmlString);

      for (final p in paragraphs) {
        var pContent = p.group(1) ?? '';
        pContent = pContent.replaceAll(tabRegex, '  ');
        pContent = pContent.replaceAll(brRegex, '\n');

        final tMatches = tRegex.allMatches(pContent);
        final lineBuffer = StringBuffer();
        for (final t in tMatches) {
          final rawText = t.group(1) ?? '';
          lineBuffer.write(_unescapeXml(rawText));
        }

        final line = lineBuffer.toString().trim();
        if (line.isNotEmpty) {
          buffer.writeln(line);
        }
      }

      final raw = buffer.toString();
      if (raw.trim().isEmpty) {
        // Fallback: strip all xml tags
        return _unescapeXml(xmlString.replaceAll(RegExp(r'<[^>]+>'), ' '));
      }

      return PdfExtractor.arrangeExtractedText(raw);
    } catch (e) {
      throw Exception('DOCX parse error: $e');
    }
  }

  static String _extractPlainText(List<int> bytes) {
    String decoded;
    try {
      decoded = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      decoded = String.fromCharCodes(bytes);
    }
    return PdfExtractor.arrangeExtractedText(decoded);
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
