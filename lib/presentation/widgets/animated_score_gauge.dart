import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/analysis_result.dart';

class AnimatedScoreGauge extends StatefulWidget {
  final AnalysisResult analysis;

  const AnimatedScoreGauge({super.key, required this.analysis});

  @override
  State<AnimatedScoreGauge> createState() => _AnimatedScoreGaugeState();
}

class _AnimatedScoreGaugeState extends State<AnimatedScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.analysis.matchScore,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analysis.matchScore != widget.analysis.matchScore) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.analysis.matchScore,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    final isUnlocked = analysis.isEligibleForUpdate;
    final primaryColor = isUnlocked ? AppColors.matchHigh : AppColors.matchMid;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? AppColors.matchHigh.withOpacity(0.4)
              : AppColors.darkBorder,
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: [
          if (isUnlocked)
            BoxShadow(
              color: AppColors.matchHigh.withOpacity(0.12),
              blurRadius: 28,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        children: [
          // Header with Threshold Badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked ? Icons.verified_rounded : Icons.radar_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'ATS Compatibility Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.matchHigh.withOpacity(0.15)
                      : AppColors.matchMid.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUnlocked ? AppColors.matchHigh : AppColors.matchMid,
                    width: 1,
                  ),
                ),
                child: Text(
                  isUnlocked
                      ? 'THRESHOLD UNLOCKED (≥ ${analysis.threshold.toInt()}%)'
                      : 'LOCKED (< ${analysis.threshold.toInt()}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isUnlocked ? AppColors.matchHigh : AppColors.matchMid,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Metadata Badges (Domain, Role, Seniority)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetadataBadge(
                icon: Icons.work_outline_rounded,
                label: analysis.detectedJobTitle,
                color: AppColors.primaryLight,
              ),
              _MetadataBadge(
                icon: Icons.domain_rounded,
                label: analysis.detectedDomain,
                color: AppColors.secondary,
              ),
              _MetadataBadge(
                icon: Icons.timeline_rounded,
                label: analysis.detectedSeniority,
                color: AppColors.cityAligned,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Circular Radial Gauge
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final val = _animation.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _RadialGaugePainter(
                        progress: val / 100.0,
                        color: isUnlocked
                            ? AppColors.matchHigh
                            : (val >= 60 ? AppColors.matchMid : AppColors.matchLow),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            val.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: isUnlocked
                                  ? AppColors.matchHigh
                                  : AppColors.darkTextPrimary,
                            ),
                          ),
                          const Text(
                            '/100',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isUnlocked ? 'High Compatibility' : 'Alignment Gaps',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isUnlocked
                              ? AppColors.matchHigh
                              : AppColors.matchMid,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // 6 Configurable Dimensions Breakdown
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SCORING RUBRIC BREAKDOWN (100 PTS TOTAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.darkTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          _SubScoreBar(
            label: 'A. Required Skills & Competencies (30 pts)',
            score: analysis.skillsScore,
            maxScore: 30.0,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _SubScoreBar(
            label: 'B. Relevant Experience & Duties (25 pts)',
            score: analysis.experienceScore,
            maxScore: 25.0,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          _SubScoreBar(
            label: 'C. Job-Specific Keywords & Terminology (15 pts)',
            score: analysis.keywordsScore,
            maxScore: 15.0,
            color: const Color(0xFF38BDF8), // Light Blue
          ),
          const SizedBox(height: 8),
          _SubScoreBar(
            label: 'D. Education & Eligibility (10 pts)',
            score: analysis.educationScore,
            maxScore: 10.0,
            color: AppColors.cityAligned,
          ),
          const SizedBox(height: 8),
          _SubScoreBar(
            label: 'E. Achievements & Evidence of Impact (10 pts)',
            score: analysis.achievementsScore,
            maxScore: 10.0,
            color: const Color(0xFFF59E0B), // Amber
          ),
          const SizedBox(height: 8),
          _SubScoreBar(
            label: 'F. Resume Readability & Parsing (10 pts)',
            score: analysis.readabilityScore,
            maxScore: 10.0,
            color: const Color(0xFFA855F7), // Purple
          ),

          const SizedBox(height: 18),

          // Score Explanation Note
          if (analysis.scoreExplanation.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Text(
                analysis.scoreExplanation,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.darkTextSecondary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetadataBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetadataBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadialGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 14.0;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFF1E2843)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Active progress track
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (math.pi * 1.5) * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _SubScoreBar extends StatelessWidget {
  final String label;
  final double score;
  final double maxScore;
  final Color color;

  const _SubScoreBar({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score / maxScore).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${score.toStringAsFixed(1)} / ${maxScore.toInt()}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: const Color(0xFF1E2843),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
