import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Displays golden crowns (1 per 1000 five-star reviews) and leftover
/// achievement stars (1 per 100 five-star reviews).
class AchievementBadges extends StatelessWidget {
  const AchievementBadges({
    super.key,
    this.goldenCrowns = 0,
    this.achievementStars = 0,
    this.iconSize = 18,
    this.maxCrowns = 3,
    this.maxStars = 5,
  });

  final int goldenCrowns;
  final int achievementStars;
  final double iconSize;
  final int maxCrowns;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    if (goldenCrowns <= 0 && achievementStars <= 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (goldenCrowns > 0) ...[
          ...List.generate(
            goldenCrowns.clamp(0, maxCrowns),
            (_) => Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                Icons.workspace_premium,
                size: iconSize + 2,
                color: AppColors.goldenCrown,
              ),
            ),
          ),
          if (goldenCrowns > maxCrowns)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '×$goldenCrowns',
                style: TextStyle(
                  fontSize: iconSize * 0.7,
                  fontWeight: FontWeight.w800,
                  color: AppColors.goldenCrown,
                ),
              ),
            ),
        ],
        if (achievementStars > 0)
          ...List.generate(
            achievementStars.clamp(0, maxStars),
            (_) => Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                Icons.star_rounded,
                size: iconSize,
                color: AppColors.star,
              ),
            ),
          ),
      ],
    );
  }
}
