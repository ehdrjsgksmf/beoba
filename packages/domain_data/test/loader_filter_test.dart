import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

import 'support/domain_assets.dart';

void main() {
  group('DomainLoader — unverified 제거', () {
    late Domain domain;
    late LoadReport report;

    setUp(() {
      final loader = DomainLoader(today: const KstDate(2026, 8, 15));
      domain = loader.loadFromJsonString(readDomainJson('debt_recovery'));
      report = loader.lastReport;
    });

    test('unverified 기한은 UI 에 도달하지 못한다', () {
      expect(
        domain.deadlines.map((d) => d.id),
        ['dl_answer', 'dl_payment_order_objection', 'dl_appeal'],
      );
      // 소멸시효는 이제 기한이 아니라 갈래로 낸다(DECISIONS 107번).
      // 걷어낼 unverified 기한이 지금 데이터에는 없다.
      expect(domain.deadlineById('dl_statute_general'), isNull);
    });

    test('관할 규칙 둘이 살아 있다 — 검수됐기 때문', () {
      // 예전에는 unverified 라 로더가 걷어냈다. [별표 3]·[별표 7] 이
      // 들어오면서 검수된 규칙 둘로 바뀌었다(DECISIONS 139번).
      expect(
        domain.jurisdiction.map((r) => r.id),
        ['jr_city_county', 'jr_district'],
      );
      for (final rule in domain.jurisdiction) {
        expect(rule.verification.status, VerificationStatus.verified);
      }
    });

    test('needs_check 는 남는다 — 배지를 달아 보여줘야 하기 때문', () {
      expect(domain.costById('cost_service_fee'), isNotNull);
      expect(domain.documentById('doc_debtor_address'), isNotNull);
      expect(
        domain.costById('cost_service_fee')!.verification.status,
        VerificationStatus.needsCheck,
      );
    });

    test('무엇이 왜 빠졌는지 기록된다', () {
      // **지금 debt_recovery 에 걷힐 것이 없다.** 마지막 하나였던
      // jr_debtor_address 가 [별표 3]·[별표 7] 이 들어오면서 검수된 규칙
      // 둘로 바뀌었다(DECISIONS 139번).
      expect(report.removed, isEmpty);
      expect(report.removed.every((r) => r.reason == 'unverified'), isTrue);
    });

    test('제거로 끊긴 참조는 정리된다', () {
      final paymentOrder = domain.procedures
          .firstWhere((p) => p.id == 'proc_payment_order');
      expect(paymentOrder.deadlineRefs, ['dl_payment_order_objection']);
    });

    test('keepAll 은 아무것도 제거하지 않는다 — 골든 테스트 전용', () {
      final loader = DomainLoader(policy: VerificationPolicy.keepAll);
      final all = loader.loadFromJsonString(readDomainJson('debt_recovery'));
      expect(all.deadlines.length, 3);
      expect(all.jurisdiction.length, 2);
      expect(loader.lastReport.removed, isEmpty);
    });
  });

  group('DomainLoader — _shared_crisis', () {
    test('전 분야 공통 데이터가 그대로 로드된다', () {
      final loader = DomainLoader(today: const KstDate(2026, 8, 15));
      final shared = loader.loadFromJsonString(readDomainJson('_shared_crisis'));

      expect(shared.publicChannels, isNotEmpty);
      expect(shared.channelById('crisis_mental')?.phone, '109');
      expect(shared.channelById('crisis_mental')?.priority, isTrue);
      expect(shared.brokerAlerts.length, greaterThan(10));
      expect(shared.limitRules.map((r) => r.id), contains('lr_brokerage_fee'));
      expect(shared.autoTriggers.map((t) => t.id), contains('trg_mental'));
      expect(shared.phoneRiskRules.map((r) => r.id), contains('pr_internet'));
      expect(shared.hardStops.map((h) => h.id), contains('hs_criminal'));
      // **hs_court_document 는 내려갔다.** 막았던 상황이 정확히 우리가 셀 수
      // 있는 기한이 있는 상황이었다(DECISIONS 121번). debt_recovery 의
      // ct_court_document 로 옮겼고, 기한 아래에 온다.
      expect(
        shared.hardStops.map((h) => h.id),
        isNot(contains('hs_court_document')),
      );
    });

    test('publicChannels 는 문자열 참조와 객체를 모두 받는다', () {
      final loader = DomainLoader();
      final debt = loader.loadFromJsonString(readDomainJson('debt_recovery'));
      final shared = loader.loadFromJsonString(readDomainJson('_shared_crisis'));

      expect(debt.publicChannels, everyElement(isA<PublicChannelRef>()));
      expect(debt.publicChannels.map((c) => c.id), ['klac_132', 'helplaw24']);
      expect(shared.publicChannels, everyElement(isA<PublicChannelFull>()));
    });
  });

  group('전 도메인 로드', () {
    test('assets/domains 의 모든 파일이 로드된다', () {
      for (final file in domainAssetFiles()) {
        final loader = DomainLoader(today: const KstDate(2026, 8, 15));
        expect(
          () => loader.loadFromJsonString(file.readAsStringSync()),
          returnsNormally,
          reason: file.path,
        );
      }
    });
  });
}
