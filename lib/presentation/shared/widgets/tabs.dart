import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Underline Tab Bar for S02-S05 (Tổng quan / Hồ sơ / Khu vực / Tài chính)
/// and S06 (Video / Lô đang bán / Đánh giá).
class UnderlineTabBar extends StatelessWidget {
  const UnderlineTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.isScrollable = true,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.tabBarMinHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppSpacing.borderWidthRegular,
          ),
        ),
      ),
      child: isScrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  tabs.length,
                  (index) => _buildTabItem(index),
                ),
              ),
            )
          : Row(
              children: List.generate(
                tabs.length,
                (index) => Expanded(child: _buildTabItem(index)),
              ),
            ),
    );
  }

  Widget _buildTabItem(int index) {
    final isSelected = index == selectedIndex;
    return InkWell(
      onTap: () => onTabSelected(index),
      child: Container(
        height: AppSpacing.tabBarMinHeight,
        constraints: const BoxConstraints(minWidth: AppSpacing.minTouchTarget),
        padding: EdgeInsets.symmetric(
          horizontal: isScrollable ? AppSpacing.s16 : AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.brandPrimary : Colors.transparent,
              width: AppSpacing.borderWidthSelected,
            ),
          ),
        ),
        child: Center(
          child: Text(
            tabs[index],
            style: isSelected
                ? AppTypography.bodyStrong.copyWith(
                    color: AppColors.brandPrimary,
                  )
                : AppTypography.body.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

/// Pill Tabs for filters and segment selection (e.g. S01 Phù hợp/Mới nhất/Đã lưu).
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: Row(
        children: List.generate(items.length, (index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: Semantics(
              selected: isSelected,
              button: true,
              child: Material(
                color: isSelected ? AppColors.brandPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.chipVisualHeight,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        items[index],
                        style: isSelected
                            ? AppTypography.compactStrong.copyWith(
                                color: AppColors.onPrimary,
                              )
                            : AppTypography.compact.copyWith(
                                color: AppColors.textPrimary,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
