class AiProviderException implements Exception {
  final String provider;
  final String message;
  final int? statusCode;
  final bool isRecoverable;

  AiProviderException({
    required this.provider,
    required this.message,
    this.statusCode,
    this.isRecoverable = true,
  });

  @override
  String toString() => '$provider error (status $statusCode): $message (recoverable: $isRecoverable)';
}

abstract class AiProvider {
  String get name;

  Future<Map<String, dynamic>> analyzeResume({
    required String resumeText,
    required String jobDescription,
    String? jobTitle,
    String? companyName,
    String? industryDomain,
    String? experienceLevel,
    String? jobLocation,
  });

  Future<Map<String, dynamic>> tailorResume({
    required String resumeText,
    required String jobDescription,
    required String detectedJobTitle,
    required String detectedDomain,
    required String targetCity,
    required int targetPages,
    required Map<String, dynamic> verifiedSkills,
  });
}
