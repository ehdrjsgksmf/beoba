import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/pinned_caution_card.dart';
import 'package:domain_data/domain_data.dart'
    show AlertDisplay, TimeUnit, VerificationStatus;
import 'package:engines/engines.dart' hide VerificationStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 두 번째 진짜 분야. **틀이 재사용되는지 보는 자리이기도 하다.**
///
/// 기한은 조문에 숫자가 하나뿐이라 **센다**. 시효는 갈래마다 달라서 안 셌다
/// (DECISIONS 107번) — 같은 원칙의 반대편이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const domainId = 'inheritance';

  /// 아신 날이 오늘 기준 [daysAgo] 일 전.
  Map<String, Object?> answers({int daysAgo = 10, String balance = 'unknown'}) {
    final known = const KstDate(2026, 8, 15).addDays(-daysAgo);
    return {
      'q_known_date': known,
      'q_estate_known': balance,
      'q_filer_count': 1,
      'q_deceased_address': '서울특별시 노원구',
    };
  }

  Future<ProviderContainer> openResult(
    WidgetTester tester, {
    Map<String, Object?>? seed,
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(container, domainId, answers: seed ?? answers());
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();
    return container;
  }

  group('기한 — 여기는 센다', () {
    test('아신 날부터 3월이고 월 단위로 돈다', () async {
      final container = await bootstrappedContainer();
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);
      final deadline = domain.deadlines.single;

      expect(deadline.basisField, 'knownDate');
      expect(deadline.offset.unit, TimeUnit.month);
      expect(deadline.offset.value, 3);

      // 제160조② — 기산일에 해당한 날의 전일.
      expect(
        CivilPeriod.statutoryEnd(
          const KstDate(2026, 8, 18),
          deadline.offset,
        ),
        const KstDate(2026, 11, 18),
      );
      // 제160조③ — 최종의 월에 해당일이 없으면 그 달의 말일.
      expect(
        CivilPeriod.statutoryEnd(
          const KstDate(2026, 1, 31),
          deadline.offset,
        ),
        const KstDate(2026, 4, 30),
      );
    });

    testWidgets('공휴일이면 밀린다', (tester) async {
      // 2026-05-02 + 3월 = 2026-08-02(일). 제161조가 다음 열리는 날로 민다.
      final container = await openResult(
        tester,
        seed: {...answers(), 'q_known_date': const KstDate(2026, 5, 2)},
      );
      final result = container.read(deadlineResultsProvider(domainId)).single;

      expect(result.statutoryDue, const KstDate(2026, 8, 2));
      expect(result.statutoryDue < result.dueDate, isTrue);
    });
  });

  group('갈래 셋 — 어느 것도 권하지 않는다', () {
    testWidgets('셋이 다 나온다', (tester) async {
      final container = await openResult(tester);
      final ids = container.read(cautionsProvider(domainId)).map((c) => c.id);

      expect(ids, containsAll([
        'ct_branch_nothing',
        'ct_branch_limited',
        'ct_branch_renounce',
      ]));
    });

    testWidgets('권유·단정하는 말이 화면에 없다', (tester) async {
      await openResult(tester);
      for (final banned in const [
        '낫습니다',
        '권해',
        '넘어갑니다',
        '손자',
        '장례비',
        '연장됩니다',
        '연장해 드립니다',
        '가족 전체가',
      ]) {
        expectNoScreenText(tester, banned);
      }
    });
  });

  group('계산 결과를 조건으로 쓴다', () {
    testWidgets('기한이 남았으면 연장 갈래만 뜬다', (tester) async {
      final container = await openResult(tester, seed: answers(daysAgo: 10));
      final ids = container.read(cautionsProvider(domainId)).map((c) => c.id);

      expect(ids, contains('ct_extend_period'));
      expect(ids, isNot(contains('ct_special_limited')));
      expect(
        container.read(proceduresProvider(domainId)).map((p) => p.id),
        contains('proc_extend'),
      );
    });

    testWidgets('기한이 지났으면 특별한정승인 갈래로 바뀐다', (tester) async {
      // **헛된 희망을 주지 않는다.** 이미 지난 사람에게 연장은 길이 아니다.
      final container = await openResult(tester, seed: answers(daysAgo: 200));
      final ids = container.read(cautionsProvider(domainId)).map((c) => c.id);

      expect(ids, contains('ct_special_limited'));
      expect(ids, isNot(contains('ct_extend_period')));
      expect(
        container.read(proceduresProvider(domainId)).map((p) => p.id),
        isNot(contains('proc_extend')),
      );
    });

    testWidgets('미성년이었다고 답해야 그 길이 보인다', (tester) async {
      final without = await openResult(tester);
      expect(
        without.read(cautionsProvider(domainId)).map((c) => c.id),
        isNot(contains('ct_was_minor')),
      );

      final with_ = await openResult(
        tester,
        seed: {...answers(daysAgo: 200), 'q_was_minor': 'yes'},
      );
      expect(
        with_.read(cautionsProvider(domainId)).map((c) => c.id),
        contains('ct_was_minor'),
      );
    });
  });

  group('★ 되돌릴 수 없는 것은 접지 않는다', () {
    testWidgets('통장 경고가 접히지 않고 맨 위에 뜬다', (tester) async {
      await openResult(tester);

      expect(find.byType(PinnedCautionCard), findsOneWidget);
      // 누르지 않아도 보인다.
      expectScreenText(tester, '돌아가신 분의 통장이나 물건에 손대기 전에');
      expectScreenText(tester, '상속재산을 처분하면 단순승인한 것으로 본다');
      // 근거도 접지 않는다.
      expect(find.text('민법 제1026조 제1호'), findsOneWidget);
      expectScreenText(tester, '상속인이 상속재산에 대한 처분행위를 한 때');
    });

    test('stop 은 이 하나뿐이다', () async {
      final container = await bootstrappedContainer();
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);
      final stops =
          domain.cautions.where((c) => c.display == AlertDisplay.stop);

      expect(stops.map((c) => c.id), ['ct_do_not_touch']);
    });
  });

  group('비용 — 신고하는 사람 수만큼', () {
    testWidgets('두 분이면 두 배다', (tester) async {
      // 인지 5,000 + 송달료 6회 × 5,500 = 38,000.
      final one = await openResult(tester);
      expect(one.read(costResultProvider(domainId)).total, 38000);

      final two = await openResult(
        tester,
        seed: {...answers(), 'q_filer_count': 2},
      );
      expect(two.read(costResultProvider(domainId)).total, 76000);
    });

    testWidgets('전자면 인지만 깎인다', (tester) async {
      // **송달료는 안 줄어든다.** 규칙 제8조는 수수료 이야기다.
      final container = await openResult(tester);
      final scenarios = container.read(costScenariosProvider(domainId));
      final byId = {for (final s in scenarios) s.id: s};

      expect(byId['cs_paper']!.result.total, 38000);
      expect(byId['cs_efiling']!.result.total, 37500);
    });

    test('송달료는 라류 6회다', () async {
      final container = await bootstrappedContainer();
      final fee = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .costs
          .firstWhere((c) => c.id == 'cost_service_fee');

      // **1회분 검수를 새로 만들지 않고 물려받았다.** 같은 값이 두 벌이 되면
      // 한쪽만 고쳐진다.
      expect(fee.verification.status, VerificationStatus.needsCheck);
      // **열린 것이 둘이고 성격이 다르다.** 하나로 뭉뚱그리면 어느 쪽이
      // 영영 안 닫히는지 모른다.
      final open = fee.verification.openPart ?? '';
      expect(open, contains('서류 무게'));
      expect(open, contains('「왕복」'));

      // 5,500원이 어디서 온 숫자인지 화면에서 볼 수 있다.
      final chips = fee.alsoBasis.map((b) => b.article ?? '').toList();
      expect(chips.where((a) => a.contains('[별표]')), hasLength(3));
    });

    test('전자 감액의 근거가 준용 조항이다', () async {
      // **제8조 제1항만 달면 틀린다.** 제1항은 소장 이야기이고 우리 사건은
      // 심판 청구다. 준용하는 것이 제2항이다.
      final container = await bootstrappedContainer();
      final cost = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .costs
          .firstWhere((c) => c.id == 'cost_filing_fee');

      final articles = cost.alsoBasis.map((b) => b.article);
      expect(articles, contains('제8조 제2항'));
      expect(articles, contains('제8조 제1항'));
    });
  });

  group('관할 — 이름을 낸다. 다만 아는 곳만', () {
    Future<String?> courtFor(WidgetTester tester, String address) async {
      final container = await openResult(
        tester,
        seed: {...answers(), 'q_deceased_address': address},
      );
      return container.read(jurisdictionResultsProvider(domainId)).single.court;
    }

    testWidgets('서울은 전체가 서울가정법원이다', (tester) async {
      // **가족관계등록 컬럼(6개 구)이 아니다.** 한정승인·포기는 가사비송이라
      // 왼쪽 컬럼 — 서울특별시 전체다. 6개 구로 넣으면 나머지 19개 구가 빈다.
      for (final address in const [
        '서울특별시 종로구',
        '서울특별시 노원구',
        '서울특별시 강서구',
      ]) {
        expect(await courtFor(tester, address), '서울가정법원', reason: address);
      }
    });

    testWidgets('지원까지 이름이 나온다', (tester) async {
      expect(await courtFor(tester, '충청남도 천안시'), '대전가정법원 천안지원');
      expect(await courtFor(tester, '경상북도 포항시'), '대구가정법원 포항지원');
      expect(await courtFor(tester, '경상남도 양산시'), '울산가정법원');
    });

    testWidgets('광주는 시·도가 있어야 갈린다', (tester) async {
      expect(await courtFor(tester, '광주광역시 서구'), '광주가정법원');
      expect(await courtFor(tester, '경기도 광주시'), '수원가정법원 성남지원');
      // **넘겨짚지 않는다.** 「광주시」만으로는 못 가른다.
      expect(await courtFor(tester, '광주시'), isNull);
    });

    testWidgets('2028년에 생기는 법원은 오늘 안 나온다', (tester) async {
      // 표에 이름이 있어도 시행일이 오늘 이후면 **없는 법원**이다.
      expect(await courtFor(tester, '전라북도 전주시'), isNull);
      expect(await courtFor(tester, '전라북도 군산시'), isNull);
    });

    testWidgets('표에 없는 곳은 비운다', (tester) async {
      // 인천은 [별표 1]에 법원이 있는데 [별표 5]에 관할구역이 없다.
      expect(await courtFor(tester, '인천광역시 남동구'), isNull);
      expect(await courtFor(tester, '경기도 부천시'), isNull);
      // 표에 아예 없는 곳도 비운다.
      expect(await courtFor(tester, '제주특별자치도 제주시'), isNull);
    });

    test('표가 말하지 않는 것을 따로 들고 있다', () async {
      final container = await bootstrappedContainer();
      final courts = container.read(domainBundleProvider).requireValue.courts;

      // [별표 3]에도 인천이 없다. 같은 이유로 이름을 내지 않는다.
      expect(courts.unmapped, [
        '인천가정법원',
        '인천가정법원 부천지원',
        '인천지방법원',
        '인천지방법원 부천지원',
      ]);
      expect(courts.notYetEffective, hasLength(4));
      expect(courts.notYetEffective.first, '전주가정법원');
    });
  });

  group('모르는 것은 모른다고 둔다', () {

    test('포기의 파급 범위는 열어 둔다', () async {
      final container = await bootstrappedContainer();
      final caution = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .cautions
          .firstWhere((c) => c.id == 'ct_renounce_ripple');

      expect(caution.verification.status, VerificationStatus.needsCheck);
      expect(caution.verification.openPart, '포기의 파급 범위');
      // 조문 넷을 옆에 둔다. 사람이 스스로 읽고 물어보러 갈 수 있게.
      expect(caution.alsoBasis, hasLength(3));
    });

    testWidgets('비용 줄은 둘뿐이다', (tester) async {
      final container = await openResult(tester);
      final ids =
          container.read(costResultProvider(domainId)).lines.map((l) => l.id);

      expect(ids, ['cost_filing_fee', 'cost_service_fee']);
    });
  });
}
