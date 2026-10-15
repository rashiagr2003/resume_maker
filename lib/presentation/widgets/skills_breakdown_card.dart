import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/user_skill_entry.dart';
import '../providers/resume_providers.dart';
import 'skill_proficiency_dialog.dart';

enum SkillFilterCategory {
  all,
  verified,
  missing,
  learning,
}

class SkillsBreakdownCard extends ConsumerStatefulWidget {
  final AnalysisResult analysis;

  const SkillsBreakdownCard({super.key, required this.analysis});

  @override
  ConsumerState<SkillsBreakdownCard> createState() => _SkillsBreakdownCardState();
}

class _SkillsBreakdownCardState extends ConsumerState<SkillsBreakdownCard> {
  late TextEditingController _searchController;
  late TextEditingController _customSkillController;
  String _searchQuery = '';
  SkillFilterCategory _activeFilter = SkillFilterCategory.all;
  SkillProficiency _customSkillProficiency = SkillProficiency.intermediate;
  bool _showCustomSkillForm = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _customSkillController = TextEditingController();

    // If analysis already has verified skills and state is empty, seed state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentMap = ref.read(verifiedSkillsProvider);
      if (currentMap.isEmpty && widget.analysis.userVerifiedSkills.isNotEmpty) {
        for (final entry in widget.analysis.userVerifiedSkills.entries) {
          ref.read(verifiedSkillsProvider.notifier).setSkill(
                entry.value.skill,
                entry.value.proficiency,
                isCustom: entry.value.isCustom,
              );
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customSkillController.dispose();
    super.dispose();
  }

  Future<void> _openProficiencyDialog(
    BuildContext context,
    String skill, {
    UserSkillEntry? existingEntry,
    bool isCustom = false,
  }) async {
    final result = await SkillProficiencyDialog.show(
      context,
      skill: skill,
      existingEntry: existingEntry,
      isCustom: isCustom,
    );

    if (!mounted || result == null) return;

    if (isRemoveSentinel(result)) {
      ref.read(verifiedSkillsProvider.notifier).removeSkill(skill);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$skill" from selections.'),
          backgroundColor: AppColors.matchMid,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ref.read(verifiedSkillsProvider.notifier).setSkill(
            result.skill,
            result.proficiency,
            isCustom: result.isCustom,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated "$skill" → ${result.proficiency.label}!',
          ),
          backgroundColor: result.proficiency.color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addCustomSkill() {
    final skillName = _customSkillController.text.trim();
    if (skillName.isEmpty) return;

    ref.read(verifiedSkillsProvider.notifier).setSkill(
          skillName,
          _customSkillProficiency,
          isCustom: true,
        );

    _customSkillController.clear();
    setState(() => _showCustomSkillForm = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added custom competency: "$skillName" (${_customSkillProficiency.label})',
        ),
        backgroundColor: _customSkillProficiency.color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveAndRecalculate() async {
    setState(() => _isSaving = true);
    final verifiedMap = ref.read(verifiedSkillsProvider);

    // Apply verified competencies to analysis in provider
    ref.read(analysisProvider.notifier).applyVerifiedSkills(verifiedMap);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isSaving = false);

    final updatedAnalysis = ref.read(analysisProvider).valueOrNull;
    final newScore = updatedAnalysis?.matchScore ?? widget.analysis.matchScore;
    final isNowUnlocked = (updatedAnalysis?.isEligibleForUpdate ?? false);

    // If a tailored resume is already generated, re-tailor with candidate's newly saved preferences
    final tailoredState = ref.read(tailoredResumeProvider).valueOrNull;
    if (tailoredState != null && updatedAnalysis != null) {
      final inputState = ref.read(resumeInputProvider);
      final forceOverride = ref.read(forceOverrideProvider);
      ref.read(tailoredResumeProvider.notifier).tailorResume(
            input: inputState,
            analysis: updatedAnalysis,
            forceOverride: forceOverride,
          );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowUnlocked
              ? '🎉 Verified ${verifiedMap.length} skills! Score updated to ${newScore.toStringAsFixed(1)}% — Optimization Studio UNLOCKED!'
              : 'Saved ${verifiedMap.length} verified skills! Updated ATS score: ${newScore.toStringAsFixed(1)}%.',
        ),
        backgroundColor: isNowUnlocked ? AppColors.matchHigh : AppColors.primary,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verifiedMap = ref.watch(verifiedSkillsProvider);
    final analysis = widget.analysis;

    // Build the complete list of suggested skills (missing + partially matched + any custom)
    final allSuggestedSkills = <String>{
      ...analysis.missingSkills,
      ...analysis.partiallyMatchedRequirements,
      ...verifiedMap.keys,
    }.toList();

    // Filter by search query
    final query = _searchQuery.toLowerCase().trim();
    final searchFiltered = allSuggestedSkills.where((s) {
      if (query.isEmpty) return true;
      return s.toLowerCase().contains(query);
    }).toList();

    // Filter by active category tab
    final filteredSkills = searchFiltered.where((s) {
      final entry = verifiedMap[s] ??
          verifiedMap.entries
              .where((e) => e.key.toLowerCase() == s.toLowerCase())
              .map((e) => e.value)
              .firstOrNull;

      switch (_activeFilter) {
        case SkillFilterCategory.all:
          return true;
        case SkillFilterCategory.verified:
          return entry != null && entry.proficiency != SkillProficiency.learning;
        case SkillFilterCategory.missing:
          return entry == null;
        case SkillFilterCategory.learning:
          return entry != null && entry.proficiency == SkillProficiency.learning;
      }
    }).toList();

    final verifiedCount = verifiedMap.values
        .where((v) => v.proficiency != SkillProficiency.learning)
        .length;
    final learningCount = verifiedMap.values
        .where((v) => v.proficiency == SkillProficiency.learning)
        .length;
    final totalMissing = analysis.missingSkills.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Competency & Skill Gap Analysis',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              if (verifiedMap.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.matchHigh.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.matchHigh.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: AppColors.matchHigh, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${verifiedMap.length} Verified',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.matchHigh,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),
          const Text(
            'Tap any missing or partially matched skill to select your genuine proficiency level. Add unlisted skills or mark in-progress learning to dynamically optimize alignment.',
            style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary, height: 1.4),
          ),

          const SizedBox(height: 16),

          // 2. Matched Core Skills & Requirements
          const Text(
            'MATCHED CORE COMPETENCIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.matchHigh,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (analysis.matchedSkills.isEmpty)
            const Text(
              'No direct keyword matches found. Incorporate explicit role competencies from the job description.',
              style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analysis.matchedSkills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.matchHigh.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.matchHigh.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, color: AppColors.matchHigh, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.matchHigh,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),

          // 3. Interactive Skill Verification & Customization Studio Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MISSING IN RESUME (RECOMMENDED FOR ${analysis.threshold.toInt()}%+ BOOST)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.matchMid,
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() => _showCustomSkillForm = !_showCustomSkillForm);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showCustomSkillForm ? Icons.remove_circle_outline : Icons.add_circle_outline,
                        size: 13,
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showCustomSkillForm ? 'Hide Custom Input' : '+ Add Custom Skill',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 4. "Add Custom Skill" Inline Form (Collapsible)
          if (_showCustomSkillForm) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Unlisted Skill or Tool',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customSkillController,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g. Workday, Bullhorn, Boolean Search, HIPAA',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            prefixIcon: const Icon(Icons.add_task_rounded, size: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onSubmitted: (_) => _addCustomSkill(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCustomSkill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        ),
                        child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Proficiency Level for this Skill:',
                    style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: SkillProficiency.values.map((p) {
                        final isSelected = _customSkillProficiency == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(p.icon, size: 12, color: isSelected ? Colors.white : p.color),
                                const SizedBox(width: 4),
                                Text(p.shortLabel, style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: p.color,
                            backgroundColor: AppColors.darkBg,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _customSkillProficiency = p);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search suggested skills (e.g. Recruit, Outreach)...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.darkTextSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.darkTextSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.darkBorder),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Filter Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All (${allSuggestedSkills.length})', SkillFilterCategory.all),
                const SizedBox(width: 6),
                _buildFilterChip('Verified ($verifiedCount)', SkillFilterCategory.verified),
                const SizedBox(width: 6),
                _buildFilterChip('Missing ($totalMissing)', SkillFilterCategory.missing),
                const SizedBox(width: 6),
                _buildFilterChip('Learning ($learningCount)', SkillFilterCategory.learning),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 6. Interactive Skill Chips Grid
          if (filteredSkills.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No suggested skills matching "$_searchQuery". Use "+ Add Custom Skill" above.'
                      : 'No skills found in this filter category.',
                  style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredSkills.map((skill) {
                final entry = verifiedMap[skill] ??
                    verifiedMap.entries
                        .where((e) => e.key.toLowerCase() == skill.toLowerCase())
                        .map((e) => e.value)
                        .firstOrNull;

                final isVerified = entry != null;

                if (isVerified) {
                  // Verified Skill Chip with Proficiency Badge & Actions
                  final p = entry.proficiency;
                  return InkWell(
                    onTap: () => _openProficiencyDialog(
                      context,
                      skill,
                      existingEntry: entry,
                      isCustom: entry.isCustom,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                      decoration: BoxDecoration(
                        color: p.color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: p.color, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p.icon, color: p.color, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            skill,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: p.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.shortLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: p.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              ref.read(verifiedSkillsProvider.notifier).removeSkill(skill);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, size: 13, color: p.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // Unverified Suggestion Chip
                  return InkWell(
                    onTap: () => _openProficiencyDialog(
                      context,
                      skill,
                      isCustom: false,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.matchMid.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.matchMid.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.matchMid,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            skill,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.matchMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }).toList(),
            ),

          const SizedBox(height: 16),

          // 7. Save Selections Action Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        verifiedMap.isEmpty
                            ? 'Select your genuine skills above to improve alignment.'
                            : '${verifiedMap.length} skill(s) verified by candidate.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: verifiedMap.isNotEmpty ? AppColors.matchHigh : AppColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Updates ATS match score and prepares factual resume optimization.',
                        style: TextStyle(fontSize: 10.5, color: AppColors.darkTextSecondary),
                      ),
                    ],
                  ),
                ),
                if (verifiedMap.isNotEmpty) ...[
                  TextButton(
                    onPressed: () {
                      ref.read(verifiedSkillsProvider.notifier).clear();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.darkTextSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                ],
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 15),
                  label: Text(
                    _isSaving ? 'Recalculating...' : 'Save & Recalculate Score',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _isSaving ? null : _saveAndRecalculate,
                ),
              ],
            ),
          ),

          // 8. Mandatory Gaps (if any)
          if (analysis.mandatoryGaps.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'MANDATORY QUALIFICATION GAPS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.matchLow,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analysis.mandatoryGaps.map((gap) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.matchLow.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.matchLow.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.matchLow, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        gap,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.matchLow,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // 9. Transferable Skills Identified
          if (analysis.transferableSkills.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'TRANSFERABLE COMPETENCIES IDENTIFIED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF38BDF8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analysis.transferableSkills.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: Color(0xFF38BDF8), size: 14),
                      const SizedBox(width: 5),
                      Text(
                        t,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // 10. Document Structure & Parsing Issues
          if (analysis.parsingIssues.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'DOCUMENT PARSING & FORMATTING ISSUES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF59E0B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...analysis.parsingIssues.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 14),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        issue,
                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // 11. Recommendations
          if (analysis.recommendations.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'ACTIONABLE RECOMMENDATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.darkTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...analysis.recommendations.map((rec) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.arrow_right_rounded,
                        color: AppColors.primaryLight,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rec,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkTextSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, SkillFilterCategory category) {
    final isSelected = _activeFilter == category;
    return InkWell(
      onTap: () => setState(() => _activeFilter = category),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.darkBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.darkBorder,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primaryLight : AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }
}
