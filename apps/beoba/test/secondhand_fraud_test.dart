import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:engines/engines.dart' show KstDate, SafetyFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 중고로 샀는데 돈만 보내고 물건이 안 왔을 때.
///
/// ★ **함정이 넷이다.** 넷 다 「그렇게 하면 되는 줄 알았다」로 오는 자리라
/// 미리 접어 주고 대신 갈 길을 같은 화면에서 이어 준다.
const String kSecondhand = 'secondhand_fraud';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openQuestion(WidgetTester tester, String question) async {
    final head = find.text(question);
    expect(head, findsOneWidget, reason: '「$question」 물음이 없습니다');
    await tester.ensureVisible(head);
    await tester.pumpAndSettle();
    await tester.tap(head, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> openResult(
    WidgetTester tester,
    Map<String, Object?> answers,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    seedAnswers(container, kSecondhand, answers: answers);
    container.read(routerProvider).go(Routes.result(kSecondhand));
    await tester.pumpAndSettle();
    return container;
  }

  /// 앱을 거쳐 계좌로 보냈고 상대를 모른다. 가장 무거운 갈래다.
  const viaApp = {
    'q_seller_type': 'individual',
    'q_via_platform': 'platform',
    'q_payment': 'bank',
    'q_know_seller': 'no',
    'q_paid_date': KstDate(2026, 8, 1),
  };

  const direct = {
    'q_seller_type': 'individual',
    'q_via_platform': 'direct',
    'q_payment': 'bank',
    'q_know_seller': 'yes',
    'q_paid_date': KstDate(2026, 8, 1),
  };

  group('★★ 함정 1 — 개인에게는 청약철회가 없다', () {
    testWidgets('첫 화면에 펴 두고, 조문 셋을 나란히 놓는다', (tester) async {
      await openResult(tester, viaApp);

      final card = find.text('7일 안에 무를 수 있다고 알고 계셨다면');
      expect(card, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(780),
        reason: '「환불해 달라고 하면 되는 줄 알았다」로 오는 자리입니다',
      );
      expect(find.textContaining('통신판매를 업(業)으로 하는 자'), findsWidgets);
      expect(find.textContaining('이 조에 한정하여 소비자로 본다'), findsWidgets);
    });

    testWidgets('막다른 골목으로 두지 않는다 — 대신 갈 길이 같은 화면에 있다',
        (tester) async {
      await openResult(tester, viaApp);

      expect(find.text('고소는 어떻게 하나요?'), findsOneWidget);
      expect(find.text('상대를 모르면 아무것도 못 하나요?'), findsOneWidget);
      expect(find.text('앱에 연락처를 알려 달라고 하면 되나요?'), findsOneWidget);
    });
  });

  group('★★ 함정 2 — 지급정지는 이 길이 아닐 수 있다', () {
    testWidgets('법이 스스로 적어 둔 단서를 그대로 낸다', (tester) async {
      await openResult(tester, viaApp);
      await openQuestion(tester, '계좌를 막아 달라고 하면 되나요?');

      expect(
        find.textContaining('재화의 공급 또는 용역의 제공 등을 가장한 행위는 제외'),
        findsWidgets,
      );
    });

    testWidgets('★ 단정하지 않는다 — 판단은 신고를 받는 곳이 한다', (tester) async {
      await openResult(tester, viaApp);
      await openQuestion(tester, '계좌를 막아 달라고 하면 되나요?');

      // 「해당합니다」가 아니라 「해당해 보여요」다.
      expect(find.textContaining('해당해 보여요'), findsWidgets);
      expect(find.textContaining('해당합니다'), findsNothing);
    });
  });

  group('★★ 함정 3 — 동의가 없으면 안 준다', () {
    testWidgets('한정한다는 말과 남는 통로 둘을 함께 낸다', (tester) async {
      await openResult(tester, viaApp);
      await openQuestion(tester, '앱에 연락처를 알려 달라고 하면 되나요?');

      expect(find.textContaining('동의한 경우에 한정한다'), findsWidgets);
      // 기대를 접어 주고 대신 두 통로를 그 자리에서 보여준다.
      expect(find.textContaining('소비자피해 분쟁조정기구'), findsWidgets);
      expect(find.textContaining('민사소송법'), findsWidgets);
    });

    testWidgets('★ 기구 이름을 우리가 지어 쓰지 않는다', (tester) async {
      await openResult(tester, viaApp);
      await openQuestion(tester, '앱에 연락처를 알려 달라고 하면 되나요?');

      // 시행령 원문을 안 봤다. 조문이 쓰는 말 그대로만 적는다.
      for (final made in const ['소비자원', '분쟁조정위원회', '소비자단체']) {
        expect(find.textContaining(made), findsNothing, reason: made);
      }
    });

    testWidgets('직거래면 이 통로가 아예 안 뜬다', (tester) async {
      await openResult(tester, direct);

      // 제20조의4 는 통신판매중개업자의 의무다. 앱을 안 거쳤으면 안 붙는다.
      expect(find.text('앱에 연락처를 알려 달라고 하면 되나요?'), findsNothing);
      expect(find.text('중개하는 곳은 아무 책임이 없나요?'), findsNothing);
    });
  });

  group('★★ 함정 4 — 고소는 돈을 돌려받는 절차가 아니다', () {
    testWidgets('담담하게, 그리고 신청해야 알려 준다는 조문을 함께', (tester) async {
      await openResult(tester, viaApp);
      await openQuestion(tester, '고소하면 돈을 돌려받나요?');

      expect(find.textContaining('형사와 민사는 다른 길'), findsWidgets);
      expect(find.textContaining('신청이 있는 때에는'), findsWidgets);
    });

    testWidgets('★ 형량을 화면에 안 낸다', (tester) async {
      await openResult(tester, viaApp);
      await openQuestion(tester, '언제까지 고소할 수 있나요?');

      // 우리 앱은 벌을 얼마나 받는지 알려 주는 앱이 아니다.
      //
      // ★ 「징역」 자체는 막지 않는다 — 공소시효 조문이 「장기 10년 이상의
      //   징역 또는 금고」라고 쓰고 그 조문은 우리가 내는 것이다. 막는 것은
      //   **형량**이다.
      for (final word in const ['20년 이하', '5천만원 이하', '벌금에 처한다']) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '「$word」가 화면에 나왔습니다',
        );
      }
      expect(find.textContaining('장기 10년 이상'), findsWidgets);
    });
  });

  group('갈래 — 답이 달라지는 축만 묻는다', () {
    testWidgets('가게였으면 다른 화면으로 이어 준다', (tester) async {
      await openResult(tester, {...viaApp, 'q_seller_type': 'business'});

      expect(find.text('상대가 가게였다면요?'), findsOneWidget);
      // 개인 간 거래 카드는 안 뜬다.
      expect(find.text('7일 안에 무를 수 있다고 알고 계셨다면'), findsNothing);
    });

    testWidgets('상대를 알면 민사 길이, 모르면 법원 통로가 열린다', (tester) async {
      await openResult(tester, direct);
      expect(find.text('민사로는 어떤 길이 있나요?'), findsOneWidget);
      expect(find.text('상대를 모르면 아무것도 못 하나요?'), findsNothing);
    });
  });

  group('데이터 — 말과 다리', () {
    late DomainBundle bundle;

    setUpAll(() async {
      bundle = await loadTestBundle();
    });

    List<String> ourSentences() {
      final d = bundle.byId(kSecondhand);
      return [
        d.name,
        d.shortName ?? '',
        d.description ?? '',
        for (final c in d.cautions) ...[c.question, c.condition, c.consequence],
        for (final p in d.procedures) ...[p.label, p.whatIsThis, p.detail].nonNulls,
        for (final q in d.intake) ...[q.text, q.whyAsk],
        for (final r in d.limitationRules) ...[r.label, r.note].nonNulls,
      ];
    }

    test('★ 브랜드 이름이 우리 문장에 0번', () {
      // 특정 업체를 지목하는 순간 사실관계 위험이 생긴다.
      for (final sentence in ourSentences()) {
        for (final brand in const ['당근', '번개장터', '중고나라', '헬로마켓']) {
          expect(sentence.contains(brand), isFalse, reason: '「$sentence」');
        }
      }
    });

    test('★ 「사기꾼」·「범인」이 0번', () {
      for (final sentence in ourSentences()) {
        expect(sentence.contains('사기꾼'), isFalse, reason: '「$sentence」');
        expect(sentence.contains('범인'), isFalse, reason: '「$sentence」');
      }
    });

    test('★ 분야 키에는 fraud 가 있어도 보이는 이름에는 「사기」가 없다', () {
      final d = bundle.byId(kSecondhand);
      expect(d.id, 'secondhand_fraud');
      for (final shown in [d.name, d.shortName ?? '', d.description ?? '']) {
        expect(shown.contains('사기'), isFalse, reason: shown);
      }
      // 걸림말에도 안 넣었다.
      for (final term in d.searchTerms) {
        expect(term.contains('사기'), isFalse, reason: term);
      }
    });

    test('판정하는 말이 우리 문장에 없다', () {
      for (final sentence in ourSentences()) {
        expect(
          SafetyFilter.scan(sentence, where: kSecondhand),
          isEmpty,
          reason: '「$sentence」',
        );
      }
    });

    test('★ 시효는 두 축이고 우리가 고르지 않는다', () {
      final rules = bundle.byId(kSecondhand).limitationRules;
      expect(rules.map((r) => r.id), ['lm_tort_three', 'lm_tort_ten']);
      // 제3항(미성년자 성적 침해)은 이 분야와 무관해 안 낸다.
      for (final r in rules) {
        expect(r.note.contains('성년'), isFalse);
      }
    });

    test('★ 복지 다리를 안 놓았다 — 눌렀을 때 0건이 될 입구는 안 세운다', () {
      expect(bundle.byId(kSecondhand).welfareBridge, isNull);
    });

    test('앱 번들에 실려 있다', () {
      expect(AssetDomainSource.bundledDomainIds, contains(kSecondhand));
    });
  });
}
