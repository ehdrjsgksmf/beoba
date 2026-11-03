import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/caution_section.dart';
import 'package:beoba/src/screens/result/take_away_link.dart';
import 'package:beoba/src/screens/result/take_away_screen.dart';
import 'package:beoba/src/sheet/take_away_sheet.dart';
import 'package:beoba/src/widgets/copy_block.dart';
import 'package:domain_data/domain_data.dart' show LegalBasisDisplay;
import 'package:engines/engines.dart' show FixedKstClock, KstDate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/domain_scenarios.dart';
import 'support/test_app.dart';

/// **정리해서 가져가는 글 한 장.**
///
/// 이 글은 화면 밀도 예산 밖이다 — 길어도 된다. 대신 **짧은 것에는 상한이
/// 있다**(1,600자). 카카오톡에 붙고 전화하며 읽혀야 하기 때문이다.
///
/// ★ **근거 절에는 상한이 없다.** 자르면 이 제품이 약속한 것이 없어진다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const workInjury = 'work_injury';
  const answers = <String, Object?>{
    'q_injury_date': KstDate(2026, 8, 1),
    'q_injury_kind': 'work',
    'q_treated_days': 'longer',
  };

  Future<ProviderContainer> open(
    WidgetTester tester, {
    String id = workInjury,
    Map<String, Object?> given = answers,
    bool plain = false,
  }) async {
    final container = await pumpApp(tester);
    if (plain) container.read(plainModeProvider.notifier).toggle();
    seedAnswers(container, id, answers: given);
    container.read(routerProvider).go(Routes.takeAway(id));
    await tester.pumpAndSettle();
    return container;
  }

  group('★ 산재 하나로 끝까지', () {
    testWidgets('결과 화면 맨 아래에 입구가 있다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, workInjury, answers: answers);
      container.read(routerProvider).go(Routes.result(workInjury));
      await tester.pumpAndSettle();

      final link = find.text(TakeAwayLink.label);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.text(TakeAwayScreen.title), findsOneWidget);
    });

    testWidgets('글이 실제로 나온다 — 답한 것이 사실로만 되받힌다', (tester) async {
      final container = await open(tester);
      final sheet = container.read(takeAwaySheetProvider(workInjury));

      // 1절 — **되받는 말이 아니라 물음과 답이다**(DECISIONS 290번).
      // 창구 직원이 읽는 종이에 「~군요」가 다섯 줄 찍히면 고개를 다섯 번
      // 끄덕이는 것으로 읽힌다.
      expect(sheet.short, contains(TakeAwaySheet.heading('제가 말씀드린 것')));
      expect(sheet.short, isNot(contains('군요')));
      final asked = container
          .read(domainBundleProvider)
          .requireValue
          .byId(workInjury)
          .intake
          .singleWhere((q) => q.id == 'q_injury_kind');
      expect(sheet.short, contains('${asked.text} — '));

      // 7절 — 우리끼리 쓰는 말이 아니라 물어볼 질문이 나온다.
      expect(sheet.short, contains('제 평균임금이 얼마로 잡히나요?'));
      expect(sheet.short, isNot(contains('원문 미확보')));
      expect(sheet.short, isNot(contains('openPart')));

      // 꼬리말 — 날짜는 머리글에서 한 번만 말한다. 보내진 글은 박제된다.
      expect(sheet.short, contains('2026년 8월 15일에 정리했어요'));
      expect(sheet.short, isNot(contains('이 날짜를 기준으로 정리한 것이에요.')));
      // **마지막 한마디가 맨 끝이다.** 긴 조문 더미 앞에 있으면 안 읽힌다.
      expect(sheet.short.trimRight(), endsWith(TakeAwaySheet.tail));
      expect(sheet.all.trimRight(), endsWith(TakeAwaySheet.tail));
    });

    testWidgets('★ 빈 절이 「(없음)」으로 안 나간다', (tester) async {
      final container = await open(tester);
      final sheet = container.read(takeAwaySheetProvider(workInjury));

      expect(sheet.short, isNot(contains('(없음)')));
      // 데이터가 왜 비었는지 말한다. 「모른다」와 「없다」를 가른다.
      // **못 세는 까닭이 적힌 절은 그대로 싣는다** — 덜 된 것이 아니라
      // 조문이 그렇게 생긴 것이다(243·248·250번).
      expect(sheet.short, contains('며칠부터 세는지를 저희가 모르기 때문이에요'));

      // ★ **「아직 정리하지 못했어요」는 종이에서 물음이 된다**(290번).
      // 창구에 내미는 종이에 그 말이 두 칸 연달아 있으면 종이가 덜 된 것으로
      // 보인다. 화면에서는 그대로 둔다(268번).
      expect(sheet.short, isNot(contains('아직 정리하지 못했어요')));
      expect(sheet.short, isNot(contains(TakeAwaySheet.heading('챙기실 것'))));
      expect(sheet.short, contains(TakeAwaySheet.notYetAsk['documents']));
    });

    testWidgets('★ 꼬리말 날짜가 오늘이다 — 고정값이 아니다', (tester) async {
      // **이 글은 날짜가 생명이다.** 화면은 열 때마다 최신이지만 보내진
      // 글은 박제된다. 날짜가 하루 어긋나면 D-3 이 D-4 가 되고, 그건 사람을
      // 늦게 보낸다.
      //
      // 시계를 옮겨 두 번 재서 **따라 움직이는지** 본다. 한 번만 재면
      // 상수를 박아 놔도 통과한다.
      final container = await open(tester);
      expect(
        container.read(takeAwaySheetProvider(workInjury)).short,
        contains('2026년 8월 15일에 정리했어요'),
      );

      final later = await pumpApp(tester, clock: const FixedKstClock(
        KstDate(2026, 12, 25),
      ));
      seedAnswers(later, workInjury, answers: answers);
      expect(
        later.read(takeAwaySheetProvider(workInjury)).short,
        contains('2026년 12월 25일에 정리했어요'),
      );
    });

    testWidgets('근거는 고를 때만 붙는다', (tester) async {
      final container = await open(tester);
      final sheet = container.read(takeAwaySheetProvider(workInjury));

      // ★ **조문 이름은 기본으로 실린다. 고를 때 붙는 것은 원문이다**(290번).
      // 전문을 다 실으면 양육비에서 글의 3분의 2가 조문이 된다.
      const article = '산업재해보상보험법 제41조 제1항';
      final text = container
          .read(domainBundleProvider)
          .requireValue
          .byId(workInjury)
          .procedures
          .first
          .legalBasis!
          .text!;
      expect(sheet.short, contains(TakeAwaySheet.heading('법에 적힌 것')));
      expect(sheet.short, contains(TakeAwaySheet.basisNote));
      expect(sheet.short, contains(article));
      expect(sheet.short, isNot(contains(text)));
      expect(sheet.all, contains(article));
      expect(sheet.all, contains(text));

      // 화면도 그렇다. 기본은 이름까지다.
      expect(find.textContaining(text), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.textContaining(text), findsWidgets);
    });
  });

  group('복사와 되돌림', () {
    testWidgets('누르면 글이 통째로 넘어간다', (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final container = await open(tester);
      final sheet = container.read(takeAwaySheetProvider(workInjury));

      await tester.ensureVisible(find.text(CopyBlock.copy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CopyBlock.copy));
      await tester.pumpAndSettle();

      expect((calls.single.arguments as Map)['text'], sheet.short);
      expect(find.text(CopyBlock.copied), findsOneWidget);
    });

    testWidgets('★ 막히면 말하고, 글자는 원래부터 고를 수 있다', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'copy_fail');
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await open(tester);
      // 글 자체가 이미 고를 수 있는 상태다 — 복사를 눌러 보기 전에도 그렇다.
      expect(find.byType(SelectableText), findsWidgets);

      await tester.ensureVisible(find.text(CopyBlock.copy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CopyBlock.copy));
      await tester.pumpAndSettle();

      expect(find.text(CopyBlock.blocked), findsOneWidget);
      expect(find.text(CopyBlock.copy), findsNothing);
    });
  });

  /// **이름 없이 내용만 실린 절이 있는가.**
  ///
  /// 절 이름을 눈으로 세어 찾는 일은 한 번이면 족하다. 글은 빈 줄로 덩이가
  /// 갈리므로 **덩이마다 첫 줄이 이름인지**만 보면 된다.
  ///
  /// ```
  /// 첫 덩이   분야 이름 + 정리한 날      이름표 없음
  /// 가운데    〔이름〕 + 내용            첫 줄이 반드시 〔…〕
  /// 마지막    꼬리말 두 줄               이름표 없음 — 절이 아니라 마지막 한마디
  /// ```
  ///
  /// `emptySections` 가 `none` 인 절은 덩이째 안 나오므로 셀 것이 없고,
  /// `notYet` 인 절은 「아직 정리하지 못했어요」라는 **내용이 있으니** 덩이가
  /// 생기고 이름도 따라온다.
  List<String> orphans(String text) {
    final blocks = text.trim().split('\n\n');
    final bad = <String>[];
    for (var i = 0; i < blocks.length; i++) {
      final lines = blocks[i].split('\n').where((l) => l.trim().isNotEmpty);
      if (lines.isEmpty) continue;
      final head = lines.first;
      final named = head.startsWith('〔') && head.contains('〕');
      final isFirst = i == 0;
      final isLast = i == blocks.length - 1;

      if (isFirst || isLast) {
        // 머리글과 꼬리말에는 이름표가 없어야 한다. 붙으면 그것도 잘못이다.
        if (named) bad.add('이름표가 붙으면 안 되는 자리: $head');
        continue;
      }
      if (!named) bad.add('이름 없이 내용만 있는 덩이: ${lines.first}');
      // 이름만 있고 내용이 없는 덩이는 반대쪽 잘못이다. 같이 본다.
      if (named && lines.length < 2) bad.add('이름만 있고 내용이 없음: $head');
    }
    return bad;
  }

  /// **접기가 걸리는 자리. 이름까지 박아 둔다.**
  ///
  /// 숫자만 세면 「4곳」이 맞는데 자리가 옮겨간 것을 못 본다. 열다섯 번째
  /// 분야가 들어와 5곳이 되면 **늘어난 것이 어디인지**가 바로 보여야 한다.
  ///
  /// 접기는 `sayThis` 가 있고 `whatIsThis` 가 그 기관·서식 이름을 되풀이할
  /// 때만 걸린다(DECISIONS 268번).
  const folds = <String>{
    '일하다 다쳤을 때 · 보통',
    '일하다 다쳤을 때 · 쉬운 말',
    '일하다 다쳤을 때 · 잘 모르겠어요 · 보통',
    '일하다 다쳤을 때 · 잘 모르겠어요 · 쉬운 말',
  };

  group('★ 되풀이를 접는다 — 전 분야 × 두 모드', () {
    for (final plain in [false, true]) {
      final mode = plain ? '쉬운 말' : '보통';
      for (final entry in screenScenarios.entries) {
        final key = '${entry.key} · $mode';

        testWidgets('$key — 접힘/그대로가 표와 같다', (tester) async {
          final (id, given) = entry.value;
          final container =
              await open(tester, id: id, given: given, plain: plain);
          final sheet = container.read(takeAwaySheetProvider(id)).short;
          final steps = container.read(proceduresProvider(id));

          final block = sectionBlock(sheet, '먼저 하실 일');
          if (steps.isEmpty || block == null) {
            expect(folds, isNot(contains(key)),
                reason: '$key — 절차가 없는데 접기 표에 적혀 있습니다');
            return;
          }
          final first = steps.first;

          // **글에서 직접 읽는다.** 예측식을 다시 짜면 코드가 아니라
          // 내 셈을 재게 된다.
          final folded = !block.contains(first.whatIsThis);
          expect(
            folded,
            folds.contains(key),
            reason: folded
                ? '$key — 새로 접혔습니다. 접기 표에 이 줄을 넣으세요'
                : '$key — 접기가 멈췄습니다. whatIsThis 가 바뀌었는지 보세요. '
                    '글에 창구 이름이 다시 두 번 나옵니다',
          );

          // ★ **접기가 하는 일을 직접 잰다.** 숫자만 맞고 실제로 안 접혔을
          // 수 있다. 접힌 자리에서 기관 이름은 한 번만 나와야 한다.
          if (folded) {
            if (first.sayThis case final say?) {
              expect(
                countOf(block, say.agency),
                1,
                reason: '$key — 접었는데 기관 이름이 '
                    '${countOf(block, say.agency)}번 나옵니다: ${say.agency}',
              );
            }
          }

          // ★★ **창구에서 말해야 하는 낱말은 한 글자도 안 줄어든다.**
          // 이 제품에서 제일 못 건드릴 것이다 — 접기와 무관하다.
          if (first.sayThis case final say?) {
            expect(block, contains('어디로: ${say.agency}'),
                reason: '$key — sayThis.agency 가 글에서 사라지거나 '
                    '줄었습니다');
            if (say.form case final String form) {
              expect(block, contains('무엇을: $form'),
                  reason: '$key — sayThis.form 이 글에서 사라지거나 '
                      '줄었습니다');
            }
          }
        });
      }
    }

    test('★ 접기 표가 실제 갈래를 가리킨다', () {
      final keys = <String>{
        for (final plain in [false, true])
          for (final name in screenScenarios.keys)
            '$name · ${plain ? '쉬운 말' : '보통'}',
      };
      expect(folds, isNotEmpty);
      expect(folds, everyElement(isIn(keys)),
          reason: '접기 표에 없는 갈래가 적혀 있습니다');
      // 전부 접히거나 전부 안 접히면 이 검사는 아무것도 안 가른다.
      expect(folds.length, lessThan(keys.length));
    });

    test('★ 검사가 비어 있지 않다 — 되풀이를 넣으면 걸린다', () {
      const agency = '근로복지공단';
      const folded = '〔먼저 하실 일〕\n  공단에 요양급여 신청서 내기\n'
          '    어디로: 근로복지공단\n    무엇을: 요양급여 신청서';
      const notFolded = '〔먼저 하실 일〕\n'
          '  공단에 요양급여 신청서 내기 — 근로복지공단에 신청하는 것이에요\n'
          '    어디로: 근로복지공단\n    무엇을: 요양급여 신청서';

      expect(countOf(folded, agency), 1);
      expect(countOf(notFolded, agency), 2);

      // 덩이를 못 찾으면 null 이다 — 절 이름을 바꿨는데 여기만 남는 것을 막는다.
      expect(sectionBlock(folded, '먼저 하실 일'), isNotNull);
      expect(sectionBlock(folded, '없는 절'), isNull);

      // 창구 말이 줄어든 글은 걸려야 한다.
      const shortened = '〔먼저 하실 일〕\n  공단에 요양급여 신청서 내기\n'
          '    어디로: 공단\n    무엇을: 신청서';
      expect(shortened.contains('어디로: $agency'), isFalse);
      expect(shortened.contains('무엇을: 요양급여 신청서'), isFalse);
    });
  });

  group('★ 내용이 실린 절에는 이름이 있다 — 전 분야 × 두 모드', () {
    for (final plain in [false, true]) {
      final mode = plain ? '쉬운 말' : '보통';
      for (final entry in screenScenarios.entries) {
        testWidgets('${entry.key} — $mode · 이름 빠진 절 0개', (tester) async {
          final (id, given) = entry.value;
          final container =
              await open(tester, id: id, given: given, plain: plain);
          final sheet = container.read(takeAwaySheetProvider(id));

          expect(
            orphans(sheet.short),
            isEmpty,
            reason: '${entry.key} · $mode — 절 이름이 빠졌습니다. '
                '내용만 있으면 읽는 사람은 그게 무엇의 목록인지 모릅니다',
          );

          // 나온 이름은 sectionOrder 안에 있고, 순서도 그대로여야 한다.
          final found = <String>[
            for (final line in sheet.short.split('\n'))
              if (line.startsWith('〔') && line.endsWith('〕'))
                line.substring(1, line.length - 1),
          ];
          expect(
            found,
            everyElement(isIn(TakeAwaySheet.sectionOrder)),
            reason: '${entry.key} · $mode — sectionOrder 에 없는 이름이 '
                '글에 있습니다. 두 벌이 어긋났습니다',
          );
          final wanted = TakeAwaySheet.sectionOrder
              .where(found.contains)
              .toList();
          expect(found, wanted,
              reason: '${entry.key} · $mode — 절 순서가 sectionOrder 와 '
                  '다릅니다. 순서가 바뀌면 데이터의 「아래 창구」가 어긋납니다');
        });
      }
    }

    test('★ 검사가 비어 있지 않다 — 이름을 빼면 걸린다', () {
      const good = '일하다 다쳤을 때\n2026년 8월 15일에 정리했어요\n\n'
          '〔제가 말씀드린 것〕\n  어쩌다 다치셨나요? — 일하다가\n\n'
          '〔드는 돈〕\n  드는 돈을 아직 정리하지 못했어요.\n\n'
          '법률 자문이 아니에요.';
      expect(orphans(good), isEmpty);

      // 이름 한 줄을 일부러 뺀다.
      final missing = good.replaceFirst('〔드는 돈〕\n', '');
      expect(orphans(missing), isNotEmpty);

      // 이름만 있고 내용이 없는 쪽도 잡는다.
      final hollow = good.replaceFirst('  드는 돈을 아직 정리하지 못했어요.', '');
      expect(orphans(hollow), isNotEmpty);
    });
  });

  group('★ 마크다운 기호가 글에 남지 않는다 — 전 분야 × 두 모드', () {
    // **카카오톡은 마크다운을 안 읽는다.** `#` 과 `- ` 가 글자 그대로 화면에
    // 남아서 글이 문서처럼 딱딱해진다. 목록은 기호 없이 줄바꿈과 들여쓰기
    // 두 칸으로만 나타낸다(DECISIONS 268번).
    //
    // ★ **근거 절까지 본다.** 조문 원문이 그 안에 들어가는데, 지금 데이터에
    // 줄 첫머리가 `- ` 인 값은 0개다. 언젠가 그런 조문이 들어오면 이 검사가
    // 걸리는데, **그때 고칠 것은 조문이 아니라 이 검사다** — 인용은 자르지
    // 않는다. 예외를 적는 자리를 그때 만든다.
    final bad = RegExp(r'^\s*(#|- )');

    for (final plain in [false, true]) {
      final mode = plain ? '쉬운 말' : '보통';
      for (final entry in screenScenarios.entries) {
        testWidgets('${entry.key} — $mode · 기호 0개', (tester) async {
          final (id, given) = entry.value;
          final container = await open(tester, id: id, given: given, plain: plain);
          final sheet = container.read(takeAwaySheetProvider(id));
          final hits = <String>[
            for (final line in sheet.all.split('\n'))
              if (bad.hasMatch(line)) line,
          ];
          expect(
            hits,
            isEmpty,
            reason: '${entry.key} · $mode — 글에 마크다운 기호가 남았습니다. '
                '카카오톡은 이걸 글자로 보여 줍니다: ${hits.take(3).join(" / ")}',
          );
        });
      }
    }

    test('★ 검사가 비어 있지 않다 — 기호를 넣으면 걸린다', () {
      // 통과만 보고 있으면 정규식이 실제로 무엇을 잡는지 알 수 없다.
      expect(bad.hasMatch('- 기한 하나'), isTrue);
      expect(bad.hasMatch('  - 들여쓴 목록'), isTrue);
      expect(bad.hasMatch('# 머리글'), isTrue);
      expect(bad.hasMatch('  요양급여 신청'), isFalse);
      expect(bad.hasMatch('〔챙기실 것〕'), isFalse);
      // 「2026년 8월 1일 - 2일」처럼 줄 가운데 붙은 것은 목록이 아니다.
      expect(bad.hasMatch('  나홀로소송 - 강제집행'), isFalse);
    });
  });

  group('★ 「D-」가 글에 안 남는다 — 전 분야 × 두 모드', () {
    // 「D-84」는 셈에 익숙한 사람의 말이다(287번). 결과 화면에서는 바꿨는데
    // **이 글과 층 문장만 옛말로 남아 있었다** — 25갈래에서 14번 나왔다.
    for (final plain in [false, true]) {
      final mode = plain ? '쉬운 말' : '보통';
      for (final entry in screenScenarios.entries) {
        testWidgets('${entry.key} — $mode · 0번', (tester) async {
          final (id, given) = entry.value;
          final container =
              await open(tester, id: id, given: given, plain: plain);
          final sheet = container.read(takeAwaySheetProvider(id));
          expect(sheet.all, isNot(contains('D-')),
              reason: '${entry.key} · $mode — formatDDay 를 안 거친 자리가 '
                  '남았습니다');
          // 기한이 뜬 갈래면 사람의 말로 적혀 있다.
          for (final line in container.read(deadlineResultsProvider(id))) {
            expect(sheet.short, contains('${line.label} · '));
          }
        });
      }
    }
  });

  group('★ 근거는 글이 말한 것의 근거다 — 전 분야 × 두 모드', () {
    // ★★ **근거만 올라가고 문장이 없는 자리가 227곳이었다.** 글이 안 한 말의
    // 조문이 글 끝에 서 있으면 읽는 사람은 조문과 글을 맞대 볼 수 없다
    // (DECISIONS 290번).
    test('절 이름이 화면과 같다 — 3층 라벨이 글에서도 그대로다', () {
      expect(TakeAwaySheet.sectionOrder, contains(CautionSection.title));
    });

    for (final plain in [false, true]) {
      final mode = plain ? '쉬운 말' : '보통';
      for (final entry in screenScenarios.entries) {
        testWidgets('${entry.key} — $mode · 말한 것만 선다', (tester) async {
          final (id, given) = entry.value;
          final container =
              await open(tester, id: id, given: given, plain: plain);
          final sheet = container.read(takeAwaySheetProvider(id));
          final cautions = container.read(cautionsProvider(id));
          final cut = sheet.short.contains('앱에서 보실 수 있어요');

          var answered = 0;
          for (final caution in cautions) {
            if (caution.showIf == null) {
              // 늘 뜨는 것 — 물음만 간다. 답은 글에 없다.
              expect(sheet.short, contains(caution.question),
                  reason: '${entry.key} · $mode — ${caution.id} 의 물음이 '
                      '글에 없습니다');
              expect(sheet.all, isNot(contains(caution.consequence)),
                  reason: '${entry.key} · $mode — ${caution.id} 는 그 사람의 '
                      '답과 상관없이 뜬 것인데 답이 글에 실렸습니다');
              continue;
            }
            // 그 답 때문에 뜬 것 — 상한에 걸려 잘린 것이 아니면 실린다.
            if (sheet.short.contains(caution.consequence)) answered++;
          }
          if (!cut) {
            expect(
              answered,
              cautions.where((c) => c.showIf != null).length,
              reason: '${entry.key} · $mode — 자른 것도 없는데 답이 빠졌습니다',
            );
          }

          // 글에 안 실린 절차의 조문은 근거에 안 선다.
          final steps = container.read(proceduresProvider(id));
          for (final skipped in steps.skip(1)) {
            final citation = skipped.legalBasis?.citation;
            if (citation == null) continue;
            if (steps.first.legalBasis?.citation == citation) {
              continue;
            }
            if (steps.first.alsoBasis.any((b) => b.citation == citation)) {
              continue;
            }
            if (cautions.any((c) =>
                c.showIf != null &&
                (c.legalBasis?.citation == citation ||
                    c.alsoBasis.any((b) => b.citation == citation)))) {
              continue;
            }
            if (container
                .read(deadlineResultsProvider(id))
                .any((d) => d.basis.citation == citation ||
                    d.alsoBasis.any((b) => b.citation == citation))) {
              continue;
            }
            expect(sheet.all, isNot(contains(citation)),
                reason: '${entry.key} · $mode — 글은 ${skipped.id} 를 말하지 '
                    '않는데 그 조문이 근거에 서 있습니다');
          }
        });
      }
    }
  });

  group('★ 짧은 것의 상한 — 전 분야 × 두 모드', () {
    // **상한은 내용으로 못 올린다.** 넘치면 절을 줄이는 것이 아니라
    // 그 분야의 문장을 다듬는다. 화면 밀도와 같은 규칙이다(134번).
    //
    // ★ **모드가 축으로 빠져 있었다.** 상한을 보통 말에서만 재고 있었는데,
    // 이 글에는 `description` 과 `whyAsk` 가 그대로 들어간다 — 쉬운 말이
    // 켜지면 **다른 글자 수**가 나간다. 밀도는 이미 배율 × 모드로 재고
    // 있었으므로(`plain_density_test`) 여기만 축이 하나 모자랐다.
    for (final plain in [false, true]) {
      final mode = plain ? '쉬운 말' : '보통';
      for (final entry in screenScenarios.entries) {
        testWidgets('${entry.key} — $mode · 1,600자 안', (tester) async {
          final (id, given) = entry.value;
          final container =
              await open(tester, id: id, given: given, plain: plain);
          final sheet = container.read(takeAwaySheetProvider(id));
          expect(
            sheet.short.length,
            lessThanOrEqualTo(TakeAwaySheet.shortLimit),
            reason: '$id 의 짧은 글이 $mode 에서 ${sheet.short.length}자입니다. '
                '절을 줄이지 말고 문장을 다듬으세요',
          );
        });
      }
    }

    test('★ 분야를 몇 개 돌았는지 센다', () {
      expectsEveryDomain(
        'take_away_test 의 상한 검사',
        screenScenarios.values.map((s) => s.$1),
      );
    });
  });
}

/// 글에서 절 한 덩이를 꺼낸다. 없으면 `null`.
///
/// 글은 빈 줄로 덩이가 갈린다 — 절 이름 검사가 쓰는 것과 같은 규칙이다.
String? sectionBlock(String sheet, String name) {
  for (final block in sheet.trim().split('\n\n')) {
    if (block.startsWith('〔$name〕')) return block;
  }
  return null;
}

/// [needle] 이 [text] 에 몇 번 나오는가.
int countOf(String text, String needle) =>
    needle.isEmpty ? 0 : needle.allMatches(text).length;

