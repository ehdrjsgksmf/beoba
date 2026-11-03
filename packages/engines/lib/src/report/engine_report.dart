import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/kst_clock.dart';
import '../cost/cost_engine.dart';
import '../deadline/deadline_engine.dart';
import '../document/document_engine.dart';
import '../interview/interview_engine.dart';
import '../jurisdiction/jurisdiction_engine.dart';
import '../limit/limit_checker.dart';

/// 도메인 하나를 모든 엔진에 통과시켜 사람이 읽을 수 있는 요약을 만든다.
///
/// 화면이 없는 M0 의 확인 수단이고, 이후에도 디버깅에 쓴다.
/// 분야를 알지 못한다 — 어떤 도메인을 넣어도 같은 형식으로 찍는다.
String buildEngineReport({
  required Domain domain,
  required CaseFacts facts,
  required KstClock clock,

  /// ① 위기 · ② 방어 데이터(`_shared_crisis`). 있으면 상한·창구도 함께 본다.
  Domain? crisis,

  /// 로더가 무엇을 제거했는지.
  LoadReport? loadReport,
}) {
  final out = StringBuffer()
    ..writeln('━━━ 버바 엔진 리포트 (${clock.today().toIso()}) ━━━')
    ..writeln('[로드]   ${domain.name} v${domain.version} · '
        '${domain.status.name} · 검수 ${domain.lastVerifiedAt?.toIso() ?? '미상'}');

  if (loadReport != null) {
    if (loadReport.removed.isEmpty) {
      out.writeln('[제거]   없음');
    } else {
      for (final removed in loadReport.removed) {
        out.writeln('[제거]   ${removed.list}.${removed.id} — ${removed.reason}');
      }
    }
    out.writeln('[검증]   스키마 통과 · 경고 ${loadReport.warnings.length}건');
    for (final warning in loadReport.warnings) {
      out.writeln('         🟡 ${warning.path} — ${warning.message}');
    }
  }

  final deadlines = DeadlineEngine(clock).compute(domain, facts);
  if (deadlines.isEmpty) {
    out.writeln('[기한]   (해당 없음)');
  }
  for (final deadline in deadlines) {
    out.writeln(
      '[기한]   ${deadline.label}  ${deadline.dueDate.toIso()}  '
      '${deadline.dDay}  ${deadline.severity.name}  '
      '${deadline.basis.citation ?? ''}'
      '${deadline.verification == VerificationStatus.needsCheck ? '  🟡' : ''}',
    );
  }

  final costs = const CostEngine().compute(domain, facts);
  for (final line in costs.lines) {
    final modifiers = line.appliedModifiers.isEmpty
        ? ''
        : ' (${line.appliedModifiers.join(', ')})';
    out.writeln(
      '[비용]   ${line.label} ${formatWon(line.amount)}$modifiers'
      '${line.verification == VerificationStatus.needsCheck ? '  🟡' : ''}',
    );
  }
  out.writeln('[비용]   합계 ${formatWon(costs.total)}');

  final documents = const DocumentEngine().compute(domain, facts);
  out.writeln('[서류]   ${documents.map((d) => d.label).join(' · ')}');

  final jurisdiction = const JurisdictionEngine().compute(domain, facts);
  out.writeln(
    '[관할]   ${jurisdiction.isEmpty ? '(규칙 없음 — 조회표 미제공)' : jurisdiction.join(' · ')}',
  );

  final limitSource = crisis ?? domain;
  for (final limit in const LimitChecker().checkAll(limitSource, facts)) {
    // 무엇을 넣어서 이 답이 나왔는지 함께 찍는다. 입력이 안 보이면 검산할 수 없다.
    final labels = _inputLabels(limitSource, limit.ruleId);
    final inputs = limit.inputs.entries
        .map((entry) =>
            '${labels[entry.key] ?? entry.key} ${_formatInputValue(entry.value)}')
        .join(' · ');
    out.writeln(
      '[상한]   ${limit.label}${inputs.isEmpty ? ' · (입력 없음)' : ' · $inputs'}',
    );

    final verdictParts = <String>[
      limit.verdict.name,
      if (limit.legalMax != null) '법정 상한 ${formatWon(limit.legalMax!)}',
      if (limit.excess != null && limit.excess! > 0)
        '초과 ${formatWon(limit.excess!)}',
    ];
    out.writeln(
      '         → ${verdictParts.join(' · ')}${limit.isProblem ? '  ⚠️' : ''}',
    );
    if (limit.message.isNotEmpty) {
      out.writeln('           ${limit.message}');
    }
  }

  final interview = const InterviewEngine().compute(domain, facts);
  out.writeln(
    '[인터뷰] ${interview.readiness.name} · 점수 ${interview.score}/${interview.maxScore} · '
    '다음 질문 ${interview.nextQuestion?.id ?? '없음'}',
  );
  if (interview.missingRequiredFields.isNotEmpty) {
    out.writeln('         빠진 필수 항목 ${interview.missingRequiredFields.length}개: '
        '${interview.missingRequiredFields.join(', ')}');
  }
  for (final hardStop in interview.triggeredHardStopIds) {
    out.writeln('[정지]   $hardStop');
  }

  if (crisis != null) {
    final priority = crisis.publicChannels
        .whereType<PublicChannelFull>()
        .where((entry) => entry.channel.priority)
        .map((entry) => '${entry.channel.label} ${entry.channel.phone}');
    if (priority.isNotEmpty) {
      out.writeln('[위기]   ${priority.join(' · ')}');
    }
  }

  return out.toString();
}

/// 상한 규칙의 `필드명 → 한글 라벨` 표. 규칙이 없거나 라벨이 없으면 빈 맵.
///
/// 엔진은 라벨을 **만들지 않는다.** 도메인 JSON 이 준 것을 그대로 읽을 뿐이다
/// (CONTRIBUTING.md 규칙 9). 라벨이 없는 필드는 호출부에서 필드명으로 폴백한다.
Map<String, String> _inputLabels(Domain source, String ruleId) {
  for (final rule in source.limitRules) {
    if (rule.id != ruleId) continue;
    return {for (final input in rule.inputs) input.field: input.label};
  }
  return const {};
}

/// 입력값을 사람이 읽을 수 있게 편다.
String _formatInputValue(Object? value) => switch (value) {
      final int amount => formatWon(amount),
      final double rate => _formatRate(rate),
      null => '(없음)',
      _ => '$value',
    };

/// `0.24` → `24%`, `0.245` → `24.5%`
String _formatRate(double rate) {
  final percent = rate * 100;
  final text = percent == percent.roundToDouble()
      ? percent.round().toString()
      : percent.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return '$text%';
}

/// 한자어 숫자. `5` → `오`
const List<String> _sinoDigits = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

/// 네 자리 안의 자리 이름.
const List<String> _sinoPlaces = ['', '십', '백', '천'];

/// 네 자리씩 끊는 큰 단위.
const List<String> _sinoGroups = ['', '만', '억', '조'];

/// 한국어는 네 자리씩 끊어 읽는다. 금액이 아니라 **말의 규칙**이다.
const int _sinoGroupSize = 10000; // not-a-legal-number: 한국어 자릿수

/// `50000000` → `오천만원` · `1234567` → `백이십삼만 사천오백육십칠원`
///
/// **오타를 눈으로 잡으라고 있는 것이다.** 만원 칸에 `50000` 을 넣으면 5억원인데,
/// 숫자만 보면 0 개수를 세어야 안다. 소리 내어 읽어 주면 바로 안다.
///
/// 관용을 따른다 — `10000` 은 `일만원` 이 아니라 `만원` 이고, 네 자리 안에서도
/// `1000` 은 `일천` 이 아니라 `천` 이다. 다만 억·조는 `일억` · `일조` 로 남긴다.
String formatWonKorean(int amount) {
  if (amount == 0) return '영원';

  final sign = amount < 0 ? '-' : '';
  var rest = amount.abs();
  final parts = <String>[];

  for (var group = 0; rest > 0; group++) {
    final chunk = rest % _sinoGroupSize;
    rest ~/= _sinoGroupSize;
    if (chunk == 0) continue;
    if (group >= _sinoGroups.length) return '$sign${formatWon(amount)}';

    final buffer = StringBuffer();
    for (var place = 3; place >= 0; place--) {
      final digit = chunk ~/ _pow10(place) % 10;
      if (digit == 0) continue;
      // 십·백·천 앞의 `일` 은 읽지 않는다. `일십이` 가 아니라 `십이`.
      if (!(digit == 1 && place > 0)) buffer.write(_sinoDigits[digit]);
      buffer.write(_sinoPlaces[place]);
    }
    // `만` 도 같다 — `일만원` 이라고 하지 않는다. 억·조는 `일억` 으로 읽는다.
    final unit = _sinoGroups[group];
    final head = group == 1 && chunk == 1 ? '' : buffer.toString();
    parts.add('$head$unit');
  }

  return '$sign${parts.reversed.join(' ')}원';
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}

/// `1234567` → `1,234,567원`
String formatWon(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer원';
}
