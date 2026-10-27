import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _localError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _localError = 'Không được để trống thông tin.';
      });
      return;
    }

    final success = await context.read<AuthCubit>().signUp(
      username: username,
      password: password,
    );

    if (success && mounted) {
      widget.onSuccess?.call();
      // Pop register page and return true
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final errorMsg =
            _localError ?? (state is AuthError ? state.message : null);

        return XLandScaffold(
          appBar: const XLandAppBar(title: 'Đăng ký', showBack: true),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s12),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.verifiedSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 36,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Đăng ký tài khoản XLand',
                  style: AppTypography.pageHero.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Tạo tài khoản nhanh chóng, không cần xác minh',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s24),
                if (errorMsg != null) ...[
                  InfoNotice(
                    title: 'Đăng ký không thành công',
                    message: errorMsg,
                    variant: NoticeVariant.danger,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],
                XLandTextField(
                  label: 'Tên đăng nhập',
                  hint: 'Nhập tên đăng nhập',
                  controller: _usernameController,
                  prefixIcon: const Icon(
                    Icons.account_circle_outlined,
                    color: AppColors.textSecondary,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.s16),
                XLandTextField(
                  label: 'Mật khẩu',
                  hint: 'Nhập mật khẩu',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.s16),
                XLandTextField(
                  label: 'Xác nhận mật khẩu',
                  hint: 'Nhập lại mật khẩu',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.s24),
                PrimaryButton(
                  label: 'Đăng ký tài khoản',
                  isSubmitting: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.s16),
                OutlineButton(
                  label: 'Đã có tài khoản? Đăng nhập',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
