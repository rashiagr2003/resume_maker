import 'package:flutter/material.dart';

/// Candidate-verified proficiency levels for skills and qualifications.
enum SkillProficiency {
  beginner(
    label: 'Beginner',
    shortLabel: 'Beginner',
    description: 'Foundational knowledge or introductory exposure',
    color: Color(0xFF60A5FA), // Light Blue
    icon: Icons.school_outlined,
  ),
  intermediate(
    label: 'Intermediate',
    shortLabel: 'Intermediate',
    description: 'Working competence and practical hands-on application',
    color: Color(0xFF34D399), // Emerald
    icon: Icons.trending_up_rounded,
  ),
  advanced(
    label: 'Advanced / Professional',
    shortLabel: 'Advanced',
    description: 'Deep mastery, production-grade or extensive workplace practice',
    color: Color(0xFFA78BFA), // Violet/Purple
    icon: Icons.workspace_premium_rounded,
  ),
  learning(
    label: 'Currently Learning',
    shortLabel: 'Learning',
    description: 'Actively pursuing, enrolled in courses, or self-studying',
    color: Color(0xFFFBBF24), // Amber
    icon: Icons.auto_awesome_outlined,
  );

  final String label;
  final String shortLabel;
  final String description;
  final Color color;
  final IconData icon;

  const SkillProficiency({
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.color,
    required this.icon,
  });
}

/// A skill explicitly verified or customized by the user.
class UserSkillEntry {
  final String skill;
  final SkillProficiency proficiency;
  final bool isCustom;
  final DateTime selectedAt;

  const UserSkillEntry({
    required this.skill,
    required this.proficiency,
    this.isCustom = false,
    required this.selectedAt,
  });

  UserSkillEntry copyWith({
    String? skill,
    SkillProficiency? proficiency,
    bool? isCustom,
    DateTime? selectedAt,
  }) {
    return UserSkillEntry(
      skill: skill ?? this.skill,
      proficiency: proficiency ?? this.proficiency,
      isCustom: isCustom ?? this.isCustom,
      selectedAt: selectedAt ?? this.selectedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'skill': skill,
        'proficiency': proficiency.name,
        'isCustom': isCustom,
        'selectedAt': selectedAt.toIso8601String(),
      };

  factory UserSkillEntry.fromJson(Map<String, dynamic> json) {
    return UserSkillEntry(
      skill: json['skill'] as String,
      proficiency: SkillProficiency.values.firstWhere(
        (e) => e.name == json['proficiency'],
        orElse: () => SkillProficiency.intermediate,
      ),
      isCustom: json['isCustom'] as bool? ?? false,
      selectedAt: json['selectedAt'] != null
          ? DateTime.tryParse(json['selectedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSkillEntry &&
          runtimeType == other.runtimeType &&
          skill.toLowerCase() == other.skill.toLowerCase() &&
          proficiency == other.proficiency &&
          isCustom == other.isCustom;

  @override
  int get hashCode => skill.toLowerCase().hashCode ^ proficiency.hashCode ^ isCustom.hashCode;
}
