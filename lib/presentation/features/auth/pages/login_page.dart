import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../widgets/extended_auth_panel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthCubit _authCubit;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _authCubit = context.read<AuthCubit>();
  }

  @override
  void dispose() {
    _authCubit.cancelPendingSignIn();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_authCubit.state is AuthLoading) return;
    setState(() {
      _localError = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _localError = 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.';
      });
      return;
    }

    final success = await context.read<AuthCubit>().signIn(
      username: username,
      password: password,
    );

    if (success && mounted) {
      widget.onSuccess?.call();
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
          appBar: const XLandAppBar(title: 'Đăng nhập', showBack: true),
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
                      Icons.person_rounded,
                      size: 36,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Đăng nhập tài khoản XLand',
                  style: AppTypography.pageHero.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Chọn phương thức đăng nhập để tiếp tục',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s24),
                if (errorMsg != null) ...[
                  InfoNotice(
                    title: 'Đăng nhập không thành công',
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
                  hint: 'Nhập mật khẩu (tối thiểu 8 ký tự)',
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
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.s24),
                PrimaryButton(
                  label: 'Đăng nhập',
                  isSubmitting: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                ExtendedAuthPanel(
                  isLoading: isLoading,
                  onSuccess: () {
                    widget.onSuccess?.call();
                    Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
                OutlineButton(
                  label: 'Quay lại chế độ khách',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
