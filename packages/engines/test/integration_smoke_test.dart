import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/asset_paths.dart';

/// M0 통합 확인.
///
/// 실제 도메인 JSON 을 로드해 5개 엔진을 전부 통과시킨다.
/// `apps/beoba/lib/main.dart` 가 콘솔에 찍는 것과 같은 시나리오다.
void main() {
  const clock = FixedKstClock(KstDate(2026, 8, 15));

  late Domain debt;
  late Domain shared;
  late LoadReport debtReport;

  setUp(() {
    final loader = DomainLoader(today: clock.today());
    debt = loader.loadFromJsonString(
      _read('debt_recovery'),
    );
    debtReport = loader.lastReport;
    shared = DomainLoader(today: clock.today())
        .loadFromJsonString(_read('_shared_crisis'));
  });

  /// 지급명령을 받은 사람. 5,000만원을 빌려줬고 전자소송으로 진행한다.
  const facts = CaseFacts({
    // 받을 쪽 화면이다. 비용·서류·절차·관할은 이제 이 갈래에만 열린다
    // (DECISIONS 122번).
    'userRole': 'creditor',
    'claimType': 'loan',
    'claimAmount': 50000000,
    'dueDate': KstDate(2020, 8, 15),
    'courtDocument': 'payment_order',
    'hasCourtDocument': true,
    'hasPaymentOrder': true,
    'paymentOrderServedDate': KstDate(2026, 8, 15),
    'procedure': 'payment_order',
    'useEfiling': true,
  });

  test('로드 — unverified 는 화면에 도달하지 못한다', () {
    // 소멸시효도 여기 있었는데, 이제 기한이 아니라 갈래로 낸다
    // (DECISIONS 107번). 값이 채워진 것이 아니라 다루는 자리가 바뀐 것이다.
    expect(debtReport.removed, isEmpty);
  });

  test('기한 — 지급명령 이의신청 2026-08-31 (D-16)', () {
    final results = const DeadlineEngine(clock).compute(debt, facts);
    expect(results, hasLength(1));

    final objection = results.single;
    expect(objection.id, 'dl_payment_order_objection');
    // 민법 157·159 로 센 말일은 2026-08-29(토)이고, 제161조가 월요일로 민다.
    // **사용자가 실제로 받는 날짜는 민 뒤의 날짜다.**
    expect(objection.statutoryDue, const KstDate(2026, 8, 29));
    expect(objection.dueDate, const KstDate(2026, 8, 31));
    expect(objection.rolledFrom, const KstDate(2026, 8, 29));
    expect(objection.dDay, 'D-16');
    expect(objection.severity, Severity.critical);
    expect(objection.basis.citation, '민사소송법 제470조 제1항');
    expect(objection.verification, VerificationStatus.verified);
  });

  test('비용 — 인지대 20,700원 + 송달료 66,000원 = 86,700원', () {
    final result = const CostEngine().compute(debt, facts);

    expect(result.lineById('cost_stamp_fee')!.amount, 20700);
    expect(
      result.lineById('cost_stamp_fee')!.appliedModifiers,
      ['mod_payment_order', 'mod_efiling'],
    );
    expect(result.lineById('cost_service_fee')!.amount, 66000);
    expect(result.total, 86700);
  });

  test('서류 — 조건에 맞는 것만 남는다', () {
    final documents = const DocumentEngine().compute(debt, facts);
    final ids = documents.map((d) => d.id).toList();

    expect(ids, contains('doc_transfer_record'));
    expect(ids, isNot(contains('doc_invoice'))); // 물품대금이 아니다
    // 내용증명은 **안 보냈어도 목록에 남는다.** 없어서 못 하는 것이 아니라
    // 아직 안 한 것이라 「지금 하실 수 있어요」가 붙는다. 목록에서 지우면
    // 지금 할 수 있는 일이 화면에서 사라진다.
    expect(ids, contains('doc_certified_mail'));
    // 이 시나리오는 보냈는지를 안 물었다. **안 물어본 것은 「모른다」다** —
    // 없다고 단정하면 「아직 안 보내셨어도 괜찮아요」가 틀린 말이 된다.
    expect(
      documents.firstWhere((d) => d.id == 'doc_certified_mail').have,
      DocumentHave.unknown,
    );
    expect(
      documents.first.importance,
      Importance.high,
      reason: '중요한 서류가 먼저 와야 한다',
    );
  });

  test('관할 — 조회표를 안 넘기면 이름을 못 낸다 (추측하지 않는다)', () {
    // 주소를 안다고 답해야 갈래가 열린다. 안 물어본 사람에게 「어느 법원」을
    // 묻지 않는다.
    expect(const JurisdictionEngine().compute(debt, facts), isEmpty);

    // 규칙은 둘 다 살아 있다. 다만 이 테스트는 표를 안 넘긴다.
    final results = const JurisdictionEngine().compute(
      debt,
      facts.merge({'knowsDebtorAddress': 'yes', 'debtorArea': '포천시'}),
    );
    expect(results, hasLength(2));
    for (final result in results) {
      expect(result.court, isNull, reason: '표 없이 이름을 냈습니다');
    }
  });

  test('상한 — 대출 중개수수료는 금액과 무관하게 위법', () {
    final results = const LimitChecker().checkAll(shared, facts);
    final brokerFee =
        results.firstWhere((r) => r.ruleId == 'lr_loan_broker_fee');

    expect(brokerFee.verdict, LimitVerdict.alwaysIllegal);
    expect(brokerFee.legalMax, 0);
    expect(brokerFee.action?.phone, '1332');
  });

  test('인터뷰 — 아직 물을 게 남았다', () {
    final state = const InterviewEngine().compute(debt, facts);

    expect(state.nextQuestion?.id, 'q_evidence_written');
    expect(state.readiness, Readiness.red);
    expect(state.missingRequiredFields, contains('writtenEvidence'));

    // 형사 하드스톱은 키워드 기반이다. 형사 단어를 쓴 적이 없으므로 발동하지 않는다.
    expect(state.triggeredHardStopIds, isEmpty);
  });

  test('법원 서류를 받았다는 사실만으로는 멈추지 않는다', () {
    // **막았던 그 상황에 우리가 셀 수 있는 기한이 있었다.** 차단이 먼저 와서
    // 지급명령 이의신청 2주를 통째로 가렸다(DECISIONS 121번).
    final triggered = const InterviewEngine().triggeredHardStops(shared, facts);
    expect(triggered, isEmpty);

    // 대신 stop 경고로 남았다. 기한 아래에 온다.
    final caution =
        debt.cautions.firstWhere((c) => c.id == 'ct_court_document');
    expect(caution.display, AlertDisplay.stop);
    expect(caution.checklist, hasLength(5));
  });

  test('지급명령을 받은 사람에게 2주가 실제로 나온다', () {
    // 이 한 줄이 없어서 못 봤다. 엔진에 값을 먹이는 테스트는 통과하는데
    // 사람은 화면에서 못 보고 있었다.
    final results = const DeadlineEngine(FixedKstClock(KstDate(2026, 8, 19)))
        .compute(debt, facts);
    final objection =
        results.firstWhere((r) => r.id == 'dl_payment_order_objection');

    // 조문대로는 8월 29일인데 토요일이라 다음 근무일로 밀린다(민법 제161조).
    expect(objection.statutoryDue, const KstDate(2026, 8, 29));
    expect(objection.dueDate, const KstDate(2026, 8, 31));
    expect(objection.severity, Severity.critical);
  });

  test('하드스톱 — 사용자가 쓴 형사 단어가 나오면 멈춘다', () {
    final criminal = facts.merge({'userNote': '사기죄로 고소하고 싶습니다'});

    // 자유 입력 필드라고 알려줘야 본다. 아무 문자열이나 훑지 않는다.
    expect(
      const InterviewEngine().triggeredHardStops(
        debt,
        criminal,
        extraTextFields: const {'userNote'},
      ),
      contains('hs_criminal_fraud'),
    );

    // 알려주지 않으면 보지 않는다 — 우리가 쓴 값이 사용자의 말로 둔갑하지 않는다.
    expect(
      const InterviewEngine().triggeredHardStops(debt, criminal),
      isEmpty,
    );
  });

  test('하드스톱 — 중독은 형사 차단이 아니라 위기 연결이다', () {
    // 마약을 쓴 사람은 피의자가 아니라 위기 대상이다. 도박장에서 잃은 사람도
    // 형사 사건이 아니라 중독이다. 차단이 이기면 연결처를 못 본다.
    // 픽스처에 hasCourtDocument 가 있어 필드 트리거는 따로 걸린다. 키워드만 본다.
    for (final text in ['마약 때문에 돈이 필요했습니다', '도박장에서 다 잃었어요']) {
      final crisis = facts.merge({'userNote': text});
      for (final domain in [debt, shared]) {
        expect(
          const InterviewEngine().triggeredHardStops(
            domain,
            crisis,
            extraTextFields: const {'userNote'},
          ),
          isNot(anyOf(contains('hs_criminal'), contains('hs_criminal_fraud'))),
          reason: '"$text" 가 ${domain.id} 에서 형사로 차단됐습니다',
        );
      }
    }
  });

  test('하드스톱 — 도박장 개장은 형사가 맞다', () {
    final opening = facts.merge({'userNote': '도박장을 운영했습니다'});
    expect(
      const InterviewEngine().triggeredHardStops(
        shared,
        opening,
        extraTextFields: const {'userNote'},
      ),
      contains('hs_criminal'),
    );
  });

  test('하드스톱 — 조사받 은 좁혀서 본다', () {
    // 부분일치라 "세무조사받" · "조사받은 적 없습니다" 까지 걸렸다.
    for (final text in ['세무조사받은 적이 있습니다', '조사받은 적 없습니다']) {
      final note = facts.merge({'userNote': text});
      expect(
        const InterviewEngine().triggeredHardStops(
          shared,
          note,
          extraTextFields: const {'userNote'},
        ),
        isNot(contains('hs_criminal')),
        reason: '"$text" 가 형사로 차단됐습니다',
      );
    }

    final police = facts.merge({'userNote': '경찰 조사를 받았습니다'});
    expect(
      const InterviewEngine().triggeredHardStops(
        shared,
        police,
        extraTextFields: const {'userNote'},
      ),
      contains('hs_criminal'),
    );
  });

  test('문구 — 도메인 전체가 SafetyFilter 를 통과한다', () {
    const validator = ContentValidator();
    expect(validator.validate(debt), isEmpty);
    expect(validator.validate(shared), isEmpty);
  });

  test('위기 창구 — 전화번호가 그대로 실려 있다', () {
    expect(shared.channelById('crisis_mental')?.phone, '109');
    expect(shared.channelById('klac_132')?.phone, '132');
    expect(
      shared.publicChannels
          .whereType<PublicChannelFull>()
          .where((c) => c.channel.priority)
          .map((c) => c.id),
      ['crisis_mental'],
    );
  });
}

String _read(String domainId) {
  for (final file in domainAssetFiles()) {
    if (domainIdOf(file) == domainId) return file.readAsStringSync();
  }
  throw StateError('$domainId.json 을 찾지 못했습니다');
}
