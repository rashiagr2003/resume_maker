import 'dart:math';
import '../../core/utils/pdf_extractor.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/resume_input.dart';
import '../../domain/entities/tailored_resume.dart';
import '../../domain/entities/user_skill_entry.dart';
import '../models/analysis_result_dto.dart';
import 'truthful_resume_rewriter.dart';

typedef HeuristicLocalDatasource = HeuristicLocalDataSource;

class HeuristicLocalDataSource {
  static const List<String> _knownCities = [
    'San Francisco', 'San Jose', 'Sunnyvale', 'Mountain View', 'Palo Alto',
    'Seattle', 'New York', 'Austin', 'Boston', 'Chicago', 'Los Angeles',
    'London', 'Berlin', 'Munich', 'Amsterdam', 'Paris', 'Zurich', 'Dublin',
    'Bengaluru', 'Bangalore', 'Hyderabad', 'Pune', 'Mumbai', 'Delhi', 'Gurgaon',
    'Noida', 'Chennai', 'Kolkata', 'Singapore', 'Toronto', 'Vancouver',
    'Sydney', 'Melbourne', 'Tokyo', 'Remote'
  ];

  /// Comprehensive multi-domain skills and competency library
  static const List<String> _commonSkills = [
    // Mobile & Frontend
    'Flutter', 'Dart', 'Riverpod', 'Bloc', 'Provider', 'Clean Architecture',
    'React', 'React Native', 'Next.js', 'TypeScript', 'JavaScript', 'HTML5', 'CSS3',
    'Redux', 'Vue.js', 'Angular', 'Tailwind CSS', 'Swift', 'Kotlin', 'Android SDK', 'iOS',
    // Backend & Systems
    'Python', 'Django', 'FastAPI', 'Flask', 'Java', 'Spring Boot',
    'Node.js', 'Express', 'Go', 'Rust', 'C++', 'C#', '.NET', 'PHP', 'Ruby',
    // Databases, Cloud & DevOps
    'SQL', 'PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'Firebase',
    'AWS', 'GCP', 'Google Cloud', 'Azure', 'Docker', 'Kubernetes',
    'CI/CD', 'Git', 'GitHub Actions', 'Jenkins', 'Linux',
    'REST API', 'GraphQL', 'Microservices', 'WebSockets', 'OAuth',
    // QA & Automation
    'Unit Testing', 'TDD', 'Agile', 'Scrum', 'Jira', 'Selenium', 'Appium', 'Cypress',
    'Test Automation', 'Manual Testing', 'Postman', 'Bug Tracking', 'API Testing',
    // US & Global IT Recruitment & HR
    'US IT Recruitment', 'US Recruitment', 'Technical Recruitment', 'IT Recruitment',
    'Non-IT Recruitment', 'Talent Acquisition', 'International Staffing', 'Staffing',
    'Candidate Sourcing', 'Sourcing', 'Screening', 'Shortlisting',
    'Candidate Screening', 'Interview Coordination', 'Recruitment Pipeline',
    'Cold Calling', 'Client Outreach', 'Client Marketing', 'Boolean Search',
    'ATS', 'Job Boards', 'LinkedIn Recruiter', 'Dice', 'Monster', 'CareerBuilder',
    'Bench Sales', 'B2B Sales', 'Lead Generation', 'W2', 'C2C', '1099',
    'Rate Negotiation', 'Salary Negotiation', 'Onboarding', 'HR Operations',
    'US Night Shift', 'Night Shift',
    // Sales, Marketing & Business Development
    'Business Development', 'Account Management', 'CRM', 'Salesforce', 'HubSpot',
    'Digital Marketing', 'Content Marketing', 'Email Marketing', 'Market Research',
    'B2B Outreach', 'Customer Engagement', 'Social Media Marketing',
    // Data, AI & Analytics
    'Data Analysis', 'Data Analytics', 'Business Analytics', 'Tableau', 'Power BI',
    'Excel', 'Advanced Excel', 'Machine Learning', 'Data Science', 'Statistics',
    // Professional & Interpersonal Competencies
    'English Communication', 'Communication Skills', 'Stakeholder Management',
    'Negotiation', 'Problem Solving', 'Team Leadership', 'Time Management', 'Target-driven'
  ];

  /// Skill aliases and keyword variations to ensure robust, non-fragile matching
  static const Map<String, List<String>> _skillAliases = {
    'US IT Recruitment': ['us it recruiter', 'us it recruitment', 'us recruitment', 'us staffing', 'international staffing', 'client marketing'],
    'Candidate Sourcing': ['candidate sourcing', 'source candidates', 'sourcing', 'source'],
    'Screening & Shortlisting': ['screening', 'shortlisting', 'screen candidates', 'shortlist candidates', 'screen', 'shortlist'],
    'Interview Coordination': ['interview coordination', 'coordinate interviews', 'coordinating interviews', 'schedule interviews'],
    'Recruitment Pipeline': ['recruitment pipeline', 'recruiting pipeline', 'hiring pipeline'],
    'Cold Calling': ['cold calling', 'cold call', 'cold calls'],
    'Client Outreach': ['client outreach', 'us client outreach', 'client communication'],
    'English Communication': ['english communication', 'communication skills', 'excellent english'],
    'US Night Shift': ['us night shift', 'night shift', 'permanent night shift'],
    'Target-driven': ['target-driven', 'target driven', 'self-motivated'],
    'Clean Architecture': ['clean architecture', 'clean code'],
    'State Management': ['state management', 'bloc', 'riverpod', 'redux', 'provider'],
    'REST API': ['rest api', 'rest apis', 'restful api', 'restful apis', 'restful'],
    'CI/CD': ['ci/cd', 'continuous integration', 'github actions', 'jenkins'],
    'Test Automation': ['test automation', 'automated testing', 'selenium', 'appium'],
    'Data Analysis': ['data analysis', 'data analytics', 'business analysis', 'data insights'],
    'Go': ['golang', 'go lang', 'go programming', 'go developer', 'go backend', 'go language'],
  };

  /// Strict word-boundary matching to prevent false positives (e.g. "Block" -> "Bloc", "go wrong" -> "Go")
  static bool hasSkill(String text, String skill) {
    // Specifically handle 'Go' (the programming language) to prevent matching common English verb "go"
    if (skill.toLowerCase() == 'go') {
      final lowerText = text.toLowerCase();
      // 1. Matches technical aliases (golang, go lang, go programming, etc.)
      for (final alias in _skillAliases['Go']!) {
        if (_hasSkillExact(lowerText, alias)) {
          return true;
        }
      }
      // 2. Or matches case-sensitive "Go" in explicit technical listing context
      final techSkillsList = RegExp(
        r'(?:Languages|Tech Stack|Skills|Proficient in|Technologies)[^.\n]*\bGo\b',
        caseSensitive: true,
      );
      if (techSkillsList.hasMatch(text)) return true;
      final techComma = RegExp(
        r'(?:Python|Java|C\+\+|Rust|Node|React|Backend)[,\s/]+Go\b|\bGo[,\s/]+(?:Python|Java|C\+\+|Rust|Node)',
        caseSensitive: true,
      );
      if (techComma.hasMatch(text)) return true;

      return false;
    }

    final lowerText = text.toLowerCase();
    final lowerSkill = skill.toLowerCase();

    // Check mapped aliases first
    if (_skillAliases.containsKey(skill)) {
      for (final alias in _skillAliases[skill]!) {
        if (_hasSkillExact(lowerText, alias.toLowerCase())) {
          return true;
        }
      }
    }

    return _hasSkillExact(lowerText, lowerSkill);
  }

  static bool _hasSkillExact(String lowerText, String lowerSkill) {
    final escaped = RegExp.escape(lowerSkill);
    final leftBoundary = RegExp(r'^[a-z0-9]').hasMatch(lowerSkill) ? r'(?:^|[^\w])' : '';
    final rightBoundary = RegExp(r'[a-z0-9]$').hasMatch(lowerSkill) ? r'(?:[^\w]|$)' : '';
    final pattern = '$leftBoundary$escaped$rightBoundary';
    return RegExp(pattern).hasMatch(lowerText);
  }

  /// Extracts previous skills present in the candidate resume (from experience, projects, or text)
  static Set<String> extractPreviousSkills(String resumeText) {
    final skills = <String>{};
    for (final skill in _commonSkills) {
      if (hasSkill(resumeText, skill)) {
        skills.add(skill);
      }
    }
    final lower = resumeText.toLowerCase();
    if (lower.contains('pivot table') || lower.contains('slicer')) {
      skills.add('Advanced Excel (Pivot Tables & Slicers)');
      skills.remove('Excel');
      skills.remove('Advanced Excel');
    }
    if (lower.contains('tableau')) skills.add('Tableau');
    if (lower.contains('power bi') || lower.contains('powerbi')) skills.add('Power BI');
    if (lower.contains('rest api') || lower.contains('rest apis')) skills.add('REST APIs');
    if (lower.contains('application testing') || lower.contains('data validation')) {
      skills.add('Application Testing & Data Validation');
    }
    return skills;
  }

  String extractCity(String text) {
    for (final city in _knownCities) {
      final reg = RegExp(r'\b' + RegExp.escape(city) + r'\b', caseSensitive: false);
      if (reg.hasMatch(text)) {
        final cLower = city.toLowerCase();
        if (cLower == 'bangalore' || cLower == 'bengaluru') return 'Bengaluru, India';
        if (cLower == 'noida') return 'Noida, India';
        if (cLower == 'gurgaon') return 'Gurgaon, India';
        if (cLower == 'delhi') return 'Delhi, India';
        if (cLower == 'mumbai') return 'Mumbai, India';
        if (cLower == 'pune') return 'Pune, India';
        if (cLower == 'hyderabad') return 'Hyderabad, India';
        if (cLower == 'chennai') return 'Chennai, India';
        if (cLower == 'kolkata') return 'Kolkata, India';
        if (cLower == 'san francisco') return 'San Francisco, CA';
        if (cLower == 'new york') return 'New York, NY';
        if (cLower == 'seattle') return 'Seattle, WA';
        if (cLower == 'austin') return 'Austin, TX';
        if (cLower == 'london') return 'London, UK';
        if (cLower == 'berlin') return 'Berlin, Germany';
        if (cLower == 'singapore') return 'Singapore';
        if (cLower == 'toronto') return 'Toronto, Canada';
        return city;
      }
    }
    return 'Remote / Flexible';
  }

  /// Dynamic Role Title Extraction from JD
  String extractRole(String jdText, [String? optionalRole]) {
    if (optionalRole != null && optionalRole.trim().isNotEmpty) {
      return optionalRole.trim();
    }

    final roleMatch = RegExp(
      r'(?:💼\s*)?(?:Role|Position|Job\s*Title|Designation|HIRING)\s*[:–—\-]\s*([^\n\r,–—|📍()]+)',
      caseSensitive: false,
    ).firstMatch(jdText);
    if (roleMatch != null) {
      final role = roleMatch.group(1)!.trim();
      if (role.isNotEmpty && role.length > 2 && role.length < 50) {
        return role;
      }
    }

    final lookingForMatch = RegExp(
      r'(?:looking for an?|seeking an?|hiring an?)\s+([A-Z][A-Za-z\s]+?)\s+(?:who|to|with|\.)',
    ).firstMatch(jdText);
    if (lookingForMatch != null) {
      final role = lookingForMatch.group(1)!.trim();
      if (role.isNotEmpty && role.length > 2 && role.length < 40) {
        return role;
      }
    }

    final lower = jdText.toLowerCase();
    if (lower.contains('us it recruiter')) return 'US IT Recruiter';
    if (lower.contains('technical recruiter')) return 'Technical Recruiter';
    if (lower.contains('talent acquisition')) return 'Talent Acquisition Specialist';
    if (lower.contains('recruiter')) return 'Recruiter';
    if (lower.contains('manual tester') || lower.contains('manual testing')) return 'Manual QA Tester';
    if (lower.contains('qa automation') || lower.contains('automation tester')) return 'QA Automation Tester';
    if (lower.contains('qa tester') || lower.contains('software tester') || lower.contains('qa engineer')) return 'QA Engineer';
    if (lower.contains('tester')) return 'QA Tester';
    if (lower.contains('flutter developer')) return 'Flutter Developer';
    if (lower.contains('mobile developer')) return 'Mobile App Developer';
    if (lower.contains('software engineer')) return 'Software Engineer';
    if (lower.contains('full stack developer')) return 'Full Stack Developer';
    if (lower.contains('frontend developer')) return 'Frontend Developer';
    if (lower.contains('backend developer')) return 'Backend Developer';
    if (lower.contains('data scientist')) return 'Data Scientist';
    if (lower.contains('data analyst')) return 'Data Analyst';
    if (lower.contains('product manager')) return 'Product Manager';
    if (lower.contains('project manager')) return 'Project Manager';
    if (lower.contains('business development') || lower.contains('b2b sales')) return 'Business Development Executive';
    if (lower.contains('marketing specialist') || lower.contains('digital marketing')) return 'Marketing Specialist';
    if (lower.contains('financial analyst') || lower.contains('accountant')) return 'Financial Analyst';

    return 'Target Role';
  }

  /// Dynamic Industry Domain Detection across ALL fields
  String detectDomain(String jdText, String resumeText, [String? optionalDomain]) {
    if (optionalDomain != null && optionalDomain.trim().isNotEmpty) {
      return optionalDomain.trim();
    }

    // 1. Prioritize domain detected directly from the Job Description (the target role)
    final jdL = jdText.toLowerCase();
    if (jdL.contains('recruiter') || jdL.contains('recruitment') || jdL.contains('staffing') || jdL.contains('talent acquisition')) {
      return 'US IT Recruitment & Staffing';
    }
    if (jdL.contains('qa ') || jdL.contains('qa engineer') || jdL.contains('tester') || jdL.contains('testing') || jdL.contains('test automation') || jdL.contains('selenium') || jdL.contains('cypress')) {
      return 'QA & Software Testing';
    }
    if (jdL.contains('flutter') || jdL.contains('mobile developer') || jdL.contains('software engineer') || jdL.contains('developer') || jdL.contains('frontend') || jdL.contains('backend')) {
      return 'Software Engineering & IT';
    }
    if (jdL.contains('data analyst') || jdL.contains('data science') || jdL.contains('tableau') || jdL.contains('machine learning')) {
      return 'Data Analytics & Data Science';
    }
    if (jdL.contains('sales') || jdL.contains('business development') || jdL.contains('lead generation') || jdL.contains('cold calling')) {
      return 'Sales & Business Development';
    }
    if (jdL.contains('marketing') || jdL.contains('seo') || jdL.contains('digital marketing')) {
      return 'Marketing & Digital Media';
    }
    if (jdL.contains('finance') || jdL.contains('accounting') || jdL.contains('audit') || jdL.contains('banking')) {
      return 'Finance & Accounting';
    }
    if (jdL.contains('hospital') || jdL.contains('clinic') || jdL.contains('healthcare') || jdL.contains('medical')) {
      return 'Healthcare & Medical Services';
    }
    if (jdL.contains('teaching') || jdL.contains('curriculum') || jdL.contains('education') || jdL.contains('school')) {
      return 'Education & Academic Training';
    }

    // 2. Fallback to combined text
    final combined = '$jdText\n$resumeText'.toLowerCase();
    if (combined.contains('recruiter') || combined.contains('recruitment') || combined.contains('staffing') || combined.contains('talent acquisition')) {
      return 'US IT Recruitment & Staffing';
    }
    if (combined.contains('qa ') || combined.contains('tester') || combined.contains('testing') || combined.contains('selenium') || combined.contains('test cases') || combined.contains('test automation')) {
      return 'QA & Software Testing';
    }
    if (combined.contains('flutter') || combined.contains('mobile') || combined.contains('developer') || combined.contains('software') || combined.contains('frontend') || combined.contains('backend')) {
      return 'Software Engineering & IT';
    }
    if (combined.contains('data analyst') || combined.contains('data science') || combined.contains('tableau') || combined.contains('machine learning')) {
      return 'Data Analytics & Data Science';
    }
    if (combined.contains('sales') || combined.contains('business development') || combined.contains('lead generation') || combined.contains('cold calling')) {
      return 'Sales & Business Development';
    }
    if (combined.contains('marketing') || combined.contains('seo') || combined.contains('social media') || combined.contains('campaign')) {
      return 'Marketing & Digital Media';
    }
    if (combined.contains('finance') || combined.contains('accounting') || combined.contains('audit') || combined.contains('banking')) {
      return 'Finance & Accounting';
    }
    if (combined.contains('hospital') || combined.contains('clinic') || combined.contains('patient') || combined.contains('healthcare')) {
      return 'Healthcare & Medical Services';
    }
    if (combined.contains('teaching') || combined.contains('curriculum') || combined.contains('student') || combined.contains('education')) {
      return 'Education & Academic Training';
    }

    return 'General Professional Services';
  }

  /// Dynamic Seniority Level Detection
  String detectSeniority(String text, [String? optionalLevel]) {
    if (optionalLevel != null && optionalLevel.trim().isNotEmpty) {
      return optionalLevel.trim();
    }

    final lower = text.toLowerCase();
    if (lower.contains('0-1 year') || lower.contains('fresher') || lower.contains('freshers') || lower.contains('intern') || lower.contains('entry level') || lower.contains('junior')) {
      return 'Entry-Level / Fresher (0–1 Year)';
    }
    if (lower.contains('director') || lower.contains('head of') || lower.contains('vp') || lower.contains('chief') || lower.contains('executive')) {
      return 'Executive / Leadership';
    }
    if (lower.contains('lead') || lower.contains('principal') || lower.contains('staff') || lower.contains('manager') || lower.contains('5+ years') || lower.contains('6+ years') || lower.contains('7+ years')) {
      return 'Senior / Lead (5+ Years)';
    }
    return 'Mid-Level Professional (2–4 Years)';
  }

  /// Dynamic Extraction of Skills & Responsibilities from JD text
  Set<String> _extractDynamicSkillsFromJd(String jdText) {
    final extracted = <String>{};

    // 1. Match against multi-domain skills using strict boundaries
    for (final skill in _commonSkills) {
      if (hasSkill(jdText, skill)) {
        extracted.add(skill);
      }
    }

    // 2. Scan lines starting with bullets or emojis (📞, 🔍, 🤝, 🗣️, 🎯, etc.)
    final chunks = jdText.split(RegExp(r'[\n\r•*–—]|\p{Emoji}', unicode: true));
    for (final rawChunk in chunks) {
      final chunk = rawChunk.trim();
      if (chunk.length >= 4 && chunk.length <= 60) {
        final cLower = chunk.toLowerCase();
        if (cLower.contains('cold calling')) extracted.add('Cold Calling');
        if (cLower.contains('client outreach')) extracted.add('Client Outreach');
        if (cLower.contains('source') || cLower.contains('sourcing')) extracted.add('Candidate Sourcing');
        if (cLower.contains('screen') || cLower.contains('shortlist')) extracted.add('Screening & Shortlisting');
        if (cLower.contains('interview') || cLower.contains('coordinate')) extracted.add('Interview Coordination');
        if (cLower.contains('recruitment pipeline')) extracted.add('Recruitment Pipeline');
        if (cLower.contains('english communication')) extracted.add('English Communication');
        if (cLower.contains('night shift')) extracted.add('US Night Shift');
        if (cLower.contains('target-driven') || cLower.contains('self-motivated')) extracted.add('Target-driven');
        if (cLower.contains('us recruitment') || cLower.contains('us it recruiter')) extracted.add('US IT Recruitment');
        if (cLower.contains('international staffing')) extracted.add('International Staffing');
        if (cLower.contains('client marketing')) extracted.add('Client Marketing');
      }
    }

    return extracted;
  }

  /// Section 4: Dynamic 6-Dimension ATS Compatibility Evaluation Engine
  AnalysisResultDto analyzeMatch(ResumeInput input) {
    final jdText = input.jobDescription;
    final resumeText = input.resumeText;

    // Detect Metadata
    final detectedJobTitle = extractRole(jdText, input.optionalJobTitle);
    final detectedDomain = detectDomain(jdText, resumeText, input.optionalIndustryDomain);
    final detectedSeniority = detectSeniority(jdText, input.optionalExperienceLevel);
    final jobCity = extractCity(input.optionalJobLocation ?? jdText);
    final resumeCity = extractCity(resumeText);
    final isCityAligned = jobCity.toLowerCase().contains('remote') ||
        (resumeCity != 'Remote / Flexible' &&
            jobCity.toLowerCase().contains(resumeCity.toLowerCase().split(',').first));

    // 1. Identify skills in JD & Resume
    final jdSkills = _extractDynamicSkillsFromJd(jdText);
    final resumeSkills = <String>{};

    for (final skill in _commonSkills) {
      if (hasSkill(resumeText, skill)) {
        resumeSkills.add(skill);
      }
    }

    final matchedSkills = jdSkills.intersection(resumeSkills).toList();
    final missingSkills = jdSkills.difference(resumeSkills).toList();

    // DIMENSION A: Required Skills & Qualifications (Max: 30 Points)
    double skillsScore;
    if (jdSkills.isEmpty) {
      skillsScore = 25.0;
    } else {
      final normalizedJdCount = max(1, min(7, jdSkills.length));
      final ratio = (matchedSkills.length / normalizedJdCount).clamp(0.0, 1.0);
      skillsScore = (ratio * 22.0) + (matchedSkills.length >= 4 ? 8.0 : (matchedSkills.isNotEmpty ? 4.0 : 1.0));
    }
    skillsScore = skillsScore.clamp(2.0, 30.0);

    // DIMENSION B: Relevant Experience & Responsibilities (Max: 25 Points)
    final wordsInJd = jdText
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z0-9+#]'))
        .where((w) => w.length > 3)
        .toSet();
    final wordsInResume = resumeText
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z0-9+#]'))
        .where((w) => w.length > 3)
        .toSet();

    final overlapWords = wordsInJd.intersection(wordsInResume).length;
    final jdWordCount = max(1, wordsInJd.length);
    final coverageRatio = (overlapWords / jdWordCount) * 2.5;

    final titleWords = detectedJobTitle.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2);
    final hasTitleMatch = titleWords.any((tw) => resumeText.toLowerCase().contains(tw));

    double experienceScore = (coverageRatio.clamp(0.0, 1.0) * 12.0) + (hasTitleMatch ? 10.0 : 3.0) + (matchedSkills.length >= 4 ? 3.0 : 0.0);
    experienceScore = experienceScore.clamp(4.0, 25.0);

    // DIMENSION C: Job-Specific Keywords & Terminology (Max: 15 Points)
    final keywordRatio = (matchedSkills.length / max(1, min(7, jdSkills.length))).clamp(0.0, 1.0);
    double keywordsScore = (keywordRatio * 8.0) + (coverageRatio.clamp(0.0, 1.0) * 4.0) + (matchedSkills.length >= 4 ? 3.0 : 0.5);
    keywordsScore = keywordsScore.clamp(2.0, 15.0);

    // DIMENSION D: Education, Certifications & Eligibility (Max: 10 Points)
    final hasDegreeInResume = RegExp(r'\b(?:bachelor|master|degree|b\.tech|btech|m\.tech|mba|bca|mca|b\.e|b\.sc|m\.sc)\b', caseSensitive: false).hasMatch(resumeText);
    final hasCertification = RegExp(r'\b(?:certified|certification|aws certified|pmp|scrum master|license)\b', caseSensitive: false).hasMatch(resumeText);
    double educationScore = (hasDegreeInResume ? 8.5 : 5.0) + (hasCertification ? 1.5 : 0.5);
    educationScore = educationScore.clamp(3.0, 10.0);

    // DIMENSION E: Relevant Achievements & Evidence of Impact (Max: 10 Points)
    final metricMatches = RegExp(r'\b\d+(?:%|\+|\s*k|\s*m|\s*users|\s*clients|\s*hires|\s*turnaround)\b', caseSensitive: false).allMatches(resumeText).length;
    double achievementsScore = (metricMatches >= 3 ? 9.5 : (metricMatches >= 1 ? 7.5 : 4.5));
    achievementsScore = achievementsScore.clamp(3.0, 10.0);

    // DIMENSION F: Resume Readability, Structure & Parsing Compatibility (Max: 10 Points)
    final hasSummary = RegExp(r'\b(?:summary|objective|profile|about me)\b', caseSensitive: false).hasMatch(resumeText);
    final hasExperienceSec = RegExp(r'\b(?:experience|employment|work history|projects)\b', caseSensitive: false).hasMatch(resumeText);
    final hasSkillsSec = RegExp(r'\b(?:skills|competencies|technologies)\b', caseSensitive: false).hasMatch(resumeText);
    final hasContactInfo = resumeText.contains('@') && (resumeText.contains('+') || RegExp(r'\b\d{10}\b').hasMatch(resumeText));

    double readabilityScore = 5.0;
    if (hasSummary) readabilityScore += 1.25;
    if (hasExperienceSec) readabilityScore += 1.25;
    if (hasSkillsSec) readabilityScore += 1.25;
    if (hasContactInfo) readabilityScore += 1.25;
    readabilityScore = readabilityScore.clamp(4.0, 10.0);

    // TOTAL ATS SCORE (Exact Sum of 6 Dimensions = 100)
    final totalScore = double.parse((skillsScore + experienceScore + keywordsScore + educationScore + achievementsScore + readabilityScore).clamp(15.0, 99.0).toStringAsFixed(1));

    // Gaps & Transferable Skills
    final mandatoryGaps = <String>[];
    final preferredGaps = <String>[];
    final transferableSkills = <String>[];

    for (final missing in missingSkills) {
      if (missing.toLowerCase().contains('recruitment') ||
          missing.toLowerCase().contains('sourcing') ||
          missing.toLowerCase().contains('flutter') ||
          missing.toLowerCase().contains('python') ||
          missing.toLowerCase().contains('testing') ||
          missing.toLowerCase().contains('sales')) {
        mandatoryGaps.add(missing);
      } else {
        preferredGaps.add(missing);
      }
    }

    if (hasSkill(resumeText, 'English Communication') || hasSkill(resumeText, 'Communication Skills')) {
      transferableSkills.add('English Communication & Stakeholder Engagement');
    }
    if (hasSkill(resumeText, 'Problem Solving')) {
      transferableSkills.add('Structured Problem Solving');
    }
    if (hasSkill(resumeText, 'Time Management')) {
      transferableSkills.add('Prioritization & Time Management');
    }

    // Parsing issues check
    final parsingIssues = <String>[];
    if (!hasContactInfo) {
      parsingIssues.add('Missing standardized phone or email in contact line.');
    }
    if (!hasSummary) {
      parsingIssues.add('No dedicated Professional Summary or Profile header found.');
    }
    if (resumeText.contains('\n•\n') || resumeText.contains('\n-\n')) {
      parsingIssues.add('Detected unmerged or lone bullet symbols in text.');
    }

    // Recommendations to reach 70%+ / 75%+
    final recommendations = <String>[];
    if (missingSkills.isNotEmpty) {
      recommendations.add('Incorporate verified target competencies: ${missingSkills.take(4).join(', ')}');
    }
    if (metricMatches < 2) {
      recommendations.add('Quantify achievements with explicit metrics (% efficiency gained, volume handled, deliverables completed).');
    }
    if (!isCityAligned) {
      recommendations.add('Align target location or indicate "Open to Relocation to $jobCity".');
    }
    if (mandatoryGaps.isNotEmpty) {
      recommendations.add('Highlight hands-on exposure to core mandatory requirements: ${mandatoryGaps.take(3).join(', ')}.');
    }

    final scoreExplanation = 'Compatibility score calculated across 6 objective dimensions: Skills ($skillsScore/30), Experience ($experienceScore/25), Keywords ($keywordsScore/15), Education ($educationScore/10), Achievements ($achievementsScore/10), Readability ($readabilityScore/10). Total estimated match: ${totalScore.toStringAsFixed(1)}%.';

    final summary = totalScore >= 70.0
        ? 'Qualified candidate match (${totalScore.toStringAsFixed(1)}%). The resume satisfies core role competencies and meets the 70% threshold. Unlocked ATS Resume Optimization Studio.'
        : 'Moderate candidate match (${totalScore.toStringAsFixed(1)}%). Threshold of 70% required to unlock automatic tailoring. Add verified missing competencies (${missingSkills.take(3).join(', ')}) to improve alignment.';

    return AnalysisResultDto(
      matchScore: totalScore,
      skillsScore: skillsScore,
      experienceScore: experienceScore,
      keywordsScore: keywordsScore,
      educationScore: educationScore,
      achievementsScore: achievementsScore,
      readabilityScore: readabilityScore,
      detectedJobTitle: detectedJobTitle,
      detectedDomain: detectedDomain,
      detectedSeniority: detectedSeniority,
      jobCity: jobCity,
      resumeCity: resumeCity == 'Remote / Flexible' ? null : resumeCity,
      isCityAligned: isCityAligned,
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
      mandatoryGaps: mandatoryGaps,
      preferredGaps: preferredGaps,
      transferableSkills: transferableSkills,
      parsingIssues: parsingIssues,
      recommendations: recommendations,
      scoreExplanation: scoreExplanation,
      summary: summary,
      threshold: 70.0,
    );
  }

  /// Section 6: Tailoring Engine Adhering to Strict Optimization Rules
  TailoredResume tailorResume(
    ResumeInput input,
    AnalysisResult analysis, {
    bool forceOverride = false,
  }) {
    final targetCity = input.customTargetCity ?? analysis.jobCity;
    final targetRole = analysis.detectedJobTitle;
    final domain = analysis.detectedDomain;

    final rewriteResult = TruthfulResumeRewriter.rewrite(
      originalResume: input.resumeText,
      jobDescription: input.jobDescription,
      analysis: analysis,
      targetCity: targetCity,
      targetRole: targetRole,
      domain: domain,
      verifiedSkills: analysis.userVerifiedSkills,
    );

    // Run ATS evaluation again against the optimized resume
    final reanalyzedDto = analyzeMatch(ResumeInput(
      jobDescription: input.jobDescription,
      resumeText: rewriteResult.tailoredResume,
      customTargetCity: targetCity,
      targetPages: input.targetPages,
    ));
    final reanalyzedResult = reanalyzedDto.toDomain();

    return TailoredResume(
      originalResume: input.resumeText,
      tailoredResume: rewriteResult.tailoredResume,
      alignedCity: targetCity,
      originalCity: analysis.resumeCity,
      tailoredSummary: rewriteResult.tailoredSummary,
      addedKeywords: rewriteResult.addedKeywords,
      modifiedSections: rewriteResult.modifiedSections,
      cityAlignmentNote:
          'Market relevance aligned to $targetCity in professional summary.',
      generationModel: 'Intelligent ATS Heuristic Engine (Truthful Full-Resume)',
      timestamp: DateTime.now(),
      targetPages: input.targetPages,
      reanalyzedScore: reanalyzedResult.matchScore,
      reanalyzedResult: reanalyzedResult,
      bulletAudits: rewriteResult.bulletAudits,
      evidenceMappings: rewriteResult.evidenceMappings,
      truthfulnessResult: rewriteResult.truthfulnessResult,
      candidateClarificationQuestions: rewriteResult.clarificationQuestions,
    );
  }
}
