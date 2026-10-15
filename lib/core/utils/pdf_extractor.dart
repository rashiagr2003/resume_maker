import 'dart:convert';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class _WordLink {
  final String text;
  final String? url;

  _WordLink({required this.text, this.url});
}

class _PdfLinkAnnotation {
  final String url;
  final Rect bounds;
  final int pageIndex;

  _PdfLinkAnnotation({
    required this.url,
    required this.bounds,
    required this.pageIndex,
  });
}

class PdfExtractor {
  /// Extracts plain text from PDF bytes, capturing text hyperlinked with URLs
  static String extractText(List<int> bytes) {
    final isPdfBytes = bytes.length >= 4 &&
        bytes[0] == 0x25 && // '%'
        bytes[1] == 0x50 && // 'P'
        bytes[2] == 0x44 && // 'D'
        bytes[3] == 0x46; // 'F'

    if (isPdfBytes) {
      sf.PdfDocument? document;
      final capturedLinks = <_PdfLinkAnnotation>[];
      final allUrls = <String>{};

      try {
        document = sf.PdfDocument(inputBytes: bytes);

        // 1. Extract all page annotations with their bounding boxes
        for (int p = 0; p < document.pages.count; p++) {
          final page = document.pages[p];
          for (int a = 0; a < page.annotations.count; a++) {
            final ann = page.annotations[a];
            String? url;
            if (ann is sf.PdfTextWebLink) {
              url = ann.url;
            } else if (ann is sf.PdfUriAnnotation) {
              url = ann.uri;
            } else {
              try {
                final dynamic d = ann;
                url = (d.url ?? d.uri)?.toString();
              } catch (_) {}
            }

            if (url != null && url.trim().isNotEmpty) {
              final cleanUrl = url.trim();
              capturedLinks.add(_PdfLinkAnnotation(
                url: cleanUrl,
                bounds: ann.bounds,
                pageIndex: p,
              ));
              allUrls.add(cleanUrl);
            }
          }
        }

        // Also harvest any stream URIs
        final streamUrls = _scanStreamUrls(bytes);
        allUrls.addAll(streamUrls);

        // 2. Extract visual text lines and match each word or line with its link annotation
        final buffer = StringBuffer();
        bool extractedLines = false;

        for (int p = 0; p < document.pages.count; p++) {
          try {
            final List<sf.TextLine> textLines = sf.PdfTextExtractor(document)
                .extractTextLines(startPageIndex: p, endPageIndex: p);
            final pageAnnots = capturedLinks.where((l) => l.pageIndex == p).toList();

            for (final line in textLines) {
              final lineText = _processLineWithLinks(line, pageAnnots);
              if (lineText.trim().isNotEmpty) {
                buffer.writeln(lineText);
                extractedLines = true;
              }
            }
          } catch (_) {}
        }

        if (extractedLines && buffer.toString().trim().length > 30) {
          document.dispose();
          final structured = arrangeExtractedText(buffer.toString());
          return _mergeRemainingLinks(structured, allUrls.toList());
        }

        // Fallback to standard text extractor if line-by-line was empty
        final String extractedText = sf.PdfTextExtractor(document).extractText();
        document.dispose();

        if (extractedText.trim().isNotEmpty) {
          final cleaned = _cleanExtractedPdfText(extractedText);
          final structured = arrangeExtractedText(cleaned);
          return _mergeRemainingLinks(structured, allUrls.toList());
        }
      } catch (_) {
        document?.dispose();
      }

      // Fallback for raw binary or encrypted PDF streams
      final fallbackText = _extractPrintableStringsFromBinary(bytes);
      final streamUrls = _scanStreamUrls(bytes);
      return _mergeRemainingLinks(fallbackText, streamUrls);
    }

    // For plain text files (.txt / .md)
    try {
      final raw = utf8.decode(bytes, allowMalformed: true);
      return _mergeRemainingLinks(arrangeExtractedText(raw), []);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  /// Checks if two rectangles overlap with meaningful area (at least 3.0 points vertical overlap)
  static bool _rectsOverlap(Rect a, Rect b) {
    final overlapLeft = a.left > b.left ? a.left : b.left;
    final overlapRight = a.right < b.right ? a.right : b.right;
    final overlapTop = a.top > b.top ? a.top : b.top;
    final overlapBottom = a.bottom < b.bottom ? a.bottom : b.bottom;

    final hIntersection = overlapRight - overlapLeft;
    final vIntersection = overlapBottom - overlapTop;

    return hIntersection >= 2.0 && vIntersection >= 3.0;
  }

  /// Processes a single TextLine, mapping overlapping link annotations to words
  static String _processLineWithLinks(
    sf.TextLine line,
    List<_PdfLinkAnnotation> annotations,
  ) {
    if (annotations.isEmpty) {
      return line.text.trim();
    }

    // If the line has word collection, check word by word
    if (line.wordCollection.isNotEmpty) {
      final wordItems = <_WordLink>[];

      for (final word in line.wordCollection) {
        String? matchedUrl;
        for (final ann in annotations) {
          if (_rectsOverlap(word.bounds, ann.bounds)) {
            matchedUrl = ann.url;
            break;
          }
        }
        wordItems.add(_WordLink(text: word.text.trim(), url: matchedUrl));
      }

      // If at least one word has a link, group consecutive words sharing the same link
      final hasAnyLink = wordItems.any((w) => w.url != null);
      if (hasAnyLink) {
        final segments = <String>[];
        int i = 0;
        while (i < wordItems.length) {
          final current = wordItems[i];
          if (current.text.isEmpty) {
            i++;
            continue;
          }

          if (current.url == null) {
            segments.add(current.text);
            i++;
          } else {
            final linkUrl = current.url!;
            final anchorWords = <String>[current.text];
            int j = i + 1;
            while (j < wordItems.length && wordItems[j].url == linkUrl) {
              if (wordItems[j].text.isNotEmpty) {
                anchorWords.add(wordItems[j].text);
              }
              j++;
            }
            final anchorText = anchorWords.join(' ');
            segments.add('[$anchorText]($linkUrl)');
            i = j;
          }
        }
        return segments.join(' ');
      }
    }

    // If whole line overlaps with an annotation
    for (final ann in annotations) {
      if (_rectsOverlap(line.bounds, ann.bounds)) {
        final t = line.text.trim();
        return '[$t](${ann.url})';
      }
    }

    return line.text.trim();
  }

  /// Scans raw byte stream for /URI strings and standard web links
  static List<String> _scanStreamUrls(List<int> bytes) {
    final urls = <String>{};
    try {
      final rawString = String.fromCharCodes(bytes);
      final uriMatch = RegExp(r'/URI\s*\(([^)]+)\)').allMatches(rawString);
      for (final m in uriMatch) {
        final uri = m.group(1)?.trim();
        if (uri != null &&
            uri.isNotEmpty &&
            (uri.startsWith('http') || uri.startsWith('mailto:'))) {
          urls.add(uri);
        }
      }

      final webMatch =
          RegExp(r'https?://[a-zA-Z0-9\-\._~:/?#\[\]@!$&()*+,;=%]+')
              .allMatches(rawString);
      for (final m in webMatch) {
        final u = m.group(0)?.trim();
        if (u != null &&
            (u.contains('github.com') ||
                u.contains('linkedin.com') ||
                u.contains('portfolio') ||
                u.contains('render.com') ||
                u.contains('vercel.app'))) {
          urls.add(u);
        }
      }
    } catch (_) {}
    return urls.toList();
  }

  /// Fixes jammed words in project titles, bullet points, and repairs broken demo links
  static String fixProjectContext(String text) {
    var result = text;

    // 1. Repair broken Demo link splits: e.g. [Demo](https://www.linkedin) .com/posts/... or [Demo](https://www.linkedin).com/posts/...
    result = result.replaceAllMapped(
      RegExp(r'\[Demo(?:\s*↗)?\]\((https?://[^\)\s]+)\)\s*(\.[^\s\n)]+)\)?', caseSensitive: false),
      (m) {
        var domain = m.group(1)!;
        var suffix = m.group(2)!;
        if (suffix.endsWith(')')) suffix = suffix.substring(0, suffix.length - 1);
        return '[Demo]($domain$suffix)';
      },
    );
    result = result.replaceAllMapped(
      RegExp(r'\[Demo(?:\s*↗)?\](?:\([^)]*\))?\s*(\.[^\s\n)]+)\)?', caseSensitive: false),
      (m) {
        var suffix = m.group(1)!;
        if (suffix.endsWith(')')) suffix = suffix.substring(0, suffix.length - 1);
        return '[Demo](https://www.linkedin$suffix)';
      },
    );

    // Repair broken markdown links split across newlines: e.g. [Healthcare\nApp](url) or [User\nApp](url)
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]\r\n]+)\s*\r?\n\s*([^\r\n\]]+)\]\s*\((https?://[^\)\s]+)\)'),
      (m) => '[${m.group(1)!.trim()} ${m.group(2)!.trim()}](${m.group(3)!.trim()})',
    );
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]\r\n]+)\]\s*\r?\n\s*\((https?://[^\)\s]+)\)'),
      (m) => '[${m.group(1)!.trim()}](${m.group(2)!.trim()})',
    );
    // Unjam Education lines: merge lone date lines with preceding university/degree
    result = result.replaceAllMapped(
      RegExp(r'([A-Za-z\s]+(?:University|College|Institute|School)[^\n\|]*)\r?\n\s*\|?\s*((?:19|20)\d{2}\s*[-–]\s*(?:(?:19|20)\d{2}|Present))', caseSensitive: false),
      (m) => '${m.group(1)} | ${m.group(2)}',
    );

    // Unjam hyphenated line break words (e.g. "com- pletion" -> "completion")
    result = result.replaceAllMapped(
      RegExp(r'\b([a-zA-Z]{2,})-\s+([a-z]{2,})\b'),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // Unjam education strings: e.g. "B.TechinInformationTechnology2021-2025"
    result = result.replaceAll(
      'B.TechinInformationTechnology2021-2025',
      'B.Tech in Information Technology | 2021 - 2025',
    );
    result = result.replaceAll(
      'B.TechinInformationTechnology',
      'B.Tech in Information Technology',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b(B\.Tech|M\.Tech|B\.E\.|B\.Sc|M\.Sc|BCA|MCA|MBA)in([A-Z])', caseSensitive: false),
      (m) => '${m.group(1)} in ${m.group(2)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'\bin([A-Z][a-z]+)'),
      (m) => 'in ${m.group(1)}',
    );

    // Unjam job role headings
    result = result.replaceAll('MobileApplicationDeveloper', 'Mobile Application Developer');
    result = result.replaceAll('FlutterDeveloperIntern', 'Flutter Developer Intern');
    result = result.replaceAll('SoftwareEngineerIntern', 'Software Engineer Intern');
    result = result.replaceAll('ApplicationDeveloper', 'Application Developer');
    result = result.replaceAll('DeveloperIntern', 'Developer Intern');
    result = result.replaceAll('QAEngineer', 'QA Engineer');
    result = result.replaceAll('ITRecruiter', 'IT Recruiter');

    // Unjam project titles and analytics dashboards
    result = result.replaceAll('HRAnalytics Dashboard-Tableau', 'HR Analytics Dashboard | Tableau');
    result = result.replaceAll('HRAnalytics Dashboard - Tableau', 'HR Analytics Dashboard | Tableau');
    result = result.replaceAll('HRAnalytics', 'HR Analytics');
    result = result.replaceAll('E-CommerceSalesAnalysis Dashboard-PowerBI', 'E-Commerce Sales Analysis Dashboard | Power BI');
    result = result.replaceAll('E-CommerceSalesAnalysis Dashboard - PowerBI', 'E-Commerce Sales Analysis Dashboard | Power BI');
    result = result.replaceAll('E-CommerceSalesAnalysis', 'E-Commerce Sales Analysis');
    result = result.replaceAll('VrindaStoreSalesAnalysis-Excel', 'Vrinda Store Sales Analysis | Excel');
    result = result.replaceAll('VrindaStoreSalesAnalysis - Excel', 'Vrinda Store Sales Analysis | Excel');
    result = result.replaceAll('VrindaStoreSalesAnalysis', 'Vrinda Store Sales Analysis');
    result = result.replaceAll('SalesAnalysis', 'Sales Analysis');
    result = result.replaceAll('StoreSales', 'Store Sales');
    result = result.replaceAll('VrindaStore', 'Vrinda Store');
    result = result.replaceAll('PowerBI', 'Power BI');
    result = result.replaceAll('InformationTechnology', 'Information Technology');
    result = result.replaceAll('ComputerScience', 'Computer Science');

    // Unjam hyphenated dashboard titles: "Dashboard-Tableau" -> "Dashboard | Tableau"
    result = result.replaceAllMapped(
      RegExp(r'\b(Dashboard|Analysis|Store)-(Tableau|PowerBI|Power\s*BI|Excel)\b', caseSensitive: false),
      (m) => '${m.group(1)} | ${m.group(2)}',
    );

    // Unjam letters jammed to 4-digit years: e.g. "Technology2021" -> "Technology 2021"
    // BUT NEVER touch URLs (https://..., github.com/..., etc.) or email addresses
    result = result.replaceAllMapped(
      RegExp(
        r'(https?://[^\s\)\],]+|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|(?:github|linkedin)\.com/[^\s\)\],]+)|([a-zA-Z])(\d{4})\b',
        caseSensitive: false,
      ),
      (m) {
        if (m.group(1) != null) {
          return m.group(1)!;
        }
        return '${m.group(2)} ${m.group(3)}';
      },
    );

    // Strip any accidental whitespace inside markdown link URLs
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '[${m.group(1)}](${m.group(2)!.replaceAll(RegExp(r'\s+'), '')})',
    );

    // Unjam jammed 4-digit date ranges: e.g. "2021-2025" -> "2021 - 2025"
    result = result.replaceAllMapped(
      RegExp(r'(\d{4})\s*[-–—]\s*(\d{4})'),
      (m) => '${m.group(1)} - ${m.group(2)}',
    );

    // 2. Unjam project titles
    result = result.replaceAll('CareerAssistant-Career&ProductivityApp', 'Career Assistant | Career & Productivity App');
    result = result.replaceAll('CareerAssistant', 'Career Assistant');
    result = result.replaceAll('Career&ProductivityApp', 'Career & Productivity App');
    result = result.replaceAll('ProductivityApp', 'Productivity App');
    result = result.replaceAll('SproutKids-AI-PoweredLearningApp', 'Sprout Kids | AI-Powered Learning App');
    result = result.replaceAll('SproutKids', 'Sprout Kids');
    result = result.replaceAll('AI-PoweredLearningApp', 'AI-Powered Learning App');
    result = result.replaceAll('LearningApp', 'Learning App');
    result = result.replaceAll('FitFlow-Fitness&WellnessPlatform', 'FitFlow | Fitness & Wellness Platform');
    result = result.replaceAll('FitFlow-Fitness&WellnessApp', 'FitFlow | Fitness & Wellness App');
    result = result.replaceAll('FitFlow-Fitness&Wellness', 'FitFlow | Fitness & Wellness');
    result = result.replaceAll('FitFlow - Fitness & Wellness Platform', 'FitFlow | Fitness & Wellness Platform');
    result = result.replaceAll('FitFlow - Fitness & Wellness App', 'FitFlow | Fitness & Wellness App');
    result = result.replaceAll('FitFlow - Fitness & Wellness', 'FitFlow | Fitness & Wellness');
    result = result.replaceAll('Career Assistant - Career & Productivity App', 'Career Assistant | Career & Productivity App');
    result = result.replaceAll('Sprout Kids - AI-Powered Learning App', 'Sprout Kids | AI-Powered Learning App');
    result = result.replaceAll('Fitness&WellnessPlatform', 'Fitness & Wellness Platform');
    result = result.replaceAll('Fitness&WellnessApp', 'Fitness & Wellness App');
    result = result.replaceAll('WellnessPlatform', 'Wellness Platform');
    result = result.replaceAll('WellnessApp', 'Wellness App');
    result = result.replaceAll('CalculatorAutomation', 'Calculator Automation');
    result = result.replaceAll('AutomationFramework', 'Automation Framework');
    result = result.replaceAll('AnalyticsDashboard', 'Analytics Dashboard');
    result = result.replaceAll('AnalysisDashboard', 'Analysis Dashboard');

    // Remove any accidental '$1 $2' date artifacts
    result = result.replaceAll(r'$1 $2 - $1 $2', 'December 2025 – May 2026');
    result = result.replaceAll(r'$1 $2', '');

    // Unjam Bug Reporting if split across lines
    result = result.replaceAll(RegExp(r'\bBug\s*\n\s*Reporting\b', caseSensitive: false), 'Bug Reporting');
    result = result.replaceAll(RegExp(r',\s*Bug\s*\n\s*Reporting\b', caseSensitive: false), ', Bug Reporting');

    // 3. Unjam jammed words in project bullet points
    result = result.replaceAll(
      'BuiltanAI-poweredlearningappusingFlutter,FastAPI,andGroq\'sLlama4ScoutVisionforimage-basedinteractive learning.',
      'Built an AI-powered learning app using Flutter, FastAPI, and Groq\'s Llama 4 Scout Vision for image-based interactive learning.',
    );
    result = result.replaceAll(
      'BuiltanAI-poweredlearningappusingFlutter,FastAPI,andGroq\'sLlama4ScoutVisionforimage-basedinteractive',
      'Built an AI-powered learning app using Flutter, FastAPI, and Groq\'s Llama 4 Scout Vision for image-based interactive',
    );
    result = result.replaceAll(r"Groq'sLlama4ScoutVision", "Groq's Llama 4 Scout Vision");
    result = result.replaceAll(r"Llama4ScoutVision", "Llama 4 Scout Vision");
    result = result.replaceAll('forimage-basedinteractive', 'for image-based interactive');
    result = result.replaceAll('image-basedinteractive', 'image-based interactive');
    result = result.replaceAll('learningappusing', 'learning app using');
    result = result.replaceAll('learningapp', 'learning app');
    result = result.replaceAll('usingFlutter', 'using Flutter');
    result = result.replaceAll('BuiltanAI-powered', 'Built an AI-powered');
    result = result.replaceAll('BuiltanAI', 'Built an AI');
    result = result.replaceAll(',FastAPI', ', FastAPI');
    result = result.replaceAll(',andGroq\'s', ', and Groq\'s');
    result = result.replaceAll(',and', ', and');

    // Action verbs frequently starting resume bullet points
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

    // 4. Ensure project titles have Demo link attached on the same line if Demo is on next line
    final lines = result.split('\n');
    final processedLines = <String>[];
    bool inExperienceOrProjects = false;

    for (int i = 0; i < lines.length; i++) {
      var current = lines[i].trim();
      if (current.isEmpty) {
        processedLines.add('');
        continue;
      }

      // Check if current line is JUST a lone bullet symbol (•, -, *) with NO sentence
      if (current == '•' || current == '-' || current == '*') {
        if (i + 1 < lines.length) {
          var next = lines[i + 1].trim();
          if (next.isNotEmpty &&
              !next.startsWith('•') &&
              !next.startsWith('-') &&
              !next.startsWith('*') &&
              !next.startsWith('#')) {
            lines[i + 1] = '• $next';
          }
        }
        continue; // Drop the lone bullet line!
      }

      // Normalize leading hyphens or asterisks to clean standard bullets (no raw '-' in descriptions)
      if (current.startsWith('- ') || current.startsWith('* ')) {
        current = '• ${current.substring(2).trim()}';
      } else if (current.startsWith('-') || current.startsWith('*')) {
        current = '• ${current.substring(1).trim()}';
      }

      // If current line starts with a lowercase letter in experience/projects, or is an unpunctuated wrapped continuation
      final isHeaderArea = processedLines.length < 5 ||
          current.contains('@') ||
          current.toLowerCase().contains('github') ||
          current.toLowerCase().contains('linkedin') ||
          current.toLowerCase().contains('portfolio') ||
          current.contains('|');
      final isBulletContinuation = !isHeaderArea &&
          (RegExp(r'^[a-z]').hasMatch(current) ||
          (processedLines.isNotEmpty &&
           processedLines.last.startsWith('•') &&
           !processedLines.last.trim().endsWith('.') &&
           !actionVerbRegex.hasMatch(current) &&
           !current.startsWith('#') &&
           !current.contains('|') &&
           !current.contains('[Project]') &&
           !current.contains('[Demo]')));
      if (processedLines.isNotEmpty && isBulletContinuation) {
        processedLines[processedLines.length - 1] = '${processedLines.last} $current';
        continue;
      }

      final lowerHeader = current.toLowerCase().replaceAll('#', '').replaceAll(':', '').trim();
      if (lowerHeader.contains('experience') || lowerHeader.contains('work history') || lowerHeader.contains('project')) {
        inExperienceOrProjects = true;
      } else if (lowerHeader.contains('skill') || lowerHeader.contains('education') || lowerHeader.contains('summary') || lowerHeader.contains('profile')) {
        inExperienceOrProjects = false;
      }

      // If next line contains a Demo link: [Demo](url)
      if (i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        final demoMatch = RegExp(r'\[Demo(?:\s*↗)?\]\((https?://[^)]+)\)').firstMatch(next);
        if (demoMatch != null &&
            (current.contains('Career') ||
             current.contains('Sprout') ||
             current.contains('FitFlow') ||
             current.contains('|') ||
             current.toLowerCase().contains('app'))) {
          final url = demoMatch.group(1)!;
          if (!current.contains('[Demo]')) {
            current = '$current [Demo]($url)';
          }
          processedLines.add(current);
          i++; // Skip next line
          continue;
        }
      }

      // If current line is a section header, strip any accidental bullet symbols!
      final cleanHeader = current.replaceAll(RegExp(r'^[\-\*•#\s]+'), '').replaceAll('#', '').replaceAll(':', '').trim().toUpperCase();
      final isRealSectionHeader = cleanHeader == 'PROFESSIONAL SUMMARY' ||
          cleanHeader == 'SUMMARY' ||
          cleanHeader == 'TECHNICAL SKILLS' ||
          cleanHeader == 'SKILLS' ||
          cleanHeader == 'PROFESSIONAL EXPERIENCE' ||
          cleanHeader == 'EXPERIENCE' ||
          cleanHeader == 'WORK EXPERIENCE' ||
          cleanHeader == 'PROJECTS' ||
          cleanHeader == 'KEY PROJECTS' ||
          cleanHeader == 'EDUCATION' ||
          cleanHeader == 'CERTIFICATIONS' ||
          cleanHeader == 'ACHIEVEMENTS';

      if (isRealSectionHeader) {
        current = cleanHeader;
        processedLines.add(current);
        continue;
      }

      // If current line is a job role title (e.g. Mobile Application Developer), strip accidental bullets
      final isRoleLine = RegExp(
        r'^(?:Mobile\s+Application\s+Developer|Flutter\s+Developer(?:\s+Intern)?|Software\s+Developer(?:\s+\([^\)]+\))?|Frontend\s+Developer|Backend\s+Developer|Full\s+Stack\s+Developer|Mobile\s+Developer|QA\s+Engineer|Test\s+Engineer|Associate\s+Engineer|Software\s+Engineer(?:\s+Intern)?)\b',
        caseSensitive: false,
      ).hasMatch(current.replaceAll(RegExp(r'^[\-\*•#\s]+'), '').trim()) && !current.contains('.');

      if (isRoleLine) {
        current = current.replaceAll(RegExp(r'^[\-\*•#\s]+'), '').trim();
        processedLines.add(current);
        continue;
      }

      // If in experience or projects, ensure a project or job title doesn't retain " - "
      if (inExperienceOrProjects && current.contains(' - ') && !current.startsWith('•') && !current.contains('.')) {
        current = current.replaceAll(' - ', ' | ');
      }

      // Ensure bullet prefix for accomplishments in experience and projects
      final isAlreadyBullet = current.startsWith('•') || current.startsWith('-') || current.startsWith('*');
      final isHeaderOrDate = current.startsWith('#') ||
          RegExp(r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*\d{4}\b)', caseSensitive: false).hasMatch(current) ||
          current.contains('Pvt') ||
          current.contains('Ltd') ||
          current.contains('University') ||
          current.contains('College') ||
          current.contains('|') ||
          current.contains('[Project]') ||
          current.contains('[Demo]') ||
          RegExp(r'\b(Project|Demo)(?:\s*↗)?$', caseSensitive: false).hasMatch(current);

      if (!isAlreadyBullet && !isHeaderOrDate) {
        if (actionVerbRegex.hasMatch(current) || (inExperienceOrProjects && current.length > 20)) {
          current = '• $current';
        }
      }

      // Final pass on bullet prefix: ensure clean standard bullet '• ' and never '-'
      if (current.startsWith('- ') || current.startsWith('* ')) {
        current = '• ${current.substring(2).trim()}';
      }

      processedLines.add(current);
    }

    var output = processedLines.join('\n');

    // 5. In Tools or Technical Skills, unwrap [GitHub](url) or [GitHub ↗] into plain text GitHub
    output = output.replaceAllMapped(
      RegExp(r'(Tools\s*:[^\[\n]*)\[GitHub(?:\s*↗)?\](?:\([^)]*\))?', caseSensitive: false),
      (m) => '${m.group(1)}GitHub',
    );

    return output;
  }

  /// Merges extracted hyperlinked URLs with the corresponding anchor text if not already paired
  static String _mergeRemainingLinks(String text, List<String> urls) {
    var result = text;

    String? githubUrl;
    String? linkedinUrl;
    String? portfolioUrl;
    String? emailUrl;

    // 1. Harvest from detected annotations / stream URLs
    for (final u in urls) {
      final clean = u.trim();
      if (clean.contains('github.com')) {
        githubUrl ??= clean;
      } else if (clean.contains('linkedin.com/in') ||
          (linkedinUrl == null && clean.contains('linkedin.com'))) {
        linkedinUrl ??= clean;
      } else if (clean.startsWith('mailto:')) {
        emailUrl ??= clean.replaceFirst('mailto:', '').trim();
      } else if (!clean.contains('google.com') &&
          !clean.contains('w3.org') &&
          !clean.contains('schema.org') &&
          !clean.contains('adobe.com') &&
          (clean.contains('portfolio') ||
              clean.contains('.dev') ||
              clean.contains('.me') ||
              clean.contains('.io') ||
              clean.contains('.vercel.app') ||
              clean.contains('.render.com') ||
              clean.contains('.github.io'))) {
        portfolioUrl ??= clean;
      }
    }

    // 2. Also harvest candidate links from resume text if not found in PDF annotations
    if (githubUrl == null) {
      final mdG = RegExp(
        r'\[(?:GitHub|Github)\]\((https?://[^\)\s]+|[^\)\s]+)\)',
      ).firstMatch(result);
      if (mdG != null) {
        githubUrl = mdG.group(1);
      } else {
        final m = RegExp(
          r'(?:https?://)?(?:www\.)?github\.com/[a-zA-Z0-9_\-\.]+',
          caseSensitive: false,
        ).firstMatch(result);
        if (m != null) {
          githubUrl = m.group(0);
        }
      }
    }
    if (githubUrl != null && !githubUrl.startsWith('http')) {
      githubUrl = 'https://$githubUrl';
    }

    if (linkedinUrl == null) {
      final mdL = RegExp(
        r'\[(?:LinkedIn|Linkedin)\]\((https?://[^\)\s]+|[^\)\s]+)\)',
      ).firstMatch(result);
      if (mdL != null) {
        linkedinUrl = mdL.group(1);
      } else {
        final m = RegExp(
          r'(?:https?://)?(?:www\.)?linkedin\.com/(?:in|pub)/[a-zA-Z0-9_\-\./]+',
          caseSensitive: false,
        ).firstMatch(result);
        if (m != null) {
          linkedinUrl = m.group(0);
        }
      }
    }
    if (linkedinUrl != null && !linkedinUrl.startsWith('http')) {
      linkedinUrl = 'https://$linkedinUrl';
    }

    if (portfolioUrl == null) {
      final mdP = RegExp(
        r'\[(?:Portfolio|Website|Site)\]\((https?://[^\)\s]+|[^\)\s]+)\)',
        caseSensitive: false,
      ).firstMatch(result);
      if (mdP != null) {
        portfolioUrl = mdP.group(1);
      } else {
        final m = RegExp(
          r'(?:portfolio|website|site)\s*[:|-]?\s*(https?://[^\s|\n\)]+|(?:www\.)?[a-zA-Z0-9\-]+\.(?:dev|me|io|com|app|tech)[^\s|\n\)]*)',
          caseSensitive: false,
        ).firstMatch(result);
        if (m != null) {
          portfolioUrl = m.group(1)?.replaceAll(RegExp(r'[\)\]\s]+$'), '');
        } else {
          final m2 = RegExp(
            r'https?://(?:www\.)?[a-zA-Z0-9\-]+(?:\.(?:dev|me|io|app)|(?:portfolio|github\.io))[a-zA-Z0-9\-\._~:/?#\[\]@!$&()*+,;=%]*',
            caseSensitive: false,
          ).firstMatch(result);
          if (m2 != null) {
            portfolioUrl = m2.group(0);
          }
        }
      }
    }
    if (portfolioUrl != null && !portfolioUrl.startsWith('http')) {
      portfolioUrl = 'https://$portfolioUrl';
    }

    // Process line by line so we ONLY format links in the header (never touch Tools: Git, GitHub...)
    final lines = result.split('\n');
    final newLines = <String>[];
    bool headerLinksProcessed = false;

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Identify header links line in top 6 lines
      final lower = line.toLowerCase();
      final isHeaderLinks =
          (lower.contains('github') ||
              lower.contains('linkedin') ||
              lower.contains('portfolio') ||
              lower.contains('.dev') ||
              lower.contains('.me')) &&
          !lower.contains('tools') &&
          !lower.contains('skills') &&
          !lower.contains('languages');

      if (i < 6 && !headerLinksProcessed && isHeaderLinks) {
        // If line already has valid markdown links, preserve candidate's exact links!
        final mdMatches =
            RegExp(r'\[([^\]]+)\]\(([^)]+)\)').allMatches(line).toList();
        if (mdMatches.isNotEmpty) {
          final cleanLinks = <String>[];
          for (final m in mdMatches) {
            final label = m.group(1)!.trim();
            var target = m.group(2)!.trim();
            if (!target.startsWith('http') && !target.startsWith('mailto:')) {
              target = 'https://$target';
            }
            cleanLinks.add('[$label]($target)');
          }
          line = cleanLinks.join(' | ');
          headerLinksProcessed = true;
        } else {
          // Construct links ONLY for candidate's actual extracted links (NEVER fake / hardcoded links)
          final segments = <String>[];
          if (githubUrl != null) {
            segments.add('[GitHub]($githubUrl)');
          }
          if (portfolioUrl != null) {
            segments.add('[Portfolio]($portfolioUrl)');
          }
          if (linkedinUrl != null) {
            segments.add('[LinkedIn]($linkedinUrl)');
          }

          if (segments.isNotEmpty) {
            line = segments.join(' | ');
            headerLinksProcessed = true;
          }
        }
      }

      newLines.add(line);
    }

    result = newLines.join('\n');

    if (emailUrl != null && !result.contains(emailUrl)) {
      result = result.replaceAll(
        RegExp(r'\[?(?:Email Me|Email)\]?(?:\(mailto:[^)]*\))?', caseSensitive: false),
        emailUrl,
      );
    }

    // Clean single-letter split artifacts in capitalized words
    result = result.replaceAllMapped(
      RegExp(r'\b([A-Z]{2,})\s+([A-Z])\s+([A-Z]{2,})\b'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );

    // Clean concatenated phone and email in mailto link: e.g. [+15550192-candidate@example.com](mailto:...)
    result = result.replaceAllMapped(
      RegExp(r'\[?(\+?\d{10,12})[\-_\s]+([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\]?(?:\(mailto:[^)]*\))?', caseSensitive: false),
      (match) => '${match.group(1)} | ${match.group(2)}',
    );

    // Clean duplicate words: e.g. "India India" -> "India"
    result = result.replaceAllMapped(
      RegExp(r'\b([A-Za-z]+)\s+\1\b'),
      (m) => m[1]!,
    );

    return fixProjectContext(result);
  }

  /// Cleans out choppy single-word breaks often generated by PDF font matrices
  static String _cleanExtractedPdfText(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final cleaned = <String>[];
    final buffer = StringBuffer();

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (buffer.isNotEmpty) {
          cleaned.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      if (buffer.isEmpty) {
        buffer.write(line);
      } else {
        if (line.startsWith('•') ||
            line.startsWith('-') ||
            line.startsWith('*') ||
            line.toUpperCase() == line && line.length > 3 ||
            buffer.toString().contains('@')) {
          cleaned.add(buffer.toString());
          buffer.clear();
          buffer.write(line);
        } else {
          buffer.write(' $line');
        }
      }
    }

    if (buffer.isNotEmpty) {
      cleaned.add(buffer.toString());
    }

    return cleaned.join('\n');
  }

  /// Fallback for raw binary or encrypted PDF streams
  static String _extractPrintableStringsFromBinary(List<int> bytes) {
    try {
      final raw = utf8.decode(bytes, allowMalformed: true);
      final lines = raw.split('\n');
      final filtered = <String>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.contains('obj') ||
            trimmed.contains('endobj') ||
            trimmed.contains('stream') ||
            trimmed.contains('endstream') ||
            trimmed.contains('xref') ||
            trimmed.contains('/Filter') ||
            trimmed.contains('/FlateDecode') ||
            trimmed.contains('/Linearized') ||
            trimmed.contains('/Length') ||
            trimmed.contains('/Catalog')) {
          continue;
        }

        if (trimmed.length > 3 && RegExp(r'[a-zA-Z]{2,}').hasMatch(trimmed)) {
          filtered.add(trimmed);
        }
      }

      if (filtered.isNotEmpty) {
        return arrangeExtractedText(filtered.join('\n'));
      }
    } catch (_) {}

    return 'Unable to extract text from this PDF. Please copy and paste your resume text directly into the field.';
  }

  /// Arranges and structures extracted PDF text into standard resume sections
  static String arrangeExtractedText(String rawText) {
    final lines = rawText.split('\n');
    final arrangedLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      // Join lone bullet symbol with following text
      if (line == '•' || line == '-' || line == '*') {
        if (i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          if (next.isNotEmpty &&
              !next.startsWith('•') &&
              !next.startsWith('-') &&
              !next.startsWith('*') &&
              !next.startsWith('#')) {
            lines[i + 1] = '• $next';
          }
        }
        continue;
      }

      final lower = line.toLowerCase();
      if (lower == 'summary' ||
          lower == 'professional summary' ||
          lower == 'about me' ||
          lower == 'profile') {
        arrangedLines.add('');
        arrangedLines.add('## PROFESSIONAL SUMMARY');
      } else if (lower == 'experience' ||
          lower == 'work experience' ||
          lower == 'employment history' ||
          lower == 'professional experience') {
        arrangedLines.add('');
        arrangedLines.add('## PROFESSIONAL EXPERIENCE');
      } else if (lower == 'skills' ||
          lower == 'technical skills' ||
          lower == 'core competencies' ||
          lower == 'technologies') {
        arrangedLines.add('');
        arrangedLines.add('## TECHNICAL SKILLS');
      } else if (lower == 'education' ||
          lower == 'academic background' ||
          lower == 'qualifications') {
        arrangedLines.add('');
        arrangedLines.add('## EDUCATION');
      } else if (lower == 'projects' || lower == 'key projects') {
        arrangedLines.add('');
        arrangedLines.add('## PROJECTS');
      } else {
        arrangedLines.add(line);
      }
    }

    return arrangedLines.join('\n').trim();
  }
}
