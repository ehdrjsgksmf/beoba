import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

import 'support/domain_assets.dart';

/// 로드가 끝난 도메인은 **바뀌지 않는다.**
///
/// freezed 의 방어적 복사를 끈 상태(`DECISIONS.md` 1번)라 생성자만으로는
/// 불변이 보장되지 않는다. 로더가 잠근다.
void main() {
  late Domain domain;
  late Domain shared;

  setUp(() {
    domain = DomainLoader(today: const KstDate(2026, 8, 15))
        .loadFromJsonString(readDomainJson('debt_recovery'));
    shared = DomainLoader(today: const KstDate(2026, 8, 15))
        .loadFromJsonString(readDomainJson('_shared_crisis'));
  });

  group('최상위 목록을 바꿀 수 없다', () {
    test('기한 목록', () {
      expect(() => domain.deadlines.clear(), throwsUnsupportedError);
    });

    test('비용 · 서류 · 절차 목록', () {
      expect(() => domain.costs.removeAt(0), throwsUnsupportedError);
      expect(() => domain.documents.clear(), throwsUnsupportedError);
      expect(() => domain.procedures.clear(), throwsUnsupportedError);
    });

    test('질문 목록', () {
      expect(() => domain.intake.clear(), throwsUnsupportedError);
    });

    test('창구 · 경보 · 상한 목록', () {
      expect(() => shared.publicChannels.clear(), throwsUnsupportedError);
      expect(() => shared.brokerAlerts.clear(), throwsUnsupportedError);
      expect(() => shared.limitRules.clear(), throwsUnsupportedError);
      expect(() => shared.hardStops.clear(), throwsUnsupportedError);
    });
  });

  group('항목 안의 목록도 바꿀 수 없다', () {
    test('안내의 갈래', () {
      final deposit = DomainLoader(today: const KstDate(2026, 8, 15))
          .loadFromJsonString(readDomainJson('deposit_return'));
      final caution =
          deposit.cautions.firstWhere((c) => c.id == 'ct_small_deposit');
      expect(caution.variants, hasLength(4));
      expect(() => caution.variants.clear(), throwsUnsupportedError);
    });

    test('질문의 선택지', () {
      final question = domain.questionById('q_claim_type')!;
      expect(
        () => question.options.add(
          const QuestionOption(value: 'x', label: 'x'),
        ),
        throwsUnsupportedError,
      );
    });

    test('기한의 알림 시점과 정답지', () {
      final deadline = domain.deadlines.first;
      expect(() => deadline.notify.clear(), throwsUnsupportedError);
      expect(() => deadline.tests.clear(), throwsUnsupportedError);
    });

    test('비용의 modifier 체인', () {
      final cost = domain.costById('cost_stamp_fee')!;
      expect(() => cost.modifiers.clear(), throwsUnsupportedError);
      expect(() => cost.tests.clear(), throwsUnsupportedError);
    });

    test('절차의 참조 목록', () {
      final procedure =
          domain.procedures.firstWhere((p) => p.id == 'proc_payment_order');
      expect(() => procedure.costRefs.clear(), throwsUnsupportedError);
      expect(() => procedure.deadlineRefs.clear(), throwsUnsupportedError);
      expect(() => procedure.documentRefs.clear(), throwsUnsupportedError);
      expect(() => procedure.officialLinks.clear(), throwsUnsupportedError);
    });

    test('하드스톱의 키워드와 창구', () {
      final hardStop = shared.hardStops.firstWhere((h) => h.id == 'hs_criminal');
      expect(() => hardStop.channels.clear(), throwsUnsupportedError);
    });

    test('멈춤 안내의 체크리스트와 창구', () {
      // 하드스톱에서 내려온 목록이다. 화면이 들고 다니다 한 줄을 빼면
      // 종이에서 확인할 것이 조용히 사라진다.
      final caution =
          domain.cautions.firstWhere((c) => c.id == 'ct_court_document');
      expect(caution.checklist, hasLength(5));
      expect(() => caution.checklist.clear(), throwsUnsupportedError);
      expect(() => caution.channels.clear(), throwsUnsupportedError);
    });

    test('안내와 경보의 근거 목록', () {
      // 근거가 둘 이상인 자리다. 화면이 들고 다니다 하나를 빼면 숫자의 출처가
      // 사라지는데, 그게 지워졌다는 사실은 아무 데도 안 남는다.
      final caution = domain.cautions
          .firstWhere((c) => c.id == 'ct_loan_contract_void_creditor');
      expect(() => caution.alsoBasis.clear(), throwsUnsupportedError);
      expect(() => caution.channels.clear(), throwsUnsupportedError);

      final alert =
          domain.brokerAlerts.firstWhere((a) => a.id == 'ba_debt_collection');
      expect(() => alert.alsoBasis.clear(), throwsUnsupportedError);
    });

    test('자동 트리거의 패턴', () {
      final trigger = shared.autoTriggers.first;
      expect(() => trigger.patterns.clear(), throwsUnsupportedError);
      expect(() => trigger.show.clear(), throwsUnsupportedError);
    });
  });

  group('법률 수치가 담긴 구간표를 바꿀 수 없다', () {
    test('인지대 구간표', () {
      final formula = domain.costById('cost_stamp_fee')!.formula;
      expect(
        () => (formula as TieredCostFormula).tiers.clear(),
        throwsUnsupportedError,
      );
    });

    test('중개보수 구간표 (거래유형별)', () {
      final formula = shared.limitRules
          .firstWhere((r) => r.id == 'lr_brokerage_fee')
          .formula! as TieredWithCapLimitFormula;
      expect(() => formula.variants.clear(), throwsUnsupportedError);
      expect(() => formula.variants['lease']!.clear(), throwsUnsupportedError);
    });

    test('상한 규칙의 입력 목록', () {
      final inputs = shared.limitRules
          .firstWhere((r) => r.id == 'lr_brokerage_fee')
          .inputs;
      expect(inputs, isA<List<LimitInput>>());
      expect(inputs.clear, throwsUnsupportedError);
    });

    test('중개보수 거래유형표', () {
      final formula = shared.limitRules
          .firstWhere((r) => r.id == 'lr_brokerage_fee')
          .formula! as TieredWithCapLimitFormula;
      expect(formula.variants.clear, throwsUnsupportedError);
    });

    test('하드스톱 키워드', () {
      final trigger = shared.hardStops
          .firstWhere((h) => h.id == 'hs_criminal')
          .trigger as KeywordHardStopTrigger;
      expect(() => trigger.patterns.clear(), throwsUnsupportedError);
    });
  });
}
