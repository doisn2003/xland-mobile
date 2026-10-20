import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';

/// S05 Finance Planning Tab Component.
/// Complies with Decision A-06:
/// - Real calculation via FinanceRepository.calculate (N01)
/// - Two repayment methods: equalInstallment & decliningBalance
/// - Monthly payment labels:
///   * equalInstallment: "Khoản trả hàng tháng ước tính; kỳ cuối có điều chỉnh"
///   * decliningBalance: "Khoản trả tháng đầu (giảm dần)"
/// - Save plan with auth gate & idempotency (N02)
/// - History snapshot & delete plan (N03, N04)
/// - NO formula calculation in widget; all outputs from repository
class FinancePlanTab extends StatefulWidget {
  const FinancePlanTab({
    super.key,
    this.property,
    this.embedded = false,
    this.onSaveAvailabilityChanged,
  });
  final bool embedded;
  final ValueChanged<bool>? onSaveAvailabilityChanged;

  final Property? property;

  @override
  State<FinancePlanTab> createState() => FinancePlanTabState();
}

class FinancePlanTabState extends State<FinancePlanTab> {
  double _loanRatio = 0.5; // 50%
  int _termYears = 20; // 240 months
  double _annualRate = 9.0; // 9.0%/year
  RepaymentMethod _method = RepaymentMethod.equalInstallment;

  FinanceResult? _result;
  bool _isCalculating = false;
  String? _calcError;
  int _calcGeneration = 0;

  bool _isSaving = false;
  String? _activeSaveKey;
  String? _lastSavePayloadSignature;
  List<SavedFinancePlan> _savedPlans = [];
  bool _isLoadingPlans = false;
  String? _plansError;
  String? _lastUserId;

  String? _plansCursor;
  bool _hasMorePlans = false;
  bool _isLoadingMorePlans = false;
  int _plansGeneration = 0;

  bool get canSave =>
      !_isCalculating && !_isSaving && _calcError == null && _result != null;
  Future<void> savePlan() async {
    if (canSave) await _handleSavePlan();
  }

  void requestLoanAdvice() => _showLoanAdviceSheet(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculate();
      _loadSavedPlans();
    });
  }

  @override
  void didUpdateWidget(covariant FinancePlanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.property?.id != oldWidget.property?.id ||
        widget.property?.priceTotal != oldWidget.property?.priceTotal) {
      _calculate();
      _loadSavedPlans();
    }
  }

  Future<void> _calculate() async {
    if (widget.property == null || !mounted) return;
    final gen = ++_calcGeneration;
    widget.onSaveAvailabilityChanged?.call(false);
    final deps = DependenciesScope.of(context);

    setState(() {
      _isCalculating = true;
      _calcError = null;
    });

    try {
      final totalAmount = widget.property!.priceTotal.amount;
      final loanPercent = (_loanRatio * 100).round();
      final loanAmount =
          (totalAmount * BigInt.from(loanPercent)) ~/ BigInt.from(100);
      final equityAmount = totalAmount - loanAmount;

      final input = FinanceInput(
        propertyId: widget.property!.id,
        equityVnd: Vnd(equityAmount.toString()),
        loanVnd: Vnd(loanAmount.toString()),
        termMonths: _termYears * 12,
        annualRatePercent: DecimalValue(
          _annualRate == _annualRate.roundToDouble()
              ? _annualRate.toInt().toString()
              : _annualRate.toStringAsFixed(1),
        ),
        method: _method,
      );

      final res = await deps.finance.calculate(input);
      if (!mounted || gen != _calcGeneration) return;
      setState(() {
        _result = res;
        _isCalculating = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || gen != _calcGeneration) return;
      setState(() {
        _result = null;
        _calcError = e.message;
        _isCalculating = false;
      });
    } catch (e) {
      if (!mounted || gen != _calcGeneration) return;
      setState(() {
        _result = null;
        _calcError = 'Không thể tính toán kế hoạch: $e';
        _isCalculating = false;
      });
    } finally {
      if (mounted && gen == _calcGeneration) {
        widget.onSaveAvailabilityChanged?.call(canSave);
      }
    }
  }

  Future<void> _loadSavedPlans() async {
    if (!mounted) return;
    final gen = ++_plansGeneration;
    final targetUserId = _lastUserId;
    final deps = DependenciesScope.of(context);

    if (targetUserId == null) {
      setState(() {
        _savedPlans = [];
        _isLoadingPlans = false;
        _plansError = null;
      });
      return;
    }

    setState(() {
      _isLoadingPlans = true;
      _plansError = null;
    });
    try {
      final List<SavedFinancePlan> matched = [];
      String? cursor;
      bool hasMore = true;
      int pagesLoaded = 0;
      const maxInitialPages = 5;

      while (hasMore && pagesLoaded < maxInitialPages) {
        final page = await deps.finance.getPlans(
          PageQuery(cursor: cursor, limit: 20),
        );
        if (!mounted ||
            gen != _plansGeneration ||
            targetUserId != _lastUserId) {
          return;
        }
        pagesLoaded++;
        cursor = page.nextCursor;
        hasMore = page.hasMore;

        final itemsForProperty = page.items
            .where(
              (p) =>
                  widget.property == null ||
                  p.propertyId == widget.property!.id,
            )
            .toList();
        matched.addAll(itemsForProperty);

        if (matched.length >= 10) break;
      }

      if (!mounted || gen != _plansGeneration || targetUserId != _lastUserId) {
        return;
      }
      setState(() {
        _savedPlans = matched;
        _plansCursor = cursor;
        _hasMorePlans = hasMore;
        _isLoadingPlans = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || gen != _plansGeneration || targetUserId != _lastUserId) {
        return;
      }
      setState(() {
        _plansError = e.message;
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted || gen != _plansGeneration || targetUserId != _lastUserId) {
        return;
      }
      setState(() {
        _plansError = 'Không thể tải danh sách kế hoạch: $e';
        _isLoadingPlans = false;
      });
    }
  }

  Future<void> _loadMorePlans() async {
    if (_isLoadingMorePlans || !_hasMorePlans) return;
    final gen = _plansGeneration;
    final targetUserId = _lastUserId;
    if (targetUserId == null) return;

    final deps = DependenciesScope.of(context);
    setState(() => _isLoadingMorePlans = true);
    try {
      final List<SavedFinancePlan> newMatched = [];
      String? cursor = _plansCursor;
      bool hasMore = _hasMorePlans;
      int pagesLoaded = 0;
      const maxPagesPerFetch = 3;

      while (hasMore && pagesLoaded < maxPagesPerFetch) {
        final page = await deps.finance.getPlans(
          PageQuery(cursor: cursor, limit: 20),
        );
        if (!mounted ||
            gen != _plansGeneration ||
            targetUserId != _lastUserId) {
          return;
        }
        pagesLoaded++;
        cursor = page.nextCursor;
        hasMore = page.hasMore;

        final itemsForProperty = page.items
            .where(
              (p) =>
                  widget.property == null ||
                  p.propertyId == widget.property!.id,
            )
            .toList();
        newMatched.addAll(itemsForProperty);
        if (newMatched.isNotEmpty) break;
      }

      if (!mounted || gen != _plansGeneration || targetUserId != _lastUserId) {
        return;
      }
      final existingIds = _savedPlans.map((p) => p.id).toSet();
      final itemsToAdd = newMatched
          .where((p) => !existingIds.contains(p.id))
          .toList();
      setState(() {
        _savedPlans.addAll(itemsToAdd);
        _plansCursor = cursor;
        _hasMorePlans = hasMore;
        _isLoadingMorePlans = false;
      });
    } catch (_) {
      if (mounted && gen == _plansGeneration && targetUserId == _lastUserId) {
        setState(() => _isLoadingMorePlans = false);
      }
    }
  }

  Future<void> _handleSavePlan() async {
    if (!canSave || widget.property == null || !mounted) return;
    final authState = context.read<AuthCubit>().state;

    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để lưu kế hoạch',
        message: 'Vui lòng đăng nhập để lưu và đồng bộ kế hoạch tài chính vào hồ sơ của bạn.',
      );
      if (!didLogin || !mounted) return;
    }

    final deps = DependenciesScope.of(context);
    setState(() => _isSaving = true);
    widget.onSaveAvailabilityChanged?.call(false);

    try {
      final payloadSignature =
          '${widget.property!.id}|${_result!.input.loanVnd.wireValue}|${_result!.input.equityVnd.wireValue}|${_result!.input.termMonths}|${_result!.input.annualRatePercent.wireValue}|${_result!.input.method.name}';
      if (_lastSavePayloadSignature != payloadSignature ||
          _activeSaveKey == null) {
        _lastSavePayloadSignature = payloadSignature;
        _activeSaveKey =
            'plan-${widget.property!.id}-${DateTime.now().millisecondsSinceEpoch}';
      }

      final label = _method == RepaymentMethod.equalInstallment
          ? 'Kế hoạch vay ${(_loanRatio * 100).toInt()}% - $_termYears năm (Gốc & lãi chia đều)'
          : 'Kế hoạch vay ${(_loanRatio * 100).toInt()}% - $_termYears năm (Dư nợ giảm dần)';

      await deps.finance.savePlan(
        label,
        _result!.input,
        idempotencyKey: _activeSaveKey!,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu kế hoạch tài chính thành công!'),
          backgroundColor: AppColors.brandPrimary,
        ),
      );
      _loadSavedPlans();
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu kế hoạch: ${e.message}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) widget.onSaveAvailabilityChanged?.call(canSave);
    }
  }

  Future<void> _handleDeletePlan(String planId) async {
    final deps = DependenciesScope.of(context);
    try {
      await deps.finance.deletePlan(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa kế hoạch tài chính.')),
      );
      _loadSavedPlans();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể xóa kế hoạch: $e')));
    }
  }

  String _formatVnd(Vnd vnd) {
    final s = vnd.amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }
    return '${buffer.toString()} đ';
  }

  @override
  Widget build(BuildContext context) {
    final prop = widget.property;
    final authState = context.watch<AuthCubit>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.session.profile.id
        : null;
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _plansGeneration++;
      _savedPlans = [];
      _plansCursor = null;
      _hasMorePlans = false;
      _isLoadingPlans = false;
      _isLoadingMorePlans = false;
      _plansError = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && currentUserId != null) {
          _loadSavedPlans();
        }
      });
    }

    return SingleChildScrollView(
      primary: widget.embedded ? false : null,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.s16,
        AppSpacing.pageGutter,
        AppSpacing.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prop != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calculate_outlined,
                        color: AppColors.feedGold,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dự tính khoản vay',
                        style: AppTypography.cardTitle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatCompactVnd(
                      Vnd(
                        (prop.priceTotal.amount *
                                BigInt.from((_loanRatio * 100).round()) ~/
                                BigInt.from(100))
                            .toString(),
                      ),
                    ),
                    style: AppTypography.displayMetric.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trên tổng giá ${formatCompactVnd(prop.priceTotal)} • Vốn tự có ${100 - (_loanRatio * 100).round()}%',
                    style: AppTypography.body.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // A-06 Finance Disclaimer Notice
          InfoNotice(
            title: 'Kế hoạch tài chính & Vay vốn',
            message: _result?.estimateNotice ?? 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
            variant: NoticeVariant.info,
          ),
          const SizedBox(height: AppSpacing.s20),

          // Layout Form Input
          const DesignSectionTitle(
            'Thông tin khoản vay (mô phỏng)',
            icon: Icons.edit_note_outlined,
          ),
          const SizedBox(height: AppSpacing.s8),
          XLandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                XLandTextField(
                  label: 'Giá trị lô đất (VNĐ)',
                  initialValue: prop != null
                      ? _formatVnd(prop.priceTotal)
                      : '2.400.000.000 đ',
                  enabled: false,
                ),
                const SizedBox(height: AppSpacing.s16),

                // Loan ratio selector
                Text(
                  'Tỷ lệ vay: ${(_loanRatio * 100).toInt()}% (${prop != null ? _formatVnd(Vnd(((prop.priceTotal.amount * BigInt.from((_loanRatio * 100).round())) ~/ BigInt.from(100)).toString())) : ""})',
                  style: AppTypography.bodyStrong,
                ),
                Slider(
                  value: _loanRatio,
                  min: 0.1,
                  max: 0.8,
                  divisions: 7, // 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%
                  activeColor: AppColors.brandPrimary,
                  onChanged: (val) {
                    setState(() => _loanRatio = val);
                    _calculate();
                  },
                ),
                const SizedBox(height: AppSpacing.s12),

                // Term selector
                Text('Thời hạn vay:', style: AppTypography.bodyStrong),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [5, 10, 15, 20, 25].map((y) {
                    final isSel = _termYears == y;
                    return ChoiceChip(
                      label: Text('$y năm (${y * 12} th)'),
                      selected: isSel,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _termYears = y);
                          _calculate();
                        }
                      },
                      selectedColor: AppColors.brandPrimary,
                      labelStyle: TextStyle(
                        color: isSel
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Annual rate
                Text(
                  'Lãi suất giả định: ${_annualRate.toStringAsFixed(1)}%/năm',
                  style: AppTypography.bodyStrong,
                ),
                Slider(
                  value: _annualRate,
                  min: 5.0,
                  max: 15.0,
                  divisions: 20,
                  activeColor: AppColors.brandPrimary,
                  onChanged: (val) {
                    setState(() => _annualRate = val);
                    _calculate();
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // Repayment Method Selector
                Text('Phương thức trả nợ:', style: AppTypography.bodyStrong),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Gốc & lãi chia đều')),
                        selected: _method == RepaymentMethod.equalInstallment,
                        onSelected: (sel) {
                          if (sel) {
                            setState(
                              () => _method = RepaymentMethod.equalInstallment,
                            );
                            _calculate();
                          }
                        },
                        selectedColor: AppColors.brandPrimary,
                        labelStyle: TextStyle(
                          color: _method == RepaymentMethod.equalInstallment
                              ? AppColors.onPrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Dư nợ giảm dần')),
                        selected: _method == RepaymentMethod.decliningBalance,
                        onSelected: (sel) {
                          if (sel) {
                            setState(
                              () => _method = RepaymentMethod.decliningBalance,
                            );
                            _calculate();
                          }
                        },
                        selectedColor: AppColors.brandPrimary,
                        labelStyle: TextStyle(
                          color: _method == RepaymentMethod.decliningBalance
                              ? AppColors.onPrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                // Calculation Results (N01)
                if (_isCalculating)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  )
                else if (_calcError != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            _calcError!,
                            style: AppTypography.compact.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _calculate,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                else if (_result != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: AppColors.goldSurface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _method == RepaymentMethod.equalInstallment
                              ? 'Khoản trả hàng tháng ước tính; kỳ cuối có điều chỉnh'
                              : 'Khoản trả tháng đầu (giảm dần)',
                          style: AppTypography.compactStrong.copyWith(
                            color: AppColors.goldForeground,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          _formatVnd(_result!.monthlyPaymentVnd),
                          style: AppTypography.sectionTitle.copyWith(
                            color: AppColors.brandPrimary,
                            fontSize: 26,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildMetricRow(
                          'Gốc tháng đầu',
                          _formatVnd(_result!.firstMonthPrincipalVnd),
                        ),
                        const SizedBox(height: 6),
                        _buildMetricRow(
                          'Lãi tháng đầu',
                          _formatVnd(_result!.firstMonthInterestVnd),
                        ),
                        const SizedBox(height: 6),
                        _buildMetricRow(
                          'Tổng lãi toàn bộ kỳ vay',
                          _formatVnd(_result!.totalInterestVnd),
                        ),
                        const SizedBox(height: 6),
                        _buildMetricRow(
                          'Tổng số tiền gốc & lãi phải trả',
                          _formatVnd(_result!.totalRepaymentVnd),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.s20),

                // Save Plan Action (N02)
                PrimaryButton(
                  label: _isSaving
                      ? 'Đang lưu kế hoạch...'
                      : 'Lưu kế hoạch tài chính',
                  isSubmitting: _isSaving,
                  onPressed:
                      (_isCalculating ||
                          _isSaving ||
                          _calcError != null ||
                          _result == null)
                      ? null
                      : _handleSavePlan,
                ),
                const SizedBox(height: AppSpacing.s12),
                OutlineButton(
                  label: 'Đăng ký tư vấn gói vay ngân hàng',
                  onPressed: () => _showLoanAdviceSheet(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s24),

          // Saved Plans History (N03 & N04)
          Text('Kế hoạch tài chính đã lưu', style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.s8),
          if (_isLoadingPlans)
            const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            )
          else if (_plansError != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _plansError!,
                      style: AppTypography.compact.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadSavedPlans,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else if (_savedPlans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Text(
                'Chưa có kế hoạch tài chính nào được lưu cho bất động sản này.',
                style: AppTypography.compact.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ..._savedPlans.map((plan) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: XLandCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.label, style: AppTypography.bodyStrong),
                            const SizedBox(height: 4),
                            if (plan.result != null)
                              Text(
                                plan.input.method ==
                                        RepaymentMethod.decliningBalance
                                    ? 'Tháng đầu: ${_formatVnd(plan.result!.monthlyPaymentVnd)} (giảm dần)'
                                    : 'Trả hàng tháng: ${_formatVnd(plan.result!.monthlyPaymentVnd)}',
                                style: AppTypography.compact.copyWith(
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            Text(
                              'Vay: ${_formatVnd(plan.input.loanVnd)} • ${plan.input.termMonths ~/ 12} năm',
                              style: AppTypography.compact.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                        ),
                        tooltip: 'Xóa kế hoạch',
                        onPressed: () => _handleDeletePlan(plan.id),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (_hasMorePlans)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _isLoadingMorePlans
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : OutlineButton(
                      label: 'Tải thêm kế hoạch',
                      onPressed: _loadMorePlans,
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.compact.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Text(
          value,
          style: AppTypography.compactStrong,
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  void _showLoanAdviceSheet(BuildContext context) {
    final deps = DependenciesScope.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authState = context.read<AuthCubit>().state;
    String initialName = '';
    String initialPhone = '';
    if (authState is AuthAuthenticated) {
      initialName = authState.session.profile.displayName;
      initialPhone = authState.session.profile.contactPhone ?? '';
    }

    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController(text: initialPhone);
    bool consent = false;
    bool isSubmitting = false;
    String? errorMessage;

    showXLandBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.s20,
                AppSpacing.pageGutter,
                AppSpacing.s24 + bottomInset,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.sheetTopRadius,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text(
                      'Đăng ký tư vấn gói vay ngân hàng',
                      style: AppTypography.sheetTitle,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      'Chuyên viên tài chính sẽ kết nối ngân hàng đối tác phù hợp với tỷ lệ vay ${(_loanRatio * 100).toInt()}% và thời hạn $_termYears năm.',
                      style: AppTypography.compact.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    XLandTextField(
                      label: 'Họ và tên',
                      controller: nameController,
                      hint: 'Nguyễn Văn A',
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    XLandTextField(
                      label: 'Số điện thoại',
                      controller: phoneController,
                      hint: '0901234567',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: consent,
                          activeColor: AppColors.brandPrimary,
                          onChanged: (val) {
                            setSheetState(() => consent = val ?? false);
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() => consent = !consent);
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Tôi đồng ý chia sẻ thông tin liên hệ và kế hoạch vay dự kiến để nhận tư vấn từ chuyên viên và ngân hàng liên kết (Bắt buộc).',
                                style: AppTypography.compact,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        errorMessage!,
                        style: AppTypography.compact.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s16),
                    PrimaryButton(
                      label: isSubmitting
                          ? 'Đang gửi yêu cầu...'
                          : 'Gửi yêu cầu tư vấn',
                      isSubmitting: isSubmitting,
                      onPressed: (!consent || isSubmitting)
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              if (name.isEmpty || phone.isEmpty) {
                                setSheetState(() {
                                  errorMessage =
                                      'Vui lòng nhập họ tên và số điện thoại.';
                                });
                                return;
                              }
                              setSheetState(() {
                                isSubmitting = true;
                                errorMessage = null;
                              });
                              try {
                                final input = SupportRequestInput(
                                  kind: SupportKind.loanAdvice,
                                  propertyId: widget.property?.id,
                                  message:
                                      'Yêu cầu tư vấn vay ${(_loanRatio * 100).toInt()}% ($_termYears năm, ${_method == RepaymentMethod.equalInstallment ? "gốc lãi đều" : "dư nợ giảm dần"})',
                                  contactName: name,
                                  contactPhone: phone,
                                  consentToShareContact: consent,
                                );
                                final idempotencyKey =
                                    'loan-advice-${widget.property?.id ?? "gen"}-${DateTime.now().millisecondsSinceEpoch}';
                                final res = await deps.support.submit(
                                  input,
                                  idempotencyKey: idempotencyKey,
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res.notice),
                                    backgroundColor: AppColors.brandPrimary,
                                  ),
                                );
                              } on XlandFailure catch (e) {
                                setSheetState(() {
                                  errorMessage = e.message;
                                  isSubmitting = false;
                                });
                              } catch (e) {
                                setSheetState(() {
                                  errorMessage = 'Lỗi gửi yêu cầu: $e';
                                  isSubmitting = false;
                                });
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
