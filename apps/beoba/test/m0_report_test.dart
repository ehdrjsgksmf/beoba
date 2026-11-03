import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter run` 이 콘솔에 찍는 내용 그대로를 검증한다.
///
/// 리포트 생성기는 engines 에 있고 `bin/m0_pipeline.dart` 와 같은 코드다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clock = FixedKstClock(KstDate(2026, 8, 15));

  test('엔진 리포트 — 5개 엔진 결과가 모두 실린다', () async {
    const source = AssetDomainSource();
    final loader = DomainLoader(today: clock.today());
    final debt = loader.loadFromJsonString(await source.read('debt_recovery'));
    final crisis = DomainLoader(today: clock.today())
        .loadFromJsonString(await source.read('_shared_crisis'));

    final report = buildEngineReport(
      domain: debt,
      crisis: crisis,
      clock: clock,
      loadReport: loader.lastReport,
      facts: const CaseFacts({
        // 받을 쪽 화면이다. 비용·서류·절차·관할은 이 갈래에만 열린다.
        'userRole': 'creditor',
        'claimType': 'loan',
        'claimAmount': 50000000, // not-a-legal-number: 데모 입력값
        'courtDocument': 'payment_order',
        'hasCourtDocument': true,
        'hasPaymentOrder': true,
        'paymentOrderServedDate': KstDate(2026, 8, 15),
        'procedure': 'payment_order',
        'useEfiling': true,
      }),
    );

    expect(report, contains('[제거]   없음'));
    expect(report, contains('[제거]   없음'));
    expect(report, contains('지급명령 이의신청  2026-08-31  D-16  critical'));
    expect(report, contains('민사소송법 제470조 제1항'));
    expect(report, contains('인지대 20,700원'));
    expect(report, contains('송달료 66,000원'));
    expect(report, contains('합계 86,700원'));
    expect(report, contains('계좌이체 내역'));
    expect(report, contains('조회표 미제공'));
    // 상한은 두 줄로 찍는다 — 무엇을 넣었는지 · 그래서 어떤 판정인지
    expect(report, contains('[상한]   대출 중개수수료'));
    expect(report, contains('→ alwaysIllegal · 법정 상한 0원'));
    expect(report, contains('다음 질문 q_due_date'));
    expect(report, contains('마음이 힘들 때 109'));
  });

  test('상한 입력은 필드명이 아니라 도메인 JSON 의 한글 라벨로 찍힌다', () async {
    const source = AssetDomainSource();
    final debt = DomainLoader(today: clock.today())
        .loadFromJsonString(await source.read('debt_recovery'));
    final crisis = DomainLoader(today: clock.today())
        .loadFromJsonString(await source.read('_shared_crisis'));

    final report = buildEngineReport(
      domain: debt,
      crisis: crisis,
      clock: clock,
      facts: const CaseFacts({
        // 받을 쪽 화면이다. 비용·서류·절차·관할은 이 갈래에만 열린다.
        'userRole': 'creditor',
        'transactionAmount': 150000000, // not-a-legal-number: 데모 입력값
        'dealType': 'lease',
        'requestedAmount': 900000, // not-a-legal-number: 데모 입력값
      }),
    );

    expect(report, contains('부동산 중개보수 · 거래금액 150,000,000원'));
    expect(report, contains('요구받은 금액 900,000원'));

    // 이자 상한은 시행령 숫자가 없어 계산을 뺐다. 입력을 받지 않으므로
    // 라벨 검사 대상에서도 빠진다 (DECISIONS 73번).

    // 필드명이 화면·리포트로 새어 나오면 라벨을 데이터에 둔 의미가 없다.
    expect(report, isNot(contains('transactionAmount')));
    expect(report, isNot(contains('requestedAmount')));
  });

  test('금액에 천 단위 구분이 들어간다', () {
    expect(formatWon(0), '0원');
    expect(formatWon(20700), '20,700원');
    expect(formatWon(1234567), '1,234,567원');
  });
}
