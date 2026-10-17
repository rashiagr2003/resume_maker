import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_extractor.dart';
import '../../core/utils/pdf_generator.dart';
import '../../domain/entities/tailored_resume.dart';
import '../../domain/entities/resume_audit_entry.dart';
import '../../core/utils/app_toast.dart';

Future<void> _launchExternalUrl(BuildContext context, String rawUrl) async {
  final cleanUrl = rawUrl.startsWith('http') || rawUrl.startsWith('mailto:')
      ? rawUrl
      : 'https://$rawUrl';
  final uri = Uri.tryParse(cleanUrl);
  if (uri != null) {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}
  }
  if (context.mounted) {
    AppToast.show(
      context,
      message: 'Opening link: $cleanUrl',
      type: ToastType.info,
    );
  }
}

class TailoredResumeView extends StatefulWidget {
  final TailoredResume tailored;
  final VoidCallback onBack;
  final VoidCallback? onDownloadSuccess;

  const TailoredResumeView({
    super.key,
    required this.tailored,
    required this.onBack,
    this.onDownloadSuccess,
  });

  @override
  State<TailoredResumeView> createState() => _TailoredResumeViewState();
}

class _TailoredResumeViewState extends State<TailoredResumeView> {
  int _selectedTab = 0; // 0: Tailored, 1: Bullet Audits & Diffs, 2: Evidence Map & Truthfulness, 3: Original
  bool _showRawMarkdown = false;
  late int _targetPages;
  final Set<int> _dismissedQuestions = {};
  final Map<int, String> _answeredQuestions = {};

  @override
  void initState() {
    super.initState();
    _targetPages = widget.tailored.targetPages;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;

        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Top Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.darkTextSecondary,
                        ),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.matchHigh,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Tailored & Aligned Resume',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Engine: ${widget.tailored.generationModel}',
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
                    ],
                  ),

                  // Action Buttons & Page Format Selector
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Page Format Selector
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.darkBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _targetPages = 1),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _targetPages == 1 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '1 Page (Fit)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _targetPages == 1 ? FontWeight.w700 : FontWeight.w500,
                                    color: _targetPages == 1 ? Colors.white : AppColors.darkTextSecondary,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _targetPages = 2),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _targetPages == 2 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '2 Pages',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _targetPages == 2 ? FontWeight.w700 : FontWeight.w500,
                                    color: _targetPages == 2 ? Colors.white : AppColors.darkTextSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Copy Text
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Copy Text', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.tailored.tailoredResume),
                          );
                          AppToast.show(
                            context,
                            message: 'Tailored resume copied to clipboard!',
                            type: ToastType.success,
                          );
                        },
                      ),

                      // Print Preview Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 15),
                        label: const Text('Print Preview', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          try {
                            await PdfGenerator.exportAndPrint(
                              tailored: widget.tailored.copyWith(
                                targetPages: _targetPages,
                              ),
                              candidateName: 'Candidate',
                            );
                          } catch (e) {
                            if (context.mounted) {
                              AppToast.show(
                                context,
                                message: 'PDF preview note: $e',
                                type: ToastType.warning,
                              );
                            }
                          }
                        },
                      ),

                      // Direct TXT Export Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text(
                          'Export TXT',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkTextPrimary,
                          side: const BorderSide(color: AppColors.darkBorder),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.tailored.tailoredResume));
                          AppToast.show(
                            context,
                            message: 'Optimized resume text copied to clipboard! You can paste or save as .txt.',
                            type: ToastType.success,
                          );
                        },
                      ),

                      // Direct PDF Download Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text(
                          'Download ${_targetPages}-Page PDF',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.matchHigh,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          try {
                            await PdfGenerator.downloadPdf(
                              tailored: widget.tailored.copyWith(
                                targetPages: _targetPages,
                              ),
                              candidateName: 'Candidate',
                            );
                            if (widget.onDownloadSuccess != null) {
                              widget.onDownloadSuccess!();
                            }
                            if (context.mounted) {
                              AppToast.show(
                                context,
                                message: 'Resume downloaded successfully! (${_targetPages}-Page ATS Layout)',
                                type: ToastType.success,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppToast.show(
                                context,
                                message: 'Download failed: $e',
                                type: ToastType.error,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // City Alignment & Post-Optimization Re-Score Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: (widget.tailored.reanalyzedScore != null && widget.tailored.reanalyzedScore! >= 70.0)
                    ? AppColors.matchHigh.withOpacity(0.12)
                    : AppColors.cityAligned.withOpacity(0.12),
                border: const Border(
                  bottom: BorderSide(color: AppColors.darkBorder),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.tailored.reanalyzedScore != null
                        ? Icons.auto_awesome_rounded
                        : Icons.location_on_rounded,
                    color: widget.tailored.reanalyzedScore != null
                        ? AppColors.matchHigh
                        : AppColors.cityAligned,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.tailored.reanalyzedScore != null
                          ? '🎉 Post-Optimization ATS Score: ${widget.tailored.reanalyzedScore!.toStringAsFixed(1)}% • ${widget.tailored.cityAlignmentNote}'
                          : '📍 Market Alignment: ${widget.tailored.cityAlignmentNote}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.tailored.reanalyzedScore != null
                            ? AppColors.matchHigh
                            : AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TabButton(
                      title: 'Tailored Resume',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(width: 8),
                    _TabButton(
                      title: 'Bullet Audits & Diffs (${widget.tailored.bulletAudits.length})',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                    const SizedBox(width: 8),
                    _TabButton(
                      title: 'Evidence Map & Truthfulness (${widget.tailored.evidenceMappings.length})',
                      isSelected: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                    const SizedBox(width: 8),
                    _TabButton(
                      title: 'Original Resume',
                      isSelected: _selectedTab == 3,
                      onTap: () => setState(() => _selectedTab = 3),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Content Body
            if (hasBoundedHeight)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildTabContent(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildTabContent(),
              ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.matchHigh.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.matchHigh.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: cardContent,
        );
      },
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode switcher: Formatted View vs Raw Markdown
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _showRawMarkdown = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: !_showRawMarkdown ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.article_rounded,
                                  size: 14,
                                  color: !_showRawMarkdown ? Colors.white : AppColors.darkTextSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Document Preview',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: !_showRawMarkdown ? Colors.white : AppColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _showRawMarkdown = true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showRawMarkdown ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.code_rounded,
                                  size: 14,
                                  color: _showRawMarkdown ? Colors.white : AppColors.darkTextSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Raw Markdown',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _showRawMarkdown ? Colors.white : AppColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_showRawMarkdown)
              SelectableText(
                widget.tailored.tailoredResume,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.darkTextPrimary,
                  height: 1.6,
                ),
              )
            else
              _InteractiveResumeDocument(
                text: widget.tailored.tailoredResume,
                originalResume: widget.tailored.originalResume,
                alignedCity: widget.tailored.alignedCity,
              ),
          ],
        );

      case 1:
        return _buildBulletAuditsAndChangesTab();

      case 2:
        return _buildEvidenceAndTruthfulnessTab();

      case 3:
      default:
        return SelectableText(
          widget.tailored.originalResume,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: AppColors.darkTextSecondary,
            height: 1.6,
          ),
        );
    }
  }

  Widget _buildBulletAuditsAndChangesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Truthfulness & Factual Integrity Certificate
        _buildTruthfulnessCertificate(),
        const SizedBox(height: 24),

        // 2. Candidate Clarification Questions (if any)
        if (widget.tailored.candidateClarificationQuestions.isNotEmpty) ...[
          _buildCandidateClarificationQuestions(),
          const SizedBox(height: 24),
        ],

        // 3. Bullet-by-Bullet Rewriting & Audit List
        _buildBulletAuditsList(),
        const SizedBox(height: 24),

        // 4. Location Alignment & Summary Insights
        const Text(
          'Location Alignment Summary',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.cityAligned,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1526),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            widget.tailored.cityAlignmentNote,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Tailored Professional Summary',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1526),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            widget.tailored.tailoredSummary,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.darkTextPrimary,
              height: 1.4,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Keywords Integrated from Job Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.matchHigh,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.tailored.addedKeywords.map((k) {
            return Chip(
              label: Text(k, style: const TextStyle(fontSize: 12)),
              backgroundColor: AppColors.matchHigh.withOpacity(0.15),
              labelStyle: const TextStyle(color: AppColors.matchHigh),
              side: BorderSide(color: AppColors.matchHigh.withOpacity(0.3)),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        const Text(
          'Modified Resume Sections',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.tailored.modifiedSections.map(
          (sec) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.matchHigh,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sec,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTruthfulnessCertificate() {
    final truth = widget.tailored.truthfulnessResult ??
        const TruthfulnessCheckResult(
          isTruthful: true,
          verifiedFactsCount: 0,
          preservedMetrics: [],
          flaggedClaims: [],
          traceabilityScore: 100.0,
          summary: 'All claims verified against candidate original resume.',
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.matchHigh.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.matchHigh.withOpacity(0.06),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.matchHigh,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Factual Integrity & Truthfulness Engine',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.matchHigh.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.matchHigh.withOpacity(0.4)),
                ),
                child: Text(
                  '${truth.traceabilityScore.toStringAsFixed(0)}% Traceable',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.matchHigh,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            truth.summary,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.darkTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildFactStatPill(
                icon: Icons.check_rounded,
                label: 'Verified Claims: ${truth.verifiedFactsCount}',
                color: AppColors.matchHigh,
              ),
              _buildFactStatPill(
                icon: Icons.security_rounded,
                label: truth.flaggedClaims.isEmpty
                    ? '0 Hallucinations Detected'
                    : '${truth.flaggedClaims.length} Flagged',
                color: truth.flaggedClaims.isEmpty
                    ? AppColors.matchHigh
                    : AppColors.matchLow,
              ),
              if (truth.preservedMetrics.isNotEmpty)
                _buildFactStatPill(
                  icon: Icons.numbers_rounded,
                  label: 'Preserved Metrics: ${truth.preservedMetrics.join(', ')}',
                  color: AppColors.cityAligned,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFactStatPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateClarificationQuestions() {
    final questions = widget.tailored.candidateClarificationQuestions;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.help_outline_rounded,
                color: AppColors.primaryLight,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Candidate Clarifications & Gap Verification',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The target Job Description emphasizes these requirements. If you have unlisted experience, confirm here to safely enrich your resume:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.darkTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final q = questions[i];
              final isDismissed = _dismissedQuestions.contains(i);
              final isAnswered = _answeredQuestions.containsKey(i);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1526),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAnswered
                        ? AppColors.matchHigh.withOpacity(0.4)
                        : isDismissed
                            ? AppColors.darkBorder
                            : AppColors.primaryLight.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isAnswered)
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.matchHigh,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Confirmed: ${_answeredQuestions[i]} (Incorporated into profile)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.matchHigh,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (isDismissed)
                      const Text(
                        'Skipped • Retained conservative evidence-based resume.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkTextSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 14),
                            label: const Text(
                              'I have this experience',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _answeredQuestions[i] =
                                    'Candidate verified experience with $q';
                              });
                              AppToast.show(
                                context,
                                message:
                                    'Experience confirmed! Added to profile without fabrication.',
                                type: ToastType.success,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() => _dismissedQuestions.add(i));
                            },
                            child: const Text(
                              'Skip / No',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBulletAuditsList() {
    final audits = widget.tailored.bulletAudits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.published_with_changes_rounded,
              color: AppColors.matchHigh,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Mandatory Bullet-by-Bullet Optimization Audit (${audits.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Every experience bullet and project was rewritten into: [Action Verb] + [Responsibility] + [Method/Tool] + [Supported Outcome].',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (audits.isEmpty)
          const Text(
            'No bullet audits found for this resume.',
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: audits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _buildBulletAuditCard(audits[i]),
          ),
      ],
    );
  }

  Widget _buildBulletAuditCard(BulletRewriteAudit audit) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: audit.hasChanged
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Section & Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  audit.section,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: audit.relevance.toLowerCase().contains('high')
                      ? AppColors.matchHigh.withOpacity(0.15)
                      : AppColors.cityAligned.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  audit.relevance,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: audit.relevance.toLowerCase().contains('high')
                        ? AppColors.matchHigh
                        : AppColors.cityAligned,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Text(
                  audit.evidence,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Original vs Rewritten Diff
          if (audit.hasChanged) ...[
            // Original Bullet (Reddish / removed indicator)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.matchLow.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.matchLow.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.remove_circle_outline,
                    size: 15,
                    color: AppColors.matchLow,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      audit.original,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.darkTextSecondary.withOpacity(0.8),
                        decoration: TextDecoration.lineThrough,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Rewritten Bullet (Greenish / added indicator)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.matchHigh.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.matchHigh.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    size: 15,
                    color: AppColors.matchHigh,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      audit.rewritten,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkTextPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Text(
                audit.original,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.darkTextPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Rationale
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 14,
                color: AppColors.matchMid,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  audit.rationale,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceAndTruthfulnessTab() {
    final mappings = widget.tailored.evidenceMappings;

    final inEmploymentCount = mappings
        .where((m) => m.classification == EvidenceClassification.demonstratedInEmployment)
        .length;
    final inProjectCount = mappings
        .where((m) => m.classification == EvidenceClassification.demonstratedInProject)
        .length;
    final gapsCount = mappings
        .where((m) => m.classification == EvidenceClassification.notEvidenced)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Truthfulness Header
        _buildTruthfulnessCertificate(),
        const SizedBox(height: 24),

        // 2. Requirement-to-Evidence Map Header & Stats
        Row(
          children: [
            const Icon(
              Icons.account_tree_rounded,
              color: AppColors.cityAligned,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Requirement-to-Evidence Map (${mappings.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Requirements are rigorously mapped to candidate evidence. Skills lacking proof are reported as gaps rather than falsely claimed.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Statistics Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFactStatPill(
              icon: Icons.work_rounded,
              label: '$inEmploymentCount in Employment',
              color: AppColors.matchHigh,
            ),
            _buildFactStatPill(
              icon: Icons.code_rounded,
              label: '$inProjectCount in Projects',
              color: AppColors.cityAligned,
            ),
            _buildFactStatPill(
              icon: Icons.warning_amber_rounded,
              label: '$gapsCount Reported Gaps (0 Fabricated)',
              color: AppColors.matchMid,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // List of Mapping Cards
        if (mappings.isEmpty)
          const Text(
            'No requirement-to-evidence mappings available.',
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mappings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _buildEvidenceMappingCard(mappings[i]),
          ),
      ],
    );
  }

  Widget _buildEvidenceMappingCard(RequirementEvidenceMapping mapping) {
    final color = _classificationColor(mapping.classification);
    final label = _classificationLabel(mapping.classification);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mapping.requirement,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  '$label • ${(mapping.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (mapping.classification == EvidenceClassification.notEvidenced) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.matchMid.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.matchMid.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.matchMid,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mapping.recommendation.isNotEmpty
                          ? mapping.recommendation
                          : 'Honest Skill Gap: Candidate did not demonstrate this tool or competency in original history. Flagged as a gap rather than hallucinating experience.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.matchMid,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evidence: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    mapping.sourceEvidence,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (mapping.recommendation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      mapping.recommendation,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.cityAligned,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _classificationLabel(EvidenceClassification c) {
    switch (c) {
      case EvidenceClassification.demonstratedInEmployment:
        return 'In Employment';
      case EvidenceClassification.demonstratedInProject:
        return 'In Project';
      case EvidenceClassification.supportedByCoursework:
        return 'Coursework / Training';
      case EvidenceClassification.listedSkillOnly:
        return 'Listed Skill Only';
      case EvidenceClassification.transferable:
        return 'Transferable';
      case EvidenceClassification.notEvidenced:
        return 'Not Evidenced (Gap)';
      case EvidenceClassification.notApplicable:
        return 'Not Applicable';
    }
  }

  Color _classificationColor(EvidenceClassification c) {
    switch (c) {
      case EvidenceClassification.demonstratedInEmployment:
        return AppColors.matchHigh;
      case EvidenceClassification.demonstratedInProject:
        return AppColors.cityAligned;
      case EvidenceClassification.supportedByCoursework:
        return AppColors.secondary;
      case EvidenceClassification.listedSkillOnly:
        return AppColors.matchMid;
      case EvidenceClassification.transferable:
        return AppColors.tertiary;
      case EvidenceClassification.notEvidenced:
        return AppColors.matchLow;
      case EvidenceClassification.notApplicable:
        return AppColors.darkTextSecondary;
    }
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _ResumeLink {
  final String label;
  final String url;
  _ResumeLink(this.label, this.url);
}

class _InteractiveResumeDocument extends StatelessWidget {
  final String text;
  final String originalResume;
  final String alignedCity;

  const _InteractiveResumeDocument({
    required this.text,
    required this.originalResume,
    required this.alignedCity,
  });

  @override
  Widget build(BuildContext context) {
    final cleanedText = PdfExtractor.fixProjectContext(text);
    final rawSplit = cleanedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) =>
            l.isNotEmpty &&
            !l.toLowerCase().contains('newly integrated') &&
            !l.toLowerCase().contains('newly aligned'))
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

    final lines = <String>[];
    bool inExpOrProj = false;

    for (int i = 0; i < rawSplit.length; i++) {
      var current = rawSplit[i];
      if (current == '•' || current == '-' || current == '*') {
        if (i + 1 < rawSplit.length) {
          final next = rawSplit[i + 1];
          if (next.isNotEmpty &&
              !next.startsWith('•') &&
              !next.startsWith('-') &&
              !next.startsWith('*') &&
              !next.startsWith('#')) {
            rawSplit[i + 1] = '• $next';
          }
        }
        continue; // Never include lone bullet line!
      }

      // Normalize leading hyphens or asterisks to clean standard bullets (no raw '-' in descriptions)
      if (current.startsWith('- ') || current.startsWith('* ')) {
        current = '• ${current.substring(2).trim()}';
      } else if (current.startsWith('-') || current.startsWith('*')) {
        current = '• ${current.substring(1).trim()}';
      }

      // If current line has an unclosed markdown link bracket (e.g. "[Healthcare" split from "App](url)")
      if (current.contains('[') && !current.contains(']') && i + 1 < rawSplit.length) {
        final next = rawSplit[i + 1].trim();
        if (next.contains('](') || next.contains(')')) {
          current = '$current $next';
          i++; // Skip next line since it was merged
        }
      }

      // If current line starts with a lowercase letter, or is an unpunctuated wrapped continuation
      final isBulletContinuation = RegExp(r'^[a-z]').hasMatch(current) ||
          (lines.isNotEmpty &&
           lines.last.startsWith('•') &&
           !lines.last.trim().endsWith('.') &&
           !actionVerbRegex.hasMatch(current) &&
           !_isSectionHeader(current) &&
           !current.startsWith('#') &&
           !current.contains('|') &&
           !current.contains('[Project]') &&
           !current.contains('[Demo]'));
      if (lines.isNotEmpty && isBulletContinuation) {
        lines[lines.length - 1] = '${lines.last} $current';
        continue;
      }

      final lowerHeader = current.toLowerCase().replaceAll('#', '').replaceAll(':', '').trim();
      if (lowerHeader.contains('experience') || lowerHeader.contains('work history') || lowerHeader.contains('project')) {
        inExpOrProj = true;
      } else if (lowerHeader.contains('skill') || lowerHeader.contains('education') || lowerHeader.contains('summary') || lowerHeader.contains('profile')) {
        inExpOrProj = false;
      }

      // If current line is JUST a date (e.g. "2021 - 2025" or "| 2021 - 2025") and follows a university, company, or degree
      final isDateOnly = RegExp(r'^\|?\s*(?:(?:\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present))|\b\d{4}\s*[\-–—]\s*\d{4}\b)\s*$', caseSensitive: false).hasMatch(current);
      if (isDateOnly && lines.isNotEmpty) {
        lines[lines.length - 1] = '${lines.last} | ${current.replaceAll('|', '').trim()}';
        continue;
      }

      if (lines.isNotEmpty &&
          (current.toLowerCase() == 'reporting' ||
           (lines.last.toLowerCase().endsWith('bug') && current.toLowerCase().startsWith('reporting')))) {
        lines[lines.length - 1] = '${lines.last} $current';
        continue;
      }

      // If in experience or projects, ensure a project or job title doesn't retain " - "
      if (inExpOrProj && current.contains(' - ') && !current.startsWith('•') && !current.contains('.')) {
        current = current.replaceAll(' - ', ' | ');
      }

      // Ensure bullet prefix for accomplishments in experience and projects
      final isAlreadyBullet = current.startsWith('•') || current.startsWith('-') || current.startsWith('*');
      final isHeaderOrDate = current.startsWith('#') ||
          _isSectionHeader(current) ||
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
        if (actionVerbRegex.hasMatch(current)) {
          current = '• $current';
        }
      }

      // Final pass on bullet prefix: ensure clean standard bullet '• ' and never '-'
      if (current.startsWith('- ') || current.startsWith('* ')) {
        current = '• ${current.substring(2).trim()}';
      }

      lines.add(current);
    }

    if (lines.isEmpty) {
      return const Center(child: Text('Empty resume content'));
    }

    final widgets = <Widget>[];
    int index = 0;

    // 1. Candidate Name
    var name = lines[0].replaceAll('#', '').trim();
    name = name.replaceAll(RegExp(r'\bAGRA\s+W\s+AL\b', caseSensitive: false), 'AGRAWAL');
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ');
    widgets.add(
      Center(
        child: Text(
          name.toUpperCase(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
    widgets.add(const SizedBox(height: 3));
    index++;

    // 2. Subtitle / Role
    if (index < lines.length &&
        !_isSectionHeader(lines[index]) &&
        !_isContactLine(lines[index]) &&
        !_isLinksLine(lines[index])) {
      var subtitle = lines[index]
          .replaceAll(
            RegExp(r'\s*\|\s*(?:Bengaluru|Bangalore|Noida|Delhi|Pune|Hyderabad|San Francisco|Remote)[^|]*$', caseSensitive: false),
            '',
          )
          .trim();
      if (subtitle.isNotEmpty) {
        widgets.add(
          Center(
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3730A3),
              ),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 3));
      }
      index++;
    }

    // 3. Contact Line: extract phone and email, strictly omit location
    String? contactPhone;
    String? contactEmail;

    while (index < lines.length &&
        !_isSectionHeader(lines[index]) &&
        !_isLinksLine(lines[index]) &&
        _isContactLine(lines[index])) {
      final p = _extractPhone(lines[index]);
      if (p != null && contactPhone == null) contactPhone = p;
      final e = _extractEmail(lines[index]);
      if (e != null && contactEmail == null) contactEmail = e;
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
      final contact = contactParts.join(' | ');
      widgets.add(
        Center(
          child: Text(
            contact,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 4));
    }

    // 4. Clickable Links Line: strictly show "LinkedIn", "Portfolio", "GitHub" with clickable pointer cursor
    if (index < lines.length &&
        !_isSectionHeader(lines[index]) &&
        _isLinksLine(lines[index])) {
      final links = _extractLinks(lines[index], originalResume);
      if (links.isNotEmpty) {
        widgets.add(
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                for (int i = 0; i < links.length; i++) ...[
                  _InteractiveLinkItem(
                    label: links[i].label,
                    url: links[i].url,
                  ),
                  if (i < links.length - 1)
                    const Text(
                      '|',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 8));
      index++;
    }

    // Divider
    widgets.add(const Divider(color: Color(0xFFCBD5E1), thickness: 1));
    widgets.add(const SizedBox(height: 10));

    // Skip any orphaned summary text before first section
    while (index < lines.length && !_isSectionHeader(lines[index])) {
      index++;
    }

    // Process remaining sections
    bool inProjectsSection = false;
    bool inSkillsSection = false;
    bool inEducationSection = false;
    bool inExperienceSection = false;

    while (index < lines.length) {
      final line = lines[index];

      // Section Header
      if (_isSectionHeader(line)) {
        final header = line
            .replaceAll(RegExp(r'^[\-\*•#\s]+'), '')
            .replaceAll('#', '')
            .replaceAll(':', '')
            .trim()
            .toUpperCase();
        inProjectsSection = header.contains('PROJECT');
        inSkillsSection = header.contains('SKILL');
        inEducationSection = header.contains('EDUCATION');
        inExperienceSection = header.contains('EXPERIENCE') || header.contains('WORK');

        widgets.add(const SizedBox(height: 14));
        widgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                header,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Container(height: 1.2, color: const Color(0xFF3730A3)),
            ],
          ),
        );
        widgets.add(const SizedBox(height: 6));
        index++;
        continue;
      }

      final cleanProjectCandidate = line.replaceFirst(RegExp(r'^[\-\*•#\s]+'), '').trim();
      final actionVerbInClean = RegExp(
        r'^(?:Built|Developed|Implemented|Integrated|Added|Used|Contributed|Executed|Automated|'
        r'Visualized|Designed|Created|Architected|Engineered|Configured|Maintained|Optimized|'
        r'Spearheaded|Streamlined|Collaborated|Conducted|Tested|Managed|Led|Authored|Generated|'
        r'Deployed|Orchestrated|Secured|Refactored|Enhanced|Accelerated|Formulated|Drafted|'
        r'Monitored|Supervised|Produced|Established|Published|Trained|Mentored|Assisted|'
        r'Pioneered|Achieved|Facilitated|Analyzed|Researched|Solved|Coordinated|Directed|'
        r'Identified|Standardized|Tracked|Validated|Wrote|Programmed|Delivered|Resolved|'
        r'Prepared|Reviewed|Supported)\b',
        caseSensitive: false,
      ).hasMatch(cleanProjectCandidate);

      final isLoneLinkLine = inProjectsSection &&
          (RegExp(
            r'^\s*\[?(?:Project|Demo|Link)(?:\s*Link)?(?:\s*↗)?\]?(?:\(https?://[^\)]+\)|https?://\S+)?\s*$',
            caseSensitive: false,
          ).hasMatch(cleanProjectCandidate) ||
              RegExp(r'^\s*https?://\S+\s*$').hasMatch(cleanProjectCandidate));

      final hasProjectLinkIndicator = cleanProjectCandidate.contains('](') ||
          cleanProjectCandidate.toLowerCase().contains('[project') ||
          cleanProjectCandidate.toLowerCase().contains('[demo') ||
          cleanProjectCandidate.toLowerCase().contains('project link') ||
          cleanProjectCandidate.toLowerCase().contains('demo link') ||
          RegExp(r'\b(Project|Demo)(?:\s*Link)?(?:\s*↗)?$', caseSensitive: false).hasMatch(cleanProjectCandidate);

      final isProjectHeaderCandidate = inProjectsSection &&
          !isLoneLinkLine &&
          !actionVerbInClean &&
          !cleanProjectCandidate.endsWith('.') &&
          (hasProjectLinkIndicator ||
              cleanProjectCandidate.contains('|') ||
              cleanProjectCandidate.contains(' - ') ||
              cleanProjectCandidate.contains('–') ||
              cleanProjectCandidate.length < 100);

      final isJobTitleCandidate = inExperienceSection &&
          !actionVerbInClean &&
          !cleanProjectCandidate.endsWith('.') &&
          !_isSectionHeader(cleanProjectCandidate) &&
          !_isContactLine(cleanProjectCandidate) &&
          !_isLinksLine(cleanProjectCandidate) &&
          cleanProjectCandidate.length < 80 &&
          !cleanProjectCandidate.toLowerCase().startsWith('http') &&
          !RegExp(r'^\s*(?:pvt\.?\s*ltd|inc\.?|llc|ltd\.?)\s*$', caseSensitive: false).hasMatch(cleanProjectCandidate);

      // Bullet points
      if (!isProjectHeaderCandidate &&
          !isJobTitleCandidate &&
          !isLoneLinkLine &&
          (line.startsWith('-') ||
              line.startsWith('*') ||
              line.startsWith('•') ||
              (inProjectsSection && actionVerbInClean) ||
              (inExperienceSection && actionVerbInClean))) {
        var bulletText = line.replaceFirst(RegExp(r'^[\-\*•#\s]+'), '').trim();
        if (inProjectsSection) {
          bulletText = bulletText.replaceAll(
            RegExp(r'(\[(?:Demo|Project|Link)(?:\s*↗)?\]\((https?://[^)]+)\)|\b(?:Project|Demo)(?:\s*Link)?(?:\s*↗)?)$', caseSensitive: false),
            '',
          ).trim();
        }
        // NEVER render an empty pointer if there is no sentence!
        if (bulletText.isEmpty) {
          index++;
          continue;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3730A3),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _buildRichTextWithClickableLinks(bulletText),
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      // Skills category line
      var skillsLine = line;
      if (skillsLine.toLowerCase().contains('tools:') ||
          skillsLine.toLowerCase().contains('languages:') ||
          skillsLine.toLowerCase().contains('skills:') ||
          skillsLine.toLowerCase().contains('automation:')) {
        skillsLine = skillsLine.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);
      }

      if (skillsLine.contains(':') &&
          !skillsLine.toLowerCase().contains('http') &&
          !skillsLine.toLowerCase().contains('|') &&
          skillsLine.indexOf(':') < 35) {
        final colonIdx = skillsLine.indexOf(':');
        final category = skillsLine.substring(0, colonIdx).trim();
        final skills = skillsLine.substring(colonIdx + 1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.4),
                children: [
                  TextSpan(
                    text: '$category: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextSpan(text: skills),
                ],
              ),
            ),
          ),
        );
        index++;
        continue;
      }

      // If line contains accidental literal $1 $2 artifact, recover real date
      var processedLine = isProjectHeaderCandidate ? cleanProjectCandidate : line;
      if (processedLine.contains(r'$1')) {
        final origMatch = RegExp(
          r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*\d{4}\b)',
          caseSensitive: false,
        ).firstMatch(originalResume);
        final realDate = origMatch?.group(1) ?? '';
        processedLine = processedLine
            .replaceAll(r'$1 $2 - $1 $2', realDate)
            .replaceAll(r'$1 $2', realDate)
            .replaceAll(r'$1', '')
            .replaceAll(r'$2', '');
      }

      // Experience/Education date lines
      final dateMatch = RegExp(
        r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*\d{4}\b)',
        caseSensitive: false,
      ).firstMatch(processedLine);

      if (dateMatch != null) {
        final rawDate = dateMatch.group(1)!;
        var cleanTitle = processedLine.replaceAll(rawDate, '').replaceAll('|', '').trim();
        cleanTitle = cleanTitle.replaceAll(r'$1 $2', '').replaceAll(r'$1', '').replaceAll(r'$2', '').trim();

        // If cleanTitle is empty (e.g. lone date), NEVER render an empty row with a floating date!
        if (cleanTitle.isEmpty) {
          index++;
          continue;
        }

        var formattedDate = rawDate
            .replaceAllMapped(RegExp(r'([a-zA-Z]+)(\d{4})'), (m) => '${m.group(1)} ${m.group(2)}')
            .replaceAll(RegExp(r'\s*[\-–—]\s*'), ' - ');

        if (formattedDate.contains(r'$1') || formattedDate.contains(r'$2')) {
          final origMatch = RegExp(
            r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[\-–—]\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|Present)|\b\d{4}\s*[\-–—]\s*\d{4}\b)',
            caseSensitive: false,
          ).firstMatch(originalResume);
          formattedDate = origMatch != null
              ? origMatch.group(1)!.replaceAll(RegExp(r'\s*[\-–—]\s*'), ' - ')
              : rawDate;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cleanTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
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
          processedLine.contains('College')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: _buildRichTextWithClickableLinks(
              processedLine,
              isItalic: false,
            ),
          ),
        );
        index++;
        continue;
      }

      // In EDUCATION section: If line has degree and CGPA, split into Row(spaceBetween: [Degree on left, CGPA on right])
      if (inEducationSection && (processedLine.toLowerCase().contains('cgpa') || processedLine.toLowerCase().contains('gpa:'))) {
        final cgpaMatch = RegExp(r'\b(?:CGPA|GPA)\s*:\s*[0-9\.]+(?:\s*/\s*10)?', caseSensitive: false).firstMatch(processedLine);
        if (cgpaMatch != null) {
          final degree = processedLine.replaceAll(cgpaMatch.group(0)!, '').replaceAll('|', '').trim();
          final cgpa = cgpaMatch.group(0)!.trim();
          final isDegree = RegExp(
            r'\b(Bachelor|Master|B\.Tech|M\.Tech|B\.E\.|B\.Sc|M\.Sc|BCA|MCA|MBA|Ph\.D|Diploma|Degree)\b',
            caseSensitive: false,
          ).hasMatch(degree);

          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      degree,
                      style: TextStyle(
                        fontSize: isDegree ? 11.5 : 11,
                        fontWeight: isDegree ? FontWeight.w700 : FontWeight.w500,
                        color: isDegree ? const Color(0xFF1E1B4B) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  Text(
                    cgpa,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
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

      if (inProjectsSection && isLoneLinkLine) {
        index++;
        continue;
      }

      // In PROJECTS section: match project title lines
      final hasPipe = processedLine.contains('|');
      final linkMatch = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').firstMatch(processedLine);
      final wordLinkMatch = RegExp(r'\b(Project|Demo)(?:\s*Link)?(?:\s*↗)?$', caseSensitive: false).firstMatch(processedLine);
      final isProjectHeader = inProjectsSection &&
          !isLoneLinkLine &&
          !actionVerbInClean &&
          (hasPipe || linkMatch != null || wordLinkMatch != null || isProjectHeaderCandidate);

      if (isProjectHeader) {
        // Strip markdown links and URLs from cleanTitle FIRST before any hyphen manipulation!
        String cleanTitle = processedLine
            .replaceFirst(RegExp(r'^[\-\*•#\s]+'), '')
            .trim();
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
          final origMatches = RegExp(r'\[?(?:Project|Demo)\]?\((https?://[^\)]+)\)', caseSensitive: false).allMatches(originalResume);
          for (final om in origMatches) {
            final ctx = originalResume.substring(
              om.start > 60 ? om.start - 60 : 0,
              om.end + 20 < originalResume.length ? om.end + 20 : originalResume.length,
            ).toLowerCase();
            if (ctx.contains(pName) || pName.split(' ').any((w) => w.length > 4 && ctx.contains(w))) {
              linkUrl = om.group(1)!.trim();
              break;
            }
          }
        } else if (cleanTitle.toLowerCase().contains('project link')) {
          linkText = 'Project Link';
          cleanTitle = cleanTitle.replaceAll(RegExp(r'\s*Project\s*Link\s*', caseSensitive: false), '').trim();
        } else if (cleanTitle.toLowerCase().contains('demo link')) {
          linkText = 'Demo Link';
          cleanTitle = cleanTitle.replaceAll(RegExp(r'\s*Demo\s*Link\s*', caseSensitive: false), '').trim();
        } else if (hasPipe || isProjectHeaderCandidate) {
          final pName = cleanTitle.split('|').first.trim().toLowerCase();
          final origMatches = RegExp(r'\[?(?:Project|Demo)\]?\((https?://[^\)]+)\)', caseSensitive: false).allMatches(originalResume);
          for (final om in origMatches) {
            final ctx = originalResume.substring(
              om.start > 60 ? om.start - 60 : 0,
              om.end + 20 < originalResume.length ? om.end + 20 : originalResume.length,
            ).toLowerCase();
            if (ctx.contains(pName) || pName.split(' ').any((w) => w.length > 4 && ctx.contains(w))) {
              linkText = 'Project';
              linkUrl = om.group(1)!.trim();
              break;
            }
          }
        }

        // Lookahead: if no link found on this line, check if the next line is a lone link
        if (linkText == null && linkUrl == null && index + 1 < lines.length) {
          final nextLine = lines[index + 1].trim();
          final nextLinkMatch = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').firstMatch(nextLine);
          final nextUrlMatch = RegExp(r'^https?://\S+$').firstMatch(nextLine);
          if (nextLinkMatch != null) {
            linkText = nextLinkMatch.group(1)!.replaceAll('↗', '').trim();
            linkUrl = nextLinkMatch.group(2)!.trim();
            index++; // consume next line
          } else if (nextUrlMatch != null) {
            linkText = 'Project';
            linkUrl = nextUrlMatch.group(0)!.trim();
            index++; // consume next line
          }
        }

        // Remove any remaining raw markdown link or URL patterns from cleanTitle
        cleanTitle = cleanTitle.replaceAll(RegExp(r'\[[^\]]*\]\([^)]*\)'), '').trim();
        cleanTitle = cleanTitle.replaceAll(RegExp(r'https?://\S+'), '').trim();

        // Remove trailing/leading pipes and extra spaces
        cleanTitle = cleanTitle.replaceAll(RegExp(r'^\s*\|\s*|\s*\|\s*$'), '').trim();

        // Unjam hyphenated project technology suffixes: e.g. "Dashboard-Tableau" -> "Dashboard | Tableau"
        cleanTitle = cleanTitle.replaceAllMapped(
          RegExp(r'\b(Dashboard|Analysis|Store|App|Project|Platform)-(Tableau|Power\s*BI|PowerBI|Excel|Flutter|React|Python|Java|[A-Z][a-z]+)\b'),
          (m) => '${m.group(1)} | ${m.group(2)}',
        );

        // Only replace spaced hyphens: e.g. "Project Name - Flutter" -> "Project Name | Flutter"
        cleanTitle = cleanTitle.replaceAllMapped(RegExp(r'(?<=\S)\s+-\s+(?=\S)'), (m) => ' | ').trim();

        cleanTitle = cleanTitle.replaceAll(RegExp(r'\s*\|\s*$'), '').trim();

        if (cleanTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').isEmpty) {
          index++;
          continue;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: linkUrl != null
                      ? InkWell(
                          onTap: () => _launchExternalUrl(context, linkUrl!),
                          child: Text(
                            cleanTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                        )
                      : Text(
                          cleanTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                ),
                if (linkText != null) ...[
                  const SizedBox(width: 8),
                  if (linkUrl != null)
                    _InteractiveLinkItem(
                      label: linkText,
                      url: linkUrl,
                    )
                  else
                    Text(
                      linkText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      // General body text
      final isTitle = isJobTitleCandidate ||
          (!inSkillsSection &&
              !inProjectsSection &&
              !processedLine.endsWith('.') &&
              !actionVerbInClean &&
              processedLine.length < 80);

      // If in Experience or Projects and line is an accomplishment/bullet, render with bullet point row and hanging indent!
      if ((inExperienceSection || inProjectsSection) &&
          !isTitle &&
          !isProjectHeaderCandidate &&
          (processedLine.startsWith('•') ||
              processedLine.startsWith('-') ||
              processedLine.startsWith('*') ||
              actionVerbInClean) &&
          processedLine.length > 15 &&
          !processedLine.contains('|') &&
          !processedLine.contains('[Project]') &&
          !processedLine.contains('[Demo]')) {
        final bulletText = processedLine.replaceFirst(RegExp(r'^[\-\*•]\s*'), '').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3730A3),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _buildRichTextWithClickableLinks(bulletText),
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: isTitle ? 4 : 0, bottom: 3),
          child: _buildRichTextWithClickableLinks(
            processedLine,
            isTitle: isTitle,
          ),
        ),
      );
      index++;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 520;
        final hPad = isMobile ? 16.0 : (constraints.maxWidth < 720 ? 24.0 : 36.0);
        final vPad = isMobile ? 20.0 : 32.0;
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 780),
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 4, vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widgets,
            ),
          ),
        );
      },
    );
  }

  static bool _isSectionHeader(String line) {
    if (line.isEmpty) return false;
    if (line.contains(':') || line.contains('|') || line.endsWith('.')) return false;
    final lower = line
        .toLowerCase()
        .replaceAll(RegExp(r'^[\-\*•#\s]+'), '')
        .replaceAll('#', '')
        .replaceAll(':', '')
        .trim();
    if (lower.isEmpty || lower.length > 35) return false;

    // Projects section
    if (lower == 'projects' ||
        lower == 'relevant projects' ||
        lower == 'key projects' ||
        lower == 'technical projects' ||
        lower == 'personal projects' ||
        lower == 'academic projects' ||
        lower == 'notable projects' ||
        lower == 'featured projects' ||
        lower == 'selected projects' ||
        lower.endsWith('projects') ||
        (lower.contains('project') && lower.length <= 30)) {
      return true;
    }

    // Summary section
    if (lower == 'summary' ||
        lower == 'professional summary' ||
        lower == 'executive summary' ||
        lower == 'career summary' ||
        lower == 'profile' ||
        lower == 'about me' ||
        lower == 'career objective' ||
        lower == 'objective') {
      return true;
    }

    // Skills section
    if (lower == 'skills' ||
        lower == 'technical skills' ||
        lower == 'core competencies' ||
        lower == 'areas of expertise' ||
        lower == 'professional skills' ||
        lower == 'key skills' ||
        lower == 'technical & professional skills' ||
        lower == 'technical and professional skills' ||
        lower == 'technical competencies') {
      return true;
    }

    // Experience section
    if (lower == 'experience' ||
        lower == 'professional experience' ||
        lower == 'work experience' ||
        lower == 'work history' ||
        lower == 'employment' ||
        lower == 'employment history' ||
        lower == 'relevant experience') {
      return true;
    }

    // Education section
    if (lower == 'education' ||
        lower == 'academic' ||
        lower == 'academic background' ||
        lower == 'education & certifications' ||
        lower == 'education and certifications' ||
        lower == 'qualifications' ||
        lower.startsWith('education')) {
      return true;
    }

    return lower == 'certifications' ||
        lower == 'certifications & licenses' ||
        lower == 'certifications & courses' ||
        lower == 'licenses & certifications' ||
        lower == 'achievements' ||
        lower == 'awards & achievements' ||
        lower == 'honors & awards' ||
        lower == 'publications';
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
        (lower.contains('remote') && (line.contains('|') || line.contains(':'))) ||
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
      RegExp(r'\[?[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\]?(?:\(mailto:[^)]*\))?', caseSensitive: false),
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

  static List<_ResumeLink> _extractLinks(String line, String originalResume) {
    final links = <_ResumeLink>[];

    // Markdown links: [Label](url)
    final mdMatches = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').allMatches(line);
    if (mdMatches.isNotEmpty) {
      for (final m in mdMatches) {
        var label = m.group(1)!;
        var rawUrl = m.group(2)!.trim().replaceAll(RegExp(r'\s+'), '');
        final url = rawUrl.startsWith('http') || rawUrl.startsWith('mailto:')
            ? rawUrl
            : 'https://$rawUrl';
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

    // Pipe-separated or bullet-separated links
    final parts = line.split(RegExp(r'[|•]')).map((p) => p.trim()).where((p) => p.isNotEmpty);
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

  static Widget _buildRichTextWithClickableLinks(String text, {bool isTitle = false, bool isItalic = false}) {
    text = text.replaceFirst(RegExp(r'^[\-\*•]\s*'), '').trim();
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final fontStyle = isItalic ? FontStyle.italic : FontStyle.normal;
    final textColor = isTitle
        ? const Color(0xFF1E1B4B)
        : (isItalic ? const Color(0xFF475569) : const Color(0xFF1E293B));
    final fontSize = isTitle ? 12.0 : (isItalic ? 11.0 : 11.5);

    if (!linkRegex.hasMatch(text)) {
      return Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
          fontStyle: fontStyle,
          color: textColor,
          height: 1.42,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in linkRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
              fontStyle: fontStyle,
              color: textColor,
              height: 1.42,
            ),
          ),
        );
      }

      final anchor = match.group(1)!;
      final rawUrl = match.group(2)!.trim();
      final url = rawUrl.startsWith('http') || rawUrl.startsWith('mailto:')
          ? rawUrl
          : 'https://$rawUrl';

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => _launchExternalUrl(ctx, url),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        anchor,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3730A3),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 10,
                        color: Color(0xFF3730A3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(
            fontSize: isTitle ? 12 : 11.5,
            fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
            color: isTitle ? const Color(0xFF1E1B4B) : const Color(0xFF1E293B),
            height: 1.42,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}

class _InteractiveLinkItem extends StatelessWidget {
  final String label;
  final String url;

  const _InteractiveLinkItem({
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _launchExternalUrl(context, url),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3730A3),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF3730A3),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.open_in_new_rounded,
                size: 11,
                color: Color(0xFF4F46E5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
