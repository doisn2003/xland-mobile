import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.imagePicker});
  final ImagePicker? imagePicker;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  late final _picker = widget.imagePicker ?? ImagePicker();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPicking = false;
  bool _clearAvatar = false;
  AvatarUpload? _avatar;
  String? _errorMessage;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await DependenciesScope.of(context).account.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameController.text = profile.displayName;
        _phoneController.text = profile.contactPhone ?? '';
        _addressController.text = profile.address ?? '';
        _isLoading = false;
      });
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final lost = await _picker.retrieveLostData();
        if (lost.files?.isNotEmpty == true) await _setAvatar(lost.files!.first);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error is XlandFailure
            ? error.message
            : 'Không thể tải hồ sơ. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _setAvatar(XFile file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('Ảnh đại diện tối đa 5 MB.');
    }
    final bytes = await file.readAsBytes();
    final String mimeType;
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      mimeType = 'image/jpeg';
    } else if (bytes.length >= 8 &&
        listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10])) {
      mimeType = 'image/png';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      mimeType = 'image/webp';
    } else {
      throw const FormatException('Vui lòng chọn ảnh JPG, PNG hoặc WebP.');
    }
    if (!mounted) return;
    setState(() {
      _avatar = AvatarUpload(bytes: bytes, mimeType: mimeType);
      _clearAvatar = false;
      _errorMessage = null;
    });
  }

  Future<void> _pickAvatar() async {
    setState(() => _isPicking = true);
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) await _setAvatar(file);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = error is FormatException
            ? error.message
            : 'Không thể chọn ảnh. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving || _isPicking || !_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final profile = _profile!;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = await deps.account.updateProfile(
        ProfileUpdate(
          displayName: name != profile.displayName ? name : null,
          contactPhone: phone.isNotEmpty && phone != profile.contactPhone
              ? phone
              : null,
          clearContactPhone: phone.isEmpty && profile.contactPhone != null,
          address: address.isNotEmpty && address != profile.address
              ? address
              : null,
          clearAddress: address.isEmpty && profile.address != null,
          avatar: _avatar,
          clearAvatar: _clearAvatar,
        ),
      );
      if (!mounted) return;
      context.read<AuthCubit>().profileUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công!'),
          backgroundColor: AppColors.brandPrimary,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = error is XlandFailure
            ? error.message
            : 'Không thể lưu hồ sơ. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _avatarPreview() {
    final url = _clearAvatar ? null : _profile?.avatarUrl;
    const fallback = Icon(
      Icons.person_rounded,
      size: 40,
      color: AppColors.brandPrimary,
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: 88,
        child: ColoredBox(
          color: AppColors.verifiedSurface,
          child: _avatar != null
              ? Image.memory(
                  _avatar!.bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : url != null
              ? Image.network(
                  url.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSaving || _isPicking;
    return XLandScaffold(
      appBar: const XLandAppBar(
        title: 'Chỉnh sửa hồ sơ',
        variant: XLandAppBarVariant.light,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pageGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: AppTypography.compact.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],
                  if (_profile == null)
                    PrimaryButton(label: 'Thử lại', onPressed: _loadProfile)
                  else
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: _avatarPreview()),
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: busy ? null : _pickAvatar,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(
                                  _isPicking
                                      ? 'Đang chọn ảnh...'
                                      : 'Chọn ảnh đại diện',
                                ),
                              ),
                              if (_avatar != null ||
                                  (!_clearAvatar &&
                                      _profile!.avatarUrl != null))
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(() {
                                          _avatar = null;
                                          _clearAvatar = true;
                                        }),
                                  child: const Text('Xóa ảnh'),
                                ),
                            ],
                          ),
                          Text(
                            'JPG, PNG hoặc WebP · Tối đa 5 MB',
                            textAlign: TextAlign.center,
                            style: AppTypography.compact,
                          ),
                          const SizedBox(height: AppSpacing.s24),
                          Text(
                            'Tất cả thông tin đều không bắt buộc.',
                            style: AppTypography.compact,
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          XLandTextField(
                            label: 'Tên hiển thị',
                            controller: _nameController,
                            hint: 'Nhập họ và tên...',
                            enabled: !busy,
                            validator: (value) =>
                                (value?.trim().length ?? 0) > 100
                                ? 'Tên tối đa 100 ký tự.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          XLandTextField(
                            label: 'Số điện thoại liên hệ',
                            controller: _phoneController,
                            hint: 'Nhập số điện thoại...',
                            enabled: !busy,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              return phone.isEmpty ||
                                      RegExp(
                                        r'^(\+[1-9][0-9]{8,14}|0[0-9]{9})$',
                                      ).hasMatch(phone)
                                  ? null
                                  : 'Số điện thoại không hợp lệ.';
                            },
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          XLandTextField(
                            label: 'Địa chỉ',
                            controller: _addressController,
                            hint: 'Nhập địa chỉ...',
                            enabled: !busy,
                            maxLines: 3,
                            keyboardType: TextInputType.streetAddress,
                            validator: (value) =>
                                (value?.trim().length ?? 0) > 500
                                ? 'Địa chỉ tối đa 500 ký tự.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.s24),
                          PrimaryButton(
                            label: _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                            isSubmitting: _isSaving,
                            onPressed: busy ? null : _handleSave,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
