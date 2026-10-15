import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/user_skill_entry.dart';

/// Modal dialog allowing users to pick or edit their genuine proficiency level
/// for a missing or partially matched skill, or mark it as currently learning.
class SkillProficiencyDialog extends StatefulWidget {
  final String skill;
  final UserSkillEntry? existingEntry;
  final bool isCustom;

  const SkillProficiencyDialog({
    super.key,
    required this.skill,
    this.existingEntry,
    this.isCustom = false,
  });

  static Future<UserSkillEntry?> show(
    BuildContext context, {
    required String skill,
    UserSkillEntry? existingEntry,
    bool isCustom = false,
  }) {
    return showDialog<UserSkillEntry>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SkillProficiencyDialog(
        skill: skill,
        existingEntry: existingEntry,
        isCustom: isCustom,
      ),
    );
  }

  @override
  State<SkillProficiencyDialog> createState() => _SkillProficiencyDialogState();
}

class _SkillProficiencyDialogState extends State<SkillProficiencyDialog> {
  late SkillProficiency _selectedProficiency;

  @override
  void initState() {
    super.initState();
    _selectedProficiency = widget.existingEntry?.proficiency ?? SkillProficiency.intermediate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: AppColors.primaryLight,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.skill,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select your actual proficiency level to reflect genuine experience.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.darkTextSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Proficiency Options List
              ...SkillProficiency.values.map((level) {
                final isSelected = _selectedProficiency == level;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedProficiency = level);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? level.color.withOpacity(0.12) : AppColors.darkBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? level.color : AppColors.darkBorder,
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? level.color.withOpacity(0.2)
                                  : AppColors.darkCard,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(level.icon, color: level.color, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      level.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? level.color : AppColors.darkTextPrimary,
                                      ),
                                    ),
                                    if (level == SkillProficiency.learning) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.matchMid.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'In Progress',
                                          style: TextStyle(fontSize: 10, color: AppColors.matchMid),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  level.description,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<SkillProficiency>(
                            value: level,
                            groupValue: _selectedProficiency,
                            activeColor: level.color,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedProficiency = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  if (widget.existingEntry != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.matchLow, size: 16),
                      label: const Text(
                        'Remove',
                        style: TextStyle(color: AppColors.matchLow, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(const _RemoveSkillSentinel());
                      },
                    ),
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkTextSecondary,
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      widget.existingEntry != null ? 'Update Level' : 'Add to Verified Skills',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedProficiency.color,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final result = UserSkillEntry(
                        skill: widget.skill,
                        proficiency: _selectedProficiency,
                        isCustom: widget.isCustom,
                        selectedAt: DateTime.now(),
                      );
                      Navigator.of(context).pop(result);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal sentinel to indicate the user explicitly clicked "Remove" in the dialog.
class _RemoveSkillSentinel extends UserSkillEntry {
  const _RemoveSkillSentinel()
      : super(
          skill: '',
          proficiency: SkillProficiency.beginner,
          selectedAt: const _StaticDate(),
        );
}

class _StaticDate implements DateTime {
  const _StaticDate();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

bool isRemoveSentinel(UserSkillEntry entry) => entry is _RemoveSkillSentinel;
