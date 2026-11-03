import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../providers/domain_providers.dart';
import '../../../safety/safe_text.dart';
import 'date_sheet.dart';

/// 날짜 입력.
///
/// 값은 [ApproxDate] 다 — **정밀도를 값이 직접 들고 다닌다.** `KstDate` 로 받으면
/// "3월쯤" 이라는 사실이 입력 단계에서 사라지고, 그다음부터는 아무도 그게 어림값인
/// 줄 모른다. `DateTime` 을 쓰지 않는 이유와 같은 결이다 (DECISIONS 3번).
///
/// ## 주 경로는 「날짜 고르기」다
///
/// 연·월을 먼저 고르는 시트가 주 경로이고, 칩은 최근 며칠을 위한 지름길이다.
/// 이 앱이 묻는 날짜는 대개 몇 달~몇 년 전이라 칩으로 닿지 않는다.
///
/// **상대 표현은 7일까지만 둔다.** 「3주 전」은 날짜보다 부정확하고, 그 착각이
/// 그대로 기한 계산으로 번진다 (DECISIONS 49번).
class DateInput extends ConsumerWidget {
  const DateInput({
    required this.question,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Question question;
  final ApproxDate? value;
  final ValueChanged<Object?> onChanged;

  static const String empty = '날짜를 골라 주세요';
  static const String pick = '날짜 고르기';

  /// 지난 쪽 상대 표현. 이름과 며칠 전인지.
  static const List<(String, int)> pastChips = [
    ('오늘', 0),
    ('어제', 1),
    ('그저께', 2),
    ('1주일 전', 7),
  ];

  /// 앞으로의 상대 표현. `dateRange` 가 미래를 허용할 때만 나온다.
  static const List<(String, int)> futureChips = [
    ('내일', 1),
    ('1주일 뒤', 7),
  ];

  /// 이 질문이 받을 수 있는 범위. 없으면 스키마 검사가 이미 빌드를 세웠다.
  DateRange get _range => question.dateRange ?? DateRange.any;

  /// 어림값을 받아도 되는 날짜인가. 데이터가 정한다.
  bool get _allowsApproximate =>
      question.datePrecision == DatePrecisionPolicy.approximate;

  bool get _allowsPast => _range != DateRange.future;
  bool get _allowsFuture => _range != DateRange.past;

  /// 고른 날을 상대 표현으로도 읽어 준다. `2026년 8월 14일 (그저께)`
  String? _relativeName(KstDate today, ApproxDate selected) {
    final exact = selected.exact;
    if (exact == null) return null;
    final days = exact.differenceInDays(today);
    for (final (name, back) in pastChips) {
      if (days == -back) return name;
    }
    for (final (name, ahead) in futureChips) {
      if (days == ahead) return name;
    }
    return null;
  }

  bool _isChipSelected(KstDate today, int offsetDays) {
    final exact = value?.exact;
    return exact != null && exact.differenceInDays(today) == offsetDays;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final selected = value;
    final relative = selected == null ? null : _relativeName(today, selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          decoration: BoxDecoration(
            color: BeobaColors.card,
            borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
          ),
          foregroundDecoration: selected == null
              ? null
              : BoxDecoration(
                  border: Border.all(color: BeobaColors.brand, width: 2),
                  borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
                ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 19,
                color: BeobaColors.ink3,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: SafeText(
                  selected == null
                      ? empty
                      : relative == null
                          ? formatApproxDate(selected)
                          : '${formatApproxDate(selected)} ($relative)',
                  where: 'DateInput.value',
                  style: theme.bodyMedium?.copyWith(
                    fontSize: 17,
                    fontWeight:
                        selected == null ? FontWeight.w400 : FontWeight.w700,
                    color: selected == null ? BeobaColors.ink3 : BeobaColors.ink,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 어림값이면 그 사실을 입력 자리에서부터 말한다. 결과 화면에서 처음
        // 알게 되면 사용자는 자기가 무엇을 답했는지 잊은 뒤다.
        if (selected != null && !selected.isExact) ...[
          const SizedBox(height: 8),
          _ApproximateNote(selected: selected),
        ],
        const SizedBox(height: 11),
        FilledButton.tonalIcon(
          onPressed: () => _openSheet(context, today),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, BeobaTapTarget.button),
          ),
          icon: const Icon(Icons.edit_calendar_outlined, size: 19),
          label: SafeText(pick, where: 'DateInput.pick'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_allowsPast)
              for (final (name, back) in pastChips)
                _DateChip(
                  label: name,
                  selected: _isChipSelected(today, -back),
                  onTap: () =>
                      onChanged(ApproxDate.exact(today.addDays(-back))),
                ),
            if (_allowsFuture)
              for (final (name, ahead) in futureChips)
                _DateChip(
                  label: name,
                  selected: _isChipSelected(today, ahead),
                  onTap: () =>
                      onChanged(ApproxDate.exact(today.addDays(ahead))),
                ),
          ],
        ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context, KstDate today) async {
    final picked = await showModalBottomSheet<ApproxDate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeobaColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BeobaSpace.radius),
        ),
      ),
      builder: (_) => DateSheet(
        today: today,
        initial: value,
        allowsPast: _allowsPast,
        allowsFuture: _allowsFuture,
        allowsApproximate: _allowsApproximate,
      ),
    );
    if (picked == null) return;
    onChanged(picked);
  }
}

/// 어림값이라는 사실을 입력 자리에서 알린다.
class _ApproximateNote extends StatelessWidget {
  const _ApproximateNote({required this.selected});

  final ApproxDate selected;

  static const String prefix = '정확한 날짜는 모르는 걸로 받았어요.';
  static const String suffix = '이 날짜로 계산한 기한은 범위로 알려드릴게요.';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BeobaColors.amberSoft,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.help_outline,
            size: 17,
            color: BeobaColors.legalMaybe,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SafeText(
              '$prefix $suffix',
              where: 'DateInput.approximate',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: BeobaColors.ink2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 날짜 칩 하나.
///
/// 선택 상태는 **색 하나에 기대지 않는다** — 테두리색·두께·배경·굵기가 함께 바뀐다.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, BeobaTapTarget.minimum),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor:
            selected ? BeobaColors.brandSoft : BeobaColors.surfaceStrong,
        foregroundColor: selected ? BeobaColors.brand : BeobaColors.ink2,
        side: selected
            ? const BorderSide(color: BeobaColors.brand, width: 2)
            : BorderSide.none,
      ),
      child: SafeText(
        label,
        where: 'DateInput.chip',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? BeobaColors.brand : BeobaColors.ink2,
            ),
      ),
    );
  }
}
