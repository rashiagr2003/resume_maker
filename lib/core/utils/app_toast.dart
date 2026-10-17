import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    Color bgColor;
    Color borderColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case ToastType.success:
        bgColor = const Color(0xFF064E3B);
        borderColor = AppColors.matchHigh;
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.matchHigh;
        break;
      case ToastType.error:
        bgColor = const Color(0xFF7F1D1D);
        borderColor = AppColors.matchLow;
        icon = Icons.error_outline_rounded;
        iconColor = AppColors.matchLow;
        break;
      case ToastType.warning:
        bgColor = const Color(0xFF78350F);
        borderColor = AppColors.matchMid;
        icon = Icons.warning_amber_rounded;
        iconColor = AppColors.matchMid;
        break;
      case ToastType.info:
        bgColor = const Color(0xFF1E1B4B);
        borderColor = AppColors.primaryLight;
        icon = Icons.info_outline_rounded;
        iconColor = AppColors.primaryLight;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        duration: duration,
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
