import 'package:flutter/material.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';

/// Tab Sự kiện (Tab 2 trong MainNavigationShell).
/// Tạm thời để trống cho giai đoạn sau theo yêu cầu thiết kế.
class EventsTabPage extends StatelessWidget {
  const EventsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const XLandAppBar(
          variant: XLandAppBarVariant.light,
          title: 'Sự kiện',
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pageGutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.verifiedSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_outlined,
                      size: 36,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'Sự kiện XLand',
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Tính năng sự kiện đang được hoàn thiện và sẽ sớm ra mắt.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
