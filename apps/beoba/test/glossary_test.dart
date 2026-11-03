import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/safety/safe_text.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/widgets/legal_basis_card.dart';
import 'package:beoba/src/widgets/term_sheet.dart';
import 'package:domain_data/domain_data.dart'
    show Glossary, GlossaryKind, GlossaryTerm, LegalBasis, Verification,
        VerificationStatus;
import 'package:engines/engines.dart' hide VerificationStatus;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **용어 풀이는 검색하지 않고 표시한다.** 우리가 쓴 문장이기 때문이다.
///
/// 문장에 `[[낱말]]` 을 박으면 그 자리가 점선 밑줄이 되고 누르면 시트가 열린다.
/// 화면 문자열을 용어집 키로 훑지 않으므로 「주소가」 안의 「소가」 같은
/// 오탐이 **생길 자리가 없다.**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openResult(WidgetTester tester) async {
    final container = await pumpApp(tester);
    seedAnswers(container, kDebtRecoveryDomainId);
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return container;
  }

  group('데이터 — 박아 둔 말이 전부 용어집에 있다', () {
    test('모든 [[낱말]] 이 용어집 키다', () async {
      final container = await bootstrappedContainer();
      final bundle = container.read(domainBundleProvider).requireValue;
      final glossary = bundle.glossary;

      var found = 0;
      for (final domain in [...bundle.domains.values, bundle.crisis]) {
        for (final text in _screenTexts(domain)) {
          for (final term in termsIn(text)) {
            found++;
            expect(glossary.byTerm(term), isNotNull, reason: term);
          }
        }
      }
      expect(found, greaterThan(0), reason: '토큰이 하나도 없으면 검사가 헛돕니다');
    });

    test('🟡 에는 조문이 붙어 있지 않다', () async {
      final container = await bootstrappedContainer();
      final glossary =
          container.read(domainBundleProvider).requireValue.glossary;

      for (final entry in glossary.terms) {
        if (entry.kind.hasStatute) {
          expect(entry.lawRef?.text, isNotNull, reason: entry.term);
          expect(entry.effective, isNotEmpty, reason: entry.term);
        } else {
          expect(entry.lawRef, isNull, reason: entry.term);
          expect(entry.alsoBasis, isEmpty, reason: entry.term);
        }
      }
    });
  });

  group('사슬은 끝까지 잇는다', () {
    test('조정은 세 장이다 — 효력 · 성립 · 재판상의 화해', () async {
      // 제29조만 실으면 「재판상의 화해와 동일한 효력」에서 멈춘다. 그게 무슨
      // 뜻인지는 민사조정법에 없고 민사소송법 제220조에 있다.
      final container = await bootstrappedContainer();
      final entry = container
          .read(domainBundleProvider)
          .requireValue
          .glossary
          .byTerm('조정')!;

      expect(entry.lawRef?.article, '제29조');
      expect(
        entry.alsoBasis.map((b) => '${b.law} ${b.article}'),
        ['민사조정법 제28조', '민사소송법 제220조'],
      );
      // **집행까지 나가지 않는다.** 그건 집행권원 시트가 따로 말한다.
      expect(entry.oneLiner, isNot(contains('압류')));
      expect(entry.oneLiner, isNot(contains('집행')));
    });

    test('소가는 용어집에만 있고 화면에는 없다', () async {
      // 금전지급청구는 소가 = 청구금액(인지규칙 제12조 제3호)이라 화면에서는
      // 「청구금액」으로 쓴다. 낯선 말을 낼 이유가 없다.
      final container = await bootstrappedContainer();
      final bundle = container.read(domainBundleProvider).requireValue;

      expect(bundle.glossary.byTerm('소가')?.kind, GlossaryKind.statute);
      for (final domain in [...bundle.domains.values, bundle.crisis]) {
        for (final text in _screenTexts(domain)) {
          expect(termsIn(text), isNot(contains('소가')));
        }
      }
    });

    test('확정판결은 낱말 하나다', () async {
      // 「확정[[판결]]」이라고 쓰면 화면에서 뒤 두 글자에만 점선이 그어져
      // 읽는 사람이 「확정」과 「판결」을 다른 말로 안다. 통째로 감싼다.
      final container = await bootstrappedContainer();
      final glossary =
          container.read(domainBundleProvider).requireValue.glossary;
      final entry = glossary.byTerm('확정판결')!;

      expect(entry.kind, GlossaryKind.statute);
      expect(entry.lawRef?.article, '제498조');
      expect(entry.alsoBasis.single.article, '제396조');
      // 새 낱말을 열지 않는다.
      expect(entry.oneLiner, isNot(contains('항소')));
      expect(entry.oneLiner, isNot(contains('불변기간')));

      // 조정의 풀이가 낱말을 통째로 가리킨다.
      expect(glossary.byTerm('조정')!.oneLiner, contains('[[확정판결]]'));

      // 「확정」이 홀로 쓰이는 자리가 아직 있어서 그 항목은 남는다.
      expect(glossary.byTerm('확정'), isNotNull);
    });

    test('지연이자는 조문을 얻어 🟢 가 됐다', () async {
      final container = await bootstrappedContainer();
      final entry = container
          .read(domainBundleProvider)
          .requireValue
          .glossary
          .byTerm('지연이자')!;

      expect(entry.kind, GlossaryKind.statute);
      expect(entry.lawRef?.article, '제397조 제1항');
      expect(entry.alsoBasis.single.article, '제397조 제2항');
      // **율은 시트가 말하지 않는다.** 세 갈래라 비용 카드가 할 일이다.
      expect(entry.oneLiner, isNot(contains('%')));
      expect(entry.oneLiner, isNot(contains('이율')));
    });
  });

  group('화면 — 대괄호가 새지 않는다', () {
    testWidgets('결과 화면 어디에도 [[ 나 ]] 가 없다', (tester) async {
      await openResult(tester);
      for (final card in const [
        CostCard.title,
        DocumentCard.title,
        JurisdictionCard.title,
        ProcedureCard.title,
      ]) {
        final finder = find.text(card);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      expectNoScreenText(tester, '[[');
      expectNoScreenText(tester, ']]');
    });

    testWidgets('밑줄이 섞인 문장도 find.text 가 본다', (tester) async {
      // 이게 깨지면 금지어 0건 검사들이 **아무것도 안 보고 통과하게 된다.**
      // Flutter 가 Text.rich 를 어떻게 보는지에 기대는 자리라 못박아 둔다.
      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(terms: [_sample]),
          child: SafeText('법원이 [[지급명령]]을 합니다', where: 'test'),
        ),
      );

      expect(find.text('법원이 지급명령을 합니다'), findsOneWidget);
      expect(find.textContaining('지급명령'), findsOneWidget);
    });
  });

  group('밑줄 — 우리가 박은 자리에만', () {
    testWidgets('토큰이 있는 자리는 점선 밑줄이다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(terms: [_sample]),
          child: SafeText('법원이 [[지급명령]]을 합니다', where: 'test'),
        ),
      );

      final marked = _underlined(tester);
      expect(marked, ['지급명령']);
    });

    testWidgets('같은 말은 첫 번째만 밑줄', (tester) async {
      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(terms: [_sample]),
          child: SafeText('[[지급명령]]과 [[지급명령]]', where: 'test'),
        ),
      );

      expect(_underlined(tester), ['지급명령']);
    });

    testWidgets('용어집에 없는 말은 밑줄이 안 생긴다', (tester) async {
      // 데이터 쪽은 빌드가 막지만, 화면은 조용히 그냥 그린다.
      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(),
          child: SafeText('법원이 [[지급명령]]을 합니다', where: 'test'),
        ),
      );

      expect(_underlined(tester), isEmpty);
      expect(find.text('법원이 지급명령을 합니다'), findsOneWidget);
    });

    /// **자동 부착이었다면 전부 오탐이 났을 문장들.**
    ///
    /// 마크업 방식이라 당연히 통과한다. 그래도 잠가 둔다 — 나중에 누가
    /// 자동 부착을 넣으면 여기서 걸린다.
    for (final text in const [
      '법원에 서류를 내려면 상대방 주소가 필요합니다.',
      '어떻게 생각하시는지 알려 주세요.',
      '확정신고 기간을 확인해 보세요.',
      '인용문은 그대로 두었습니다.',
    ]) {
      testWidgets('골든셋 — "$text" 에 밑줄이 없다', (tester) async {
        await pumpWidgetOnly(
          tester,
          GlossaryScope(
            glossary: const Glossary(terms: [_sample, _plain]),
            child: SafeText(text, where: 'test'),
          ),
        );

        expect(_underlined(tester), isEmpty);
      });
    }

    testWidgets('한 화면이 밑줄 밭이 되지 않는다', (tester) async {
      // 상한을 세는 단위는 카드가 아니라 **이어지는 문장 300자**다(검증기가
      // 센다). 여기서는 화면이 실제로 밑줄 밭이 아닌지만 눈으로 확인한다.
      await openResult(tester);
      final finder = find.text(ProcedureCard.title);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();

      final marked = _underlined(tester);
      expect(marked.length, lessThanOrEqualTo(3));
      expect(marked.toSet().length, marked.length, reason: '같은 말이 두 번');
    });
  });

  group('시트 — 순서가 고정이다', () {
    testWidgets('🟢 은 조문 원문과 출처를 접지 않고 바로 보여준다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(terms: [_sample]),
          // 낱말만 그린다. 문장 가운데를 누르면 밑줄이 아닌 자리에 닿는다.
          child: SafeText('[[지급명령]]', where: 'test'),
        ),
      );
      await tester.tap(find.textContaining('지급명령'));
      await tester.pumpAndSettle();

      expect(find.text('지급명령'), findsWidgets);
      expect(find.text(TermSheet.statuteHeading), findsOneWidget);
      // **접지 않는다.** 접으면 아무도 안 연다.
      expect(find.text(LegalBasisCard.open), findsNothing);
      expectScreenText(tester, '법원은 채권자의 신청에 따라');
      expectScreenText(tester, '2025-07-12 시행');
      // 🟢 에는 우리 말이라는 고지가 붙지 않는다.
      expect(find.text(TermSheet.ourWordsNotice), findsNothing);
      expect(find.text(TermSheet.closeLabel), findsOneWidget);
    });

    testWidgets('🟡 은 우리 말이라고 먼저 밝히고 근거를 안 단다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(terms: [_plain]),
          child: SafeText('[[각하]]', where: 'test'),
        ),
      );
      await tester.tap(find.textContaining('각하'));
      await tester.pumpAndSettle();

      expect(find.text(TermSheet.ourWordsNotice), findsOneWidget);
      expect(find.byType(LegalBasisCard), findsNothing);
      expect(find.text(TermSheet.statuteHeading), findsNothing);
      expectNoScreenText(tester, '시행');
    });

    testWidgets('풀이 안의 밑줄도 눌린다', (tester) async {
      // 40자 안에서는 괄호로 풀 자리가 없다. **밑줄이 곧 그 자리를 여는 문**이라
      // 시트 안에서도 같은 장치를 쓴다.
      const chained = GlossaryTerm(
        term: '조정',
        kind: GlossaryKind.statute,
        oneLiner: '확정[[판결]]과 같은 힘을 가져요',
        lawRef: LegalBasis(
          law: '민사조정법',
          article: '제29조',
          text: '조정은 재판상의 화해와 동일한 효력이 있다.',
        ),
        effective: '2020-03-05',
        verification: Verification(status: VerificationStatus.verified),
      );

      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(terms: [chained, _plain2]),
          child: SafeText('[[조정]]', where: 'test'),
        ),
      );
      await tester.tap(find.textContaining('조정'));
      await tester.pumpAndSettle();

      expectScreenText(tester, '확정판결과 같은 힘을 가져요');
      expectNoScreenText(tester, '[[');
    });

    testWidgets('시트는 한 겹까지만 열린다', (tester) async {
      // **세 겹 쌓이면 뒤로가기를 세 번 눌러야 한다.** 그 순간 사람은
      // 자기가 어디에 있었는지 잊는다. 두 번째 겹부터는 밑줄을 안 그려서
      // 더 들어갈 문 자체를 없앤다.
      const a = GlossaryTerm(
        term: '가',
        kind: GlossaryKind.ourWords,
        oneLiner: '[[나]]',
        verification: Verification(status: VerificationStatus.verified),
      );
      const b = GlossaryTerm(
        term: '나',
        kind: GlossaryKind.ourWords,
        oneLiner: '[[다]]',
        verification: Verification(status: VerificationStatus.verified),
      );
      const c = GlossaryTerm(
        term: '다',
        kind: GlossaryKind.ourWords,
        oneLiner: '여기서 끝이에요',
        verification: Verification(status: VerificationStatus.verified),
      );

      await pumpWidgetOnly(
        tester,
        const SafeText('[[가]]', where: 'test'),
        glossary: const Glossary(terms: [a, b, c]),
      );

      // 화면(0겹) — 밑줄이 있다.
      expect(_underlined(tester), ['가']);
      await tester.tap(find.textContaining('가'));
      await tester.pumpAndSettle();

      // 첫 시트(1겹) — 풀이 안의 밑줄이 살아 있다.
      expect(_underlined(tester), contains('나'));
      // 시트 안의 풀이는 폭을 꽉 채워서 늘어난다. 가운데를 누르면 글자가
      // 없는 빈 자리다 — 손가락은 글자를 누른다. 왼쪽 끝을 짚는다.
      await tester.tapAt(
        tester.getTopLeft(find.text('나').last) + const Offset(6, 12),
      );
      await tester.pumpAndSettle();

      // 둘째 시트(2겹) — 글자는 그대로인데 **밑줄이 없다.**
      // 앞 시트는 아래에 그대로 깔려 있으므로 「다」만 본다.
      expectScreenText(tester, '다');
      expect(_underlined(tester), isNot(contains('다')));
      expectNoScreenText(tester, '[[');
    });

    testWidgets('닫으면 그 자리로 돌아온다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const GlossaryScope(
          glossary: Glossary(terms: [_sample]),
          // 낱말만 그린다. 문장 가운데를 누르면 밑줄이 아닌 자리에 닿는다.
          child: SafeText('[[지급명령]]', where: 'test'),
        ),
      );
      await tester.tap(find.textContaining('지급명령'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TermSheet.closeLabel));
      await tester.pumpAndSettle();

      expect(find.byType(TermSheet), findsNothing);
      expect(find.textContaining('지급명령'), findsOneWidget);
    });
  });
}

/// 지금 화면에서 점선 밑줄이 그어진 낱말들.
List<String> _underlined(WidgetTester tester) {
  final marked = <String>[];
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final span = text.textSpan;
    if (span == null) continue;
    span.visitChildren((child) {
      if (child is TextSpan &&
          child.style?.decorationStyle == TextDecorationStyle.dotted) {
        marked.add(child.text ?? '');
      }
      return true;
    });
  }
  return marked;
}

/// 화면에 나가는 문장만 모은다. 조문 원문·검수 메모는 토큰을 쓰지 않는다.
List<String> _screenTexts(Domain domain) => [
      domain.name,
      domain.description ?? '',
      for (final question in domain.intake) ...[
        question.text,
        question.whyAsk,
        question.echo,
        for (final option in question.options) option.label,
      ],
      for (final procedure in domain.procedures) ...[
        procedure.caution ?? '',
        procedure.detail ?? '',
        procedure.whenApplicable ?? '',
        procedure.noticeToUser ?? '',
      ],
      for (final caution in domain.cautions) ...[
        caution.condition,
        caution.consequence,
      ],
      for (final alert in domain.brokerAlerts) alert.truth,
      for (final stop in domain.hardStops) ...[
        stop.title ?? '',
        stop.message ?? '',
        ...stop.checklist,
      ],
    ];

const GlossaryTerm _sample = GlossaryTerm(
  term: '지급명령',
  kind: GlossaryKind.statute,
  oneLiner: '법원이 서류만 보고 돈을 갚으라고 하는 명령이에요',
  lawRef: LegalBasis(
    law: '민사소송법',
    article: '제462조',
    text: '법원은 채권자의 신청에 따라 지급명령을 할 수 있다.',
  ),
  effective: '2025-07-12',
  verification: Verification(status: VerificationStatus.verified),
);

const GlossaryTerm _plain = GlossaryTerm(
  term: '각하',
  kind: GlossaryKind.ourWords,
  oneLiner: '따져 보기 전에 요건이 안 맞아 돌려보내는 것이에요',
  verification: Verification(status: VerificationStatus.verified),
);

const GlossaryTerm _plain2 = GlossaryTerm(
  term: '판결',
  kind: GlossaryKind.ourWords,
  oneLiner: '재판의 마지막 결정이에요',
  verification: Verification(status: VerificationStatus.verified),
);
