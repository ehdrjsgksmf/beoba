import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/layers/agency_layer.dart';
import 'package:beoba/src/layers/legal_layer.dart';
import 'package:domain_data/domain_data.dart';
import 'package:beoba/src/defense/broker_watch.dart';
import 'package:beoba/src/widgets/broker_alert_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('★ 카드가 선 자리 — 조문 · 기관 안내 · 아무것도 아님 (274)', () {
    const notice = AgencyNotice(
      agency: '국토교통부',
      checkedAt: KstDate(2026, 9, 16),
      dateScope: NoticeDateScope.visited,
      dataset: '전세사기피해자 지원 안내',
    );

    Caution card({AgencyNotice? notice, LegalBasis? basis, String? noBasis}) =>
        Caution(
          id: 'ct_x',
          condition: '이런 경우라면',
          consequence: '이렇게 돼요.',
          legalBasis: basis,
          notice: notice,
          noBasis: noBasis,
          verification: const Verification(
            status: VerificationStatus.verified,
            source: '시험',
            checkedAt: KstDate(2026, 9, 16),
            checkedBy: CheckedBy.self,
          ),
        );

    test('Caution 이 기관 안내를 들 수 있다 — 조문 자리를 대신한다', () {
      final c = card(notice: notice);
      expect(c.legalBasis, isNull);
      expect(c.notice, isNotNull);
      // 문장은 AgencyNotice 가 만든다. 카드가 조립하지 않는다.
      expect(c.notice!.sentence, contains('국토교통부'));
      expect(c.notice!.sentence, contains('법에 적힌 게 아니라'));
      expect(c.notice!.sentence, contains('2026-09-16'));
    });

    test('셋 다 없을 수도 있다 — 막는 것은 SchemaValidator 다', () {
      // 모델은 막지 않는다. 데이터가 들어올 때 걸러야 화면이 안 깨진다.
      expect(card().notice, isNull);
      expect(card(noBasis: '창구로 보내기만 한다').noBasis, isNotNull);
    });
  });

  group('네 번째 층 — 기관이 알려 준 것', () {
    test('세 층에 끼워 넣지 않았다. 조문이 아니기 때문이다', () {
      expect(LegalLayer.values, hasLength(3));
      expect(
        LegalLayer.values.map((layer) => layer.name).toList(),
        ['statute', 'likely', 'unknown'],
      );
    });

    test('출처 없이는 블록을 만들 수 없다', () {
      const block = AgencyBlock(
        id: 'WLF00000022',
        title: '(산재근로자)사회심리재활지원',
        notice: AgencyNotice(
          agency: '보건복지부',
          checkedAt: KstDate(2025, 7, 22),
          dateScope: NoticeDateScope.record,
          dataset: '복지서비스정보',
        ),
      );
      expect(
        block.disclosure,
        '법에 적힌 게 아니라 보건복지부에서 알려 준 내용이에요. 마지막 확인 2025-07-22.',
      );
    });

    test('★ 기관 페이지에 날짜가 없으면 우리가 본 날이라고 적는다', () {
      // 신용회복위원회 채무조정 안내에는 기관이 고친 날이 없다.
      // **없는 칸을 있는 척하지 않는다** — 우리가 본 날을 적고, 그것이
      // 우리 날짜라는 것도 함께 적는다.
      const notice = AgencyNotice(
        agency: '신용회복위원회',
        checkedAt: KstDate(2026, 8, 18),
        dateScope: NoticeDateScope.visited,
        dataset: '신용회복위원회 채무조정 안내',
      );
      expect(
        notice.sentence,
        '법에 적힌 게 아니라 신용회복위원회에서 알려 준 내용이에요. '
        '2026-08-18에 저희가 보고 옮겼어요.',
      );
    });

    test('자료 전체 기준일이면 그렇다고 적는다', () {
      const notice = AgencyNotice(
        agency: '삼성꿈장학재단',
        checkedAt: KstDate(2025, 11, 5),
        dateScope: NoticeDateScope.dataset,
        dataset: '민간복지서비스정보',
      );
      expect(
        notice.sentence,
        '법에 적힌 게 아니라 삼성꿈장학재단에서 알려 준 내용이에요. '
        '마지막 확인 2025-11-05 (자료 전체 기준).',
      );
    });
  });

  group('★ 조문이 아닌 금액에는 조문 딱지를 안 단다', () {
    test('신복위 신청비가 붙은 세 자리에 다 딱지가 있다', () async {
      final crisis = (await loadTestBundle()).crisis;

      final alert =
          crisis.brokerAlerts.firstWhere((a) => a.id == 'ba_ccrs_fee');
      final rule = crisis.limitRules.firstWhere((r) => r.id == 'lr_ccrs_fee');
      final channel = crisis.channelById('crisis_debt')!;

      for (final notice in [alert.notice, rule.notice, channel.notice]) {
        expect(notice, isNotNull, reason: '5만원이 딱지 없이 화면에 나갑니다');
        expect(notice!.agency, '신용회복위원회');
        expect(notice.dateScope, NoticeDateScope.visited);
      }

      // **조문 딱지는 없어야 한다.** 5만원은 법령이 아니다.
      expect(alert.legalBasis, isNull);
      expect(rule.legalBasis, isNull);
    });

    testWidgets('경보 카드에 그 한 줄이 함께 나온다', (tester) async {
      final alert = (await loadTestBundle())
          .crisis
          .brokerAlerts
          .firstWhere((a) => a.id == 'ba_ccrs_fee');

      await pumpWidgetOnly(tester, BrokerAlertCard(warning: BrokerWarning(alert: alert)));

      expectScreenText(tester, '법에 적힌 게 아니라 신용회복위원회에서 알려 준 내용이에요');
      expectScreenText(tester, '저희가 보고 옮겼어요');
    });
  });

  group('복지 자료를 앱 번들에서 읽는다', () {
    test('공공 · 민간 두 자료가 따로 실린다', () async {
      const source = AssetWelfareSource();
      final public = await source.loadPublic();
      final private = await source.loadPrivate();

      expect(public.services, isNotEmpty);
      expect(private.services, isNotEmpty);
      expect(public.dataset, '복지서비스정보');
      expect(private.dataset, '민간복지서비스정보');
      // 공공에는 축이 없다. 있는 척하지 않는다.
      // 물러난 뒤에 한 줄이 덧붙었다 — 덮은 것이 아니다(DECISIONS 235번).
      expect(public.openPart, contains('중앙부처 복지서비스 상세(지원대상·조건)'));
      expect(private.openPart, isNull);
    });

    test('중앙부처 자료도 따로 실린다', () async {
      final central = await const AssetWelfareSource().loadCentral();
      expect(central.services, isNotEmpty);
      expect(central.dataset, '중앙부처복지서비스');
      expect(central.openPart, contains('지자체'));
    });

    test('★ 어느 자료든 출처 딱지 없이는 한 건도 없다', () async {
      const source = AssetWelfareSource();
      final notices = <AgencyNotice>[
        for (final s in (await source.loadPublic()).services) s.notice,
        for (final s in (await source.loadPrivate()).services) s.notice,
        for (final s in (await source.loadCentral()).services) s.notice,
      ];
      expect(notices, isNotEmpty);
      for (final notice in notices) {
        expect(notice.agency, isNotEmpty);
        expect(notice.sentence, contains('법에 적힌 게 아니라'));
        expect(notice.sentence, contains('마지막 확인'));
      }
    });
  });
}
