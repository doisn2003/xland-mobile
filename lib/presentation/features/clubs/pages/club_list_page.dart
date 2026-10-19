import 'package:flutter/material.dart';
import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import 'club_detail_page.dart';

/// Investor & Community Clubs List Page (K01).
/// Features:
/// - List clubs from ClubRepository.getClubs
/// - Real club IDs (e.g. K01/K02 / 00000000-0000-4000-8000-000000000102)
/// - Illustrative notice (no fake payment or membership trading)
/// - Navigate to ClubDetailPage
class ClubListPage extends StatefulWidget {
  const ClubListPage({super.key});

  @override
  State<ClubListPage> createState() => _ClubListPageState();
}

class _ClubListPageState extends State<ClubListPage> {
  List<Club> _clubs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClubs();
    });
  }

  Future<void> _loadClubs() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await deps.clubs.getClubs(const PageQuery(limit: 20));
      if (!mounted) return;
      setState(() {
        _clubs = page.items;
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
        _errorMessage = 'Không thể tải danh sách câu lạc bộ: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLandScaffold(
      appBar: const XLandAppBar(
        title: 'Cộng đồng đầu tư & CLB',
        variant: XLandAppBarVariant.light,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: AppSpacing.s12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: AppTypography.body),
              const SizedBox(height: AppSpacing.s16),
              PrimaryButton(label: 'Thử lại', onPressed: _loadClubs),
            ],
          ),
        ),
      );
    }

    if (_clubs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_outlined, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Chưa có câu lạc bộ nào được mở tại khu vực này.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s16),
              OutlineButton(label: 'Tải lại', onPressed: _loadClubs),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageGutter),
      children: [
        const InfoNotice(
          title: 'Cộng đồng nhà đầu tư XLand',
          message:
              'Không gian giao lưu học hỏi, cập nhật thông tin quy hoạch và khảo sát thực địa. Chưa tích hợp phí hội viên hay mua bán token.',
          variant: NoticeVariant.info,
        ),
        const SizedBox(height: AppSpacing.s16),
        ..._clubs.map((club) => _buildClubCard(club)),
      ],
    );
  }

  Widget _buildClubCard(Club club) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: XLandCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(text: club.regionLabel, variant: StatusBadgeVariant.source),
                const Spacer(),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(club.title, style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.s4),
            Text(club.summary, style: AppTypography.body),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: club.activities.map((act) => Chip(
                label: Text(act, style: AppTypography.compact),
                backgroundColor: AppColors.disabledSurface,
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
            const SizedBox(height: AppSpacing.s12),
            OutlineButton(
              label: 'Tìm hiểu câu lạc bộ',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClubDetailPage(clubId: club.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
