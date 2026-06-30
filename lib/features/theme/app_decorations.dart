import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppDecorations {
  static BoxDecoration get glassPanel {
    return BoxDecoration(
      color: AppColors.glassBackground,
      borderRadius: AppRadius.lgAll,
      border:
          Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowMedium,
          blurRadius: 16,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  static BoxDecoration get brandedCard {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowLight,
          blurRadius: 8,
          offset: const Offset(0, 2),
        )
      ],
    );
  }

  static BoxDecoration pillBadge(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    );
  }

  static BoxDecoration get activeFilterPill {
    return BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primary),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    );
  }

  static BoxDecoration get inactiveFilterPill {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    );
  }

  static BoxDecoration get mapMarker {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border, width: 2),
      boxShadow: [
        BoxShadow(color: AppColors.shadowMedium, blurRadius: 6),
      ],
    );
  }

  static BoxDecoration get downloadCard {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowLight,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration get infoPanel {
    return BoxDecoration(
      color: AppColors.infoBackground,
      borderRadius: AppRadius.lgAll,
      border: Border.all(color: AppColors.infoBorder),
    );
  }
}
