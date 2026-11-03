import 'dart:convert';

import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

/// 한 번에 하나만 맞아야 하는 묶음이 **겹치지도 빠지지도 않는지** 잠근다.
///
/// 겹치면 카드가 두 장 뜨고 사용자는 긴 쪽을 믿는다. 빠지면 조용히 사라진다.
///
/// ## 붙박이를 쓴다
///
/// 예전에는 `debt_recovery` 의 소멸시효 묶음을 빌려 썼다. 그런데 시효를
/// **갈래로 나란히 내기로** 하면서 그 묶음이 사라졌고([DECISIONS 107](#107))
/// 검사도 함께 죽었다. **쓰는 데가 없어졌다고 검사까지 없앨 이유는 없다** —
/// 다음 분야가 묶음을 쓰는 날 이 검사가 그대로 지킨다.
void main() {
  const validator = SchemaValidator();

  /// 묶음을 쓰는 가장 작은 분야 하나.
  Map<String, dynamic> broken(void Function(Map<String, dynamic> json) breakIt) {
    final json = jsonDecode(jsonEncode(_fixture)) as Map<String, dynamic>;
    breakIt(json);
    return json;
  }

  List<Map<String, dynamic>> listOf(Map<String, dynamic> json, String key) =>
      (json[key] as List<dynamic>).cast<Map<String, dynamic>>();

  Map<String, dynamic> statuteGroup(Map<String, dynamic> json) =>
      listOf(json, 'exclusiveGroups').firstWhere((g) => g['id'] == 'statute');

  Map<String, dynamic> statuteDeadline(Map<String, dynamic> json) =>
      listOf(json, 'deadlines')
          .firstWhere((d) => d['id'] == 'dl_statute_general');

  List<SchemaIssue> check(Map<String, dynamic> json) =>
      validator.checkExclusiveGroups(Domain.fromJson(json));

  List<String> errorsOf(Map<String, dynamic> json) => check(json)
      .where((i) => i.isError)
      .map((i) => '${i.path} ${i.message}')
      .toList();

  test('지금 데이터는 통과한다', () {
    expect(errorsOf(broken((_) {})), isEmpty);
  });

  group('겹치면 막는다', () {
    test('두 항목이 같은 값을 맡으면 실패', () {
      // 짧은 쪽이 실제 답인데 두 장을 나란히 보여주면 사용자는 긴 쪽을 믿는다.
      final json = broken((j) {
        final copy = Map<String, dynamic>.from(statuteDeadline(j))
          ..['id'] = 'dl_statute_copy';
        listOf(j, 'deadlines').add(copy);
      });
      expect(errorsOf(json).join(), contains('하나만 맞아야'));
    });

    test('모른다고 적은 값을 동시에 맡으면 실패', () {
      // 둘 중 하나가 거짓말이다.
      final json = broken((j) {
        (statuteGroup(j)['unknownValues'] as List<dynamic>).add('loan');
      });
      expect(errorsOf(json).join(), contains('모르는 값으로도'));
    });
  });

  group('빠지면 막는다', () {
    test('아무도 안 맡는 선택지가 있으면 실패', () {
      // 「그 밖의 돈」이 조용히 빠지는 것이 지금까지 아무도 못 잡던 구멍이다.
      final json = broken((j) {
        (statuteGroup(j)['unknownValues'] as List<dynamic>).remove('other');
      });
      expect(errorsOf(json).join(), contains('other'));
      expect(errorsOf(json).join(), contains('아무도 맡지 않습니다'));
    });

    test('선택지에 없는 값을 맡으면 실패', () {
      // 오타이거나 옛 값이다.
      final json = broken((j) {
        (statuteGroup(j)['unknownValues'] as List<dynamic>).add('없는값');
      });
      expect(errorsOf(json).join(), contains('선택지에 없습니다'));
    });

    test('다른 분야로 넘기는 선택지는 요구하지 않는다', () {
      // deposit · wage 는 redirect 라 이 분야를 떠난다. 여기서 맡을 것이 없다.
      final json = broken((_) {});
      expect(errorsOf(json).join(), isNot(contains('deposit')));
      expect(errorsOf(json).join(), isNot(contains('wage')));
    });
  });

  group('선언과 참조가 어긋나면 막는다', () {
    test('없는 묶음을 가리키면 실패', () {
      final json = broken((j) {
        statuteDeadline(j)['exclusiveGroup'] = 'nope';
      });
      expect(errorsOf(json).join(), contains('선언되지 않은 묶음'));
    });
  });

  group('검사할 수 없는 모양은 **조용히 통과시키지 않는다**', () {
    List<String> warningsOf(Map<String, dynamic> json) => check(json)
        .where((i) => !i.isError)
        .map((i) => '${i.path} ${i.message}')
        .toList();

    test('== · in 이 아니면 경고를 남긴다', () {
      // "검사됐다" 와 "검사 못 했다" 는 구별할 수 있어야 한다.
      final json = broken((j) {
        statuteDeadline(j)['showIf'] = {
          '!=': [
            {'var': 'claimType'},
            'deposit',
          ],
        };
      });
      expect(warningsOf(json).join(), contains('검사하지 못했습니다'));
    });

    test('검사 못 한 묶음은 빠짐도 따지지 않는다', () {
      // 반쪽만 아는 상태로 실패를 내면 고칠 수 없는 오류가 된다.
      final json = broken((j) {
        statuteDeadline(j)['showIf'] = {
          '!=': [
            {'var': 'claimType'},
            'deposit',
          ],
        };
      });
      expect(errorsOf(json).join(), isNot(contains('아무도 맡지 않습니다')));
    });

    test('묶음이 비어 있으면 경고한다', () {
      final json = broken((j) {
        // 묶음에 든 것을 **전부** 뗀다. 하나만 떼면 나머지가 남아 안 빈다.
        for (final deadline in listOf(j, 'deadlines')) {
          deadline.remove('exclusiveGroup');
        }
      });
      expect(warningsOf(json).join(), contains('든 항목이 없습니다'));
    });

    test('기준 필드를 묻는 질문이 없으면 경고한다', () {
      final json = broken((j) {
        statuteGroup(j)['field'] = 'nothingAsksThis';
      });
      expect(warningsOf(json).join(), contains('검사하지 못했습니다'));
    });
  });

  group('거르기 전 데이터를 본다', () {
    test('unverified 여도 맡은 것으로 센다', () {
      // 로더는 `unverified` 를 걷어낸다. 그래도 **아직 확인 안 된 항목**이지
      // **빠뜨린 항목**은 아니다. 둘은 다르다 — 걷어낸 뒤에 세면 묶음이
      // 통째로 비어 「아무도 안 맡았다」로 잘못 잡힌다.
      final json = broken((j) {
        listOf(j, 'deadlines').first['verification'] = <String, dynamic>{
          'status': 'unverified',
          'checkedAt': '2026-08-18',
        };
      });

      expect(errorsOf(json), isEmpty, reason: '거르기 전 데이터를 봐야 한다');

      final loaded = DomainLoader(today: const KstDate(2026, 8, 15))
          .loadFromJsonString(jsonEncode(json));
      expect(
        loaded.deadlines.any((d) => d.id == 'dl_statute_general'),
        isFalse,
        reason: '걸러지는 것이 맞다',
      );
    });
  });
}

/// 소멸시효를 기한으로 다루던 시절의 모양 그대로다. **묶음 검사의 붙박이.**
final Map<String, dynamic> _fixture = <String, dynamic>{
  'id': 'fixture',
  'version': '1.0.0',
  'schemaVersion': 1,
  'name': '붙박이',
  // 분야 이름은 두 층이다 — 작은 글씨가 없으면 스키마가 막는다(194번).
  'searchTerms': ['붙박이', '시효', '채권'],
  'status': 'active',
  'exclusiveGroups': [
    {
      'id': 'statute',
      'field': 'claimType',
      'unknownValues': ['other'],
      'unknownNote': '이 경우는 아직 확인하지 못했어요.',
    },
  ],
  'intake': [
    {
      'id': 'q_claim_type',
      'order': 1,
      'text': '어떤 돈을 받지 못하고 계신가요?',
      'whyAsk': '돈의 성격에 따라 밟을 수 있는 절차가 달라집니다.',
      'type': 'single',
      'field': 'claimType',
      'weight': 2,
      'required': true,
      'options': [
        {'value': 'loan', 'label': '빌려준 돈'},
        {'value': 'goods', 'label': '물건값'},
        {'value': 'other', 'label': '그 밖의 것'},
      ],
    },
  ],
  'deadlines': [
    {
      'id': 'dl_statute_general',
      'exclusiveGroup': 'statute',
      'label': '오래 두면 못 받는 기한',
      'whatIsThis': '너무 오래 두면 달라고 할 수 없게 돼요',
      'severity': 'warning',
      'basisField': 'dueDate',
      'offset': {'value': 10, 'unit': 'year'},
      'calcRule': 'from_basis',
      'showIf': {'==': [{'var': 'claimType'}, 'loan']},
      'appearsWhen': '빌려준 돈일 때 나옵니다',
      'legalBasis': {
        'law': '민법',
        'article': '제162조 제1항',
        'text': '채권은 10년간 행사하지 아니하면 소멸시효가 완성한다.',
        'url': 'https://www.law.go.kr',
      },
      'verification': {'status': 'verified', 'checkedAt': '2026-08-18'},
      'tests': [
        {'basis': '2020-08-15', 'expected': '2030-08-15'},
      ],
    },
    {
      'id': 'dl_statute_goods',
      'exclusiveGroup': 'statute',
      'label': '물건값은 더 짧아요',
      'whatIsThis': '물건값은 더 짧은 기간이 정해져 있어요',
      'severity': 'warning',
      'basisField': 'dueDate',
      'offset': {'value': 3, 'unit': 'year'},
      'calcRule': 'from_basis',
      'showIf': {'==': [{'var': 'claimType'}, 'goods']},
      'appearsWhen': '물건값일 때 나옵니다',
      'legalBasis': {
        'law': '민법',
        'article': '제163조 제6호',
        'text': '다음 각호의 채권은 3년간 행사하지 아니하면 소멸시효가 완성한다.',
        'url': 'https://www.law.go.kr',
      },
      'verification': {'status': 'verified', 'checkedAt': '2026-08-18'},
      'tests': [
        {'basis': '2020-08-15', 'expected': '2023-08-15'},
      ],
    },
  ],
};
