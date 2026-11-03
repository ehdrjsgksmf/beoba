/// 화면에 나가는 모든 숫자·날짜는 **이 파일을 거친다.**
///
/// 엔진이 이미 계산한 값을 화면에서 다시 만들지 않는다. 여기 있는 것은
/// 계산이 아니라 표기다. 계산이 필요해지면 그건 엔진의 몫이다.
library;

import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

/// `1234567` → `1,234,567원`
///
/// engines 의 것을 그대로 쓴다. 다시 구현하지 않는다 — 두 벌이 되면 갈라진다.
export 'package:engines/engines.dart' show formatWon, formatWonKorean;

/// `KstDate(2026, 9, 14)` → `2026년 9월 14일`
String formatKstDate(KstDate date) => '${date.year}년 ${date.month}월 ${date.day}일';

/// `KstDate(2026, 9, 14)` → `9월 14일`
///
/// 같은 해가 명백한 자리(타임라인 · 표)에서 쓴다.
String formatKstDateShort(KstDate date) => '${date.month}월 ${date.day}일';

/// `14일 남음` · `오늘까지` · `3일 지남`
///
/// 「D-84」는 셈에 익숙한 사람의 말이다 — 우리 사용자는 「D」를 읽지 않는다
/// (DECISIONS 287번). 일수는 [DeadlineResult.daysRemaining] 을 그대로 쓴다.
/// 남은 일수를 화면에서 다시 빼지 않는다.
///
/// ★ **「D-」가 남은 자리는 없다.** 결과 화면에서 바꾸고 들고 가는 종이와
/// 층 문장은 [DeadlineResult.dDay] 를 그대로 쓰고 있었다 — 25갈래에서 14번
/// 나왔다. 둘 다 이 함수를 타게 했다(DECISIONS 290번). `dDay` 는 이제
/// 엔진 보고서(`engine_report`)만 쓴다.
String formatDDay(DeadlineResult deadline) {
  final days = deadline.daysRemaining;
  if (days == 0) return '오늘까지';
  return days > 0 ? '$days일 남음' : '${-days}일 지남';
}

/// 진행 표시. `3 / 12`
String formatProgress(int done, int total) => '$done / $total';

/// `ApproxDate(2023, 3)` → `2023년 3월` · `ApproxDate(2023)` → `2023년`
///
/// **보정하지 않는다.** 「3월」을 「3월 1일」로 적으면 사용자가 자기가 그렇게
/// 답한 줄 안다.
String formatApproxDate(ApproxDate date) {
  final exact = date.exact;
  if (exact != null) return formatKstDate(exact);
  if (date.month != null) return '${date.year}년 ${date.month}월';
  return '${date.year}년';
}

/// 기한이 놓일 수 있는 범위. `2030년 8월 1일 ~ 8월 31일`
///
/// 같은 해면 뒤쪽에서 연도를 뺀다. 두 날짜가 같으면 한쪽만 적는다.
String formatDateRange(KstDate from, KstDate to) {
  if (from == to) return formatKstDate(from);
  final tail = from.year == to.year ? formatKstDateShort(to) : formatKstDate(to);
  return '${formatKstDate(from)} ~ $tail';
}

/// 사용자가 답한 값을 화면에 쓸 말로 바꾼다.
///
/// **선택지는 라벨을 데이터에서** 가져온다. 코드가 `loan` 을 "빌려준 돈" 으로
/// 번역하지 않는다 — 그러면 화면이 분야 어휘를 알게 된다.
///
/// 정리 카드와 되받기가 같은 함수를 쓴다. 두 벌이 되면 같은 답이 두 화면에서
/// 다르게 보인다.
String formatAnswer(Question question, Object? value, {String empty = '—'}) {
  final labels = {
    for (final option in question.options) option.value: option.label,
  };

  return switch (value) {
    null => empty,
    // 어림 날짜는 **어림 그대로** 되받는다. 보정해서 되받으면 사용자는 자기가
    // 그렇게 답한 줄 안다.
    final ApproxDate date => formatApproxDate(date),
    final KstDate date => formatKstDate(date),
    final int amount when question.type == QuestionType.money =>
      formatWon(amount),
    final int number => '$number',
    final List<dynamic> list when list.isEmpty => empty,
    final List<dynamic> list => list.map((e) => labels['$e'] ?? '$e').join(', '),
    final String raw => labels[raw] ?? raw,
    _ => '$value',
  };
}

/// 되받는 말. `{value}` 자리에 답을 끼운다. 되받을 것이 없으면 null.
///
/// **직전 답 하나만** 되받는다. 여러 개를 나열하면 그건 요약이지 대화가 아니다.
String? formatEcho(Question question, Object? value) {
  if (value == null) return null;

  // **선택지가 먼저다.** 고른 것마다 자연스러운 되받기가 달라서, 한 틀에
  // 끼우면 「잘 모르겠어요이시군요」 같은 말이 나온다.
  if (value is String) {
    final option =
        question.options.where((o) => o.value == value).firstOrNull;
    final line = option?.echo;
    if (line != null && line.isNotEmpty) return line;
  }

  if (question.echo.isEmpty) return null;
  final shown = formatAnswer(question, value, empty: '');
  if (shown.isEmpty) return null;
  return question.echo.replaceAll('{value}', shown);
}

/// `0.0045` → `0.45%` · `0.005` → `0.5%`
///
/// 계산 근거를 보여줄 때 쓴다. 요율은 데이터가 준 값이고 여기서는 표기만 한다.
String formatRate(double rate) {
  final percent = rate * 100;
  final text = percent == percent.roundToDouble()
      ? percent.round().toString()
      : percent.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
  return '$text%';
}

/// `0.1` → `10분의 1` · `0.9` → `10분의 9` · 그 밖은 `×0.75` 그대로
///
/// 법령이 「10분의 9」로 적힌 것을 소수로 보여주면 조문과 대조가 안 된다.
String formatMultiplier(double multiply) {
  const tenths = 10;
  final scaled = multiply * tenths;
  if (scaled == scaled.roundToDouble() && scaled >= 1 && scaled < tenths) {
    return '$tenths분의 ${scaled.round()}';
  }
  return '$multiply';
}
