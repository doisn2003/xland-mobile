import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../../../shared/widgets/design_widgets.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  static const categories = [
    'Đất nền',
    'Công nghiệp',
    'Pháp lý',
    'Tài chính',
    'Sự kiện',
  ];
  static const _icons = [
    Icons.landscape_outlined,
    Icons.factory_outlined,
    Icons.description_outlined,
    Icons.savings_outlined,
    Icons.calendar_month_outlined,
  ];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < categories.length; i++)
          Expanded(
            child: Semantics(
              selected: selectedIndex == i,
              button: true,
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.verifiedSurface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DesignIcon(
                        _icons[i],
                        size: 30,
                        color: i == 3
                            ? AppColors.goldDecorative
                            : AppColors.brandPrimary,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        categories[i],
                        style: AppTypography.compact,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 2,
                        width: 25,
                        color: selectedIndex == i
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
