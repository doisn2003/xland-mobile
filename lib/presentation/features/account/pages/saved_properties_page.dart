import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/pages/login_page.dart';
import '../../booking/pages/booking_sheet.dart';
import '../../property_detail/pages/property_detail_page.dart';

/// Saved Properties Page (Bất động sản đã lưu).
/// Displays properties saved by user, fetched from PropertyRepository.search with savedOnly: true.
class SavedPropertiesPage extends StatefulWidget {
  const SavedPropertiesPage({super.key});

  @override
  State<SavedPropertiesPage> createState() => _SavedPropertiesPageState();
}

class _SavedPropertiesPageState extends State<SavedPropertiesPage> {
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? _nextCursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  int _requestEpoch = 0;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedProperties();
    });
  }

  Future<void> _loadSavedProperties() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    final currentEpoch = ++_requestEpoch;
    final targetUserId = _lastUserId;

    if (targetUserId == null) {
      setState(() {
        _properties = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await deps.properties.search(
        const PropertyFilter(
          regions: [],
          areaBands: [],
          landTypes: [],
          savedOnly: true,
          sort: PropertySort.relevant,
        ),
        const PageQuery(limit: 10),
      );
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _properties = res.page.items;
        _nextCursor = res.page.nextCursor;
        _hasMore = res.page.hasMore;
        _isLoading = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _errorMessage = 'Không thể tải danh sách bất động sản đã lưu: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreSavedProperties() async {
    if (_isLoadingMore || !_hasMore) return;
    final deps = DependenciesScope.of(context);
    final currentEpoch = _requestEpoch;
    final targetUserId = _lastUserId;
    if (targetUserId == null) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final res = await deps.properties.search(
        const PropertyFilter(
          regions: [],
          areaBands: [],
          landTypes: [],
          savedOnly: true,
          sort: PropertySort.relevant,
        ),
        PageQuery(cursor: _nextCursor, limit: 10),
      );
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      final existingIds = _properties.map((p) => p.id).toSet();
      final newItems = res.page.items.where((p) => !existingIds.contains(p.id)).toList();
      setState(() {
        _properties.addAll(newItems);
        _nextCursor = res.page.nextCursor;
        _hasMore = res.page.hasMore;
        _isLoadingMore = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _loadMoreError = e.message;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _loadMoreError = 'Lỗi tải thêm: $e';
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleToggleSave(Property prop) async {
    final deps = DependenciesScope.of(context);
    try {
      await deps.properties.setSaved(prop.id, false);
      if (!mounted) return;
      setState(() {
        _properties = _properties.where((p) => p.id != prop.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ lưu bất động sản.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bỏ lưu: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthState? authState;
    try {
      authState = context.watch<AuthCubit>().state;
    } catch (_) {}
    final currentUserId = authState is AuthAuthenticated ? authState.session.profile.id : null;
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _requestEpoch++;
      _properties = [];
      _nextCursor = null;
      _hasMore = false;
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = null;
      _loadMoreError = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSavedProperties();
      });
    }

    final isGuest = currentUserId == null;

    return XLandScaffold(
      appBar: const XLandAppBar(
        title: 'Bất động sản đã lưu',
        variant: XLandAppBarVariant.light,
      ),
      body: isGuest
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pageGutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: AppSpacing.s12),
                    Text('Tài khoản khách', style: AppTypography.sectionTitle),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Vui lòng đăng nhập để xem danh sách bất động sản đã lưu của bạn.',
                      style: AppTypography.compact.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    PrimaryButton(
                      label: 'Đăng nhập',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.pageGutter),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                        const SizedBox(height: AppSpacing.s12),
                        Text(_errorMessage!, style: AppTypography.body, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.s16),
                        PrimaryButton(label: 'Thử lại', onPressed: _loadSavedProperties),
                      ],
                    ),
                  ),
                )
              : _properties.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.pageGutter),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bookmark_border_rounded, size: 56, color: AppColors.textSecondary),
                            const SizedBox(height: AppSpacing.s12),
                            Text('Chưa có bất động sản nào được lưu', style: AppTypography.sectionTitle),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Nhấn biểu tượng lưu trên chi tiết lô đất hoặc danh sách Khám phá để lưu lại.',
                              style: AppTypography.compact.copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.pageGutter),
                      itemCount: _properties.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s16),
                      itemBuilder: (context, idx) {
                        if (idx == _properties.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: _isLoadingMore
                                  ? const CircularProgressIndicator(color: AppColors.brandPrimary)
                                  : _loadMoreError != null
                                      ? TextButton.icon(
                                          onPressed: _loadMoreSavedProperties,
                                          icon: const Icon(Icons.refresh_rounded, size: 16),
                                          label: Text('Lỗi: $_loadMoreError. Thử lại'),
                                        )
                                      : OutlineButton(
                                          label: 'Tải thêm bất động sản',
                                          onPressed: _loadMoreSavedProperties,
                                        ),
                            ),
                          );
                        }
                        final prop = _properties[idx];
                        return XLandCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Mã: ${prop.code}', style: AppTypography.compactStrong),
                                  IconButton(
                                    icon: const Icon(Icons.bookmark_remove_outlined, color: AppColors.danger),
                                    tooltip: 'Bỏ lưu',
                                    onPressed: () => _handleToggleSave(prop),
                                  ),
                                ],
                              ),
                              const Divider(height: AppSpacing.s12),
                              Text(prop.title, style: AppTypography.cardTitle),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                prop.locationLabel,
                                style: AppTypography.compact.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              PriceText(priceVnd: '${prop.priceTotal.wireValue} đ'),
                              const SizedBox(height: AppSpacing.s12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlineButton(
                                      label: 'Xem chi tiết',
                                      height: 36,
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => PropertyDetailPage(propertyId: prop.id),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: PrimaryButton(
                                      label: 'Xem thực địa',
                                      height: 36,
                                      onPressed: () {
                                        BookingSheet.show(context, propertyId: prop.id);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
