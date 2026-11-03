import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/json_logic.dart';

/// 아슬아슬하게 못 쓰게 된 절차 하나.
class NearMiss {
  const NearMiss({
    required this.procedureId,
    required this.label,
    required this.threshold,
    required this.actual,
  });

  final String procedureId;
  final String label;

  /// `showIf` 가 정한 경계. **코드에 적힌 값이 아니다.**
  final int threshold;

  /// 사용자의 실제 값.
  final int actual;

  /// 얼마나 넘었는가.
  int get excess => actual - threshold;
}

/// **경계를 아슬아슬하게 넘겨 못 쓰게 된 절차**를 찾는다.
///
/// 3,000만원과 3,000만 10원은 밟는 절차가 다르다. 인지대 몇 백 원보다 이게 훨씬
/// 크다. **1,500원 때문에 더 복잡한 절차로 가야 한다는 걸 모르고 진행하면 나중에
/// 되돌릴 수 없다.**
///
/// ## 경계값을 코드에 적지 않는다
///
/// 경계는 `showIf` 에서 읽는다. 얼마나 가까워야 가까운 것인지는
/// `nearMissWithin` 으로 **분야가 선언한다.** 둘 다 데이터라, 분야가 늘어도
/// 이 파일은 그대로다.
///
/// `nearMissWithin` 이 없으면 아무것도 알리지 않는다. **켜는 것이 선택이다** —
/// 모든 경계를 다 알리면 1억원 청구에도 "3,000만원을 7,000만원 넘었습니다" 가
/// 뜨고, 그건 도움이 아니라 소음이다.
class NearMissChecker {
  const NearMissChecker();

  /// `<=` · `<` 만 본다. 위쪽 경계를 넘어 탈락하는 경우만 다루기 때문이다.
  static const List<String> _upperBoundOps = ['<=', '<'];

  List<NearMiss> check(Domain domain, CaseFacts facts) {
    final data = facts.toJsonLogicData();
    final results = <NearMiss>[];

    for (final procedure in domain.procedures) {
      final within = procedure.nearMissWithin;
      final showIf = procedure.showIf;
      if (within == null || showIf == null) continue;

      final bound = _upperBound(showIf);
      if (bound == null) continue;

      // **값을 먼저 읽는다.** 답하지 않은 항목을 JsonLogic 에 넘기면 던진다.
      // 안 답한 것은 오류가 아니라 아직 모르는 것이다.
      final actual = facts.money(bound.field);
      if (actual == null) continue;

      // 이미 쓸 수 있는 절차는 알릴 것이 없다.
      if (JsonLogic.test(showIf, data)) continue;

      final excess = actual - bound.threshold;
      if (excess <= 0 || excess > within) continue;

      results.add(
        NearMiss(
          procedureId: procedure.id,
          label: procedure.label,
          threshold: bound.threshold,
          actual: actual,
        ),
      );
    }
    return results;
  }

  /// `{"<=": [{"var": "claimAmount"}, 30000000]}` 에서 필드와 경계를 뽑는다.
  ///
  /// 이 모양이 아니면 null 이다. **모르는 모양을 추측하지 않는다.**
  ///
  /// 다만 `and` 는 한 겹 벗긴다. 절차에 갈래 조건(「받을 쪽일 때만」)이 붙는
  /// 순간 경계가 `and` 안으로 들어가는데, 그걸 모르는 모양으로 보면 아슬아슬한
  /// 금액 안내가 **조용히 사라진다.** 안쪽에 경계가 하나일 때만 읽는다 —
  /// 둘이면 어느 쪽이 경계인지 우리가 고르게 되고, 그건 추측이다.
  static ({String field, int threshold})? _upperBound(JsonMap showIf) {
    if (showIf.length != 1) return null;
    final op = showIf.keys.first;
    if (op == 'and') {
      final args = showIf[op];
      if (args is! List) return null;
      final found = <({String field, int threshold})>[];
      for (final arg in args) {
        if (arg is! Map) continue;
        final bound = _upperBound(JsonMap.from(arg));
        if (bound != null) found.add(bound);
      }
      return found.length == 1 ? found.first : null;
    }
    if (!_upperBoundOps.contains(op)) return null;

    final args = showIf[op];
    if (args is! List || args.length != 2) return null;

    final left = args[0];
    if (left is! Map || left['var'] is! String) return null;
    final right = args[1];
    if (right is! num) return null;

    return (field: left['var'] as String, threshold: right.toInt());
  }
}
