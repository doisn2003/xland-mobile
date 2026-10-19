import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Form Input Text Field complying with XLand design spec.
/// Height >= 48dp, 12dp radius, full validation & error display.
class XLandTextField extends StatelessWidget {
  const XLandTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.onTap,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.bodyStrong.copyWith(
              color: enabled ? AppColors.textPrimary : AppColors.disabledForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.gapControl),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.inputMinHeight,
          ),
          child: TextFormField(
            controller: controller,
            initialValue: initialValue,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            obscureText: obscureText,
            readOnly: readOnly,
            enabled: enabled,
            maxLines: maxLines,
            onChanged: onChanged,
            onTap: onTap,
            validator: validator,
            style: AppTypography.body.copyWith(
              color: enabled ? AppColors.textPrimary : AppColors.disabledForeground,
            ),
            decoration: InputDecoration(
              hintText: hint,
              helperText: helperText,
              errorText: errorText,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}

/// Search Bar input field with icon and optional filter button.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Tìm kiếm khu vực, mã lô đất...',
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.hasActiveFilters = false,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: AppSpacing.inputMinHeight,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.inputRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: AppTypography.body,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: hint,
                hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: AppSpacing.iconRegular,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s12,
                ),
              ),
            ),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: AppSpacing.s8),
          Material(
            color: hasActiveFilters ? AppColors.verifiedSurface : AppColors.surface,
            borderRadius: AppRadius.inputRadius,
            child: InkWell(
              onTap: onFilterTap,
              borderRadius: AppRadius.inputRadius,
              child: Container(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.inputRadius,
                  border: Border.all(
                    color: hasActiveFilters ? AppColors.brandPrimary : AppColors.border,
                    width: hasActiveFilters ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: AppSpacing.iconRegular,
                        color: hasActiveFilters ? AppColors.brandPrimary : AppColors.textPrimary,
                      ),
                      if (hasActiveFilters)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brandPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Location Selector Pill (e.g., "Toàn quốc", "Hòa Lạc").
class LocationPill extends StatelessWidget {
  const LocationPill({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.chipVisualHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.onPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.compact.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Counter Input for attendees / quantity with touch targets >= 48dp.
class CounterInput extends StatelessWidget {
  const CounterInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.label,
    this.unit = 'người',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.bodyStrong),
          const SizedBox(height: AppSpacing.gapControl),
        ],
        Container(
          height: AppSpacing.inputMinHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.inputRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: canDecrement ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_rounded),
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTouchTarget,
                  minHeight: AppSpacing.minTouchTarget,
                ),
                color: canDecrement ? AppColors.brandPrimary : AppColors.disabledForeground,
              ),
              Text(
                '$value $unit',
                style: AppTypography.bodyStrong,
              ),
              IconButton(
                onPressed: canIncrement ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_rounded),
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTouchTarget,
                  minHeight: AppSpacing.minTouchTarget,
                ),
                color: canIncrement ? AppColors.brandPrimary : AppColors.disabledForeground,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
