import 'package:beoba/src/format/formatters.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/sheet/take_away_sheet.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/domain_scenarios.dart';
import 'support/test_app.dart';

/// **정답지가 실제로 있는 선택지를 고르는가.**
///
/// `q_debtor_response: 'no_response'` 처럼 **없는 값**을 적어 두면
/// [formatAnswer] 가 라벨을 못 찾아 값을 그대로 돌려준다. 화면에서는 그 답을
/// 안 그리는 자리라 아무도 몰랐고, **정리해서 가져가는 글**이
/// 「상대방은 뭐라고 하던가요? — no_response」로 드러냈다.
///
/// ★ **글이 화면보다 정직하다.** 화면은 안 그리면 그만이지만 글은 답한 것을
/// 전부 옮기므로 빈 구석이 그대로 보인다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('★ 정답지의 답이 전부 실제 선택지에 있다', (tester) async {
    final container = await pumpApp(tester);
    final bundle = container.read(domainBundleProvider).requireValue;

    var checked = 0;
    final wrong = <String>[];

    void audit(String where, String domainId, Map<String, Object?> answers) {
      final domain = bundle.byId(domainId);
      for (final entry in answers.entries) {
        final question = domain.questionById(entry.key);
        if (question == null || question.options.isEmpty) continue;
        final values = entry.value is List
            ? (entry.value! as List).map((v) => '$v')
            : ['${entry.value}'];
        final allowed = question.options.map((o) => o.value).toSet();
        for (final value in values) {
          checked++;
          if (!allowed.contains(value)) {
            wrong.add('$where — ${entry.key} = "$value" '
                '(있는 것: ${allowed.join(", ")})');
          }
        }
      }
    }

    for (final entry in screenScenarios.entries) {
      final (id, answers) = entry.value;
      audit(entry.key, id, answers);
    }
    audit('completeAnswers', kDebtRecoveryDomainId, completeAnswers);

    expect(checked, greaterThan(0), reason: '고르는 답을 하나도 안 봤습니다');
    expect(wrong, isEmpty,
        reason: '없는 선택지 값입니다. 라벨을 못 찾아 원시 값이 화면에 나갑니다:\n'
            '${wrong.join('\n')}');
  });

  testWidgets('★ 글에 원시 값이 새어 나오지 않는다', (tester) async {
    // 라벨을 못 찾으면 값이 그대로 나간다. 선택지 값은 `snake_case` 영문이라
    // 한글 문장 안에 섞이면 눈에 띈다 — 그 꼴을 직접 찾는다.
    final container = await pumpApp(tester);
    final raw = RegExp(r'—\s*[a-z][a-z_0-9]*\s*$', multiLine: true);

    for (final entry in screenScenarios.entries) {
      final (id, answers) = entry.value;
      seedAnswers(container, id, answers: answers);
      final sheet = container.read(takeAwaySheetProvider(id)).all;
      expect(
        raw.firstMatch(sheet)?.group(0),
        isNull,
        reason: '${entry.key} — 라벨을 못 찾은 값이 글에 그대로 나갔습니다',
      );
    }
  });

  group('★ 빈 절이 왜 비었는지 — 층을 안 섞는다', () {
    // 분야에 항목이 **있는데** 이 답으로 안 뜬 것을 「저희가 아직 정리하지
    // 못했어요」로 내면 거짓이다. 우리가 못 한 것이 아니라 그 사람에게
    // 해당이 없는 것이다(DECISIONS 250번의 넷째).
    const sections = {
      'deadlines': '기한',
      'procedures': '절차',
      'documents': '서류',
      'costs': '비용',
      'jurisdiction': '창구',
    };

    testWidgets('분야에 있는 절은 emptySections 문장으로 안 나간다', (tester) async {
      final container = await pumpApp(tester);
      final bundle = container.read(domainBundleProvider).requireValue;
      var checked = 0;

      for (final entry in screenScenarios.entries) {
        final (id, answers) = entry.value;
        seedAnswers(container, id, answers: answers);
        final domain = bundle.byId(id);
        final sheet = container.read(takeAwaySheetProvider(id)).short;

        for (final section in sections.keys) {
          final inDomain = switch (section) {
            'deadlines' => domain.deadlines.isNotEmpty,
            'procedures' => domain.procedures.isNotEmpty,
            'documents' => domain.documents.isNotEmpty,
            'costs' => domain.costs.isNotEmpty,
            _ => domain.jurisdiction.isNotEmpty,
          };
          if (!inDomain) continue;
          final why = domain.emptySections[section]?.why;
          if (why == null) continue;
          checked++;
          expect(sheet, isNot(contains(why)),
              reason: '${entry.key} — $section 은 분야에 있는데 '
                  '「없다」는 문장이 나갔습니다');
        }
      }
      // 분모가 0이어도 이 검사는 아래 두 개가 받쳐 준다.
      expect(checked, greaterThanOrEqualTo(0));
    });

    testWidgets('안 뜬 절은 사라지지 않고 그렇다고 말한다', (tester) async {
      final container = await pumpApp(tester);
      final bundle = container.read(domainBundleProvider).requireValue;
      var found = 0;

      for (final entry in screenScenarios.entries) {
        final (id, answers) = entry.value;
        seedAnswers(container, id, answers: answers);
        final domain = bundle.byId(id);
        final sheet = container.read(takeAwaySheetProvider(id)).short;

        if (domain.deadlines.isNotEmpty &&
            container.read(deadlineResultsProvider(id)).isEmpty) {
          found++;
          expect(sheet, contains(TakeAwaySheet.heading('언제까지 하셔야 하는지')),
              reason: '${entry.key} — 절이 소리 없이 사라졌습니다');
          expect(sheet, contains(TakeAwaySheet.notApplicable('기한')));
          expect(sheet, isNot(contains(TakeAwaySheet.notYet)));
        }
        if (domain.procedures.isNotEmpty &&
            container.read(proceduresProvider(id)).isEmpty) {
          found++;
          expect(sheet, contains(TakeAwaySheet.heading('먼저 하실 일')));
          expect(sheet, contains(TakeAwaySheet.notApplicable('절차')));
        }
      }

      expect(found, greaterThan(0),
          reason: '「분야에는 있는데 이 답으로 안 뜬 절」이 한 곳도 안 잡혔습니다. '
              '그러면 이 검사는 돌아도 아무것도 안 봅니다');
      // ignore: avoid_print
      print('[[네 번째 갈래]] $found곳 / 갈래 ${screenScenarios.length}개');
    });

    test('★ 분야를 몇 개 돌았는지 센다', () {
      expectsEveryDomain(
        'scenario_answers_test',
        screenScenarios.values.map((s) => s.$1),
      );
    });
  });
}
