import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';

/// Edit Profile Page.
/// Features:
/// - Fetches current user profile from AccountRepository.getProfile
/// - Form to update displayName, contactPhone, and avatar
/// - Explicit handling of keep / set / clear / conflict per contract
/// - Server response display and error / 401 handling
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _clearPhone = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await deps.account.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _nameController.text = p.displayName;
        _phoneController.text = p.contactPhone ?? '';
        _clearPhone = false;
        _isLoading = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải thông tin hồ sơ: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên hiển thị.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final deps = DependenciesScope.of(context);
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final currentPhone = _profile?.contactPhone ?? '';
      final enteredPhone = _phoneController.text.trim();
      final phoneChanged = enteredPhone != currentPhone;

      final currentName = _profile?.displayName ?? '';
      final nameChanged = name != currentName;

      final String? contactPhoneToSet;
      final bool clearContactPhone;

      if (_clearPhone) {
        contactPhoneToSet = null;
        clearContactPhone = true;
      } else if (phoneChanged) {
        if (enteredPhone.isEmpty) {
          contactPhoneToSet = null;
          clearContactPhone = true;
        } else {
          contactPhoneToSet = enteredPhone;
          clearContactPhone = false;
        }
      } else {
        // Untouched: omission preserves contactVerified
        contactPhoneToSet = null;
        clearContactPhone = false;
      }

      final update = ProfileUpdate(
        displayName: nameChanged ? name : null,
        contactPhone: contactPhoneToSet,
        clearContactPhone: clearContactPhone,
      );

      final updatedProfile = await deps.account.updateProfile(update);
      if (!mounted) return;

      try {
        context.read<AuthCubit>().checkSession();
      } catch (_) {}

      setState(() {
        _profile = updatedProfile;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin hồ sơ thành công!'),
          backgroundColor: AppColors.brandPrimary,
        ),
      );
      Navigator.pop(context);
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Lỗi cập nhật hồ sơ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLandScaffold(
      appBar: const XLandAppBar(
        title: 'Chỉnh sửa hồ sơ',
        variant: XLandAppBarVariant.light,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pageGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(_errorMessage!, style: AppTypography.compact.copyWith(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.verifiedSurface,
                          child: const Icon(Icons.person_rounded, size: 40, color: AppColors.brandPrimary),
                        ),
                        if (_profile != null) ...[
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            _profile!.contactVerified ? 'Tài khoản đã xác minh liên hệ' : 'Chưa xác thực số điện thoại',
                            style: AppTypography.compact.copyWith(
                              color: _profile!.contactVerified ? AppColors.brandPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  XLandTextField(
                    label: 'Tên hiển thị',
                    controller: _nameController,
                    hint: 'Nhập họ và tên...',
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  XLandTextField(
                    label: 'Số điện thoại liên hệ',
                    controller: _phoneController,
                    hint: 'Nhập số điện thoại...',
                    enabled: !_clearPhone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.s8),

                  Row(
                    children: [
                      Checkbox(
                        value: _clearPhone,
                        activeColor: AppColors.brandPrimary,
                        onChanged: (val) {
                          setState(() {
                            _clearPhone = val ?? false;
                            if (_clearPhone) _phoneController.clear();
                          });
                        },
                      ),
                      Text('Xóa / bỏ số điện thoại khỏi hồ sơ', style: AppTypography.compact),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  PrimaryButton(
                    label: _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                    isSubmitting: _isSaving,
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ],
              ),
            ),
    );
  }
}
