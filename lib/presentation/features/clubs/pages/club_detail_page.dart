import 'package:flutter/material.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../events/widgets/community_cards.dart';

/// Investor & Community Club Detail Page (K02).
/// Features:
/// - Club info from ClubRepository.getClub(clubId)
/// - Activities, description, region, support recipient
/// - Illustrative notice (no fake payment or membership trading)
/// - Read-only introductory content per Phase 2 C-4 Baseline
class ClubDetailPage extends StatefulWidget {
  const ClubDetailPage({super.key, required this.clubId});

  final String clubId;

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> {
  Club? _club;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClub();
    });
  }

  Future<void> _loadClub() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final c = await deps.clubs.getClub(widget.clubId);
      if (!mounted) return;
      setState(() {
        _club = c;
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
        _errorMessage = 'Không thể tải thông tin câu lạc bộ: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const XLandScaffold(
        appBar: XLandAppBar(
          title: 'Câu lạc bộ',
          variant: XLandAppBarVariant.light,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null || _club == null) {
      return XLandScaffold(
        appBar: const XLandAppBar(
          title: 'Câu lạc bộ',
          variant: XLandAppBarVariant.light,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.danger,
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  _errorMessage ?? 'Không tìm thấy câu lạc bộ.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(label: 'Thử lại', onPressed: _loadClub),
              ],
            ),
          ),
        ),
      );
    }

    final c = _club!;

    return XLandScaffold(
      appBar: XLandAppBar(title: c.title, variant: XLandAppBarVariant.light),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CommunityCover(
                media: c.media,
                isIllustrative: c.isIllustrative,
                aspectRatio: 16 / 9,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            // Region & Badge Row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusBadge(
                  text: c.regionLabel,
                  variant: StatusBadgeVariant.source,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // Title & Summary
            Text(c.title, style: AppTypography.pageHero.copyWith(fontSize: 22)),
            const SizedBox(height: AppSpacing.s8),
            Text(c.summary, style: AppTypography.body),
            const SizedBox(height: AppSpacing.s20),

            // Description Card
            XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giới thiệu hoạt động',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(c.description, style: AppTypography.body),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'Các hoạt động trọng tâm:',
                    style: AppTypography.compactStrong,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: c.activities
                        .map(
                          (act) => Chip(
                            label: Text(act, style: AppTypography.compact),
                            backgroundColor: AppColors.disabledSurface,
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Support Recipient Card
            if (c.supportRecipientLabel != null) ...[
              XLandCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.support_agent_rounded,
                      size: 28,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đội ngũ hỗ trợ', style: AppTypography.compact),
                          const SizedBox(height: 2),
                          Text(
                            c.supportRecipientLabel!,
                            style: AppTypography.bodyStrong,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
            ],

            const InfoNotice(
              title: 'Cộng đồng đầu tư',
              message: 'CLB là không gian kết nối giao lưu và thông tin thị trường giữa các nhà đầu tư. Không hỗ trợ đăng ký hội viên độc lập.',
              variant: NoticeVariant.info,
            ),
          ],
        ),
      ),
    );
  }
}
