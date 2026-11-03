import 'dart:convert';

import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

import 'support/domain_assets.dart';

/// 쉬운 말 한 벌과 「이 말을 그대로 보여 주세요」 카드가 **데이터로 잠기는가.**
///
/// 두 가지를 막는다.
///
/// * 쉬운 말이 **조문 원문이나 이름 자리를 가리키는 것.** 조문은 한 글자도
///   못 바꾸고, 기관·서식 이름은 창구에서 그 말을 그대로 써야 한다.
/// * 카드에 **지어낸 이름을 적는 것.** 창구에 그대로 내미는 화면이라
///   틀린 이름은 사람을 엉뚱한 곳에 보낸다.
void main() {
  final loader = DomainLoader(today: const KstDate(2026, 8, 23));

  Map<String, dynamic> workInjury(
    void Function(Map<String, dynamic> json) breakIt,
  ) {
    final json =
        jsonDecode(readDomainJson('work_injury')) as Map<String, dynamic>;
    breakIt(json);
    return json;
  }

  Map<String, dynamic> firstWhereId(List<dynamic> list, String id) =>
      list.cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == id);

  void expectFails(Map<String, dynamic> json, String contains_) {
    expect(
      () => loader.loadFromMap(json),
      throwsA(
        isA<DomainValidationException>().having(
          (e) => e.errors.map((i) => i.message).join(' / '),
          'message',
          contains(contains_),
        ),
      ),
    );
  }

  group('쉬운 말 한 벌 — 키가 가리키는 자리', () {
    test('★ 조문 원문을 가리키면 실패', () {
      expectFails(
        workInjury((j) {
          (j['plain'] as Map<String, dynamic>)
              ['cautions.ct_all_workplaces.legalBasis.text'] = '짧게 쓴 조문';
        }),
        '쉬운 말로 바꿀 수 없는 자리',
      );
    });

    test('★ 기관·서식 이름을 가리키면 실패', () {
      expectFails(
        workInjury((j) {
          (j['plain'] as Map<String, dynamic>)
              ['procedures.proc_care_claim.sayThis'] = '공단';
        }),
        '쉬운 말로 바꿀 수 없는 자리',
      );
    });

    test('없는 항목을 가리키면 실패', () {
      expectFails(
        workInjury((j) {
          (j['plain'] as Map<String, dynamic>)['cautions.ct_없음.condition'] =
              '짧은 문장이에요.';
        }),
        '없습니다',
      );
    });

    test('원래 문장과 똑같으면 실패', () {
      expectFails(
        workInjury((j) {
          final plain = j['plain'] as Map<String, dynamic>;
          plain['cautions.ct_all_workplaces.question'] =
              firstWhereId(j['cautions'] as List<dynamic>, 'ct_all_workplaces')
                  ['question'];
        }),
        '원래 문장과 똑같습니다',
      );
    });

    test('빈 문장이면 실패', () {
      expectFails(
        workInjury((j) {
          (j['plain'] as Map<String, dynamic>)
              ['cautions.ct_all_workplaces.question'] = '   ';
        }),
        '쉬운 문장이 비어 있습니다',
      );
    });

    test('한 벌이 아예 없어도 통과한다', () {
      final domain = loader.loadFromMap(workInjury((j) => j.remove('plain')));
      expect(domain.plain, isEmpty);
    });
  });

  group('★ 창구에 내미는 이름은 지어 쓸 수 없다', () {
    test('그 절차의 글에 없는 기관 이름이면 실패', () {
      expectFails(
        workInjury((j) {
          firstWhereId(j['procedures'] as List<dynamic>, 'proc_care_claim')
              ['sayThis'] = {'agency': '고용노동부 산재과'};
        }),
        '지어 쓸 수 없습니다',
      );
    });

    test('그 절차의 글에 없는 서식 이름이면 실패', () {
      expectFails(
        workInjury((j) {
          firstWhereId(j['procedures'] as List<dynamic>, 'proc_care_claim')
              ['sayThis'] = {
            'agency': '근로복지공단',
            'form': '산업재해 요양신청서',
          };
        }),
        '지어 쓸 수 없습니다',
      );
    });

    test('이름이 비면 실패', () {
      expectFails(
        workInjury((j) {
          firstWhereId(j['procedures'] as List<dynamic>, 'proc_care_claim')
              ['sayThis'] = {'agency': '  '};
        }),
        '이름이 비어 있습니다',
      );
    });

    test('★ 이름은 조문에서 온다 — 셋 다 근거가 있다', () {
      final domain =
          loader.loadFromMap(jsonDecode(readDomainJson('work_injury')));
      final names = {
        for (final p in domain.procedures)
          if (p.sayThis case final SayThis say) p.id: say.agency,
      };
      expect(names, {
        'proc_care_claim': '근로복지공단',
        'proc_review': '근로복지공단',
        'proc_rereview': '산업재해보상보험재심사위원회',
      });
    });

    test('★ 「공단」이라고만 쓴 조문에는 이름을 정하는 조문이 함께 붙는다', () {
      // 제103조 제1항은 「공단에 심사 청구를 할 수 있다」까지만 적는다.
      // 그 이름이 무엇인지는 제10조가 정한다 — 하나만 달면 「근로복지공단」이
      // 근거 없이 떠 있게 된다.
      final domain =
          loader.loadFromMap(jsonDecode(readDomainJson('work_injury')));
      for (final id in const ['proc_care_claim', 'proc_review']) {
        final p = domain.procedures.firstWhere((e) => e.id == id);
        expect(
          [for (final b in p.alsoBasis) b.article],
          contains('제10조'),
          reason: '$id 에 이름을 정하는 조문이 없습니다',
        );
      }
    });

    test('★ 서식 이름이 없는 절차는 그 사실을 openPart 로 적는다', () {
      final domain =
          loader.loadFromMap(jsonDecode(readDomainJson('work_injury')));
      for (final id in const ['proc_review', 'proc_rereview']) {
        final p = domain.procedures.firstWhere((e) => e.id == id);
        expect(p.sayThis?.form, isNull);
        expect(p.verification.openPart, contains('서식 이름'));
      }
    });
  });
}
