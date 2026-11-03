import 'dart:convert';

import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

import 'support/domain_assets.dart';

/// **결과에 나오는 모든 용어는 일상어 풀이를 갖는다.**
///
/// 인지대·송달료·지급명령·관할을 아는 사람은 이 앱이 필요 없다.
/// `Question` 에 `whyAsk` 가 있듯 결과 쪽에는 `whatIsThis` 가 있어야 한다.
void main() {
  final loader = DomainLoader(today: const KstDate(2026, 8, 15));

  Map<String, dynamic> brokenDebtRecovery(
    void Function(Map<String, dynamic> json) breakIt,
  ) {
    final json =
        jsonDecode(readDomainJson('debt_recovery')) as Map<String, dynamic>;
    breakIt(json);
    return json;
  }

  Map<String, dynamic> firstWhereId(List<dynamic> list, String id) =>
      list.cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == id);

  group('빌드를 멈춰야 하는 것', () {
    for (final list in SchemaValidator.plainLanguageLists) {
      test('$list 에 whatIsThis 가 없으면 실패', () {
        final json = brokenDebtRecovery((j) {
          final items = j[list] as List<dynamic>;
          (items.first as Map<String, dynamic>).remove('whatIsThis');
        });
        expect(
          () => loader.loadFromMap(json),
          throwsA(
            isA<DomainValidationException>().having(
              (e) => e.errors.first.message,
              'message',
              contains('whatIsThis'),
            ),
          ),
        );
      });
    }

    test('whatIsThis 가 40자를 넘으면 실패', () {
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['costs'] as List<dynamic>, 'cost_stamp_fee')
                ['whatIsThis'] =
            '이 설명은 마흔 글자를 넘기려고 일부러 길게 늘여 쓴 문장이며 이렇게 길면 읽는 사람이 끝까지 못 읽습니다';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('${SchemaValidator.whatIsThisMaxLength}자'),
          ),
        ),
      );
    });

  });

  group('선택지 풀이는 선택 사항이다', () {
    test('없어도 빌드가 깨지지 않는다', () {
      final json = brokenDebtRecovery((j) {
        for (final question in (j['intake'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          for (final option
              in (question['options'] as List<dynamic>? ?? const [])
                  .cast<Map<String, dynamic>>()) {
            option.remove('whatIsThis');
          }
        }
      });
      expect(() => loader.loadFromMap(json), returnsNormally);
    });

    test('적었다면 길이는 지킨다', () {
      final json = brokenDebtRecovery((j) {
        final question = firstWhereId(j['intake'] as List<dynamic>, 'q_demanded');
        final options = (question['options'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        options.first['whatIsThis'] =
            '선택지 설명도 마흔 글자를 넘으면 안 됩니다 왜냐하면 선택지는 훑어보는 것이지 읽는 것이 아니기 때문입니다';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(isA<DomainValidationException>()),
      );
    });
  });

  group('실제 데이터', () {
    test('결과에 나오는 모든 항목이 풀이를 갖는다', () {
      final domain =
          loader.loadFromJsonString(readDomainJson('debt_recovery'));

      final items = <(String, String, String)>[
        for (final i in domain.costs) ('costs', i.id, i.whatIsThis),
        for (final i in domain.documents) ('documents', i.id, i.whatIsThis),
        for (final i in domain.deadlines) ('deadlines', i.id, i.whatIsThis),
        for (final i in domain.procedures) ('procedures', i.id, i.whatIsThis),
      ];

      expect(items, isNotEmpty);
      for (final (list, id, whatIsThis) in items) {
        expect(whatIsThis, isNotEmpty, reason: '$list.$id 에 풀이가 없습니다');
        expect(
          whatIsThis.runes.length,
          lessThanOrEqualTo(SchemaValidator.whatIsThisMaxLength),
          reason: '$list.$id 의 풀이가 너무 깁니다',
        );
      }
    });

    test('제목 자리는 언제나 공식 용어다', () {
      // 쉬운 말로 이름을 갈아치우면 사용자가 전자소송·법원 창구·받은 서류에서
      // 그 이름을 다시 찾지 못한다. 쉬운 말은 부제 자리에만 둔다.
      final domain =
          loader.loadFromJsonString(readDomainJson('debt_recovery'));

      expect(domain.costById('cost_stamp_fee')?.label, '인지대');
      expect(
        domain.procedures.map((p) => p.label),
        contains('지급명령 (독촉절차)'),
      );
    });

    test('절차는 label 을 쓴다 (name 이 아니다)', () {
      // 타입마다 이름이 다르면 검증기가 새어 나간다.
      final domain =
          loader.loadFromJsonString(readDomainJson('debt_recovery'));
      for (final procedure in domain.procedures) {
        expect(procedure.label, isNotEmpty);
      }
    });
  });
}
