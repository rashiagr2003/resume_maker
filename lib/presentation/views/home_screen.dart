import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/privacy_cleanup_service.dart';
import '../../core/utils/pdf_extractor.dart';
import '../../core/utils/resume_file_extractor.dart';
import '../../core/utils/app_toast.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/analysis_result.dart';
import '../providers/resume_providers.dart';
import '../widgets/animated_score_gauge.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/city_alignment_card.dart';
import '../widgets/skills_breakdown_card.dart';
import '../widgets/tailored_resume_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  late TextEditingController _jdController;
  late TextEditingController _resumeController;
  late TextEditingController _cityController;
  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _domainController;
  late TextEditingController _seniorityController;

  bool _isUploading = false;
  String? _uploadedFileName;
  bool _showOptionalJobFields = false;
  String? _jdError;
  String? _resumeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _jdController = TextEditingController();
    _resumeController = TextEditingController();
    _cityController = TextEditingController();
    _titleController = TextEditingController();
    _companyController = TextEditingController();
    _domainController = TextEditingController();
    _seniorityController = TextEditingController();

    // Enforce fresh session cleanup on startup/reload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PrivacyCleanupService.cleanupOnSessionStart(ref);
    });
  }

  void _clearAll() {
    ref.read(resumeInputProvider.notifier).clear();
    ref.read(verifiedSkillsProvider.notifier).clear();
    ref.read(forceOverrideProvider.notifier).state = false;
    _jdController.clear();
    _resumeController.clear();
    _cityController.clear();
    _titleController.clear();
    _companyController.clear();
    _domainController.clear();
    _seniorityController.clear();
    setState(() {
      _uploadedFileName = null;
      _jdError = null;
      _resumeError = null;
    });
    ref.read(analysisProvider.notifier).reset();
    ref.read(tailoredResumeProvider.notifier).reset();
    PrivacyCleanupService.clearTemporaryBrowserStorage();
  }

  void _syncControllersToProvider() {
    ref.read(resumeInputProvider.notifier).updateResumeText(_resumeController.text);
    ref.read(resumeInputProvider.notifier).updateJobDescription(_jdController.text);
    if (_cityController.text.trim().isNotEmpty) {
      ref.read(resumeInputProvider.notifier).updateTargetCity(_cityController.text.trim());
    }
    ref.read(resumeInputProvider.notifier).updateOptionalFields(
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      domain: _domainController.text.trim().isEmpty ? null : _domainController.text.trim(),
      level: _seniorityController.text.trim().isEmpty ? null : _seniorityController.text.trim(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      PrivacyCleanupService.resetApplicationState(
        ref: ref,
        onResetUi: _clearAll,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jdController.dispose();
    _resumeController.dispose();
    _cityController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    _domainController.dispose();
    _seniorityController.dispose();
    super.dispose();
  }

  Future<void> _pickResumeFile() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final extraction = ResumeFileExtractor.extract(
            bytes: file.bytes!,
            fileName: file.name,
          );

          if (extraction.isSuccess) {
            _resumeController.text = extraction.text;
            setState(() {
              _uploadedFileName = file.name;
              _resumeError = null;
            });
            ref.read(resumeInputProvider.notifier).updateResumeText(extraction.text);
            ref.read(resumeInputProvider.notifier).updateUploadedFileName(file.name);
            if (!mounted) return;
            AppToast.show(
              context,
              message:
                  'Successfully extracted ${file.name} (${extraction.fileType.toUpperCase()}, ${extraction.text.length} chars)!',
              type: ToastType.success,
            );
          } else {
            if (!mounted) return;
            AppToast.show(
              context,
              message: extraction.errorMessage ??
                  'Could not extract text from the document.',
              type: ToastType.error,
              duration: const Duration(seconds: 5),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Note: Could not open file: $e. You can paste resume text directly!',
        type: ToastType.warning,
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputState = ref.watch(resumeInputProvider);
    final analysisState = ref.watch(analysisProvider);
    final tailoredState = ref.watch(tailoredResumeProvider);
    final apiKeyAsync = ref.watch(apiKeyProvider);
    final forceOverride = ref.watch(forceOverrideProvider);

    final hasApiKey = (apiKeyAsync.valueOrNull ?? '').isNotEmpty;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.darkCard,
            border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 950;
                final showStudioBadge = constraints.maxWidth >= 640;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Logo & Title
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'ResumeCraft AI',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkTextPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (showStudioBadge)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'ATS Optimization Studio',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (!isCompact)
                            Text(
                              'Intelligent Match Analysis • Location Alignment • Executive 1-Page Tailoring',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.darkTextSecondary.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    if (inputState.jobDescription.isNotEmpty || inputState.resumeText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                          size: 15,
                          color: AppColors.darkTextSecondary,
                        ),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          foregroundColor: AppColors.darkTextSecondary,
                          side: const BorderSide(
                            color: AppColors.darkBorder,
                          ),
                        ),
                        onPressed: _clearAll,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Input Form
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildInputPanel(context, inputState),
                  ),
                ),

                // Vertical Divider
                Container(width: 1, color: AppColors.darkBorder),

                // Right Column: Output / Analysis / Tailored Resume
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildOutputPanel(
                      context,
                      analysisState,
                      tailoredState,
                      inputState,
                      forceOverride,
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Stacked for smaller viewports
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInputPanel(context, inputState),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.darkBorder),
                  const SizedBox(height: 24),
                  _buildOutputPanel(
                    context,
                    analysisState,
                    tailoredState,
                    inputState,
                    forceOverride,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildInputPanel(BuildContext context, dynamic inputState) {
    final isAnalyzing = ref.watch(analysisProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Title
        const Row(
          children: [
            Icon(
              Icons.description_rounded,
              color: AppColors.primaryLight,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '1. Target Job Requirement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Target job description and requirements to analyze for ATS compatibility.',
          style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 10),

        // JD Text Field
        TextField(
          controller: _jdController,
          maxLines: 8,
          style: const TextStyle(fontSize: 13, height: 1.45),
          decoration: InputDecoration(
            hintText:
                'Paste target Job Description here (responsibilities, required qualifications, tech stack)...',
            errorText: _jdError,
          ),
          onChanged: (val) {
            if (_jdError != null) setState(() => _jdError = null);
            ref.read(resumeInputProvider.notifier).updateJobDescription(val);
          },
        ),

        const SizedBox(height: 12),

        // Optional Job Metadata Expansion Tile (Cross-Industry Support)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: ExpansionTile(
            initiallyExpanded: _showOptionalJobFields,
            onExpansionChanged: (val) => setState(() => _showOptionalJobFields = val),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            leading: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryLight),
            title: const Text(
              'Optional Job Metadata & Overrides',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text(
              'Auto-detected across any industry. Fill only if you wish to override.',
              style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              labelText: 'Job Title (Optional)',
                              hintText: 'e.g. US IT Recruiter, QA Lead',
                              prefixIcon: Icon(Icons.badge_outlined, size: 16),
                            ),
                            onChanged: (val) {
                              ref.read(resumeInputProvider.notifier).updateOptionalFields(
                                title: val.trim().isEmpty ? null : val.trim(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _companyController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              labelText: 'Company (Optional)',
                              hintText: 'e.g. Google, TechCorp',
                              prefixIcon: Icon(Icons.business_outlined, size: 16),
                            ),
                            onChanged: (val) {
                              ref.read(resumeInputProvider.notifier).updateOptionalFields(
                                company: val.trim().isEmpty ? null : val.trim(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _domainController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              labelText: 'Domain / Industry (Optional)',
                              hintText: 'e.g. Staffing, Healthcare, Finance',
                              prefixIcon: Icon(Icons.domain_outlined, size: 16),
                            ),
                            onChanged: (val) {
                              ref.read(resumeInputProvider.notifier).updateOptionalFields(
                                domain: val.trim().isEmpty ? null : val.trim(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _seniorityController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              labelText: 'Experience Level (Optional)',
                              hintText: 'e.g. 0-1 Year, Senior, Lead',
                              prefixIcon: Icon(Icons.timeline_rounded, size: 16),
                            ),
                            onChanged: (val) {
                              ref.read(resumeInputProvider.notifier).updateOptionalFields(
                                level: val.trim().isEmpty ? null : val.trim(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cityController,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(
                        labelText: 'Target Job Location (Optional)',
                        hintText: 'Auto-detected from JD or specify custom (e.g. Noida, India, New York, NY)',
                        prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.cityAligned, size: 16),
                      ),
                      onChanged: (val) {
                        ref.read(resumeInputProvider.notifier).updateTargetCity(
                          val.trim().isEmpty ? null : val.trim(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_rounded, color: AppColors.secondary, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '2. Current Candidate Resume',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (_isUploading)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8),
                  Text('Extracting...', style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
                ],
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Upload Resume (PDF, DOCX, TXT)'),
                onPressed: _pickResumeFile,
              ),
          ],
        ),
        if (_uploadedFileName != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.matchHigh.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.matchHigh.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.matchHigh, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Uploaded File: $_uploadedFileName',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.matchHigh),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() => _uploadedFileName = null);
                    _resumeController.clear();
                    ref.read(resumeInputProvider.notifier).updateResumeText('');
                    ref.read(resumeInputProvider.notifier).updateUploadedFileName(null);
                  },
                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          'Paste current resume text or upload PDF, DOCX, or TXT. All industries supported.',
          style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 10),

        // Resume Text Field
        TextField(
          controller: _resumeController,
          maxLines: 12,
          style: const TextStyle(fontSize: 13, height: 1.45),
          decoration: InputDecoration(
            hintText: 'Paste current resume text here, or click "Upload Resume" above...',
            errorText: _resumeError,
          ),
          onChanged: (val) {
            if (_resumeError != null) setState(() => _resumeError = null);
            ref.read(resumeInputProvider.notifier).updateResumeText(val);
          },
        ),

        const SizedBox(height: 20),

        // 3. Resume Page Length Question
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.article_rounded,
                        color: AppColors.primaryLight,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '3. Target Document Format',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.matchHigh.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Industry Standard • 1 Page',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.matchHigh,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Configure target length. Industry standards recommend a concise 1-page format for high-impact recruiter screening.',
                style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary, height: 1.35),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final card1 = _DocumentFormatCard(
                    title: '1 Page',
                    subtitle: 'Executive Standard • ATS Focused',
                    badge: 'Recommended',
                    icon: Icons.article_rounded,
                    isSelected: inputState.targetPages == 1,
                    onTap: () => ref.read(resumeInputProvider.notifier).updateTargetPages(1),
                  );
                  final card2 = _DocumentFormatCard(
                    title: '2 Pages',
                    subtitle: 'Extended Portfolio & Detail',
                    icon: Icons.layers_rounded,
                    isSelected: inputState.targetPages == 2,
                    onTap: () => ref.read(resumeInputProvider.notifier).updateTargetPages(2),
                  );

                  if (constraints.maxWidth >= 560) {
                    return Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 10),
                        Expanded(child: card2),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      card1,
                      const SizedBox(height: 8),
                      card2,
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Analyze Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          onPressed: isAnalyzing
              ? null
              : () {
                  _syncControllersToProvider();
                  ref.read(tailoredResumeProvider.notifier).reset();

                  final jd = _jdController.text.trim();
                  final resume = _resumeController.text.trim();

                  String? jdErr;
                  String? resumeErr;

                  if (jd.isEmpty) {
                    jdErr = 'Job Description is mandatory.';
                  } else if (jd.length < 20) {
                    jdErr = 'Job Description too brief (minimum 20 characters required).';
                  }

                  if (resume.isEmpty) {
                    resumeErr = 'Candidate Resume is mandatory.';
                  } else if (resume.length < 20) {
                    resumeErr = 'Resume content too brief (minimum 20 characters required).';
                  }

                  setState(() {
                    _jdError = jdErr;
                    _resumeError = resumeErr;
                  });

                  if (jdErr != null && resumeErr != null) {
                    AppToast.show(
                      context,
                      message:
                          '⚠️ Mandatory Fields Required: Please provide both the Job Description and Resume (minimum 20 characters each).',
                      type: ToastType.warning,
                    );
                    return;
                  } else if (jdErr != null) {
                    AppToast.show(
                      context,
                      message: '⚠️ Mandatory Field Missing: $jdErr',
                      type: ToastType.warning,
                    );
                    return;
                  } else if (resumeErr != null) {
                    AppToast.show(
                      context,
                      message: '⚠️ Mandatory Field Missing: $resumeErr',
                      type: ToastType.warning,
                    );
                    return;
                  }

                  final input = ref.read(resumeInputProvider);
                  ref.read(analysisProvider.notifier).runAnalysis(input);
                },
          child: isAnalyzing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Analyzing ATS Match & Parsing Location...',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radar_rounded, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Calculate Dynamic ATS Compatibility Score (70% Gate)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildOutputPanel(
    BuildContext context,
    AsyncValue<AnalysisResult?> analysisState,
    AsyncValue<dynamic> tailoredState,
    dynamic inputState,
    bool forceOverride,
  ) {
    // If Tailored Resume is ready, display the Tailored Resume View!
    if (tailoredState.valueOrNull != null) {
      return TailoredResumeView(
        tailored: tailoredState.valueOrNull!,
        onBack: () {
          ref.read(tailoredResumeProvider.notifier).reset();
        },
        onDownloadSuccess: () {
          PrivacyCleanupService.handlePostDownloadCleanup(
            ref: ref,
            onResetUi: _clearAll,
            messenger: ScaffoldMessenger.of(context),
          );
        },
      );
    }

    // Loading tailored resume
    if (tailoredState.isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.matchHigh.withOpacity(0.3)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.matchHigh),
              SizedBox(height: 20),
              Text(
                'Tailoring Resume & Aligning Target City...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Rewriting summary, integrating missing keywords, and updating location header...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return analysisState.when(
      data: (analysis) {
        if (analysis == null) {
          return _buildEmptyState();
        }

        final isUnlocked = analysis.isEligibleForUpdate || forceOverride;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Radial Gauge
              AnimatedScoreGauge(analysis: analysis),

              const SizedBox(height: 16),

              // City Alignment Card
              CityAlignmentCard(analysis: analysis),

              const SizedBox(height: 16),

              // Skills Breakdown
              SkillsBreakdownCard(analysis: analysis),

              const SizedBox(height: 20),

              // THE CORE 75% ACTION BUTTON
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.matchHigh.withOpacity(0.08)
                      : AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.matchHigh
                        : AppColors.darkBorder,
                    width: isUnlocked ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    if (!isUnlocked) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.matchMid,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${analysis.threshold.toInt()}% Score Threshold Locked (${analysis.matchScore.toStringAsFixed(1)}% match)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.matchMid,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'The automatic resume optimization option unlocks once your resume reaches ${analysis.threshold.toInt()}% or higher compatibility with this job description.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Force Override Switch
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          const Text(
                            'Force Override (Test Tailoring Anyway): ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                          Switch(
                            value: forceOverride,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) {
                              ref.read(forceOverrideProvider.notifier).state =
                                  val;
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.matchHigh,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              analysis.matchScore >= analysis.threshold
                                  ? '🎉 ATS Score is ${analysis.matchScore.toStringAsFixed(1)}%! Threshold Met.'
                                  : '⚠️ Manual Override Enabled (${analysis.matchScore.toStringAsFixed(1)}%)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.matchHigh,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You now have the option to optimize your resume for "${analysis.detectedJobTitle}" and align market relevance with "${analysis.jobCity}".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.matchHigh,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          elevation: 4,
                        ),
                        onPressed: () {
                          _syncControllersToProvider();
                          final currentInput = ref.read(resumeInputProvider);
                          ref
                              .read(tailoredResumeProvider.notifier)
                              .tailorResume(
                                input: currentInput,
                                analysis: analysis,
                                forceOverride: forceOverride,
                              );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_fix_high_rounded, size: 20),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Optimize Resume for "${analysis.detectedJobTitle}"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 20),
              Text(
                'Analyzing Compatibility...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Evaluating keyword density, domain experience & target city alignment...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, st) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.matchLow),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.matchLow,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'Analysis Error: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.darkTextPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.darkBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.25),
                            AppColors.secondary.withOpacity(0.25),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 36,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'ATS Match & Tailoring Studio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste a target job description and your resume on the left to begin deep ATS scoring, keyword alignment, and 1-click tailored PDF creation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary.withOpacity(0.9),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Feature Highlights
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1526),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Column(
                        children: [
                          _buildStudioFeatureItem(
                            icon: Icons.radar_rounded,
                            color: AppColors.primaryLight,
                            title: 'Dynamic 6-Dimension ATS Scoring (70% Gate)',
                            subtitle: 'Identifies missing keywords, strengths, and skills compatibility.',
                          ),
                          const Divider(color: AppColors.darkBorder, height: 18),
                          _buildStudioFeatureItem(
                            icon: Icons.location_on_rounded,
                            color: AppColors.cityAligned,
                            title: 'Location & Header Alignment',
                            subtitle: 'Synchronizes your contact location to the target job market.',
                          ),
                          const Divider(color: AppColors.darkBorder, height: 18),
                          _buildStudioFeatureItem(
                            icon: Icons.picture_as_pdf_rounded,
                            color: AppColors.matchHigh,
                            title: 'Executive 1-Page PDF Export',
                            subtitle: 'Publication-grade typography, verified ATS parsing, and interactive project hyperlinks.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 15,
                          color: AppColors.primaryLight.withValues(alpha: 0.85),
                        ),
                        const Text(
                          'Paste your Job Description & Resume on the left to begin',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudioFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.darkTextSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentFormatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DocumentFormatCard({
    required this.title,
    required this.subtitle,
    this.badge,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.16)
              : const Color(0xFF0F172A).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.darkBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.darkCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.darkTextPrimary,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.matchHigh.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.matchHigh,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.darkTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isSelected ? AppColors.primaryLight : AppColors.darkTextSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
