import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../theme/theme.dart';
import '../cubit/filter_cubit.dart';
import '../cubit/filter_state.dart';

class PropertyFilterSheet extends StatelessWidget {
  const PropertyFilterSheet({super.key});

  static Future<PropertyFilter?> show(
    BuildContext context, {
    required PropertyRepository propertyRepository,
    required PropertyFilter currentFilter,
  }) => showXLandBottomSheet<PropertyFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) =>
          FilterCubit(propertyRepository, initialFilter: currentFilter),
      child: const PropertyFilterSheet(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * .86),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: BlocBuilder<FilterCubit, FilterState>(
        builder: (context, state) {
          final cubit = context.read<FilterCubit>();
          final draft = state.draftFilter;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tìm đất theo nhu cầu',
                            style: AppTypography.sheetTitle,
                          ),
                          Text(
                            'Chọn vùng và tiêu chí phù hợp',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in [
                              (
                                Region.north,
                                'Miền Bắc',
                                'Hà Nội và các tỉnh lân cận',
                                IllustrativeAssets.countryside,
                              ),
                              (
                                Region.central,
                                'Miền Trung',
                                'Đà Nẵng, Khánh Hòa, Nghệ An…',
                                IllustrativeAssets.coastal,
                              ),
                              (
                                Region.south,
                                'Miền Nam',
                                'TP. Hồ Chí Minh và các tỉnh',
                                IllustrativeAssets.coastal,
                              ),
                              (
                                null,
                                'Khu Công Nghiệp',
                                'Nhóm tài sản',
                                IllustrativeAssets.countryside,
                              ),
                            ])
                              SizedBox(
                                width: (constraints.maxWidth - 8) / 2,
                                child: _RegionTile(
                                  title: item.$2,
                                  subtitle: item.$3,
                                  asset: item.$4,
                                  selected: item.$1 == null
                                      ? draft.category ==
                                            PropertyCategory.industrial
                                      : draft.regions.contains(item.$1),
                                  onTap: () => item.$1 == null
                                      ? cubit.setCategory(
                                          PropertyCategory.industrial,
                                        )
                                      : cubit.toggleRegion(item.$1!),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (state.isLoadingCatalog)
                        const LinearProgressIndicator(minHeight: 2),
                      if (state.catalogHasError)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.catalogErrorMessage ??
                                    'Không thể tải danh mục',
                                style: AppTypography.compact,
                              ),
                            ),
                            TextButton(
                              onPressed: cubit.retryCatalog,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SelectField<String>(
                              label: 'Tỉnh thành',
                              icon: Icons.location_on_outlined,
                              value: draft.provinceCode,
                              entries: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Tất cả tỉnh'),
                                ),
                                ...?state.catalog?.provinces.map(
                                  (p) => DropdownMenuItem(
                                    value: p.code,
                                    child: Text(p.label),
                                  ),
                                ),
                              ],
                              onChanged: state.isLoadingCatalog
                                  ? null
                                  : (v) => cubit.setProvinceCode(v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SelectField<String>(
                              label: 'Xã / phường',
                              icon: Icons.map_outlined,
                              value: draft.communeCode,
                              entries: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Tất cả'),
                                ),
                                ...?state.catalog?.communes.map(
                                  (d) => DropdownMenuItem(
                                    value: d.code,
                                    child: Text(d.label),
                                  ),
                                ),
                              ],
                              onChanged:
                                  state.isLoadingCatalog ||
                                      draft.provinceCode == null
                                  ? null
                                  : (v) => cubit.setCommuneCode(v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const DesignSectionTitle(
                        'Ngân sách',
                        icon: Icons.savings_outlined,
                        trailing: Text(
                          'Đơn vị: tỷ đồng',
                          style: AppTypography.compact,
                        ),
                      ),
                      _PriceRangeSelector(
                        key: ValueKey(state.resetGeneration),
                        minPriceVnd: draft.minPriceVnd,
                        maxPriceVnd: draft.maxPriceVnd,
                        onChanged: cubit.setPriceRange,
                        onValidationChanged: cubit.setPriceValid,
                      ),
                      const SizedBox(height: 14),
                      const DesignSectionTitle(
                        'Diện tích',
                        icon: Icons.crop_free_rounded,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final band in [
                            (AreaBand.below100, 'Dưới 100 m²'),
                            (AreaBand.from100To200, '100 – 200 m²'),
                            (AreaBand.above200, 'Trên 200 m²'),
                          ])
                            _FilterChip(
                              label: band.$2,
                              isSelected: draft.areaBands.contains(band.$1),
                              onTap: () => cubit.toggleAreaBand(band.$1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SelectField<String>(
                              label: 'Đường tiếp cận',
                              icon: Icons.add_road_outlined,
                              value: draft.minRoadWidthM?.wireValue,
                              entries: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Tất cả'),
                                ),
                                for (final n in ['3', '4', '5', '6'])
                                  DropdownMenuItem(
                                    value: n,
                                    child: Text('Từ $n m'),
                                  ),
                              ],
                              onChanged: (v) => cubit.setRoadWidth(
                                v == null || v.isEmpty ? null : DecimalValue(v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SelectField<String>(
                              label: 'Hồ sơ',
                              icon: Icons.description_outlined,
                              value: draft.hasDocuments?.toString(),
                              entries: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('Tất cả'),
                                ),
                                DropdownMenuItem(
                                  value: 'true',
                                  child: Text('Có tài liệu'),
                                ),
                                DropdownMenuItem(
                                  value: 'false',
                                  child: Text('Chưa có tài liệu'),
                                ),
                              ],
                              onChanged: (v) => cubit.setHasDocuments(
                                v == 'true'
                                    ? true
                                    : v == 'false'
                                    ? false
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SelectField<String>(
                        label: 'Phân loại bất động sản',
                        icon: Icons.landscape_outlined,
                        value: draft.category?.name,
                        entries: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('Tất cả loại tài sản'),
                          ),
                          DropdownMenuItem(
                            value: 'residential',
                            child: Text('Đất nền'),
                          ),
                          DropdownMenuItem(
                            value: 'industrial',
                            child: Text('Khu công nghiệp (KCN)'),
                          ),
                          DropdownMenuItem(
                            value: 'agricultural',
                            child: Text('Đất nông nghiệp'),
                          ),
                          DropdownMenuItem(value: 'other', child: Text('Khác')),
                        ],
                        onChanged: (v) {
                          final selected = v == null || v.isEmpty
                              ? null
                              : PropertyCategory.values.byName(v);
                          if (selected != draft.category) {
                            cubit.setCategory(selected);
                          }
                        },
                      ),
                      if (state.countHasError)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.countErrorMessage ??
                                    'Không thể đếm kết quả',
                                style: AppTypography.compact.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: cubit.retryCount,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + mq.padding.bottom),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Đã chọn ${state.selectedCriteriaCount} tiêu chí',
                            style: AppTypography.compactStrong.copyWith(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: cubit.reset,
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Đặt lại'),
                        ),
                      ],
                    ),
                    PrimaryButton(
                      label: state.isCounting
                          ? 'Đang tìm lô phù hợp…'
                          : 'Xem ${state.matchingCount} lô phù hợp',
                      icon: const Icon(Icons.search, size: 20),
                      onPressed:
                          state.isCounting ||
                              state.countHasError ||
                              !state.isPriceValid
                          ? null
                          : () => Navigator.pop(context, draft),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.selected,
    required this.onTap,
  });
  final String title, subtitle, asset;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: AppColors.disabledSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? AppColors.brandPrimary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 54,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(asset, fit: BoxFit.cover),
                  if (selected)
                    const Positioned(
                      top: 5,
                      right: 5,
                      child: Icon(
                        Icons.check_circle,
                        size: 23,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyStrong),
                  Text(
                    subtitle,
                    style: AppTypography.compact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.icon,
    required this.value,
    required this.entries,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> entries;
  final ValueChanged<T?>? onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey('$label-$value-${entries.length}'),
    initialValue: entries.any((e) => e.value == value)
        ? value
        : entries.first.value,
    isExpanded: true,
    items: entries,
    onChanged: onChanged,
    style: AppTypography.bodyStrong,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      prefixIcon: Icon(icon, color: AppColors.goldDecorative, size: 22),
      prefixIconConstraints: const BoxConstraints(minWidth: 36),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: isSelected,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.brandPrimary,
    backgroundColor: AppColors.disabledSurface,
    labelStyle: AppTypography.compact.copyWith(
      color: isSelected ? Colors.white : AppColors.textPrimary,
    ),
    side: const BorderSide(color: AppColors.border),
    shape: const StadiumBorder(),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

class _PriceRangeSelector extends StatefulWidget {
  const _PriceRangeSelector({
    super.key,
    required this.minPriceVnd,
    required this.maxPriceVnd,
    required this.onChanged,
    this.onValidationChanged,
  });

  final Vnd? minPriceVnd;
  final Vnd? maxPriceVnd;
  final void Function(Vnd? min, Vnd? max) onChanged;
  final ValueChanged<bool>? onValidationChanged;

  @override
  State<_PriceRangeSelector> createState() => _PriceRangeSelectorState();
}

class _PriceRangeSelectorState extends State<_PriceRangeSelector> {
  late TextEditingController _minController;
  late TextEditingController _maxController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: _formatBillion(widget.minPriceVnd),
    );
    _maxController = TextEditingController(
      text: _formatBillion(widget.maxPriceVnd),
    );
  }

  @override
  void didUpdateWidget(covariant _PriceRangeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.minPriceVnd != oldWidget.minPriceVnd) {
      final text = _formatBillion(widget.minPriceVnd);
      final currentDouble = double.tryParse(
        _minController.text.trim().replaceAll(',', '.'),
      );
      final widgetDouble = widget.minPriceVnd == null
          ? null
          : widget.minPriceVnd!.amount.toDouble() / 1e9;
      if (currentDouble != widgetDouble && _minController.text != text) {
        _minController.text = text;
      }
    }
    if (widget.maxPriceVnd != oldWidget.maxPriceVnd) {
      final text = _formatBillion(widget.maxPriceVnd);
      final currentDouble = double.tryParse(
        _maxController.text.trim().replaceAll(',', '.'),
      );
      final widgetDouble = widget.maxPriceVnd == null
          ? null
          : widget.maxPriceVnd!.amount.toDouble() / 1e9;
      if (currentDouble != widgetDouble && _maxController.text != text) {
        _maxController.text = text;
      }
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String _formatBillion(Vnd? vnd) {
    if (vnd == null) return '';
    final scale = BigInt.from(1000000000);
    final fraction = (vnd.amount % scale)
        .toString()
        .padLeft(9, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${vnd.amount ~/ scale}${fraction.isEmpty ? '' : ',$fraction'}';
  }

  Vnd? _parseBillion(String text) {
    if (text.isEmpty) return null;
    if (!RegExp(r'^\d+(?:[.,]\d{1,9})?$').hasMatch(text)) {
      throw const FormatException();
    }
    final parts = text.replaceAll(',', '.').split('.');
    return Vnd(
      (BigInt.parse(parts[0]) * BigInt.from(1000000000) +
              BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(9, '0')))
          .toString(),
    );
  }

  void _onInputsChanged() {
    try {
      final min = _parseBillion(_minController.text.trim());
      final upper = _maxController.text.trim();
      final max = upper == '10+' ? null : _parseBillion(upper);
      if (min != null && max != null && min.amount > max.amount) {
        setState(
          () =>
              _validationError = 'Mức giá tối thiểu không được lớn hơn tối đa',
        );
        widget.onValidationChanged?.call(false);
        return;
      }
      setState(() => _validationError = null);
      widget.onValidationChanged?.call(true);
      widget.onChanged(min?.amount == BigInt.zero ? null : min, max);
    } on FormatException {
      setState(() => _validationError = 'Nhập mức giá hợp lệ, ví dụ 1,5');
      widget.onValidationChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double rawMin = widget.minPriceVnd != null
        ? (widget.minPriceVnd!.amount.toDouble() / 1e9).clamp(0.5, 10.0)
        : 0.5;
    final double rawMax = widget.maxPriceVnd != null
        ? (widget.maxPriceVnd!.amount.toDouble() / 1e9).clamp(0.5, 10.0)
        : 10.0;
    final sliderMin = rawMin;
    final sliderMax = rawMax < rawMin ? rawMin : rawMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Từ (tỷ VNĐ)',
                  hintText: 'Không giới hạn',
                  suffixText: 'tỷ',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                ),
                onChanged: (_) => _onInputsChanged(),
                onSubmitted: (_) => _onInputsChanged(),
                onEditingComplete: _onInputsChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            const Text('—', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: TextField(
                controller: _maxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Đến (tỷ VNĐ)',
                  hintText: '10+',
                  suffixText: 'tỷ',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                ),
                onChanged: (_) => _onInputsChanged(),
                onSubmitted: (_) => _onInputsChanged(),
                onEditingComplete: _onInputsChanged,
              ),
            ),
          ],
        ),
        if (_validationError != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            _validationError!,
            style: AppTypography.compact.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbColor: AppColors.goldDecorative,
            rangeThumbShape: const _GoldRangeThumb(),
            rangeTickMarkShape: const RoundRangeSliderTickMarkShape(
              tickMarkRadius: 0,
            ),
            activeTrackColor: AppColors.brandPrimary,
            inactiveTrackColor: AppColors.border,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            overlayColor: AppColors.goldDecorative.withValues(alpha: .12),
          ),
          child: RangeSlider(
            values: RangeValues(sliderMin, sliderMax),
            min: 0.5,
            max: 10.0,
            divisions: 19,
            labels: RangeLabels(
              widget.minPriceVnd == null
                  ? '< 0.5 tỷ'
                  : '${sliderMin.toStringAsFixed(1)} tỷ',
              widget.maxPriceVnd == null
                  ? '10+ tỷ (Mở)'
                  : '${sliderMax.toStringAsFixed(1)} tỷ',
            ),
            onChanged: (RangeValues values) {
              final Vnd? minVnd = values.start <= 0.5
                  ? null
                  : Vnd.fromInt((values.start * 1e9).round());
              final Vnd? maxVnd = values.end >= 10.0
                  ? null
                  : Vnd.fromInt((values.end * 1e9).round());
              widget.onChanged(minVnd, maxVnd);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0,5 tỷ',
              style: AppTypography.compact.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '10+ tỷ (Mở)',
              style: AppTypography.compact.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoldRangeThumb extends RangeSliderThumbShape {
  const _GoldRangeThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(16, 16);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    context.canvas.drawCircle(center, 7, Paint()..color = AppColors.surface);
    context.canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = AppColors.goldDecorative
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }
}
