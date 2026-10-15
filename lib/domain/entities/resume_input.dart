class ResumeInput {
  final String jobDescription;
  final String resumeText;
  final String? customTargetCity;
  final int targetPages; // 1 for single-page ATS (default), 2 for two-page

  // Optional Context Inputs
  final String? optionalJobTitle;
  final String? optionalCompanyName;
  final String? optionalIndustryDomain;
  final String? optionalExperienceLevel;
  final String? optionalJobLocation;
  final String? uploadedFileName;

  const ResumeInput({
    required this.jobDescription,
    required this.resumeText,
    this.customTargetCity,
    this.targetPages = 1,
    this.optionalJobTitle,
    this.optionalCompanyName,
    this.optionalIndustryDomain,
    this.optionalExperienceLevel,
    this.optionalJobLocation,
    this.uploadedFileName,
  });

  bool get isValid =>
      jobDescription.trim().length >= 20 && resumeText.trim().length >= 20;

  ResumeInput copyWith({
    String? jobDescription,
    String? resumeText,
    String? customTargetCity,
    int? targetPages,
    String? optionalJobTitle,
    String? optionalCompanyName,
    String? optionalIndustryDomain,
    String? optionalExperienceLevel,
    String? optionalJobLocation,
    String? uploadedFileName,
  }) {
    return ResumeInput(
      jobDescription: jobDescription ?? this.jobDescription,
      resumeText: resumeText ?? this.resumeText,
      customTargetCity: customTargetCity ?? this.customTargetCity,
      targetPages: targetPages ?? this.targetPages,
      optionalJobTitle: optionalJobTitle ?? this.optionalJobTitle,
      optionalCompanyName: optionalCompanyName ?? this.optionalCompanyName,
      optionalIndustryDomain: optionalIndustryDomain ?? this.optionalIndustryDomain,
      optionalExperienceLevel: optionalExperienceLevel ?? this.optionalExperienceLevel,
      optionalJobLocation: optionalJobLocation ?? this.optionalJobLocation,
      uploadedFileName: uploadedFileName ?? this.uploadedFileName,
    );
  }
}
