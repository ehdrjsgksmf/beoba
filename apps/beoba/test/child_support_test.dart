import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/result/sections/pinned_caution_card.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show SafetyFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 양육비를 못 받고 있을 때.
///
/// ★★ **이 분야에서 가장 위험한 오독은 「집행권원이 없으면 아무것도 못 한다」다.**
/// 제2조 제2호가 「양육비 채무」를 집행권원이 있는 것으로 정의하는데, 제11조
/// 제1항이 **없는 사람의 길을 따로** 두고 있다. 조문은 「못 한다」고 말하지
/// 않는다. 조각이 데이터에 있는 것만으로는 모자라서 **화면까지** 본다 —
/// 펼쳐진 카드 안에 둘이 다 오는지, 접혀 있지는 않은지.
const String kChildSupport = 'child_support';

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
    seedAnswers(container, kChildSupport, answers: answers);
    container.read(routerProvider).go(Routes.result(kChildSupport));
    await tester.pumpAndSettle();
    return container;
  }

  /// 갈래를 하나씩 갈아 끼운다. 기본은 **가장 무거운 갈래**다.
  Map<String, Object?> answers({
    String orderKind = 'judgment',
    String canTalk = 'no',
    String whereKnown = 'no',
    String incomeKind = 'salary',
    String courtOrder = 'enforce',
  }) =>
      {
        'q_order_kind': orderKind,
        'q_talk': canTalk,
        'q_where_known': whereKnown,
        'q_income_kind': incomeKind,
        'q_court_order': courtOrder,
      };

  const noTitleCondition = '양육비를 얼마씩 줄지 정한 서류가 아직 없다면';
  const noTitleHead = '정해 놓은 서류가 없으면 못 하나요?';
  const haveTitleHead = '서류가 있으면 무엇을 할 수 있나요?';
  const licenseHead = '운전면허를 정지시킬 수 있나요?';
  const travelBanHead = '나라 밖으로 못 나가게 할 수 있나요?';
  const disclosureHead = '이름을 공개할 수 있나요?';
  const orderHead = '셋 중에 어느 것부터 해야 하나요?';
  const detentionHead = '가둘 수도 있나요?';
  const prepayHead = '나라가 먼저 줄 수도 있나요?';
  const howLongHead = '얼마나 못 받아야 하나요?';

  group('★★ 「집행권원이 없으면 아무것도 못 한다」로 읽히면 안 된다', () {
    testWidgets('서류가 없어도 펼쳐진 카드가 먼저 온다', (tester) async {
      await openResult(tester, answers(orderKind: 'none'));

      // **펼친 카드는 물음 머리를 안 그린다.** 접혀 있으면 안 누른 분이
      // 그대로 돌아간다.
      expect(find.text(noTitleCondition), findsOneWidget);
      expect(find.text(noTitleHead), findsNothing);
    });

    testWidgets('★ 두 조문이 같은 카드 안에 온다', (tester) async {
      await openResult(tester, answers(orderKind: 'none'));

      // 펼쳐진 카드가 둘이다(선지급도 편다). **그 조각들이 흩어지지 않고
      // 한 카드 안에 있는지**를 보려는 것이므로 조건절로 그 카드를 찾는다.
      final card = find.ancestor(
        of: find.text(noTitleCondition),
        matching: find.byType(PinnedCautionCard),
      );
      expect(card, findsOneWidget);

      // 앞의 것만 있으면 「이 법의 대상이 아니다」로 읽힌다.
      expect(
        find.descendant(
          of: card,
          matching: find.text('양육비 이행확보 및 지원에 관한 법률 제2조 제2호'),
        ),
        findsOneWidget,
      );
      // 뒤의 것이 **없는 분의 길**이다.
      expect(
        find.descendant(
          of: card,
          matching: find.text('양육비 이행확보 및 지원에 관한 법률 제11조 제1항'),
        ),
        findsOneWidget,
        reason: '없는 분의 길이 같은 카드에 없으면 그분이 돌아갑니다',
      );
    });

    testWidgets('서류가 있으면 그쪽 길이 뜬다', (tester) async {
      await openResult(tester, answers());

      expect(find.text(haveTitleHead), findsOneWidget);
      expect(find.text(noTitleCondition), findsNothing);
    });

    testWidgets('★ 잘 모르겠어요 → 두 길을 다 편다', (tester) async {
      // 좁히는 것이 목적이 아니다. 자기 자리를 못 찾은 분에게 둘을 다 낸다.
      await openResult(tester, answers(orderKind: 'unknown'));

      expect(find.text(noTitleCondition), findsOneWidget);
      expect(find.text(haveTitleHead), findsOneWidget);
    });

    testWidgets('집행권원이 무엇인지 우리가 설명하지 않는다', (tester) async {
      await openResult(tester, answers(orderKind: 'none'));
      await openQuestion(tester, '그 서류가 무엇을 말하는 건가요?');

      // 가사소송법 제64조 제1항이 목록을 갖고 있다. 그 목록을 그대로 낸다.
      expect(find.text('가사소송법 제64조 제1항'), findsOneWidget);
    });
  });

  group('★★ 지금 바로 되는 것과 절차를 밟은 뒤에 오는 것', () {
    testWidgets('선지급은 접혀 있고 물음 머리가 남아 있다', (tester) async {
      // **선지급은 절차를 밟은 뒤에 온다.** 제21조의6 제1항 제3호가
      // 「제11조제2항에 따른 … 신청한 경우 또는 … 절차를 종료하였거나
      // 진행 중인 경우」를 요건으로 둔다.
      await openResult(tester, answers());

      expect(find.text(prepayHead), findsOneWidget);
      // 접혀 있어도 사라진 것은 아니다 — 「밟을 수 있는 절차」에 서 있다.
      expect(
        (await loadTestBundle())
            .byId(kChildSupport)
            .procedures
            .map((p) => p.id),
        contains('proc_prepay'),
      );
    });

    testWidgets('★ 선지급 물음이 절차 카드보다 아래에 온다', (tester) async {
      // **우리가 단계를 매긴 것이 아니다.** 제3호의 요건이 그 순서를 말한다.
      await openResult(tester, answers());

      final procedures = find.text(ProcedureCard.title);
      final prepay = find.text(prepayHead);

      // **한 번만 굴리고 둘을 같은 화면에서 잰다.** 두 번 굴려서 각각 재면
      // 맨 아래에 무엇이 하나 더 붙는 순간 둘 다 맨 위(56.0)에 붙어 같아진다 —
      // 순서가 아니라 스크롤 끝을 재고 있던 것이다. `PageBody` 는
      // `SingleChildScrollView` 라 화면 밖 위젯도 트리에 남아 좌표가 나온다.
      await tester.ensureVisible(prepay);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(prepay).dy,
        greaterThan(tester.getTopLeft(procedures).dy),
        reason: '선지급이 이행확보 절차보다 위에 오면 순서를 우리가 지은 것이 됩니다',
      );
    });

    testWidgets('요건이 까다로워도 숨기지 않는다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, prepayHead);

      expectScreenText(tester, '신청해 봐야 알 수 있어요');
      expect(
        find.text('양육비 이행확보 및 지원에 관한 법률 제21조의6 제1항'),
        findsWidgets,
      );
    });

    testWidgets('★ 첫 화면에 펼쳐진 카드는 하나다', (tester) async {
      await openResult(tester, answers(orderKind: 'none'));

      final title = find.ancestor(
        of: find.text(noTitleCondition),
        matching: find.byType(PinnedCautionCard),
      );
      expect(find.byType(PinnedCautionCard), findsOneWidget);
      expect(tester.getTopLeft(title).dy, lessThan(780));
    });
  });

  group('★★ 창구가 다르다', () {
    test('★ 창구 이름을 지어내지 않는다 — 조문 원문 그대로다', () async {
      final domain = (await loadTestBundle()).byId(kChildSupport);
      final proc =
          domain.procedures.firstWhere((p) => p.id == 'proc_hanbumo_benefit');

      // 「시·군·구청」으로 줄이지 않았다. 창구에 그대로 내미는 화면이다.
      expect(proc.sayThis!.agency, '특별자치시장ㆍ특별자치도지사ㆍ시장ㆍ군수ㆍ구청장');
      expect(proc.legalBasis!.text, contains(proc.sayThis!.agency));

      // 서식 이름은 조문에 없다. 지어내면 사람을 엉뚱한 창구에 보낸다.
      expect(proc.sayThis!.form, isNull);
      expect(proc.verification.openPart, contains('서식 이름'));
    });

    test('★ 양육비 창구와 한부모 창구가 서로 다른 이름이다', () async {
      final domain = (await loadTestBundle()).byId(kChildSupport);
      final agencies = {
        for (final p in domain.procedures) ?p.sayThis?.agency,
      };
      expect(agencies, contains('양육비이행관리원'));
      expect(agencies, contains('특별자치시장ㆍ특별자치도지사ㆍ시장ㆍ군수ㆍ구청장'));
    });

    test('★ 순서를 정한 조문이 없다 — 그 사실을 적고, 순서는 화면에 나가던 대로 굳혔다', () async {
      // 처음에는 둘을 같은 step 으로 두어 「순서 없음」을 나타내려 했다. 그런데
      // 화면은 목록이라 하나가 먼저 서고, 같은 step 이면 정렬 운이 정한다.
      // 「순서 없음」은 화면에 나타낼 수 없는 뜻이었다(DECISIONS 283번).
      final domain = (await loadTestBundle()).byId(kChildSupport);
      Procedure of(String id) =>
          domain.procedures.firstWhere((p) => p.id == id);
      final consult = of('proc_consult');
      final hanbumo = of('proc_hanbumo_benefit');
      expect(consult.step, isNot(hanbumo.step));
      for (final p in [consult, hanbumo]) {
        expect(p.verification.note, contains('조문이 순서를 말하지 않는다'));
      }
    });

    testWidgets('절차를 펴면 창구 이름이 그대로 보인다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, ProcedureCard.title);

      expectScreenText(tester, '특별자치시장ㆍ특별자치도지사ㆍ시장ㆍ군수ㆍ구청장');
      expectScreenText(tester, '한부모가족 복지 급여 신청하기');
    });
  });

  group('★ 부모가 아니어도 조문에 들어 있다', () {
    testWidgets('조부모가 키우는 경우가 조문에 있다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, '제가 아니라 다른 사람이 키우고 있어도 되나요?');

      // 제2조 제5호가 「법정대리인 등 실질적으로 미성년 자녀를 양육하고
      // 있는 사람」까지 넣어 두었다. 우리가 판정하지 않고 조문을 편다.
      expect(find.text('양육비 이행확보 및 지원에 관한 법률 제2조 제5호'), findsOneWidget);
      expect(find.text('양육비 이행확보 및 지원에 관한 법률 제2조 제6호'), findsOneWidget);
      expectScreenText(tester, '실질적으로 키우고 있는 사람도 들어 있어요');
    });
  });

  group('★ 함정 3 — 내가 신청하는 것과 국가가 하는 것은 다르다', () {
    testWidgets('명단 공개에만 신청이 있다고 말한다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, disclosureHead);

      expectScreenText(tester, '이것 하나만 조문에 신청이라는 말이 있어요');
    });

    testWidgets('면허 정지와 출국금지에는 신청이 없다고 말한다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, licenseHead);
      expectScreenText(tester, '이 조문에는 신청이라는 말이 없어요');

      await openQuestion(tester, travelBanHead);
      expectScreenText(tester, '이 조문에도 신청이라는 말이 없어요');
    });

    testWidgets('★ 「신청하세요」가 화면에 없다', (tester) async {
      await openResult(tester, answers());
      for (final head in const [licenseHead, travelBanHead, disclosureHead]) {
        await openQuestion(tester, head);
      }

      expectNoScreenText(
        tester,
        '신청하세요',
        reason: '조문에 신청이 없는 것을 신청하라고 쓰면 헛걸음을 시킵니다',
      );
    });
  });

  group('★ 쉬운 말 한 벌이 화면까지 온다', () {
    testWidgets('켜면 우리 문장이 쉬운 쪽으로 바뀐다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.reset);

      final container = await pumpApp(tester);
      container.read(plainModeProvider.notifier).toggle();
      seedAnswers(container, kChildSupport, answers: answers(orderKind: 'none'));
      container.read(routerProvider).go(Routes.result(kChildSupport));
      await tester.pumpAndSettle();

      expectScreenText(tester, '서류가 없는 분에게 하는 일이 법에 있어요');
      // ★ **「집행권원」은 쉬운 말로 갈아치우지 않는다.** 창구에서 그 말을
      // 그대로 써야 한다. 옆에 풀이를 붙일 뿐이다.
      expectScreenText(tester, '집행권원(법원이 인정한 서류)');
    });
  });

  group('★ 함정 4 — 면허 정지의 단서를 빼지 않는다', () {
    testWidgets('본문과 단서가 한 문장 안에 함께 온다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, licenseHead);

      final body = renderedTexts(tester).where(
        (t) => t.contains('운전면허의 효력을 정지시킬 것을 요청할 수 있다고 적혀 있어요'),
      );
      expect(body, isNotEmpty, reason: '면허 정지 본문이 없습니다');
      // 본문만 보이면 「무조건 정지」로 읽힌다.
      expect(
        body.every((t) => t.contains('생계유지가 곤란할 것으로 인정되는 경우')),
        isTrue,
        reason: '단서가 본문과 같은 카드에 없습니다',
      );
    });
  });

  group('★ 함정 2 — 제재 셋에 순서가 없다', () {
    testWidgets('셋이 나란히 서고 번호가 안 붙는다', (tester) async {
      await openResult(tester, answers());

      for (final head in const [licenseHead, travelBanHead, disclosureHead]) {
        expect(find.text(head), findsOneWidget);
      }
      // 「1단계」·「먼저」·「그 다음」이 붙는 순간 우리가 순서를 지은 것이 된다.
      for (final word in const ['1단계', '2단계', '3단계', '그 다음에']) {
        expectNoScreenText(tester, word);
      }
    });

    testWidgets('순서를 물으면 없다고 답한다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, orderHead);

      expectScreenText(tester, '순서를 정한 조문이 없어요');
    });
  });

  group('★ 명령을 받은 분에게만 제재 이야기를 한다', () {
    testWidgets('아직 명령이 없으면 제재 물음이 안 뜬다', (tester) async {
      await openResult(tester, answers(courtOrder: 'none'));

      for (final head in const [
        licenseHead,
        travelBanHead,
        disclosureHead,
        detentionHead,
      ]) {
        expect(find.text(head), findsNothing);
      }
    });

    testWidgets('서류가 없으면 아예 묻지도 않는다', (tester) async {
      // `q_court_order` 가 안 뜨므로 제재 물음도 안 뜬다.
      await openResult(tester, answers(orderKind: 'none', courtOrder: 'none'));

      expect(find.text(licenseHead), findsNothing);
    });
  });

  group('★ 함정 6 · 8 · 9 — 모르는 것을 모른다고 적는다', () {
    testWidgets('감치는 요건과 30일까지만 말한다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, detentionHead);

      expectScreenText(tester, '대법원규칙으로 정한다고만 되어 있어요');
      expectScreenText(tester, '그 규칙의 원문을 아직 못 봐서');
    });

    testWidgets('선지급 첫 요건은 신청해 봐야 안다까지', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, prepayHead);

      expectScreenText(tester, '신청해 봐야 알 수 있어요');
      // 금액은 조문에 없다. 고시라서 우리에게 없다.
      expectScreenText(tester, '성평등가족부장관이 정하여 고시한다고 넘겼어요');
    });

    testWidgets('기간과 횟수 중 하나를 우리가 고르지 않는다', (tester) async {
      await openResult(tester, answers());
      await openQuestion(tester, howLongHead);

      expectScreenText(tester, '직전 3개월');
      expectScreenText(tester, '연속하여 3회');
      expectScreenText(tester, '하나를 고르지 않고');
    });
  });

  group('데이터 — 말 · 함정 · 다리', () {
    late Domain domain;

    setUpAll(() async {
      domain = (await loadTestBundle()).byId(kChildSupport);
    });

    /// **우리가 쓴 문장 전부.** 조문 원문(`legalBasis.text`)은 여기 없다 —
    /// 인용은 원문 그대로여야 하고, 우리 말과 규칙이 다르다.
    List<String> ours() => <String>[
          domain.name,
          ?domain.description,
          for (final q in domain.intake) ...[q.text, q.whyAsk, q.echo],
          for (final q in domain.intake)
            for (final o in q.options) ...[o.label, ?o.whatIsThis],
          for (final c in domain.cautions) ...[
            c.question,
            c.condition,
            c.consequence,
          ],
          for (final p in domain.procedures) ...[
            p.label,
            p.whatIsThis,
            ?p.detail,
          ],
          for (final p in domain.procedures)
            for (final t in p.courtTerms) ...[t.label, t.within, ...t.exceptWhen],
        ];

    /// 조문 원문 전부. **인용은 각 원문 그대로다.**
    List<String> quotes() => <String>[
          for (final c in domain.cautions) ...[
            ?c.legalBasis?.text,
            for (final a in c.alsoBasis) ?a.text,
          ],
          for (final p in domain.procedures) ...[
            ?p.legalBasis?.text,
            for (final a in p.alsoBasis) ?a.text,
            for (final t in p.courtTerms) ?t.legalBasis?.text,
          ],
        ];

    test('★ 금지어 다섯이 0건이다', () {
      // 「무조건」은 SafetyFilter 도 막지만, 나머지 넷은 이 분야의 규칙이다.
      for (final word in const [
        '전남편',
        '전처',
        '양육비 안 주는 사람',
        '받아 드립니다',
        '무조건',
      ]) {
        for (final sentence in ours()) {
          expect(sentence.contains(word), isFalse, reason: '「$sentence」');
        }
      }
    });

    test('★ 상대를 비난하는 말을 쓰지 않는다', () {
      // 화가 난 상태로 오는 분야다. 압박 수단을 「방법」으로 권하기 시작하면
      // 다른 앱이 된다. 요건을 담담하게 놓기만 한다.
      for (final word in const [
        '나쁜',
        '괘씸',
        '곤란해집니다',
        '압박',
        '혼내',
        '망신',
      ]) {
        for (final sentence in ours()) {
          expect(sentence.contains(word), isFalse, reason: '「$sentence」');
        }
      }
    });

    test('★ 아이의 이름·나이·학교를 묻지 않는다', () {
      for (final question in domain.intake) {
        for (final word in const ['이름', '나이', '몇 살', '학교', '학년']) {
          expect(
            '${question.text} ${question.whyAsk}'.contains(word),
            isFalse,
            reason: '${question.id} — 「$word」를 묻고 있습니다. 사람이 특정됩니다',
          );
        }
      }
      // 나이가 필요해 보이는 자리는 선지급 기간이다. 그래도 묻지 않는다.
      expect(
        domain.cautions.map((c) => c.id),
        contains('ct_prepay_period'),
      );
    });

    test('★ 함정 5 — 두 법이 다르게 쓰는 말을 우리가 고르지 않는다', () {
      for (final sentence in ours()) {
        expect(sentence.contains('지방경찰청장'), isFalse, reason: '「$sentence」');
        expect(sentence.contains('시ㆍ도경찰청장'), isFalse, reason: '「$sentence」');
      }
      // 인용은 원문 그대로다. 법이 쓰는 말은 그대로 남아 있다.
      expect(
        quotes().where((q) => q.contains('지방경찰청장')),
        isNotEmpty,
        reason: '법 제21조의3 제1항의 말이 인용에서 사라졌습니다',
      );
    });

    test('★ 함정 5 — 붙여 쓴 말과 띄어 쓴 말이 각자 원문대로다', () {
      // 가사소송법은 「양육비채무자」, 양육비법은 「양육비 채무자」다.
      // 통일하지 않는다 — 고르는 순간 한쪽이 틀린 게 된다.
      final family = quotes().where((q) => q.contains('양육비채무자'));
      final support = quotes().where((q) => q.contains('양육비 채무자'));
      expect(family, isNotEmpty);
      expect(support, isNotEmpty);

      // 우리 문장에서는 둘 다 안 쓴다.
      for (final sentence in ours()) {
        expect(sentence.contains('양육비채무자'), isFalse, reason: '「$sentence」');
        expect(sentence.contains('양육비 채무자'), isFalse, reason: '「$sentence」');
        expect(sentence.contains('양육비 채권자'), isFalse, reason: '「$sentence」');
      }
    });

    test('★ 판정하는 말이 우리 문장에 없다', () {
      for (final sentence in ours()) {
        expect(
          SafetyFilter.scan(sentence, where: kChildSupport),
          isEmpty,
          reason: '「$sentence」',
        );
      }
    });

    test('★ 함정 2 — 제재 셋은 절차가 아니라 안내다', () {
      // `procedures` 에 넣으면 단계 번호가 붙는다. 순서를 정한 조문이 없다.
      final ids = domain.procedures.map((p) => p.id).toList();
      for (final id in ids) {
        expect(id.contains('license'), isFalse);
        expect(id.contains('travel'), isFalse);
        expect(id.contains('disclosure'), isFalse);
      }

      // 셋의 대상은 시행령이 똑같이 세 호로 적어 두었다.
      final three = <String>[
        for (final id in const ['ct_license', 'ct_travel_ban', 'ct_sanction_order'])
          [
            ?domain.cautions.firstWhere((c) => c.id == id).legalBasis?.text,
            for (final a in domain.cautions.firstWhere((c) => c.id == id).alsoBasis)
              ?a.text,
          ].join(' '),
      ];
      for (final text in three) {
        expect(text, contains('일시금 지급명령 결정을 받고 30일 이내에'));
        expect(text, contains('3천만원 이상인 사람'));
        expect(text, contains('3기(期) 이상'));
      }
    });

    test('★ 함정 1 — 우리가 지어낸 금액이 없다', () {
      // 선지급 금액은 고시, 양육비 산정기준표는 대법원 자료라 **조문이 아니다.**
      // 그래서 이 분야에는 `costs` 가 없다 — 낼 수 없는 값이다.
      expect(domain.costs, isEmpty);
      expect(domain.deadlines, isEmpty);

      // 우리 문장에 금액이 나온다면 **그 금액은 조문에도 있어야 한다.**
      // 1천만원(가사소송법 제67조 제1항)은 조문에 있고,
      // 3천만원(시행령 제17조의2 제1항 제2호)은 인용에만 있다.
      final money = RegExp(r'[0-9]+(천|만|억)*원');
      final quoted = quotes().join(' ');
      for (final sentence in ours()) {
        for (final hit in money.allMatches(sentence)) {
          expect(
            quoted.contains(hit.group(0)!),
            isTrue,
            reason: '「$sentence」의 ${hit.group(0)} 이 조문에 없습니다',
          );
        }
      }
      expect(quotes().where((q) => q.contains('3천만원')), isNotEmpty);
      for (final sentence in ours()) {
        expect(sentence.contains('3천만원'), isFalse, reason: '「$sentence」');
      }
    });

    test('★ 함정 6 · 8 · 9 — 열린 조각에 이름이 붙어 있다', () {
      Caution byId(String id) =>
          domain.cautions.firstWhere((c) => c.id == id);

      expect(byId('ct_detention').verification.status,
          VerificationStatus.needsCheck);
      expect(byId('ct_detention').verification.openPart, contains('대법원규칙'));

      expect(byId('ct_prepay').verification.openPart, contains('고시'));
      expect(byId('ct_prepay_how_long').verification.openPart, contains('횟수'));
    });

    test('★ 2026-10-29 에 없어진 소득 요건이 남아 있지 않다', () {
      // 그날 전에는 **미리 지우지 않았다** — 그때 맞던 조문을 지우는 것이 됐다.
      // 그날 검사 (z)가 빌드를 멈췄고(DECISIONS 241번), 시행판으로 다시 떴다.
      // 없어진 요건을 「해당해야 합니다」로 계속 내면 안 되는 사람을 돌려보낸다.
      expect(
        quotes().where((q) => q.contains('기준 중위소득의 100분의 150')),
        isEmpty,
        reason: '삭제된 소득 요건이 아직 인용에 남아 있습니다',
      );
      expect(
        quotes().where((q) => q.contains('2. 삭제 <2026. 4. 28.>')),
        isNotEmpty,
        reason: '제21조의6 제1항 제2호가 삭제됐다는 것을 조문 그대로 보여 줘야 합니다',
      );
    });

    test('★ 겉이 닮았다고 두 법의 「그 사람」을 잇지 않는다', () {
      // 한부모법 제5조의2 제2항의 조부ㆍ조모와 양육비법 제2조 제5호의
      // 「실질적으로 양육하고 있는 사람」은 겉이 같은 자리로 보인다.
      // **그러나 저쪽은 부모가 사망ㆍ장애ㆍ장기복역ㆍ유기로 부양을 못 하는
      // 경우다.** 해당하는지는 사실 판단이라 우리가 못 한다 — 이으면
      // 우리가 판정한 것이 된다. 나중에 「비슷하니까」로 이을 수 있는 자리다.
      final who = domain.cautions.firstWhere((c) => c.id == 'ct_who');
      for (final basis in [who.legalBasis, ...who.alsoBasis]) {
        expect(
          basis?.law,
          isNot('한부모가족지원법'),
          reason: '두 법의 「그 사람」이 같은 사람인지 우리가 판정하면 안 됩니다',
        );
      }
    });

    test('묶음은 family — 이 분야로 처음 선다', () {
      expect(domain.group, 'family');
    });

    test('앱 번들에 실려 있다', () {
      expect(AssetDomainSource.bundledDomainIds, contains(kChildSupport));
    });
  });
}
