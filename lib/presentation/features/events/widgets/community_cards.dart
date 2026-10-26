import 'package:flutter/material.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/utils/timezone_utils.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../theme/theme.dart';

String eventStatusLabel(EventStatus status) => switch (status) {
  EventStatus.open => 'Đang mở',
  EventStatus.soldOut => 'Hết chỗ',
  EventStatus.closed => 'Đã đóng',
  EventStatus.cancelled => 'Đã hủy',
};

/// Natural row heights keep two columns usable with large text.
class CommunityGrid extends StatelessWidget {
  const CommunityGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2)
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < children.length ? 12 : 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class CommunityCover extends StatelessWidget {
  const CommunityCover({
    super.key,
    required this.media,
    required this.isIllustrative,
    this.badge,
    this.aspectRatio = 4 / 3,
    this.height,
  });
  final List<MediaAsset> media;
  final bool isIllustrative;
  final String? badge;
  final double aspectRatio;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final asset = media
        .where((m) => m.kind == MediaKind.image || m.thumbnailUrl != null)
        .firstOrNull;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        XLandMediaImage(
          url: asset?.thumbnailUrl ?? asset?.url,
          isIllustrative: isIllustrative,
          illustrativeAsset: IllustrativeAssets.coffee,
        ),
        if (badge != null)
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: .95),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.compactStrong.copyWith(
                    fontSize: 11,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (height != null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: content,
      );
    }
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: content,
    );
  }
}

class ClubGridCard extends StatelessWidget {
  const ClubGridCard({super.key, required this.club, required this.onTap});
  final Club club;
  final VoidCallback onTap;
  static const double cardHeight = 270;

  @override
  Widget build(BuildContext context) => _CommunityCard(
    onTap: onTap,
    height: cardHeight,
    cover: CommunityCover(
      media: club.media,
      isIllustrative: club.isIllustrative,
      badge: 'CÂU LẠC BỘ',
      height: 110,
    ),
    children: [
      Text(
        club.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _title,
      ),
      const SizedBox(height: 6),
      Text(
        club.summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _secondary,
      ),
      const Spacer(),
      _Metadata(icon: Icons.location_on_outlined, text: club.regionLabel),
      const SizedBox(height: 8),
      Text('Khám phá CLB →', style: _action),
    ],
  );
}

class EventGridCard extends StatelessWidget {
  const EventGridCard({super.key, required this.event, required this.onTap});
  final XlandEvent event;
  final VoidCallback onTap;
  static const double cardHeight = 295;

  @override
  Widget build(BuildContext context) {
    final date = toBusinessTime(event.startsAt, event.timeZone);
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return _CommunityCard(
      onTap: onTap,
      height: cardHeight,
      cover: CommunityCover(
        media: event.media,
        isIllustrative: event.isIllustrative,
        badge: event.tags.firstOrNull ?? 'SỰ KIỆN',
        height: 110,
      ),
      children: [
        Text(
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · $time',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _action.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _title,
        ),
        const SizedBox(height: 6),
        _Metadata(icon: Icons.location_on_outlined, text: event.venueName),
        const SizedBox(height: 6),
        Text(
          eventStatusLabel(event.status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _secondary,
        ),
        if (event.status == EventStatus.open)
          Text(
            'Còn ${event.remainingSlots} chỗ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _secondary,
          ),
        const Spacer(),
        Text(
          event.ticketPriceVnd.amount == BigInt.zero
              ? 'Miễn phí'
              : formatVndAmount(event.ticketPriceVnd),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _action,
        ),
      ],
    );
  }
}

TextStyle get _title =>
    AppTypography.bodyStrong.copyWith(fontSize: 15, height: 1.35);
TextStyle get _secondary => AppTypography.compact.copyWith(
  fontSize: 12,
  color: AppColors.textSecondary,
);
TextStyle get _action =>
    AppTypography.compactStrong.copyWith(color: AppColors.brandPrimary);

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.onTap,
    required this.cover,
    required this.children,
    this.height,
  });
  final VoidCallback onTap;
  final Widget cover;
  final List<Widget> children;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isLargeText = textScale > 1.1;
    final effectiveHeight = isLargeText ? null : height;

    return Semantics(
      button: true,
      child: SizedBox(
        height: effectiveHeight,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cover,
                effectiveHeight != null
                    ? Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: children,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              children.where((w) => w is! Spacer).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _secondary,
        ),
      ),
    ],
  );
}
