
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppDecorations {
  /// Glassmorphism panel for map overlays
  static BoxDecoration get glassPanel {
    return BoxDecoration(
      color: AppColors.glassBackground,
      borderRadius: AppRadius.lgAll,
      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowMedium,
          blurRadius: 16,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  /// Branded card with subtle shadow for data lists
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

  /// Compact status pill badge
  static BoxDecoration pillBadge(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    );
  }

  /// Active filter pill
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

  /// Inactive filter pill
  static BoxDecoration get inactiveFilterPill {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    );
  }

  /// Map marker container 
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

  /// Download card for APK download prompts
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

  /// Info/release notes container
  static BoxDecoration get infoPanel {
    return BoxDecoration(
      color: AppColors.infoBackground,
      borderRadius: AppRadius.lgAll,
      border: Border.all(color: AppColors.infoBorder),
    );
  }
}
