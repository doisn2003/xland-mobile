import 'package:flutter/material.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../theme/theme.dart';

class LegalSummaryTab extends StatelessWidget {
  const LegalSummaryTab({
    super.key,
    required this.legalSummary,
    required this.onDownloadDocument,
    this.downloadGrant,
    this.downloadError,
    this.embedded = false,
  });
  final LegalSummary legalSummary;
  final ValueChanged<String> onDownloadDocument;
  final DownloadGrant? downloadGrant;
  final String? downloadError;

  IconData _icon(String title) {
    if (title.contains('quyền')) return Icons.person_outline;
    if (title.contains('thửa')) return Icons.map_outlined;
    if (title.contains('tiếp cận')) return Icons.add_road;
    if (title.contains('quy hoạch')) return Icons.assignment_outlined;
    if (title.contains('Hạn chế')) return Icons.block;
    return Icons.description_outlined;
  }

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final missing = legalSummary.totalCount - legalSummary.verifiedCount;
    return SingleChildScrollView(
      primary: embedded ? false : null,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      key: const PageStorageKey('property-legal'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesignSectionTitle(
            'Tiến độ kiểm tra',
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${legalSummary.verifiedCount}/${legalSummary.totalCount}',
                      style: AppTypography.displayMetric.copyWith(
                        color: AppColors.brandPrimary,
                        fontSize: 48,
                      ),
                    ),
                    const Text(
                      'Hạng mục đã đối chiếu',
                      style: AppTypography.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      missing > 0
                          ? '⚠ $missing mục cần bổ sung'
                          : 'Đã đối chiếu các mục',
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.goldForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Kết quả theo phạm vi tài liệu được chia sẻ.',
                      style: AppTypography.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          XLandCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < legalSummary.items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _item(legalSummary.items[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          DesignSectionTitle(
            'Tài liệu được chia sẻ',
            icon: Icons.folder_open_outlined,
            trailing: Text(
              '${legalSummary.documents.length} tài liệu',
              style: AppTypography.compact,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final doc in legalSummary.documents)
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: XLandCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 88,
                            child: doc.previewUrl != null
                                ? XLandMediaImage(
                                    url: doc.previewUrl,
                                    showLabel: false,
                                  )
                                : ColoredBox(
                                    color: AppColors.disabledSurface,
                                    child: Center(
                                      child: Icon(
                                        doc.mimeType.contains('pdf')
                                            ? Icons.description_outlined
                                            : Icons.photo_outlined,
                                        color: AppColors.goldDecorative,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.title,
                                  style: AppTypography.bodyStrong,
                                ),
                                Text(
                                  '${doc.mimeType.split('/').last.toUpperCase()} • ${(doc.sizeBytes / 1048576).toStringAsFixed(1)} MB',
                                  style: AppTypography.compact,
                                ),
                                Text(
                                  doc.uploadedDate,
                                  style: AppTypography.compact,
                                ),
                                if (doc.canDownload)
                                  IconButton(
                                    tooltip: 'Tải ${doc.title}',
                                    onPressed: () => onDownloadDocument(doc.id),
                                    icon: const Icon(
                                      Icons.file_download_outlined,
                                      color: AppColors.brandPrimary,
                                    ),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Chờ bổ sung',
                                      style: AppTypography.compact,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (downloadGrant != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InfoNotice(
                title: 'Đã nhận quyền xem tài liệu',
                message:
                    '${downloadGrant!.fileName}. Lưu và mở tệp trên thiết bị tạm thời còn thiếu, sẽ bổ sung sau.',
                variant: NoticeVariant.info,
              ),
            ),
          if (downloadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InfoNotice(
                title: 'Không thể tải tài liệu',
                message: downloadError!,
                variant: NoticeVariant.danger,
              ),
            ),
          const SizedBox(height: 12),
          InfoNotice(
            title: 'Kết quả theo phạm vi đã kiểm tra',
            message: legalSummary.scopeNotice,
            variant: NoticeVariant.info,
          ),
        ],
      ),
    );
  }

  Widget _item(LegalItem item) {
    final checked = item.status == LegalStatus.verified;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _icon(item.title),
            size: 26,
            color: checked ? AppColors.brandPrimary : AppColors.goldForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTypography.bodyStrong),
                if (item.subtitle != null)
                  Text(item.subtitle!, style: AppTypography.compact),
                if (item.checkedDate != null)
                  Text(item.checkedDate!, style: AppTypography.compact),
                const SizedBox(height: 5),
                StatusBadge(
                  text: checked ? 'Đã đối chiếu' : 'Cần bổ sung',
                  variant: checked
                      ? StatusBadgeVariant.verified
                      : StatusBadgeVariant.pending,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
