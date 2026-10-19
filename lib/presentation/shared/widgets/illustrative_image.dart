import 'package:flutter/material.dart';

import '../../theme/theme.dart';

abstract final class IllustrativeAssets {
  static const countryside = 'assets/images/report/countryside-landscape.png';
  static const portrait = 'assets/images/report/countryside-portrait.png';
  static const coastal = 'assets/images/report/coastal-landscape.png';
  static const coffee = 'assets/images/report/community-coffee.png';
  static const consultant = 'assets/images/report/consultant-fictional.png';
}

/// Generated scenery is used only for explicitly illustrative records whose
/// real media is absent. A failing real URL keeps its honest error fallback.
class XLandMediaImage extends StatelessWidget {
  const XLandMediaImage({
    super.key,
    this.url,
    this.isIllustrative = false,
    this.illustrativeAsset = IllustrativeAssets.countryside,
    this.showLabel = true,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });
  final Uri? url;
  final bool isIllustrative;
  final String illustrativeAsset;
  final bool showLabel;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final useIllustration = url == null && isIllustrative;
    final image = url != null
        ? Image.network(
            url.toString(),
            fit: fit,
            alignment: alignment,
            errorBuilder: (_, _, _) => _fallback(),
          )
        : useIllustration
        ? Image.asset(
            illustrativeAsset,
            fit: fit,
            alignment: alignment,
            errorBuilder: (_, _, _) => _fallback(),
          )
        : _fallback();
    return Semantics(
      image: true,
      label: 'Hình ảnh',
      child: Stack(fit: StackFit.expand, children: [image]),
    );
  }

  Widget _fallback() => ColoredBox(
    color: AppColors.disabledSurface,
    child: LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < 100 || constraints.maxHeight < 80
          ? const Padding(
              padding: EdgeInsets.all(4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textMuted,
                  size: 24,
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.landscape_outlined,
                    color: AppColors.textMuted,
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chưa có hình ảnh',
                    style: AppTypography.compact.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
