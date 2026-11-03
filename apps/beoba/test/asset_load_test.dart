import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 번들에서 도메인 JSON 이 실제로 잡히는지 확인한다.
///
/// 파일은 `domain_data` 패키지가 소유하고 앱은 package asset 경로로 읽는다.
/// 이 테스트가 깨지면 경로 설정이 틀린 것이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('package asset 경로로 도메인 JSON 을 읽는다', () async {
    const source = AssetDomainSource();
    final raw = await source.read('debt_recovery');
    expect(raw, contains('"id": "debt_recovery"'));
  });

  test('읽은 JSON 이 그대로 로드·계산까지 간다', () async {
    const source = AssetDomainSource();
    const clock = FixedKstClock(KstDate(2026, 8, 15));

    final domain = DomainLoader(today: clock.today())
        .loadFromJsonString(await source.read('debt_recovery'));

    final costs = const CostEngine().compute(
      domain,
      const CaseFacts({
        // 받을 쪽 화면이다. 비용·서류·절차·관할은 이 갈래에만 열린다.
        'userRole': 'creditor',
        'claimAmount': 50000000,
        'procedure': 'payment_order',
        'useEfiling': true,
      }),
    );
    expect(costs.lineById('cost_stamp_fee')!.amount, 20700);
  });

  test('번들에 들어 있는 모든 도메인이 읽힌다', () async {
    const source = AssetDomainSource();
    for (final id in await source.list()) {
      expect(await source.read(id), isNotEmpty, reason: id);
    }
  });
}
