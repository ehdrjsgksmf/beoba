import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';

/// 연 · 월 · 일을 **그 순서로** 고르는 시트.
///
/// ## 왜 연·월이 먼저인가
///
/// 사람은 날짜를 "날" 이 아니라 "월" 로 기억한다. 그리고 이 앱이 묻는 날짜는 대개
/// 몇 달~몇 년 전이다. **달력으로 3년 전에 가려면 36번 넘겨야 한다.** 휠은 3칸이다.
///
/// 조작 순서가 기억하는 순서와 같아서, 「일」에 다다르기 전에 「모름」을 만난다.
///
/// ## 「모름」은 정식 선택지다
///
/// 별도 모드나 체크박스가 아니라 **같은 줄에 있는 항목**이다. 그래야 사용자가
/// "모르면 안 되나 보다" 라고 느끼지 않는다.
///
/// **처음 열 때 커서가 「모름」에 있다.** 기본값이 특정 날짜면 아무것도 안 한
/// 사람이 그 날짜로 확정된다. 조작하지 않은 사람이 거짓을 얻어서는 안 된다.
///
/// **연 휠에는 「모름」이 없다.** 연도를 모르면 어떤 계산도 못 한다 —
/// 그건 어림값이 아니라 답하지 않은 것이다.
///
/// ## 휠이 유일한 경로여서는 안 된다
///
/// `ListWheelScrollView` 는 스크린리더 지원이 약하다. 휠만 두면 못 쓰는 사람이
/// 생기고, 그 사람들은 이 앱이 돕겠다고 한 사람들과 겹친다. 그래서 시트 안에
/// **숫자 직접 입력 칸**을 함께 둔다. 둘은 같은 값을 양방향으로 공유한다.
class DateSheet extends StatefulWidget {
  const DateSheet({
    required this.today,
    required this.initial,
    required this.allowsPast,
    required this.allowsFuture,
    required this.allowsApproximate,
    super.key,
  });

  final KstDate today;
  final ApproxDate? initial;
  final bool allowsPast;
  final bool allowsFuture;

  /// 「모름」을 내줄 것인가. 데이터가 정한다.
  final bool allowsApproximate;

  static const String title = '언제였는지 골라 주세요';
  static const String unknown = '모름';
  static const String confirm = '이 날짜로';
  static const String cancel = '그만두기';
  static const String yearLabel = '연';
  static const String monthLabel = '월';
  static const String dayLabel = '일';

  /// 휠을 못 쓰는 사람을 위한 길.
  static const String typeInstead = '숫자로 직접 넣기';
  static const String typeHint = '2023 · 2023-03 · 2023-03-15';
  static const String typeBad = '이 날짜를 읽지 못했어요';
  static const String outOfRangePast = '지난 날짜만 넣을 수 있어요';
  static const String outOfRangeFuture = '앞으로의 날짜만 넣을 수 있어요';

  /// 몇 해 전까지 거슬러 갈 것인가.
  static const int yearsBack = 30;

  /// 몇 해 앞까지 갈 것인가.
  static const int yearsAhead = 5;

  @override
  State<DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<DateSheet> {
  late final List<int> _years = _buildYears();
  late int _yearIndex;

  /// 0 이면 「모름」. 1~12 가 실제 월이다.
  late int _month;

  /// 0 이면 「모름」. 1~ 이 실제 일이다.
  late int _day;

  late final TextEditingController _typed;
  String? _typedError;

  List<int> _buildYears() {
    final first = widget.allowsPast ? widget.today.year - DateSheet.yearsBack : widget.today.year;
    final last = widget.allowsFuture ? widget.today.year + DateSheet.yearsAhead : widget.today.year;
    return [for (var y = first; y <= last; y++) y];
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final year = initial?.year ?? widget.today.year;
    _yearIndex = _years.indexOf(year).clamp(0, _years.length - 1);
    // 조작하지 않은 사람이 거짓을 얻지 않도록 「모름」에서 시작한다.
    _month = initial?.month ?? (widget.allowsApproximate ? 0 : widget.today.month);
    _day = initial?.day ?? (widget.allowsApproximate ? 0 : widget.today.day);
    _typed = TextEditingController(text: initial?.toIso() ?? '');
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  ApproxDate get _value => ApproxDate(
        _years[_yearIndex],
        _month == 0 ? null : _month,
        _month == 0 || _day == 0 ? null : _day,
      );

  int get _daysInMonth =>
      _month == 0 ? 31 : KstDate.daysInMonth(_years[_yearIndex], _month);

  /// 범위를 벗어났으면 이유. 괜찮으면 null.
  String? _rangeProblem(ApproxDate value) {
    if (!widget.allowsFuture && value.earliest > widget.today) {
      return DateSheet.outOfRangePast;
    }
    if (!widget.allowsPast && value.latest < widget.today) {
      return DateSheet.outOfRangeFuture;
    }
    return null;
  }

  void _syncFromWheels() {
    setState(() {
      // 말일이 줄면 고른 일을 끌어내린다. 2월 31일 같은 값을 만들지 않는다.
      if (_day > _daysInMonth) _day = _daysInMonth;
      _typed.text = _value.toIso();
      _typedError = _rangeProblem(_value);
    });
  }

  void _syncFromTyped(String raw) {
    final parsed = ApproxDate.tryParse(raw);
    setState(() {
      if (raw.trim().isEmpty) {
        _typedError = null;
        return;
      }
      if (parsed == null) {
        _typedError = DateSheet.typeBad;
        return;
      }
      if (!widget.allowsApproximate && !parsed.isExact) {
        _typedError = DateSheet.typeBad;
        return;
      }
      final index = _years.indexOf(parsed.year);
      if (index < 0) {
        _typedError = widget.allowsFuture
            ? DateSheet.outOfRangeFuture
            : DateSheet.outOfRangePast;
        return;
      }
      _typedError = _rangeProblem(parsed);
      _yearIndex = index;
      _month = parsed.month ?? 0;
      _day = parsed.day ?? 0;
    });
  }

  bool get _canConfirm => _typedError == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BeobaSpace.pageH,
          18,
          BeobaSpace.pageH,
          12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeText(
                DateSheet.title,
                where: 'DateSheet.title',
                style: theme.titleMedium,
              ),
              const SizedBox(height: 14),
              _wheels(context),
              const SizedBox(height: 6),
              SafeText(
                formatApproxDate(_value),
                where: 'DateSheet.preview',
                style: theme.bodyMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: BeobaColors.brand2,
                  fontFeatures: kTabularFigures,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 휠을 못 쓰는 사람도 날짜를 넣을 수 있어야 한다.
              TextField(
                controller: _typed,
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                ],
                style: theme.bodyMedium?.copyWith(fontFeatures: kTabularFigures),
                decoration: InputDecoration(
                  labelText: DateSheet.typeInstead,
                  hintText: DateSheet.typeHint,
                  errorText: _typedError,
                ),
                onChanged: _syncFromTyped,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, BeobaTapTarget.button),
                      ),
                      child: SafeText(
                        DateSheet.cancel,
                        where: 'DateSheet.cancel',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _canConfirm
                          ? () => Navigator.of(context).pop(_value)
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, BeobaTapTarget.button),
                      ),
                      child: SafeText(
                        DateSheet.confirm,
                        where: 'DateSheet.confirm',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wheels(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _Wheel(
              label: DateSheet.yearLabel,
              // 연 휠에는 「모름」이 없다. 연도를 모르면 답하지 않은 것이다.
              items: [for (final y in _years) '$y'],
              index: _yearIndex,
              onChanged: (i) {
                _yearIndex = i;
                _syncFromWheels();
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: _Wheel(
              label: DateSheet.monthLabel,
              items: [
                if (widget.allowsApproximate) DateSheet.unknown,
                for (var m = 1; m <= 12; m++) '$m',
              ],
              index: widget.allowsApproximate ? _month : _month - 1,
              onChanged: (i) {
                _month = widget.allowsApproximate ? i : i + 1;
                if (_month == 0) _day = 0;
                _syncFromWheels();
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: _Wheel(
              label: DateSheet.dayLabel,
              enabled: _month != 0,
              items: [
                if (widget.allowsApproximate) DateSheet.unknown,
                for (var d = 1; d <= _daysInMonth; d++) '$d',
              ],
              index: widget.allowsApproximate ? _day : _day - 1,
              onChanged: (i) {
                _day = widget.allowsApproximate ? i : i + 1;
                _syncFromWheels();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 휠 하나.
///
/// `ListWheelScrollView` 는 Material 기본 위젯이다. 패키지가 필요 없다.
/// 다만 스크린리더에는 약해서 [Semantics] 로 지금 값과 이름을 읽어 준다 —
/// 그래도 부족한 사람을 위해 시트에 숫자 입력 칸이 함께 있다.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.label,
    required this.items,
    required this.index,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.index.clamp(0, 1 << 30));

  @override
  void didUpdateWidget(_Wheel old) {
    super.didUpdateWidget(old);
    // 숫자 칸에서 값이 바뀌면 휠도 따라가야 한다. 다만 **빌드 중에 옮기지 않는다** —
    // 컨트롤러가 알림을 쏘면서 같은 프레임에 다시 빌드를 요구한다.
    final target = widget.index.clamp(0, widget.items.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (_controller.selectedItem != target) _controller.jumpToItem(target);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final safeIndex = widget.index.clamp(0, widget.items.length - 1);
    final current = widget.items.isEmpty ? '' : widget.items[safeIndex];

    return Column(
      children: [
        SafeText(
          widget.label,
          where: 'DateSheet.wheelLabel',
          style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Semantics(
            label: widget.label,
            value: current,
            enabled: widget.enabled,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: 40,
              physics: widget.enabled
                  ? const FixedExtentScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              perspective: 0.003,
              overAndUnderCenterOpacity: 0.45,
              onSelectedItemChanged: widget.enabled ? widget.onChanged : null,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.items.length,
                builder: (context, index) => Center(
                  child: SafeText(
                    widget.items[index],
                    where: 'DateSheet.wheelItem',
                    style: theme.bodyMedium?.copyWith(
                      fontSize: 17,
                      fontWeight:
                          index == safeIndex ? FontWeight.w700 : FontWeight.w400,
                      color: widget.enabled
                          ? (index == safeIndex
                              ? BeobaColors.ink
                              : BeobaColors.ink3)
                          : BeobaColors.ink3,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
