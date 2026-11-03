import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

import '../format/formatters.dart';
import 'legal_layer.dart';

/// 엔진 결과를 3층 블록으로 옮긴다.
///
/// **분야 어휘를 모른다.** `DeadlineResult` · `CostLine` 이 들고 있는 것만 읽는다.
/// 순수 Dart 라 Flutter 없이 테스트할 수 있다.
class LayerAssembler {
  const LayerAssembler();

  LayerBlocks assemble({
    required Domain domain,
    required CaseFacts facts,
    required List<DeadlineResult> deadlines,
    required CostResult costs,
    required InterviewState interview,
  }) {
    final green = <GreenBlock>[];
    final yellow = <YellowBlock>[];

    // 기간을 세는 법(민법 157·159·160·161)은 **여기 넣지 않는다.**
    //
    // 넣었더니 3층 맨 위를 조문 네 줄이 차지하고, 정작 이 사건의 🟢 이 아래로
    // 밀렸다. 결과를 보러 온 사람이 알고 싶은 것은 「언제까지 뭘 해야 하나」이지
    // 「기간은 어떻게 세는가」가 아니다.
    //
    // 그 조문들은 상세 화면 아래쪽 `PeriodRuleSection` 이 맡는다. 기한 카드의
    // 「이 날짜는 어떻게 셌나요?」 가 거기로 데려간다.
    for (final deadline in deadlines) {
      final text = deadline.basis.text;
      final citation = deadline.basis.citation;
      // 조문 원문이 없으면 🟢 가 아니다. 인용할 것이 없는데 "법에 있는 내용" 이라고
      // 적을 수는 없다. 🟢 가 없으면 그에 딸린 🟡 도 만들지 않는다.
      if (text == null || text.isEmpty || citation == null) continue;

      final id = 'dl_${deadline.id}';
      green.add(
        GreenBlock(
          id: id,
          title: citation,
          basis: deadline.basis,
          quotedText: text,
        ),
      );

      final basisDate = _basisDateOf(domain, deadline.id, facts);
      if (basisDate == null) continue;

      // 기산일이 어림이면 기한도 범위다. **거기서 하나를 고르면 앱이 사실을 만든다.**
      yellow.add(
        YellowBlock(
          greenRefId: id,
          condition: _ifSo(
            basisDate.isExact
                ? '「${deadline.label}」의 기산일이 ${formatApproxDate(basisDate)}'
                : '「${deadline.label}」의 기산일이 ${formatApproxDate(basisDate)} 중 어느 날',
          ),
          consequence: deadline.isApproximate
              ? '기한은 ${formatDateRange(deadline.dueDate, deadline.dueDateLatest)}'
                  ' 사이입니다. 가장 이른 ${formatKstDateShort(deadline.dueDate)}'
                  ' (${formatDDay(deadline)}) 을 기준으로 보세요'
              : '기한은 ${formatKstDate(deadline.dueDate)}'
                  ' (${formatDDay(deadline)}) 입니다',
        ),
      );
    }

    for (final line in costs.lines) {
      final basis = line.basis;
      final text = basis?.text;
      final citation = basis?.citation;
      if (basis == null || text == null || text.isEmpty || citation == null) {
        continue;
      }

      // 🟢 만 만든다. **금액에는 🟡 를 달지 않는다.**
      //
      // 두 가지가 걸렸다. 하나는 문장이었다 — 「입력하신 내용이 그대로라면,
      // 인지대은 5,000원으로 계산됩니다」에서 조건절은 당연한 말이고 조사는
      // 틀렸다. 사용자가 적은 것이 사실이라는 전제를 매번 말하면 앱이 자기
      // 방어를 하는 것처럼 읽히고 정작 읽어야 할 숫자가 뒤로 밀린다.
      //
      // 더 나쁜 것은 숫자였다. 여기 오는 `costs` 는 갈래를 안 정한 채 계산한
      // 한 벌이라 **소장·종이 금액**이다. 지급명령·전자소송의 11배를 「이 사건의
      // 금액」인 양 적고 있었다 (DECISIONS 75). 갈래별 금액은 요약의 비용
      // 카드가 나란히 낸다. 여기서는 근거 조문만 든다.
      green.add(
        GreenBlock(
          id: 'cost_${line.id}',
          title: citation,
          basis: basis,
          quotedText: text,
        ),
      );
    }

    return LayerBlocks(
      green: green,
      yellow: yellow,
      red: _red(domain, interview),
    );
  }

  /// 사실 한 조각을 조건절로 맺는다 — `…8월 15일` → `…8월 15일이라면`.
  ///
  /// 어미가 붙는 자리가 여기 하나뿐이다. 화면은 붙이지 않는다.
  /// `이라/라` 는 앞말의 받침을 보고 갈린다 (`Josa`).
  static String _ifSo(String fact) => '${withJosa(fact, Josa.called)}면';

  /// 아직 답하지 못한 필수 항목 → 되돌아갈 질문.
  List<RedBlock> _red(Domain domain, InterviewState interview) {
    final byField = <String, Question>{
      for (final question in domain.intake) question.field: question,
    };

    final blocks = <RedBlock>[];
    for (final field in interview.missingRequiredFields) {
      final question = byField[field];
      if (question == null) continue;
      blocks.add(
        RedBlock(
          label: question.text,
          questionId: question.id,
          field: field,
        ),
      );
    }
    return blocks;
  }

  /// 기한의 기산일. 엔진이 쓴 것과 같은 필드를 본다.
  ///
  /// `calcRule` 별 계산은 엔진이 이미 했다. 여기서는 **표시할 날짜만** 꺼낸다.
  ApproxDate? _basisDateOf(Domain domain, String deadlineId, CaseFacts facts) {
    final deadline = domain.deadlineById(deadlineId);
    if (deadline == null) return null;

    final known = deadline.knownDateField;
    if (known != null) {
      final date = facts.approxDate(known);
      if (date != null) return date;
    }
    return facts.approxDate(deadline.basisField);
  }
}
