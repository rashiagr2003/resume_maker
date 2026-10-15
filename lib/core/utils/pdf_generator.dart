import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../data/datasources/heuristic_local_datasource.dart';
import '../../domain/entities/tailored_resume.dart';
import 'pdf_extractor.dart';

class _ResumeLink {
  final String label;
  final String url;
  _ResumeLink(this.label, this.url);
}

/// Adaptive typography & spacing profile to naturally distribute resume content vertically across 1 A4 page
class _PdfSpacingProfile {
  final double nameFontSize;
  final double subTitleFontSize;
  final double contactFontSize;
  final double headerMarginBottom;
  final double sectionHeaderFontSize;
  final double sectionGap;
  final double sectionHeaderBottomPadding;
  final double entryTopPadding;
  final double entryBottomPadding;
  final double bulletFontSize;
  final double bulletLineSpacing;
  final double bulletPaddingBottom;
  final double bodyFontSize;
  final double bodyLineSpacing;
  final pw.EdgeInsets pageMargin;

  const _PdfSpacingProfile({
    required this.nameFontSize,
    required this.subTitleFontSize,
    required this.contactFontSize,
    required this.headerMarginBottom,
    required this.sectionHeaderFontSize,
    required this.sectionGap,
    required this.sectionHeaderBottomPadding,
    required this.entryTopPadding,
    required this.entryBottomPadding,
    required this.bulletFontSize,
    required this.bulletLineSpacing,
    required this.bulletPaddingBottom,
    required this.bodyFontSize,
    required this.bodyLineSpacing,
    required this.pageMargin,
  });

  // Profile A: Extra Spacious (for concise resumes <= 22 lines) - fully utilizes 1 A4 page height
  static const extraSpacious = _PdfSpacingProfile(
    nameFontSize: 25.0,
    subTitleFontSize: 11.8,
    contactFontSize: 10.0,
    headerMarginBottom: 16.0,
    sectionHeaderFontSize: 12.0,
    sectionGap: 21.0,
    sectionHeaderBottomPadding: 5.0,
    entryTopPadding: 8.5,
    entryBottomPadding: 2.0,
    bulletFontSize: 10.4,
    bulletLineSpacing: 1.35,
    bulletPaddingBottom: 5.2,
    bodyFontSize: 10.4,
    bodyLineSpacing: 1.35,
    // 0.50 in top/bottom (36 pt), 0.58 in sides (42 pt)
    pageMargin: pw.EdgeInsets.symmetric(horizontal: 42.0, vertical: 36.0),
  );

  // Profile B: Spacious (for concise resumes 23 - 28 lines) - distributes content vertically
  static const spacious = _PdfSpacingProfile(
    nameFontSize: 24.5,
    subTitleFontSize: 11.2,
    contactFontSize: 9.8,
    headerMarginBottom: 13.5,
    sectionHeaderFontSize: 11.8,
    sectionGap: 16.5,
    sectionHeaderBottomPadding: 4.0,
    entryTopPadding: 7.0,
    entryBottomPadding: 1.5,
    bulletFontSize: 10.2,
    bulletLineSpacing: 1.32,
    bulletPaddingBottom: 4.5,
    bodyFontSize: 10.2,
    bodyLineSpacing: 1.32,
    pageMargin: pw.EdgeInsets.symmetric(horizontal: 42.0, vertical: 36.0),
  );

  // Profile C: Balanced / Standard (for 29 - 34 lines)
  static const standard = _PdfSpacingProfile(
    nameFontSize: 23.5,
    subTitleFontSize: 11.0,
    contactFontSize: 9.5,
    headerMarginBottom: 11.0,
    sectionHeaderFontSize: 11.5,
    sectionGap: 13.0,
    sectionHeaderBottomPadding: 3.2,
    entryTopPadding: 5.0,
    entryBottomPadding: 1.0,
    bulletFontSize: 10.0,
    bulletLineSpacing: 1.28,
    bulletPaddingBottom: 3.6,
    bodyFontSize: 10.0,
    bodyLineSpacing: 1.28,
    pageMargin: pw.EdgeInsets.symmetric(horizontal: 42.0, vertical: 36.0),
  );

  // Profile D: Compact (for dense 35 - 41 lines)
  static const compact = _PdfSpacingProfile(
    nameFontSize: 22.0,
    subTitleFontSize: 10.5,
    contactFontSize: 9.2,
    headerMarginBottom: 8.5,
    sectionHeaderFontSize: 11.0,
    sectionGap: 9.5,
    sectionHeaderBottomPadding: 2.5,
    entryTopPadding: 3.5,
    entryBottomPadding: 0.8,
    bulletFontSize: 9.8,
    bulletLineSpacing: 1.25,
    bulletPaddingBottom: 2.8,
    bodyFontSize: 9.8,
    bodyLineSpacing: 1.25,
    // 0.55 in sides (40 pt), 0.47 in top/bottom (34 pt)
    pageMargin: pw.EdgeInsets.symmetric(horizontal: 40.0, vertical: 34.0),
  );

  // Profile E: Ultra Compact (safety net for extremely dense 42+ lines)
  static const ultraCompact = _PdfSpacingProfile(
    nameFontSize: 21.0,
    subTitleFontSize: 10.0,
    contactFontSize: 8.8,
    headerMarginBottom: 6.5,
    sectionHeaderFontSize: 10.5,
    sectionGap: 7.0,
    sectionHeaderBottomPadding: 2.0,
    entryTopPadding: 2.0,
    entryBottomPadding: 0.5,
    bulletFontSize: 9.2,
    bulletLineSpacing: 1.22,
    bulletPaddingBottom: 2.0,
    bodyFontSize: 9.2,
    bodyLineSpacing: 1.22,
    // 0.55 in sides (39.6 pt), 0.45 in top/bottom (32.4 pt)
    pageMargin: pw.EdgeInsets.symmetric(horizontal: 39.6, vertical: 32.4),
  );
}

class PdfGenerator {
  static Future<Uint8List> generatePdfBytes({
    required TailoredResume tailored,
    required String candidateName,
  }) async {
    final isSinglePage = tailored.targetPages == 1;

    final cleanedTailoredText = PdfExtractor.fixProjectContext(
      tailored.tailoredResume,
    );
    final rawSplit = cleanedTailoredText
        .split('\n')
        .where(
          (l) =>
              !l.toLowerCase().contains('newly integrated') &&
              !l.toLowerCase().contains('newly aligned'),
        )
        .map((l) => _sanitizeForPdf(l))
        .where((l) => l.isNotEmpty)
        .toList();

    final actionVerbRegex = RegExp(
      r'^(?:Built|Developed|Implemented|Integrated|Added|Used|Contributed|Executed|Automated|'
      r'Visualized|Designed|Created|Architected|Engineered|Configured|Maintained|Optimized|'
      r'Spearheaded|Streamlined|Collaborated|Conducted|Tested|Managed|Led|Authored|Generated|'
      r'Deployed|Orchestrated|Secured|Refactored|Enhanced|Accelerated|Formulated|Drafted|'
      r'Monitored|Supervised|Produced|Established|Published|Trained|Mentored|Assisted|'
      r'Pioneered|Achieved|Facilitated|Analyzed|Researched|Solved|Coordinated|Directed|'
      r'Identified|Standardized|Tracked|Validated|Wrote|Programmed|Delivered|Resolved|'
      r'Prepared|Reviewed|Supported)\b',
      caseSensitive: false,
    );

    final rawLines = <String>[];
    bool inExpOrProj = false;

    for (int i = 0; i < rawSplit.length; i++) {
      var current = rawSplit[i].trim();
      if (current == '•' || current == '-' || current == '*') {
        if (i + 1 < rawSplit.length) {
          final next = rawSplit[i + 1].trim();
          if (next.isNotEmpty &&
              !next.startsWith('•') &&
              !next.startsWith('-') &&
              !next.startsWith('*') &&
              !next.startsWith('#')) {
            rawSplit[i + 1] = '• $next';
          }
        }
        continue; // Never include lone pointer!
      }
      // If current line has an unclosed markdown link bracket (e.g. "[Healthcare" split from "App](url)")
      if (current.contains('[') &&
          !current.contains(']') &&
          i + 1 < rawSplit.length) {
        final next = rawSplit[i + 1].trim();
        if (next.contains('](') || next.contains(')')) {
          current = '$current $next';
          i++; // Skip next line since it was merged
        }
      }

      // If current line starts with a lowercase letter in experience/projects, or is an unpunctuated wrapped continuation
      final isHeaderArea = rawLines.length < 5 ||
          _isContactLine(current) ||
          _isLinksLine(current) ||
          _isSectionHeader(current) ||
          current.contains('@');
      final isBulletContinuation = !isHeaderArea &&
          ((inExpOrProj && RegExp(r'^[a-z]').hasMatch(current)) ||
              (rawLines.isNotEmpty &&
                  rawLines.last.startsWith('•') &&
                  !rawLines.last.trim().endsWith('.') &&
                  !actionVerbRegex.hasMatch(current) &&
                  !_isSectionHeader(current) &&
                  !current.startsWith('#') &&
                  !current.contains('|') &&
                  !current.contains('[Project]') &&
                  !current.contains('[Demo]')));
      if (rawLines.isNotEmpty && isBulletContinuation) {
        rawLines[rawLines.length - 1] = '${rawLines.last} $current';
        continue;
      }

      final lowerHeader = current
          .toLowerCase()
          .replaceAll('#', '')
          .replaceAll(':', '')
          .trim();
      if (lowerHeader.contains('experience') ||
          lowerHeader.contains('work history') ||
          lowerHeader.contains('project')) {
        inExpOrProj = true;
      } else if (lowerHeader.contains('skill') ||
          lowerHeader.contains('education') ||
          lowerHeader.contains('summary') ||
          lowerHeader.contains('profile')) {
        inExpOrProj = false;
      }

      // If current line is JUST a date (e.g. "2021 - 2025" or "| 2021 - 2025") and follows a university, company, or degree
      final isDateOnly = RegExp(
        r'^\|?\s*(?:(?:\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present))|\b\d{4}\s*[\-–—]\s*\d{4}\b)\s*$',
        caseSensitive: false,
      ).hasMatch(current);
      if (isDateOnly && rawLines.isNotEmpty) {
        rawLines[rawLines.length - 1] =
            '${rawLines.last} | ${current.replaceAll('|', '').trim()}';
        continue;
      }

      if (rawLines.isNotEmpty &&
          (current.toLowerCase() == 'reporting' ||
              (rawLines.last.toLowerCase().endsWith('bug') &&
                  current.toLowerCase().startsWith('reporting')))) {
        rawLines[rawLines.length - 1] = '${rawLines.last} $current';
        continue;
      }

      // Ensure bullet prefix for accomplishments in experience and projects
      final isAlreadyBullet =
          current.startsWith('•') ||
          current.startsWith('-') ||
          current.startsWith('*');
      final isHeaderOrDate =
          current.startsWith('#') ||
          _isSectionHeader(current) ||
          RegExp(
            r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*\d{4}\b)',
            caseSensitive: false,
          ).hasMatch(current) ||
          current.contains('Pvt') ||
          current.contains('Ltd') ||
          current.contains('University') ||
          current.contains('College') ||
          current.contains('|') ||
          current.contains('[Project]') ||
          current.contains('[Demo]') ||
          RegExp(
            r'\b(Project|Demo)(?:\s*↗)?$',
            caseSensitive: false,
          ).hasMatch(current);

      if (!isAlreadyBullet && !isHeaderOrDate) {
        if (actionVerbRegex.hasMatch(current) ||
            (inExpOrProj && current.length > 20)) {
          current = '• $current';
        }
      }

      rawLines.add(current);
    }

    // Organize into exact standard section order: Summary -> Skills -> Experience -> Projects -> Education
    final orderedLines = _organizeSectionsInStandardOrder(rawLines, tailored);

    final totalLines = orderedLines.length;

    // Profiles tested from most spacious (naturally filling vertical space) to compact
    final profiles = <_PdfSpacingProfile>[
      if (totalLines <= 24) _PdfSpacingProfile.extraSpacious,
      if (totalLines <= 30) _PdfSpacingProfile.spacious,
      if (totalLines <= 36) _PdfSpacingProfile.standard,
      _PdfSpacingProfile.compact,
      _PdfSpacingProfile.ultraCompact,
    ];

    Uint8List? bestBytes;
    for (final profile in profiles) {
      final doc = _buildDocument(
        tailored: tailored,
        rawLines: orderedLines,
        profile: profile,
        candidateName: candidateName,
      );
      final bytes = await doc.save();
      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      final pageCount = sfDoc.pages.count;
      sfDoc.dispose();

      if (!isSinglePage || pageCount == 1) {
        return bytes;
      }
      bestBytes = bytes;
    }

    return bestBytes!;
  }

  /// Organizes sections in strict executive standard order:
  /// Professional Summary -> Technical Skills -> Professional Experience -> Projects -> Education
  static List<String> _organizeSectionsInStandardOrder(
    List<String> rawLines,
    TailoredResume tailored,
  ) {
    if (rawLines.isEmpty) return rawLines;

    // 1. Separate header lines (before first section header)
    final headerLines = <String>[];
    int i = 0;
    while (i < rawLines.length && !_isSectionHeader(rawLines[i])) {
      headerLines.add(rawLines[i]);
      i++;
    }

    // 2. Parse remaining lines into section groups
    final sections = <String, List<String>>{};
    String? currentSectionKey;

    while (i < rawLines.length) {
      final line = rawLines[i];
      if (_isSectionHeader(line)) {
        final clean = line
            .replaceAll(RegExp(r'^[\-\*•#\s]+'), '')
            .replaceAll('#', '')
            .replaceAll(':', '')
            .trim()
            .toUpperCase();

        if (clean == 'PROFESSIONAL SUMMARY' ||
            clean == 'SUMMARY' ||
            clean == 'PROFILE' ||
            clean == 'ABOUT ME') {
          currentSectionKey = 'summary';
        } else if (clean == 'TECHNICAL SKILLS' ||
            clean == 'SKILLS' ||
            clean == 'CORE COMPETENCIES' ||
            clean == 'AREAS OF EXPERTISE' ||
            clean == 'PROFESSIONAL SKILLS' ||
            clean == 'KEY SKILLS') {
          currentSectionKey = 'skills';
        } else if (clean == 'PROFESSIONAL EXPERIENCE' ||
            clean == 'EXPERIENCE' ||
            clean == 'WORK EXPERIENCE' ||
            clean == 'WORK HISTORY' ||
            clean == 'EMPLOYMENT') {
          currentSectionKey = 'experience';
        } else if (clean == 'PROJECTS' ||
            clean == 'KEY PROJECTS' ||
            clean == 'ACADEMIC PROJECTS') {
          currentSectionKey = 'projects';
        } else if (clean == 'EDUCATION' ||
            clean == 'ACADEMIC' ||
            clean == 'ACADEMIC BACKGROUND') {
          currentSectionKey = 'education';
        } else {
          currentSectionKey = 'other_${sections.length}';
        }
        sections.putIfAbsent(currentSectionKey, () => <String>[]);
        sections[currentSectionKey]!.add(line);
      } else {
        if (currentSectionKey != null) {
          sections[currentSectionKey]!.add(line);
        } else {
          headerLines.add(line);
        }
      }
      i++;
    }

    // 3. Guaranteed Skills Section if not present or empty
    if (!sections.containsKey('skills') || sections['skills']!.length <= 1) {
      final prevSkills = HeuristicLocalDataSource.extractPreviousSkills(
        tailored.originalResume,
      );
      final domainSkills = tailored.addedKeywords.isNotEmpty
          ? tailored.addedKeywords
              .map((s) => s.contains('(') ? s : '$s (Intermediate)')
              .toList()
          : <String>[];

      prevSkills.removeWhere(
        (ps) => domainSkills.any(
          (ds) => ds.toLowerCase().contains(ps.toLowerCase()),
        ),
      );

      final injectedSkillsLines = <String>['TECHNICAL SKILLS'];
      if (domainSkills.isNotEmpty) {
        injectedSkillsLines.add(
          'Core Competencies: ${domainSkills.join(", ")}',
        );
      }
      if (prevSkills.isNotEmpty) {
        injectedSkillsLines.add(
          'Technical & Analytical Tools: ${prevSkills.join(", ")}',
        );
      }
      if (injectedSkillsLines.length > 1) {
        sections['skills'] = injectedSkillsLines;
      }
    }

    // 4. Reconstruct in the EXACT standard order requested:
    // Professional Summary, Technical Skills, Professional Experience, Projects, Education, Others
    final orderedLines = <String>[...headerLines];

    if (sections.containsKey('summary')) {
      orderedLines.addAll(sections['summary']!);
    }
    if (sections.containsKey('skills')) {
      orderedLines.addAll(sections['skills']!);
    }
    if (sections.containsKey('experience')) {
      orderedLines.addAll(sections['experience']!);
    }
    if (sections.containsKey('projects')) {
      orderedLines.addAll(sections['projects']!);
    }
    if (sections.containsKey('education')) {
      orderedLines.addAll(sections['education']!);
    }
    for (final entry in sections.entries) {
      if (entry.key.startsWith('other_')) {
        orderedLines.addAll(entry.value);
      }
    }

    return orderedLines;
  }

  /// Builds a pw.Document for a specific layout profile
  static pw.Document _buildDocument({
    required TailoredResume tailored,
    required List<String> rawLines,
    required _PdfSpacingProfile profile,
    required String candidateName,
  }) {
    final pdf = pw.Document();
    final contentWidgets = <pw.Widget>[];
    int index = 0;

    // 1. Process Header: Name, Job Title, Contact (Phone, Email), Clickable Links (GitHub, Portfolio, LinkedIn)
    if (rawLines.isNotEmpty) {
      var name = rawLines[0].replaceAll('#', '').trim();
      name = name.replaceAllMapped(
        RegExp(r'\b([A-Za-z]{2,})\s+([A-Za-z])\s+([A-Za-z]{2,})\b'),
        (m) => '${m[1]}${m[2]}${m[3]}',
      );
      name = name.replaceAll(RegExp(r'\s{2,}'), ' ');

      // Name: Bold, dark blue, centered, 22-26 pt
      contentWidgets.add(
        pw.Center(
          child: pw.Text(
            name.toUpperCase(),
            style: pw.TextStyle(
              fontSize: profile.nameFontSize,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF0F2B5C), // Dark blue
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
      contentWidgets.add(pw.SizedBox(height: 1.5));
      index++;

      // Subtitle / Job Title: Bold, centered, dark blue / slate
      if (index < rawLines.length &&
          !_isSectionHeader(rawLines[index]) &&
          !_isContactLine(rawLines[index]) &&
          !_isLinksLine(rawLines[index])) {
        var titleText = rawLines[index];
        titleText = titleText
            .replaceAll(
              RegExp(
                r'\s*\|\s*(?:Bengaluru|Bangalore|Noida|Delhi|Pune|Hyderabad|San Francisco|Remote)[^|]*$',
                caseSensitive: false,
              ),
              '',
            )
            .trim();

        if (titleText.isNotEmpty) {
          contentWidgets.add(
            pw.Center(
              child: pw.Text(
                titleText,
                style: pw.TextStyle(
                  fontSize: profile.subTitleFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF1E3A8A), // Dark slate / indigo
                ),
              ),
            ),
          );
          contentWidgets.add(pw.SizedBox(height: 1.5));
        }
        index++;
      }

      // Collect all contact info (phone, email) and links (GitHub, Portfolio, LinkedIn)
      // across all header lines before the first section header
      String? contactPhone;
      String? contactEmail;
      final links = <_ResumeLink>[];
      final seenUrls = <String>{};

      while (index < rawLines.length && !_isSectionHeader(rawLines[index])) {
        final line = rawLines[index];
        final phone = _extractPhone(line);
        if (phone != null && contactPhone == null) {
          contactPhone = phone;
        }
        final email = _extractEmail(line);
        if (email != null && contactEmail == null) {
          contactEmail = email;
        }
        if (_isLinksLine(line)) {
          final lineLinks = _extractLinksFromLine(line, tailored.originalResume);
          for (final l in lineLinks) {
            if (seenUrls.add(l.url.toLowerCase())) {
              links.add(l);
            }
          }
        }
        index++;
      }

      final contactParts = <String>[];
      if (contactPhone != null && contactPhone.isNotEmpty) {
        contactParts.add(contactPhone);
      }
      if (contactEmail != null && contactEmail.isNotEmpty) {
        contactParts.add(contactEmail);
      }

      if (contactParts.isNotEmpty) {
        final contactText = contactParts.join(' | ');
        contentWidgets.add(
          pw.Center(
            child: pw.Text(
              contactText,
              style: pw.TextStyle(
                fontSize: profile.contactFontSize,
                color: PdfColors.grey800,
              ),
            ),
          ),
        );
        contentWidgets.add(pw.SizedBox(height: 2.0));
      }

      // Centered Clickable Links Line (GitHub, Portfolio, LinkedIn)
      if (links.isNotEmpty) {
        final linkWidgets = <pw.Widget>[];
        for (int i = 0; i < links.length; i++) {
          final link = links[i];
          linkWidgets.add(
            pw.UrlLink(
              destination: link.url,
              child: pw.Text(
                link.label,
                style: pw.TextStyle(
                  fontSize: profile.contactFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF1D4ED8), // Professional link blue
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          );
          if (i < links.length - 1) {
            linkWidgets.add(
              pw.Text(
                ' | ',
                style: pw.TextStyle(
                  fontSize: profile.contactFontSize,
                  color: PdfColors.grey500,
                ),
              ),
            );
          }
        }

        contentWidgets.add(
          pw.Center(
            child: pw.Wrap(
              alignment: pw.WrapAlignment.center,
              crossAxisAlignment: pw.WrapCrossAlignment.center,
              children: linkWidgets,
            ),
          ),
        );
        contentWidgets.add(pw.SizedBox(height: 2.5));
      }

      // Divider below header
      contentWidgets.add(pw.Divider(color: PdfColors.grey300, thickness: 0.6));
      contentWidgets.add(pw.SizedBox(height: profile.headerMarginBottom));
    }

    // Skip any orphaned summary text that might appear before the first real section header
    while (index < rawLines.length && !_isSectionHeader(rawLines[index])) {
      index++;
    }

    // 2. Process Sections & Content
    bool inProjectsSection = false;
    bool inSkillsSection = false;
    bool inEducationSection = false;
    bool inExperienceSection = false;

    while (index < rawLines.length) {
      final line = rawLines[index];

      // Section Header (Summary, Skills, Experience, Projects, Education)
      if (_isSectionHeader(line)) {
        final headerText = line
            .replaceAll(RegExp(r'^[\-\*•#\s]+'), '')
            .replaceAll('#', '')
            .replaceAll(':', '')
            .trim()
            .toUpperCase();

        inProjectsSection = headerText.contains('PROJECT');
        inSkillsSection =
            headerText.contains('SKILL') || headerText.contains('COMPETENC');
        inEducationSection = headerText.contains('EDUCATION');
        inExperienceSection =
            headerText.contains('EXPERIENCE') || headerText.contains('WORK');

        contentWidgets.add(pw.SizedBox(height: profile.sectionGap));
        contentWidgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                headerText,
                style: pw.TextStyle(
                  fontSize: profile.sectionHeaderFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0F2B5C), // Bold dark blue
                  letterSpacing: 0.6,
                ),
              ),
              pw.SizedBox(height: 2.2),
              // Thin blue horizontal line
              pw.Container(
                height: 0.8,
                color: const PdfColor.fromInt(0xFF2563EB),
              ),
            ],
          ),
        );
        contentWidgets.add(
          pw.SizedBox(height: profile.sectionHeaderBottomPadding),
        );
        index++;
        continue;
      }

      // Bullet points: drawn with crisp native vector circle and consistent indentation
      if (line.startsWith('-') ||
          line.startsWith('*') ||
          line.startsWith('•')) {
        final text = line.replaceFirst(RegExp(r'^[\-\*•]\s*'), '').trim();
        if (text.isEmpty) {
          index++;
          continue;
        }

        contentWidgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: profile.bulletPaddingBottom),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 2.8,
                  height: 2.8,
                  margin: const pw.EdgeInsets.only(top: 4.2, right: 5.5, left: 1.0),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF0F2B5C),
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: _buildRichLineWithLinks(
                    text,
                    fontSize: profile.bulletFontSize,
                    lineSpacing: profile.bulletLineSpacing,
                    textColor: PdfColors.grey900,
                  ),
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      // Skills category line (e.g. "Programming Languages: Dart, Java, Python")
      var skillsLine = line;
      if (skillsLine.toLowerCase().contains('tools:') ||
          skillsLine.toLowerCase().contains('languages:') ||
          skillsLine.toLowerCase().contains('skills:') ||
          skillsLine.toLowerCase().contains('automation:')) {
        skillsLine = skillsLine.replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (m) => m.group(1)!,
        );
      }

      if (skillsLine.contains(':') &&
          !skillsLine.toLowerCase().contains('http') &&
          !skillsLine.toLowerCase().contains('|') &&
          skillsLine.indexOf(':') < 35) {
        final colonIdx = skillsLine.indexOf(':');
        final category = skillsLine.substring(0, colonIdx).trim();
        final skills = skillsLine.substring(colonIdx + 1).trim();

        contentWidgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: profile.bulletPaddingBottom),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$category: ',
                    style: pw.TextStyle(
                      fontSize: profile.bodyFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.TextSpan(
                    text: skills,
                    style: pw.TextStyle(
                      fontSize: profile.bodyFontSize,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        index++;
        continue;
      }

      // If line contains accidental literal $1 $2 artifact, recover real date
      var processedLine = line;
      if (processedLine.contains(r'$1')) {
        final origMatch = RegExp(
          r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*\d{4}\b)',
          caseSensitive: false,
        ).firstMatch(tailored.originalResume);
        final realDate = origMatch?.group(1) ?? 'December 2025 – May 2026';
        processedLine = processedLine
            .replaceAll(r'$1 $2 - $1 $2', realDate)
            .replaceAll(r'$1 $2', realDate);
      }

      // Check if project line with explicit link to let project header handle it
      final isProjectWithExplicitLink = inProjectsSection &&
          (processedLine.contains('](') ||
              processedLine.toLowerCase().contains('[project]') ||
              processedLine.toLowerCase().contains('[demo]') ||
              RegExp(r'\b(Project|Demo)(?:\s*↗)?$', caseSensitive: false).hasMatch(processedLine));

      // Company | Date or Degree | Date line (or concatenated title + date)
      final dateMatch = !isProjectWithExplicitLink
          ? RegExp(
              r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*(?:\d{4}|Present)\b)',
              caseSensitive: false,
            ).firstMatch(processedLine)
          : null;

      if (dateMatch != null) {
        final rawDate = dateMatch.group(1)!;
        var cleanTitle = processedLine
            .replaceAll(rawDate, '')
            .replaceAll('|', '')
            .trim();
        cleanTitle = cleanTitle
            .replaceAll(r'$1 $2', '')
            .replaceAll(r'$1', '')
            .replaceAll(r'$2', '')
            .trim();
        cleanTitle = PdfExtractor.fixProjectContext(cleanTitle);

        if (cleanTitle.isEmpty) {
          index++;
          continue;
        }

        var formattedDate = rawDate
            .replaceAllMapped(
              RegExp(r'([a-zA-Z]+)(\d{4})'),
              (m) => '${m.group(1)} ${m.group(2)}',
            )
            .replaceAll(RegExp(r'\s*[\-–—]\s*'), ' - ');

        if (formattedDate.contains(r'$1') || formattedDate.contains(r'$2')) {
          final origMatch = RegExp(
            r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*\d{4}\b)',
            caseSensitive: false,
          ).firstMatch(tailored.originalResume);
          formattedDate = origMatch != null
              ? origMatch.group(1)!.replaceAll(RegExp(r'\s*[\-–—]\s*'), ' - ')
              : 'December 2025 - May 2026';
        }

        // Job / Degree Title (Bold dark blue) with date aligned to the right
        contentWidgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(
              top: profile.entryTopPadding,
              bottom: profile.entryBottomPadding,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    cleanTitle,
                    style: pw.TextStyle(
                      fontSize: profile.bodyFontSize + 0.4,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F2B5C), // Bold dark blue
                    ),
                  ),
                ),
                pw.Text(
                  formattedDate,
                  style: pw.TextStyle(
                    fontSize: profile.bodyFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      // Secondary company / university info line
      if (processedLine.contains('Pvt') ||
          processedLine.contains('Ltd') ||
          processedLine.contains('University') ||
          processedLine.contains('College') ||
          processedLine.contains('Clinic') ||
          processedLine.contains('Hospital')) {
        contentWidgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: profile.entryBottomPadding),
            child: _buildRichLineWithLinks(
              processedLine,
              fontSize: profile.bodyFontSize,
              fontStyle: pw.FontStyle.italic,
              textColor: PdfColors.grey800,
            ),
          ),
        );
        index++;
        continue;
      }

      // In EDUCATION section: If line has degree and CGPA, split into Row(spaceBetween: [Degree on left, CGPA on right])
      if (inEducationSection &&
          (processedLine.toLowerCase().contains('cgpa') ||
              processedLine.toLowerCase().contains('gpa:'))) {
        final cgpaMatch = RegExp(
          r'\b(?:CGPA|GPA)\s*:\s*[0-9\.]+(?:\s*/\s*10)?',
          caseSensitive: false,
        ).firstMatch(processedLine);
        if (cgpaMatch != null) {
          final degree = processedLine
              .replaceAll(cgpaMatch.group(0)!, '')
              .replaceAll('|', '')
              .trim();
          final cgpa = cgpaMatch.group(0)!.trim();
          contentWidgets.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(
                top: 0.8,
                bottom: profile.entryBottomPadding,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      degree,
                      style: pw.TextStyle(
                        fontSize: profile.bodyFontSize,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                  pw.Text(
                    cgpa,
                    style: pw.TextStyle(
                      fontSize: profile.bodyFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          );
          index++;
          continue;
        }
      }

      // In PROJECTS section: ONLY match project title lines
      final hasPipe = processedLine.contains('|');
      final linkMatch = RegExp(
        r'\[([^\]]+)\]\(([^)]+)\)',
      ).firstMatch(processedLine);
      final wordLinkMatch = RegExp(
        r'\b(Project|Demo)(?:\s*↗)?$',
        caseSensitive: false,
      ).firstMatch(processedLine);
      final isProjectHeader =
          inProjectsSection &&
          !processedLine.startsWith('•') &&
          !processedLine.startsWith('-') &&
          !processedLine.startsWith('*') &&
          (hasPipe || linkMatch != null || wordLinkMatch != null);

      if (isProjectHeader) {
        String cleanTitle = processedLine.replaceAll(' - ', ' | ');
        String? linkText;
        String? linkUrl;

        if (linkMatch != null) {
          linkText = linkMatch.group(1)!.replaceAll('↗', '').trim();
          linkUrl = linkMatch.group(2)!.trim();
          cleanTitle = cleanTitle.replaceAll(linkMatch.group(0)!, '').trim();
        } else if (wordLinkMatch != null) {
          linkText = wordLinkMatch.group(1)!.replaceAll('↗', '').trim();
          cleanTitle = cleanTitle.substring(0, wordLinkMatch.start).trim();
          final pName = cleanTitle.split('|').first.trim().toLowerCase();
          final origMatches = RegExp(
            r'\[?(?:Project|Demo)\]?\((https?://[^\)]+)\)',
            caseSensitive: false,
          ).allMatches(tailored.originalResume);
          for (final om in origMatches) {
            final ctx = tailored.originalResume
                .substring(
                  om.start > 60 ? om.start - 60 : 0,
                  om.end + 20 < tailored.originalResume.length
                      ? om.end + 20
                      : tailored.originalResume.length,
                )
                .toLowerCase();
            if (ctx.contains(pName) ||
                pName.split(' ').any((w) => w.length > 4 && ctx.contains(w))) {
              linkUrl = om.group(1)!.trim();
              break;
            }
          }
        } else if (hasPipe) {
          final pName = cleanTitle.split('|').first.trim().toLowerCase();
          final origMatches = RegExp(
            r'\[?(?:Project|Demo)\]?\((https?://[^\)]+)\)',
            caseSensitive: false,
          ).allMatches(tailored.originalResume);
          for (final om in origMatches) {
            final ctx = tailored.originalResume
                .substring(
                  om.start > 60 ? om.start - 60 : 0,
                  om.end + 20 < tailored.originalResume.length
                      ? om.end + 20
                      : tailored.originalResume.length,
                )
                .toLowerCase();
            if (ctx.contains(pName) ||
                pName.split(' ').any((w) => w.length > 4 && ctx.contains(w))) {
              linkText = 'Project';
              linkUrl = om.group(1)!.trim();
              break;
            }
          }
        }

        final projectDateMatch = RegExp(
          r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*(?:\d{4}|Present)\b|\b20\d{2}\b)',
          caseSensitive: false,
        ).firstMatch(cleanTitle);

        String? projectDate;
        if (projectDateMatch != null) {
          projectDate = projectDateMatch.group(1)!.trim();
          cleanTitle = cleanTitle.replaceAll(projectDate, '').replaceAll(RegExp(r'\s*\|\s*$'), '').trim();
        }

        cleanTitle = cleanTitle.replaceAll(RegExp(r'\s*\|\s*$'), '').trim();
        cleanTitle = PdfExtractor.fixProjectContext(cleanTitle);

        contentWidgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(
              top: profile.entryTopPadding,
              bottom: profile.entryBottomPadding,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    cleanTitle,
                    style: pw.TextStyle(
                      fontSize: profile.bodyFontSize + 0.4,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F2B5C), // Bold dark blue
                    ),
                  ),
                ),
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    if (linkText != null && linkUrl != null) ...[
                      pw.UrlLink(
                        destination: linkUrl,
                        child: pw.Text(
                          linkText,
                          style: pw.TextStyle(
                            fontSize: profile.bodyFontSize,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF1D4ED8),
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ),
                      if (projectDate != null) pw.SizedBox(width: 8),
                    ],
                    if (projectDate != null)
                      pw.Text(
                        projectDate,
                        style: pw.TextStyle(
                          fontSize: profile.bodyFontSize,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      // General body text (wraps any embedded markdown links cleanly!)
      final isTitle =
          !inSkillsSection &&
          !inProjectsSection &&
          !processedLine.contains('.') &&
          !processedLine.contains(',') &&
          processedLine.length < 40 &&
          (processedLine.toLowerCase().contains('developer') ||
              processedLine.toLowerCase().contains('engineer') ||
              processedLine.toLowerCase().contains('bachelor') ||
              processedLine.toLowerCase().contains('master') ||
              processedLine.toLowerCase().contains('b.tech'));

      // If in Experience or Projects and line is an accomplishment/bullet, render with bullet point row and hanging indent!
      if ((inExperienceSection || inProjectsSection) &&
          !isTitle &&
          processedLine.length > 15 &&
          !processedLine.contains('|') &&
          !processedLine.contains('[Project]') &&
          !processedLine.contains('[Demo]')) {
        final bulletText = processedLine
            .replaceFirst(RegExp(r'^[\-\*•]\s*'), '')
            .trim();
        contentWidgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: profile.bulletPaddingBottom),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 2.8,
                  height: 2.8,
                  margin: const pw.EdgeInsets.only(top: 4.2, right: 5.5, left: 1.0),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF0F2B5C),
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: _buildRichLineWithLinks(
                    bulletText,
                    fontSize: profile.bulletFontSize,
                    lineSpacing: profile.bulletLineSpacing,
                    textColor: PdfColors.grey900,
                  ),
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      contentWidgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            top: isTitle ? profile.entryTopPadding : 0,
            bottom: profile.entryBottomPadding,
          ),
          child: _buildRichLineWithLinks(
            processedLine,
            fontSize: isTitle ? profile.bodyFontSize + 0.4 : profile.bodyFontSize,
            lineSpacing: profile.bodyLineSpacing,
            fontWeight: isTitle ? pw.FontWeight.bold : pw.FontWeight.normal,
            textColor: isTitle
                ? const PdfColor.fromInt(0xFF0F2B5C)
                : (inSkillsSection ? PdfColors.grey800 : PdfColors.grey900),
          ),
        ),
      );
      index++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: profile.pageMargin,
        build: (context) => contentWidgets,
      ),
    );

    return pdf;
  }

  static Future<void> exportAndPrint({
    required TailoredResume tailored,
    required String candidateName,
  }) async {
    final bytes = await generatePdfBytes(
      tailored: tailored,
      candidateName: candidateName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${candidateName.replaceAll(' ', '_')}_Tailored_Resume.pdf',
    );
  }

  static Future<void> downloadPdf({
    required TailoredResume tailored,
    required String candidateName,
  }) async {
    final bytes = await generatePdfBytes(
      tailored: tailored,
      candidateName: candidateName,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: '${candidateName.replaceAll(' ', '_')}_Tailored_Resume.pdf',
    );
  }

  /// Parses inline markdown links [Label](URL) and wraps them cleanly with surrounding text
  static pw.Widget _buildRichLineWithLinks(
    String line, {
    double fontSize = 8.6,
    double lineSpacing = 1.24,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    pw.FontStyle fontStyle = pw.FontStyle.normal,
    PdfColor textColor = PdfColors.grey900,
  }) {
    var processed = line.replaceFirst(RegExp(r'^[\-\*•]\s*'), '').trim();
    processed = processed.replaceAll('•', '').trim();

    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    if (!linkRegex.hasMatch(processed)) {
      return pw.Text(
        processed,
        style: pw.TextStyle(
          fontSize: fontSize,
          lineSpacing: lineSpacing,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: textColor,
        ),
      );
    }

    final widgets = <pw.Widget>[];
    int lastEnd = 0;

    for (final match in linkRegex.allMatches(processed)) {
      if (match.start > lastEnd) {
        final plainText = processed.substring(lastEnd, match.start);
        if (plainText.isNotEmpty) {
          widgets.add(
            pw.Text(
              plainText,
              style: pw.TextStyle(
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                fontWeight: fontWeight,
                fontStyle: fontStyle,
                color: textColor,
              ),
            ),
          );
        }
      }

      final anchorText = match.group(1)!;
      final rawUrl = match.group(2)!.trim();
      final url = rawUrl.startsWith('http') || rawUrl.startsWith('mailto:')
          ? rawUrl
          : 'https://$rawUrl';

      widgets.add(
        pw.UrlLink(
          destination: url,
          child: pw.Text(
            anchorText,
            style: pw.TextStyle(
              fontSize: fontSize,
              lineSpacing: lineSpacing,
              fontWeight: pw.FontWeight.bold,
              fontStyle: fontStyle,
              color: PdfColors.indigo700,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < processed.length) {
      final remaining = processed.substring(lastEnd);
      if (remaining.isNotEmpty) {
        widgets.add(
          pw.Text(
            remaining,
            style: pw.TextStyle(
              fontSize: fontSize,
              lineSpacing: lineSpacing,
              fontWeight: fontWeight,
              fontStyle: fontStyle,
              color: textColor,
            ),
          ),
        );
      }
    }

    return pw.Wrap(
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      children: widgets,
    );
  }

  static bool _isContactLine(String line) {
    final lower = line.toLowerCase();
    return line.contains('@') ||
        line.contains('+') ||
        lower.contains('india') ||
        lower.contains('location') ||
        lower.contains('noida') ||
        lower.contains('bengaluru') ||
        lower.contains('bangalore') ||
        lower.contains('delhi') ||
        lower.contains('gurgaon') ||
        lower.contains('pune') ||
        lower.contains('hyderabad') ||
        lower.contains('mumbai') ||
        lower.contains('chennai') ||
        lower.contains('kolkata') ||
        lower.contains('san francisco') ||
        lower.contains('seattle') ||
        lower.contains('austin') ||
        lower.contains('new york') ||
        lower.contains('relocation') ||
        lower.contains('hybrid') ||
        (lower.contains('remote') &&
            (line.contains('|') || line.contains(':'))) ||
        RegExp(r'\b\d{10}\b').hasMatch(line);
  }

  static bool _isLinksLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('github') ||
        lower.contains('linkedin') ||
        lower.contains('portfolio') ||
        lower.contains('gitlab') ||
        lower.contains('leetcode') ||
        lower.contains('behance') ||
        lower.contains('dribbble') ||
        (lower.contains('website') &&
            (line.contains(':') || line.contains('|') || line.contains('http'))) ||
        RegExp(r'\[[^\]]+\]\(https?://[^)]+\)').hasMatch(line);
  }

  static String? _extractPhone(String text) {
    var clean = text.replaceAll(
      RegExp(
        r'\[?[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\]?(?:\(mailto:[^)]*\))?',
        caseSensitive: false,
      ),
      ' ',
    );
    clean = clean.replaceAll(RegExp(r'\[[^\]]+\]\([^)]+\)'), ' ');

    // Match any phone sequence starting with optional + that contains 10-15 digits
    final phoneRegex = RegExp(r'\+?[0-9][0-9\s().-]{8,}[0-9]');
    final matches = phoneRegex.allMatches(clean);
    for (final m in matches) {
      final candidate = m.group(0)!.trim();
      final digits = candidate.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10 && digits.length <= 15) {
        return candidate;
      }
    }
    return null;
  }

  static String? _extractEmail(String text) {
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      caseSensitive: false,
    );
    final match = emailRegex.firstMatch(text);
    return match?.group(0);
  }

  static String _cleanContactLine(String line, [String targetCity = '']) {
    final phone = _extractPhone(line);
    final email = _extractEmail(line);
    final parts = <String>[];
    if (phone != null && phone.isNotEmpty) parts.add(phone);
    if (email != null && email.isNotEmpty) parts.add(email);
    return parts.join(' | ');
  }

  static List<_ResumeLink> _extractLinksFromLine(
    String line,
    String originalResume,
  ) {
    final links = <_ResumeLink>[];

    // 1. Check for markdown links: [Label](url)
    final mdMatches = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').allMatches(line);
    if (mdMatches.isNotEmpty) {
      for (final m in mdMatches) {
        var label = m.group(1)!;
        var rawUrl = m.group(2)!.trim().replaceAll(RegExp(r'\s+'), '');
        final url = rawUrl.startsWith('http') || rawUrl.startsWith('mailto:')
            ? rawUrl
            : 'https://$rawUrl';
        // Format common labels
        if (label.toLowerCase().contains('linkedin')) label = 'LinkedIn';
        if (label.toLowerCase().contains('github')) label = 'GitHub';
        if (label.toLowerCase().contains('portfolio') ||
            label.toLowerCase().contains('website')) {
          label = 'Portfolio';
        }
        links.add(_ResumeLink(label, url));
      }
      return links;
    }

    // 2. Check for pipe-separated or bullet-separated items
    final parts = line
        .split(RegExp(r'[|•]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    for (final part in parts) {
      if (part.contains(':')) {
        final colon = part.indexOf(':');
        var label = part.substring(0, colon).trim();
        var rawUrl = part.substring(colon + 1).trim();
        rawUrl = rawUrl.replaceAll('[', '').replaceAll(']', '').trim().replaceAll(RegExp(r'\s+'), '');

        if (label.toLowerCase().contains('linkedin')) label = 'LinkedIn';
        if (label.toLowerCase().contains('github')) label = 'GitHub';
        if (label.toLowerCase().contains('portfolio') ||
            label.toLowerCase().contains('website')) {
          label = 'Portfolio';
        }

        if (rawUrl.isNotEmpty) {
          final url = rawUrl.startsWith('http') || rawUrl.startsWith('mailto:')
              ? rawUrl
              : 'https://$rawUrl';
          links.add(_ResumeLink(label, url));
          continue;
        }
      }

      // Check for standalone URLs
      if (part.contains('github.com') ||
          part.contains('linkedin.com') ||
          part.contains('portfolio') ||
          part.startsWith('http')) {
        final label = part.contains('github')
            ? 'GitHub'
            : part.contains('linkedin')
            ? 'LinkedIn'
            : 'Portfolio';
        final cleanPart = part.replaceAll(RegExp(r'\s+'), '');
        final url = cleanPart.startsWith('http') ? cleanPart : 'https://$cleanPart';
        links.add(_ResumeLink(label, url));
        continue;
      }

      // Check if part is just "LinkedIn", "GitHub", "Portfolio"
      final pLower = part.toLowerCase();
      if (pLower.contains('linkedin')) {
        final urlMatch = RegExp(
          r'(?:https?://)?(?:www\.)?linkedin\.com/(?:in|pub)/[a-zA-Z0-9_\-\./]+',
          caseSensitive: false,
        ).firstMatch(originalResume);
        if (urlMatch != null) {
          var url = urlMatch.group(0)!.replaceAll(RegExp(r'\s+'), '');
          if (!url.startsWith('http')) url = 'https://$url';
          links.add(_ResumeLink('LinkedIn', url));
        }
      } else if (pLower.contains('github')) {
        final urlMatch = RegExp(
          r'(?:https?://)?(?:www\.)?github\.com/[a-zA-Z0-9_\-\./]+',
          caseSensitive: false,
        ).firstMatch(originalResume);
        if (urlMatch != null) {
          var url = urlMatch.group(0)!.replaceAll(RegExp(r'\s+'), '');
          if (!url.startsWith('http')) url = 'https://$url';
          links.add(_ResumeLink('GitHub', url));
        }
      } else if (pLower.contains('portfolio') || pLower.contains('website')) {
        final urlMatch = RegExp(
          r'\[?(?:Portfolio|Website)\]?[\s:(]+(https?://[^\s|\n\)]+|(?:www\.)?[a-zA-Z0-9\-]+\.(?:dev|me|io|com|app|tech)[^\s|\n\)]*)',
          caseSensitive: false,
        ).firstMatch(originalResume) ??
        RegExp(
          r'https?://(?:www\.)?[a-zA-Z0-9\-]+(?:\.(?:dev|me|io|app)|(?:portfolio|github\.io))[a-zA-Z0-9\-\._~:/?#\[\]@!$&()*+,;=%]*',
          caseSensitive: false,
        ).firstMatch(originalResume);
        if (urlMatch != null) {
          var url = (urlMatch.group(1) ?? urlMatch.group(0))!.trim().replaceAll(RegExp(r'\s+'), '');
          url = url.replaceAll(RegExp(r'[\)\]\s]+$'), '');
          if (!url.startsWith('http')) url = 'https://$url';
          links.add(_ResumeLink('Portfolio', url));
        }
      }
    }

    return links;
  }

  /// Sanitizes text for Helvetica font, eliminating all missing glyphs / tofu boxes
  static String _sanitizeForPdf(String text) {
    var s = text;
    // Replace unicode dashes with ASCII hyphen
    s = s.replaceAll('\u2013', '-'); // en-dash
    s = s.replaceAll('\u2014', '-'); // em-dash
    s = s.replaceAll('\u2212', '-'); // minus sign
    // Replace smart quotes
    s = s.replaceAll('\u2018', "'");
    s = s.replaceAll('\u2019', "'");
    s = s.replaceAll('\u201C', '"');
    s = s.replaceAll('\u201D', '"');
    // Normalize bullets to standard bullet • so the parser recognizes them
    s = s.replaceAll('\u00B7', '•');
    s = s.replaceAll('\u25AA', '•');
    s = s.replaceAll('\u25CF', '•');
    // Strip Unicode arrow symbols (Helvetica has no glyph for U+2197, rendering tofu boxes)
    s = s.replaceAll('↗', '');
    s = s.replaceAll('\u2197', '');
    // Clean duplicate spaces and commas
    s = s.replaceAll(
      RegExp(r',\s*India\s*,\s*India', caseSensitive: false),
      ', India',
    );
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
    return s.trim();
  }

  static bool _isSectionHeader(String line) {
    if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*')) {
      if (!line.contains('#') && line.length > 25) return false;
    }
    final clean = line
        .replaceAll(RegExp(r'^[\-\*•#\s]+'), '')
        .replaceAll('#', '')
        .replaceAll(':', '')
        .trim()
        .toUpperCase();
    if (clean.isEmpty || clean.length > 35) return false;

    return clean == 'PROFESSIONAL SUMMARY' ||
        clean == 'SUMMARY' ||
        clean == 'PROFILE' ||
        clean == 'ABOUT ME' ||
        clean == 'TECHNICAL SKILLS' ||
        clean == 'SKILLS' ||
        clean == 'CORE COMPETENCIES' ||
        clean == 'AREAS OF EXPERTISE' ||
        clean == 'PROFESSIONAL SKILLS' ||
        clean == 'KEY SKILLS' ||
        clean == 'PROFESSIONAL EXPERIENCE' ||
        clean == 'EXPERIENCE' ||
        clean == 'WORK EXPERIENCE' ||
        clean == 'WORK HISTORY' ||
        clean == 'EMPLOYMENT' ||
        clean == 'PROJECTS' ||
        clean == 'KEY PROJECTS' ||
        clean == 'ACADEMIC PROJECTS' ||
        clean == 'EDUCATION' ||
        clean == 'ACADEMIC BACKGROUND' ||
        clean == 'ACADEMIC' ||
        clean == 'CERTIFICATIONS' ||
        clean == 'ACHIEVEMENTS';
  }
}
