import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/prepared_content_controls.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';

/// App Settings Page.
/// Features:
/// - Loads settings via AccountRepository.getSettings for authenticated users
/// - Uses local preferences for guests without calling private API
/// - Updates notification consent, video autoplay, and default mute options
/// - Protects against out-of-order responses with epoch counters
/// - Rolls back to server-confirmed settings on failure
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  UserSettings? _settings;
  bool _isGuest = true;
  bool _guestPreferencesAvailable = false;

  bool _notificationConsent = true;
  bool _feedAutoplay = true;
  bool _feedMutedByDefault = false;
  int _settingsRequestEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    final currentEpoch = ++_settingsRequestEpoch;

    AuthState? authState;
    try {
      final auth = context.read<AuthCubit>();
      if (auth.state is AuthInitial) await auth.checkSession();
      authState = auth.state;
    } catch (_) {}
    if (!mounted || currentEpoch != _settingsRequestEpoch) return;
    final isGuest = authState is! AuthAuthenticated;

    final deps = DependenciesScope.maybeOf(context);
    _isGuest = isGuest;
    _guestPreferencesAvailable = deps?.guestPreferences != null;

    if (isGuest) {
      try {
        final guestData =
            await deps?.guestPreferences?.read() ??
            const GuestPlaybackPreferences();
        if (!mounted || currentEpoch != _settingsRequestEpoch) return;
        setState(() {
          _applyGuest(guestData);
          _errorMessage = null;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted || currentEpoch != _settingsRequestEpoch) return;
        setState(() {
          _errorMessage =
              'Không thể đọc cài đặt trên thiết bị. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
      return;
    }

    if (deps == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final s = await deps.account.getSettings();
      if (!mounted || currentEpoch != _settingsRequestEpoch) return;
      setState(() {
        _settings = s;
        _notificationConsent = s.notificationConsent;
        _feedAutoplay = s.feedAutoplay;
        _feedMutedByDefault = s.feedMutedByDefault;
        _isLoading = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || currentEpoch != _settingsRequestEpoch) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _settingsRequestEpoch) return;
      setState(() {
        _errorMessage = 'Không thể tải cài đặt: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSetting({
    bool? notificationConsent,
    bool? feedAutoplay,
    bool? feedMutedByDefault,
  }) async {
    final currentEpoch = ++_settingsRequestEpoch;

    AuthState? authState;
    try {
      authState = context.read<AuthCubit>().state;
    } catch (_) {}
    final isGuest = authState is! AuthAuthenticated;

    setState(() {
      if (notificationConsent != null) {
        _notificationConsent = notificationConsent;
      }
      if (feedAutoplay != null) _feedAutoplay = feedAutoplay;
      if (feedMutedByDefault != null) _feedMutedByDefault = feedMutedByDefault;
    });

    final deps = DependenciesScope.maybeOf(context);
    if (isGuest) {
      final repository = deps?.guestPreferences;
      if (repository == null) return;
      try {
        final saved = await repository.update(
          GuestPreferenceUpdate(
            feedAutoplay: feedAutoplay,
            feedMutedByDefault: feedMutedByDefault,
          ),
        );
        if (!mounted || currentEpoch != _settingsRequestEpoch) return;
        setState(() => _applyGuest(saved));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu tùy chọn trên thiết bị.'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (_) {
        GuestPlaybackPreferences? confirmed;
        try {
          confirmed = await repository.read();
        } catch (_) {
          /* use last confirmed state */
        }
        if (!mounted || currentEpoch != _settingsRequestEpoch) return;
        setState(
          () => _applyGuest(
            confirmed ??
                GuestPlaybackPreferences(
                  feedAutoplay: _settings?.feedAutoplay ?? true,
                  feedMutedByDefault: _settings?.feedMutedByDefault ?? false,
                ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được cài đặt. Vui lòng thử lại.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (deps == null) return;
    try {
      final update = SettingsUpdate(
        notificationConsent: notificationConsent,
        feedAutoplay: feedAutoplay,
        feedMutedByDefault: feedMutedByDefault,
      );
      final newSettings = await deps.account.updateSettings(update);
      if (!mounted || currentEpoch != _settingsRequestEpoch) return;
      setState(() {
        _settings = newSettings;
        _notificationConsent = newSettings.notificationConsent;
        _feedAutoplay = newSettings.feedAutoplay;
        _feedMutedByDefault = newSettings.feedMutedByDefault;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _settingsRequestEpoch) return;
      setState(() {
        if (_settings != null) {
          _notificationConsent = _settings!.notificationConsent;
          _feedAutoplay = _settings!.feedAutoplay;
          _feedMutedByDefault = _settings!.feedMutedByDefault;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật cài đặt: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _applyGuest(GuestPlaybackPreferences value) {
    _notificationConsent = false;
    _feedAutoplay = value.feedAutoplay;
    _feedMutedByDefault = value.feedMutedByDefault;
    _settings = UserSettings(
      notificationConsent: false,
      locale: 'vi_VN',
      timeZone: 'Asia/Ho_Chi_Minh',
      feedAutoplay: value.feedAutoplay,
      feedMutedByDefault: value.feedMutedByDefault,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _loginForNotifications() async {
    if (await LoginPromptSheet.show(
          context,
          title: 'Đăng nhập để nhận thông báo',
        ) &&
        mounted) {
      await _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLandScaffold(
      appBar: const XLandAppBar(
        title: 'Cài đặt ứng dụng',
        variant: XLandAppBarVariant.light,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pageGutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      _errorMessage!,
                      style: AppTypography.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    PrimaryButton(label: 'Thử lại', onPressed: _loadSettings),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pageGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PreparedContentControls(),
                  Text(
                    'Thông báo & Tương tác',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  XLandCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (_isGuest)
                          ListTile(
                            title: Text(
                              'Nhận thông báo lịch hẹn & sự kiện',
                              style: AppTypography.body,
                            ),
                            subtitle: Text(
                              'Đăng nhập để quản lý thông báo của bạn',
                              style: AppTypography.compact,
                            ),
                            trailing: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.textSecondary,
                            ),
                            onTap: _loginForNotifications,
                          )
                        else
                          SwitchListTile(
                            title: Text(
                              'Nhận thông báo lịch hẹn & sự kiện',
                              style: AppTypography.body,
                            ),
                            subtitle: Text(
                              'Cập nhật trạng thái đặt lịch và vé mời sự kiện',
                              style: AppTypography.compact,
                            ),
                            value: _notificationConsent,
                            activeThumbColor: AppColors.brandPrimary,
                            onChanged: (val) {
                              setState(() => _notificationConsent = val);
                              _updateSetting(notificationConsent: val);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  Text(
                    'Trải nghiệm Video Feed',
                    style: AppTypography.sectionTitle,
                  ),
                  if (_isGuest && !_guestPreferencesAvailable)
                    Text(
                      'Cài đặt trên thiết bị tạm thời chưa khả dụng.',
                      style: AppTypography.compact,
                    ),
                  const SizedBox(height: AppSpacing.s8),
                  XLandCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(
                            'Tự động phát video',
                            style: AppTypography.body,
                          ),
                          subtitle: Text(
                            'Tự động phát video thực địa khi cuộn tới',
                            style: AppTypography.compact,
                          ),
                          value: _feedAutoplay,
                          activeThumbColor: AppColors.brandPrimary,
                          onChanged: _isGuest && !_guestPreferencesAvailable
                              ? null
                              : (val) {
                                  setState(() => _feedAutoplay = val);
                                  _updateSetting(feedAutoplay: val);
                                },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(
                            'Tắt tiếng mặc định',
                            style: AppTypography.body,
                          ),
                          subtitle: Text(
                            'Bắt đầu phát video ở chế độ im lặng',
                            style: AppTypography.compact,
                          ),
                          value: _feedMutedByDefault,
                          activeThumbColor: AppColors.brandPrimary,
                          onChanged: _isGuest && !_guestPreferencesAvailable
                              ? null
                              : (val) {
                                  setState(() => _feedMutedByDefault = val);
                                  _updateSetting(feedMutedByDefault: val);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  Text('Khu vực & Ngôn ngữ', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.s8),
                  XLandCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('Múi giờ', style: AppTypography.body),
                            ),
                            Expanded(
                              child: Text(
                                'Việt Nam (GMT+7)',
                                textAlign: TextAlign.right,
                                style: AppTypography.compactStrong,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: AppSpacing.s16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Ngôn ngữ hiển thị',
                                style: AppTypography.body,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Tiếng Việt',
                                textAlign: TextAlign.right,
                                style: AppTypography.compactStrong,
                              ),
                            ),
                          ],
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
