import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Standard 4-tab Bottom Navigation Bar according to BUSINESS.md v1.0 and DESIGN_SPEC.md v1.2:
/// 1. Trang chủ (Video feed)
/// 2. Khám phá (Discovery / Listing)
/// 3. Sự kiện (Events)
/// 4. Tôi (Profile & Settings)
class XLandBottomNavBar extends StatelessWidget {
  const XLandBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: AppSpacing.borderWidthRegular,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.bottomNavMinHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'Trang chủ',
                icon: Icons.play_circle_outline_rounded,
                selectedIcon: Icons.play_circle_filled_rounded,
              ),
              _buildNavItem(
                index: 1,
                label: 'Khám phá',
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore_rounded,
              ),
              _buildNavItem(
                index: 2,
                label: 'Sự kiện',
                icon: Icons.event_outlined,
                selectedIcon: Icons.event_rounded,
              ),
              _buildNavItem(
                index: 3,
                label: 'Tôi',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isSelected = index == currentIndex;
    final color = isSelected ? AppColors.brandPrimary : AppColors.textMuted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Tab $label',
        child: InkWell(
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: color,
                size: AppSpacing.iconRegular,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: isSelected
                    ? AppTypography.compactStrong.copyWith(color: color)
                    : AppTypography.compact.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
