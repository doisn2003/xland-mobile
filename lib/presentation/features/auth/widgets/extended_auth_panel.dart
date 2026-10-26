import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/auth/extended_auth.dart';
import '../../../../domain/failures/xland_failure.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../cubit/auth_cubit.dart';
import '../pages/register_page.dart';

class ExtendedAuthPanel extends StatefulWidget {
  const ExtendedAuthPanel({
    super.key,
    required this.isLoading,
    required this.onSuccess,
  });
  final bool isLoading;
  final VoidCallback onSuccess;
  @override
  State<ExtendedAuthPanel> createState() => _ExtendedAuthPanelState();
}

class _ExtendedAuthPanelState extends State<ExtendedAuthPanel> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  late final ExtendedAuthRepository? _repository;
  AuthCapabilities _capabilities = const AuthCapabilities();
  PhoneOtpChallenge? _challenge;
  Timer? _timer;
  bool _loadingCapabilities = true;
  bool _sending = false;
  bool _phoneMode = false;
  String? _error;
  String? _requestKey;
  String? _requestedPhone;
  int _epoch = 0;
  int get _secondsUntilResend => _challenge == null
      ? 0
      : max(0, _challenge!.resendAt.difference(DateTime.now()).inSeconds + 1);
  bool get _expired =>
      _challenge != null && !_challenge!.expiresAt.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _repository = context.read<AuthCubit>().extendedAuth;
    unawaited(_loadCapabilities());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _challenge != null) setState(() {});
    });
  }

  Future<void> _loadCapabilities() async {
    setState(() => _loadingCapabilities = true);
    try {
      final capabilities =
          await _repository?.capabilities() ?? const AuthCapabilities();
      if (mounted) {
        setState(() {
          _capabilities = capabilities;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa kiểm tra được phương thức đăng nhập. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCapabilities = false);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String _newKey() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> _request({bool resend = false}) async {
    if (_sending ||
        widget.isLoading ||
        _repository == null ||
        _secondsUntilResend > 0) {
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Vui lòng nhập số điện thoại Việt Nam.');
      return;
    }
    // Keep the key after timeout. Only an explicit resend/new phone changes it.
    if (resend || _requestedPhone != phone) _requestKey = null;
    _requestKey ??= _newKey();
    _requestedPhone = phone;
    final epoch = ++_epoch;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final challenge = await _repository.requestPhoneOtp(phone, _requestKey!);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _challenge = challenge;
        _code.clear();
      });
    } on XlandFailure catch (failure) {
      if (mounted && epoch == _epoch) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(
          () => _error = 'Chưa xác nhận được yêu cầu SMS. Bấm thử lại để kiểm tra cùng yêu cầu.',
        );
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (widget.isLoading || _sending || challenge == null || _expired) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _error = 'Nhập mã OTP gồm 6 chữ số.');
      return;
    }
    setState(() => _error = null);
    final success = await context.read<AuthCubit>().signInWithPhoneOtp(
      challenge.id,
      _code.text,
    );
    if (success && mounted) widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isLoading || _sending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppSpacing.s32),
        if (_loadingCapabilities) const LinearProgressIndicator(),
        OutlineButton(
          label: 'Tiếp tục với Google',
          icon: const GoogleLogo(size: 20),
          onPressed: !busy && !_loadingCapabilities && _capabilities.google
              ? () async {
                  final success = await context
                      .read<AuthCubit>()
                      .signInWithGoogle();
                  if (success && mounted) widget.onSuccess();
                }
              : null,
        ),
        if (!_loadingCapabilities && !_capabilities.google)
          const Text(
            'Đăng nhập Google chưa sẵn sàng trên thiết bị này.',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: AppSpacing.s16),
        Text(
          'Bạn chưa có tài khoản? Hãy đăng ký ngay',
          textAlign: TextAlign.center,
          style: AppTypography.compact.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        OutlineButton(
          label: 'Đăng ký ngay',
          onPressed: busy
              ? null
              : () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => RegisterPage(onSuccess: widget.onSuccess),
                    ),
                  );
                  if (result == true && mounted) {
                    widget.onSuccess();
                  }
                },
        ),
        if (_capabilities.phoneOtp) ...[
          const SizedBox(height: AppSpacing.s12),
          OutlineButton(
            label: 'Đăng ký / đăng nhập bằng số điện thoại',
            onPressed: !busy && !_loadingCapabilities
                ? () => setState(() => _phoneMode = !_phoneMode)
                : null,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s12),
          InfoNotice(
            title: 'Chưa hoàn tất',
            message: _error!,
            variant: NoticeVariant.danger,
          ),
        ],
        
        if (_phoneMode) ...[
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _phone,
            enabled: !busy && _challenge == null,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Số điện thoại Việt Nam',
              hintText: '09xxxxxxxx hoặc +84…',
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (_challenge == null)
            PrimaryButton(
              label: _requestKey == null
                  ? 'Nhận mã OTP'
                  : 'Thử lại yêu cầu OTP',
              isSubmitting: _sending,
              onPressed: busy ? null : () => _request(),
            ),
          if (_challenge case final challenge?) ...[
            Text(switch (challenge.deliveryStatus) {
              OtpDeliveryStatus.accepted =>
                'Đã tiếp nhận yêu cầu gửi mã tới ${challenge.maskedPhone}.',
              OtpDeliveryStatus.pending =>
                'Đang xử lý yêu cầu SMS tới ${challenge.maskedPhone}.',
              OtpDeliveryStatus.unknown =>
                'Chưa xác nhận trạng thái gửi tới ${challenge.maskedPhone}. Nếu nhận được mã, bạn vẫn có thể xác minh.',
            }),
            if (_expired) const Text('Mã đã hết hạn. Hãy yêu cầu mã mới.'),
            TextField(
              controller: _code,
              enabled: !busy && !_expired,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(labelText: 'Mã OTP 6 chữ số'),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: AppSpacing.s12),
            PrimaryButton(
              label: 'Xác minh và tiếp tục',
              isSubmitting: widget.isLoading,
              onPressed: busy || _expired ? null : _verify,
            ),
            TextButton(
              onPressed: busy || _secondsUntilResend > 0
                  ? null
                  : () => _request(resend: true),
              child: Text(
                _secondsUntilResend > 0
                    ? 'Gửi lại sau $_secondsUntilResend giây'
                    : 'Gửi mã mới',
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      _epoch++;
                      context.read<AuthCubit>().cancelPendingSignIn();
                      setState(() {
                        _challenge = null;
                        _requestKey = null;
                        _requestedPhone = null;
                        _code.clear();
                        _error = null;
                      });
                    },
              child: const Text('Dùng số điện thoại khác'),
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Số điện thoại mới sẽ tạo tài khoản XLand. Tài khoản dùng Google hoặc tên đăng nhập được quản lý riêng.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
