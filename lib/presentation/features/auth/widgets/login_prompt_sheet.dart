import 'package:flutter/material.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../pages/login_page.dart';

class LoginPromptSheet extends StatelessWidget {
  const LoginPromptSheet({
    super.key,
    required this.title,
    required this.message,
    this.onAuthenticated,
  });

  final String title;
  final String message;
  final VoidCallback? onAuthenticated;

  static Future<bool> show(
    BuildContext context, {
    String title = 'Đăng nhập để tiếp tục',
    String message = 'Bạn đang ở chế độ khách. Vui lòng đăng nhập để lưu và quản lý dữ liệu cá nhân.',
    VoidCallback? onAuthenticated,
  }) async {
    final wantLogin = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LoginPromptSheet(title: title, message: message),
    );

    if (wantLogin == true && context.mounted) {
      final loginSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => LoginPage(onSuccess: onAuthenticated),
        ),
      );
      return loginSuccess ?? false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheetTopRadius,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.pageGutter,
        right: AppSpacing.pageGutter,
        top: AppSpacing.s12,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.verifiedSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.brandPrimary,
                  size: AppSpacing.iconRegular,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.sheetTitle.copyWith(fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            label: 'Đăng nhập ngay',
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          const SizedBox(height: AppSpacing.s8),
          OutlineButton(
            label: 'Để sau (Tiếp tục chế độ khách)',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
