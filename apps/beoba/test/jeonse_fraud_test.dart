import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 전세사기 — 열다섯 번째 분야.
///
/// 설계는 `docs/작업중_전세사기.md` 의 「정해진 것」이다. **짓기 전에 정한 것을
/// 지은 뒤에도 지키는지** 여기서 잠근다 — 적히지 않은 결정은 없는 결정이고,
/// 잠기지 않은 결정은 다음 손질에서 풀린다.
const String kJeonse = 'jeonse_fraud';

/// 형사 쪽 문장에 쓰지 않는 말(「정해진 것」 ③ · DECISIONS 278번).
///
/// 특별법 제3조 ① 4호에 「수사 개시」가 예시로 있다. 고소 절차의 문장에 이
/// 말들이 오면 「고소하면 결정된다」로도 「고소해야 결정받는다」로도 읽힌다.
const List<String> kNotOnCriminalSide = ['수사', '결정', '피해자로', '요건'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('데이터 — 짓기 전에 정한 것', () {
    late DomainBundle bundle;
    late Domain d;

    setUpAll(() async {
      bundle = await loadTestBundle();
      d = bundle.byId(kJeonse);
    });

    test('앱이 싣는 분야다', () {
      expect(AssetDomainSource.bundledDomainIds, contains(kJeonse));
    });

    group('① 세 갈래는 절차 셋 — 행정 → 민사 → 형사', () {
      test('step 순서가 행정 · 민사 · 형사다', () {
        final byStep = [...d.procedures]
          ..sort((a, b) => a.step.compareTo(b.step));
        expect(
          byStep.map((p) => p.id),
          ['proc_decision_apply', 'proc_distribution_request', 'proc_criminal_report'],
          reason: '맨 앞 절차가 「오늘 할 일」이 됩니다. 형사가 앞에 서면 우리가 '
              '사람을 그쪽으로 미는 것입니다',
        );
      });

      test('★ step 이 겹치지 않고, 고소는 행정·민사보다 뒤다', () {
        // **순서를 정렬 운에 맡기지 않는다.** 고소장 내기가 배당요구와 같은
        // step 2 였는데 순서가 맞게 나왔다 — 파일에서 배당요구가 앞이었고
        // 정렬이 우연히 안정적이었을 뿐이다. Dart 의 List.sort 는 안정성을
        // 약속하지 않는다. 맨 앞 절차가 「오늘 할 일」이 되므로 이 시험이
        // 278번의 약속(고소로 사람을 밀지 않는다)을 지킨다.
        final steps = d.procedures.map((p) => p.step).toList();
        expect(steps.toSet(), hasLength(steps.length),
            reason: 'step 이 겹칩니다: $steps');
        int stepOf(String id) =>
            d.procedures.firstWhere((p) => p.id == id).step;
        final criminal = stepOf('proc_criminal_report');
        expect(criminal, greaterThan(stepOf('proc_decision_apply')));
        expect(criminal, greaterThan(stepOf('proc_distribution_request')));
      });

      test('행정과 민사에 showIf 가 없다 — 형사가 맨 앞에 설 갈래가 없다', () {
        for (final id in ['proc_decision_apply', 'proc_distribution_request']) {
          final p = d.procedures.firstWhere((p) => p.id == id);
          expect(
            p.showIf,
            isNull,
            reason: '$id 가 빠지는 갈래가 생기면 절차 목록에서 형사가 앞으로 '
                '오르거나 행정 바로 아래에 붙습니다',
          );
        }
      });
    });

    group('② 형사는 중고거래 모양 그대로', () {
      test('절차가 중고거래와 한 벌이다 — 설명 한 줄까지', () {
        final ours = d.procedures.firstWhere((p) => p.id == 'proc_criminal_report');
        final theirs = bundle
            .byId('secondhand_fraud')
            .procedures
            .firstWhere((p) => p.id == 'proc_criminal_report');
        expect(ours.label, theirs.label);
        // ★ 한쪽만 고치면 두 벌이 된다. 설명은 제237조의 말이다 — 「수사기관」은
        // 조문에 없는 말이었고, 옛 분야를 고쳐 맞췄다(DECISIONS 279번).
        expect(ours.whatIsThis, theirs.whatIsThis);
        expect(ours.whatIsThis, '검사나 사법경찰관에게 고소하는 것이에요');
        expect(ours.detail, theirs.detail);
        expect(ours.stage, theirs.stage);
        expect(ours.legalBasis, theirs.legalBasis);
        expect(ours.alsoBasis, theirs.alsoBasis);
      });

      test('고소 물음 카드가 중고거래와 한 글자도 같다', () {
        final ours = d.cautions.firstWhere((c) => c.id == 'ct_criminal_is_not_refund');
        final theirs = bundle
            .byId('secondhand_fraud')
            .cautions
            .firstWhere((c) => c.id == 'ct_criminal_is_not_refund');
        expect(ours.question, theirs.question);
        expect(ours.condition, theirs.condition);
        expect(ours.consequence, theirs.consequence);
        expect(ours.legalBasis, theirs.legalBasis);
      });
    });

    group('③ 「수사 개시」와 고소 절차가 붙지 않는다', () {
      test('형사 쪽 문장에 「수사」·「결정」·「피해자로」·「요건」이 없다', () {
        final p = d.procedures.firstWhere((p) => p.id == 'proc_criminal_report');
        final c = d.cautions.firstWhere((c) => c.id == 'ct_criminal_is_not_refund');
        final sentences = {
          'proc_criminal_report.label': p.label,
          'proc_criminal_report.whatIsThis': p.whatIsThis,
          'proc_criminal_report.detail': p.detail ?? '',
          'ct_criminal_is_not_refund.question': c.question,
          'ct_criminal_is_not_refund.condition': c.condition,
          'ct_criminal_is_not_refund.consequence': c.consequence,
          for (final e in d.plain.entries)
            if (e.key.contains('proc_criminal_report') ||
                e.key.contains('ct_criminal_is_not_refund'))
              'plain ${e.key}': e.value,
        };
        for (final e in sentences.entries) {
          for (final word in kNotOnCriminalSide) {
            expect(
              e.value.contains(word),
              isFalse,
              reason: '${e.key} 에 「$word」가 있습니다: ${e.value}',
            );
          }
        }
      });

      test('요건 카드와 고소 물음 사이에 showIf 없는 카드가 선다', () {
        final ids = d.cautions.map((c) => c.id).toList();
        final from = ids.indexOf('ct_requirements');
        final to = ids.indexOf('ct_criminal_is_not_refund');
        expect(from, greaterThanOrEqualTo(0));
        expect(to, greaterThan(from + 1));
        final between = d.cautions.sublist(from + 1, to);
        expect(
          between.where((c) => c.showIf == null),
          isNotEmpty,
          reason: '사이 카드가 전부 showIf 로 빠지는 갈래에서 둘이 붙습니다',
        );
      });

      test('요건 카드는 4호를 틀째로 옮긴다 — 예시 넷 중 하나로 보인다', () {
        final c = d.cautions.firstWhere((c) => c.id == 'ct_requirements');
        expect(c.consequence, contains('의심할 만한 상당한 이유'));
        expect(c.consequence, contains('수사 개시, 기망'));
        expect(c.consequence, contains('등을 들어요'));
        expect(c.consequence, contains('국토교통부장관이 결정한다'));
      });
    });

    group('④ 밀도 — 대항력 카드를 접었다', () {
      test('대항력(startsFrom) 기한이 없다', () {
        expect(
          d.deadlines.where((x) => x.kind == DeadlineKind.startsFrom),
          isEmpty,
          reason: '보증금 분야에 있는 카드입니다. 두 벌이 생기면 검사 (ak)가 '
              '맞대야 할 짝만 늘어납니다',
        );
      });
    });

    group('⑤ 부칙 제2조 적용범위 카드는 안 접는다', () {
      test('멈춰 세우는 카드이고 조문과 물어볼 말을 함께 든다', () {
        final c = d.cautions.firstWhere((c) => c.id == 'ct_scope_first_contract');
        expect(c.display, AlertDisplay.stop);
        expect(c.legalBasis?.article, '부칙(제20956호) 제2조');
        expect(c.verification.openPart, isNotNull);
        expect(c.verification.askThis, isNotNull);
      });

      test('「적용돼요」도 「안 돼요」도 쓰지 않는다', () {
        final c = d.cautions.firstWhere((c) => c.id == 'ct_scope_first_contract');
        for (final word in ['적용돼요', '적용되지 않아요', '신청할 수 없어요', '신청할 수 있어요']) {
          expect(c.consequence.contains(word), isFalse, reason: '「$word」');
        }
      });
    });

    group('한시법 · 기간 · 금액', () {
      test('유효기간 만료일을 사람에게 보이는 문장에 찍지 않는다', () {
        final shown = _userFacing(d);
        for (final e in shown.entries) {
          expect(
            e.value.contains('2027'),
            isFalse,
            reason: '${e.key} — 만료일은 조문에 없는 날입니다. 검사만 씁니다',
          );
        }
        final apply = d.procedures.firstWhere((p) => p.id == 'proc_decision_apply');
        expect(apply.caution, contains('시행 후 4년이 경과하는 날까지'));
      });

      test('우리가 날짜로 세는 기한이 없다 — 이의신청 30일도 세지 않는다', () {
        expect(d.deadlines, isEmpty);
        final c = d.cautions.firstWhere((c) => c.id == 'ct_objection_period');
        expect(c.verification.openPart, isNotNull);
      });

      test('최우선변제 금액을 우리 문장에 적지 않는다', () {
        final money = RegExp(r'[0-9,]+\s*(원|만원|억원)');
        for (final e in _userFacing(d).entries) {
          expect(money.hasMatch(e.value), isFalse, reason: '${e.key}: ${e.value}');
        }
      });

      test('보완은 「14일 이내의 기간을 정하여」다 — 「14일」로 줄이지 않는다', () {
        final c = d.cautions.firstWhere((c) => c.id == 'ct_fix_request');
        expect(c.consequence, contains('14일 이내의 기간을 정해서'));
        expect(c.consequence, contains('14일이 정해져 있는 것이 아니라'));
      });
    });

    test('이사 카드는 보증금 분야의 문장을 그대로 쓴다 — 다른 것은 display 하나', () {
      final ours = d.cautions.firstWhere((c) => c.id == 'ct_before_moving');
      final theirs = bundle
          .byId('deposit_return')
          .cautions
          .firstWhere((c) => c.id == 'ct_before_moving');
      expect(ours.condition, theirs.condition);
      expect(ours.consequence, theirs.consequence);
      expect(ours.verification.openPart, theirs.verification.openPart);
      expect(ours.display, AlertDisplay.inline);
    });
  });

  group('화면', () {
    Future<ProviderContainer> openResult(
      WidgetTester tester,
      Map<String, Object?> answers,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.reset);
      final container = await pumpApp(tester);
      seedAnswers(container, kJeonse, answers: answers);
      container.read(routerProvider).go(Routes.result(kJeonse));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('이전 계약이면 적용범위 카드가 안 선다', (tester) async {
      final container = await openResult(tester, const {
        'q_first_contract': 'before',
        'q_apply_stage': 'not_yet',
        'q_auction': 'no',
      });
      final ids = container.read(cautionsProvider(kJeonse)).map((c) => c.id);
      expect(ids, isNot(contains('ct_scope_first_contract')));
    });

    for (final when in ['after', 'unknown']) {
      testWidgets('처음 계약이 $when 이면 적용범위 카드가 첫 화면에 선다', (tester) async {
        await openResult(tester, {
          'q_first_contract': when,
          'q_apply_stage': 'not_yet',
          'q_auction': 'no',
        });
        final card = find.text('처음 계약한 날이 2025년 6월 1일이나 그 뒤이거나, 잘 모르시면');
        expect(card, findsOneWidget);
        expect(tester.getTopLeft(card).dy, lessThan(780));
      });
    }

    testWidgets('어느 갈래에서도 형사가 맨 앞 절차가 아니다', (tester) async {
      final container = await openResult(tester, const {
        'q_first_contract': 'unknown',
        'q_apply_stage': 'unknown',
        'q_auction': 'unknown',
      });
      final procedures = container.read(proceduresProvider(kJeonse));
      expect(procedures.first.id, 'proc_decision_apply');
      final sheet = container.read(takeAwaySheetProvider(kJeonse));
      expect(sheet.short.contains('2027'), isFalse);
      expect(sheet.short.contains('고소장 내기'), isFalse,
          reason: '〔먼저 하실 일〕에는 맨 앞 절차 하나만 실립니다');
    });
  });
}

/// 사람에게 보이는 우리 문장. 조문 원문과 검수 메모는 뺀다.
Map<String, String> _userFacing(Domain d) => {
      'name': d.name,
      'description': d.description ?? '',
      for (final q in d.intake) ...{
        'intake.${q.id}.text': q.text,
        'intake.${q.id}.whyAsk': q.whyAsk,
        for (final o in q.options) 'intake.${q.id}.${o.value}': '${o.label} ${o.echo ?? ''}',
      },
      for (final c in d.cautions) ...{
        'cautions.${c.id}.question': c.question,
        'cautions.${c.id}.condition': c.condition,
        'cautions.${c.id}.consequence': c.consequence,
      },
      for (final p in d.procedures) ...{
        'procedures.${p.id}.label': p.label,
        'procedures.${p.id}.whatIsThis': p.whatIsThis,
        'procedures.${p.id}.detail': p.detail ?? '',
        'procedures.${p.id}.caution': p.caution ?? '',
        'procedures.${p.id}.whenApplicable': p.whenApplicable ?? '',
      },
      for (final doc in d.documents) 'documents.${doc.id}': '${doc.label} ${doc.whatIsThis}',
      for (final e in d.emptySections.entries) 'emptySections.${e.key}': e.value.why,
      for (final e in d.plain.entries) 'plain.${e.key}': e.value,
    };
