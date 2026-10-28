import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';

class PropertyComparisonPicker extends StatefulWidget {
  const PropertyComparisonPicker({super.key, required this.currentProperty});
  final Property currentProperty;

  static Future<Property?> show(
    BuildContext context,
    Property currentProperty,
  ) => showXLandBottomSheet<Property>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => PropertyComparisonPicker(currentProperty: currentProperty),
  );

  @override
  State<PropertyComparisonPicker> createState() =>
      _PropertyComparisonPickerState();
}

class _PropertyComparisonPickerState extends State<PropertyComparisonPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Property> _items = [];
  String? _cursor;
  String _query = '';
  bool _hasMore = false;
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    ++_generation; // Invalidate the old request before the debounce expires.
    setState(() {
      _query = value.trim();
      _items = [];
      _cursor = null;
      _hasMore = false;
      _failed = false;
      _loading = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted || (!reset && _loading)) return;
    final generation = ++_generation;
    final repository = DependenciesScope.of(context).properties;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _cursor = null;
        _items = [];
        _hasMore = false;
      }
    });
    try {
      final result = await repository.search(
        PropertyFilter(
          query: _query.isEmpty ? null : _query,
          regions: const [],
          areaBands: const [],
          landTypes: const [],
          savedOnly: false,
          sort: PropertySort.newest,
        ),
        PageQuery(limit: 20, cursor: _cursor),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = {
          for (final p in [..._items, ...result.page.items])
            if (p.id != widget.currentProperty.id) p.id: p,
        }.values.toList();
        _cursor = result.page.nextCursor;
        _hasMore = result.page.hasMore && _cursor != null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .88,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Chọn lô đất để so sánh',
                  style: AppTypography.sectionTitle,
                ),
              ),
              IconButton(
                tooltip: 'Đóng lựa chọn',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'So sánh với ${widget.currentProperty.code}',
            style: AppTypography.compact.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _search,
            onChanged: _searchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _debounce?.cancel();
              _load(reset: true);
            },
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, mã lô hoặc khu vực',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _searchChanged('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Đang tìm lô đất',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    for (final property in _items)
                      _PropertyChoice(
                        property: property,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).pop(property);
                        },
                      ),
                    if (_failed)
                      _PickerNotice(
                        icon: Icons.wifi_off_outlined,
                        message:
                            'Chưa thể tải danh sách lô đất. Vui lòng thử lại.',
                        action: TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      )
                    else if (_items.isEmpty && !_hasMore)
                      _PickerNotice(
                        icon: Icons.search_off_rounded,
                        message: _query.isEmpty
                            ? 'Chưa có lô đất khác để so sánh.'
                            : 'Không tìm thấy lô đất phù hợp.\nThử tên, mã lô hoặc khu vực khác.',
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_hasMore && !_failed)
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Xem thêm lô đất'),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}

class _PropertyChoice extends StatelessWidget {
  const _PropertyChoice({required this.property, required this.onTap});
  final Property property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = property.media
        .where((m) => m.kind == MediaKind.image || m.thumbnailUrl != null)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('compare-choice-${property.id}'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 76,
                      height: 86,
                      child: XLandMediaImage(
                        url: media?.thumbnailUrl ?? media?.url,
                        isIllustrative: property.isIllustrative,
                        illustrativeAsset: IllustrativeAssets.countryside,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          style: AppTypography.compactStrong,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${property.code} · ${property.locationLabel}',
                          style: AppTypography.compact.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              formatCompactVnd(property.priceTotal),
                              style: AppTypography.compactStrong.copyWith(
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            Text(
                              formatMeasurement(property.areaM2, 'm²'),
                              style: AppTypography.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerNotice extends StatelessWidget {
  const _PickerNotice({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Icon(icon, size: 36, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: AppTypography.body),
        ?action,
      ],
    ),
  );
}
