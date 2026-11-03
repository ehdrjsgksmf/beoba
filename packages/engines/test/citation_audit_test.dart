import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// 인용 점검이 **무엇을 잡고 무엇을 못 잡는지** 하나씩 보여 준다.
///
/// 규칙마다 그 규칙을 만든 사례를 넣는다. 사례를 못 잡으면 규칙이 헛도는
/// 것이다 — 처음 규칙이 실제로 `ct_before_moving` 을 놓쳤다(269번).
void main() {
  CitationRow row(String law, List<(String, String)> ours) => CitationRow(
        domain: 'd',
        where: 'cautions.c',
        kind: 'legalBasis',
        cite: '어느 법 제1조',
        lawText: law,
        ours: [for (final (text, mode) in ours) OurLine('consequence', text, mode)],
      );

  group('인용 점검 — 우리 문장이 조문을 넘는가', () {
    const art3 = '주택의 인도와 주민등록을 마친 때에는 그 다음 날부터 제삼자에 대하여 '
        '효력이 생긴다.';
    const art3of3 = '임차권등기 이전에 이미 대항력이나 우선변제권을 취득한 경우에는 그 '
        '대항력이나 우선변제권은 그대로 유지되며, …';
    const said = '제삼자에 대한 효력은 살고 있고 주민등록이 되어 있어야 유지된다고 '
        '법에 있어요.';

    test('★ 조문에 없는 「유지」를 잡는다 (269번의 사례)', () {
      final f = flagCitation(row(art3, [(said, '보통')]));
      expect(f.marks.keys, contains('유지'));
    });

    test('★★ 인용마다 자기 조문과만 대조한다 — 옆 조문의 「유지」에 가려지지 않는다', () {
      // 처음 규칙은 항목의 조문 전부와 대조해서, 옆 조문의 「그대로 유지되며」
      // 때문에 이 문장을 놓쳤다. 인용 하나는 자기 조문 하나와만 본다.
      expect(flagCitation(row(art3, [(said, '보통')])).isEmpty, isFalse);
      expect(flagCitation(row(art3of3, [(said, '보통')])).marks.keys,
          isNot(contains('유지')));
    });

    test('「…」 안은 조문을 옮긴 것이라 안 본다', () {
      final f = flagCitation(row('효력이 생긴다.', [('조문에는 「반드시 한다」라고 적혀 있어요.', '보통')]));
      expect(f.marks.keys, isNot(contains('반드시')));
    });

    test('길 안내 문장은 「할 수 있다」에서 빼고, 뺀 수를 센다', () {
      final f = flagCitation(row('효력이 생긴다.', [('아래 창구에서 확인할 수 있어요.', '쉬운 말')]));
      expect(f.marks.keys, isNot(contains('할 수 있다')));
      expect(f.guided, 1);
    });

    test('길 안내가 아닌 「할 수 있다」는 걸린다', () {
      final f = flagCitation(row('효력이 생긴다.', [('면허를 정지시킬 수 있어요.', '쉬운 말')]));
      expect(f.marks['할 수 있다'], {'쉬운 말'});
    });

    test('조문에 같은 뜻의 말이 있으면 안 걸린다 — 「잃다」와 「상실」', () {
      final f = flagCitation(row('이미 취득한 대항력을 상실하지 아니한다.', [('그 효력을 잃지 않아요.', '보통')]));
      expect(f.isEmpty, isTrue);
    });
  });

  group('단서 — 조문의 재량을 우리가 약속으로 옮겼나', () {
    const law = '장관은 … 정지시킬 것을 요청할 수 있다. 다만, … 생계유지가 곤란할 것으로 '
        '인정되는 경우에는 그러하지 아니하다.';

    test('★ 재량이 약속이 된 것을 (나)가 잡는다 (270번의 사례)', () {
      final p = provisoOf(row(law, [
        ('법에 운전면허의 효력을 정지시킬 것을 요청할 수 있다고 … 인정되는 경우에는 '
            '그러하지 아니하다고 되어 있어요.', '보통'),
        ('단서도 붙어 있어요. 생계를 위해 쓰는 면허면 정지하지 않아요.', '쉬운 말'),
      ]))!;
      expect(p.promised, {'쉬운 말'});
    });

    test('★ (가)는 같은 사례를 못 잡는다 — 「단서도 붙어 있어요」라고 말은 했으니', () {
      // 이게 (나)가 있는 까닭이다. (가)만 믿으면 ct_license 를 놓친다.
      final p = provisoOf(row(law, [('단서도 붙어 있어요. 생계를 위해 쓰는 면허면 정지하지 않아요.', '쉬운 말')]))!;
      expect(p.dropped, isEmpty);
      expect(p.promised, {'쉬운 말'});
    });

    test('「인정되는 경우」를 살리면 안 걸린다', () {
      final p = provisoOf(row(law, [('생계가 곤란하다고 인정되는 경우예요.', '쉬운 말')]))!;
      expect(p.promised, isEmpty);
    });

    test('단서가 없는 조문은 셈에 안 든다', () {
      expect(provisoOf(row('효력이 생긴다.', [('효력이 생겨요.', '보통')])), isNull);
    });
  });

  group('모으기 — 분야 JSON 에서 인용을 뽑는다', () {
    test('legalBasis 하나와 alsoBasis 하나는 인용 둘이다', () {
      final rows = collectCitations('d', {
        'id': 'd',
        'cautions': [
          {
            'id': 'c1',
            'consequence': '효력이 생긴다고 법에 있어요.',
            'legalBasis': {'law': '가법', 'article': '제1조', 'text': '효력이 생긴다.'},
            'alsoBasis': [
              {'law': '가법', 'article': '제2조', 'text': '상실하지 아니한다.'},
            ],
            'verification': {'note': '속 메모 — 안 본다. 반드시.'},
          },
        ],
        'plain': {'cautions.c1.consequence': '효력이 생겨요.'},
      });
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.kind), ['legalBasis', 'alsoBasis']);
      expect(rows.first.key, 'd.cautions.c1');
      // 쉬운 말 한 벌도 같이 모으고, 속 메모는 안 모은다.
      expect(rows.first.ours.map((l) => l.mode), ['보통', '쉬운 말']);
      expect(rows.first.ours.any((l) => l.text.contains('속 메모')), isFalse);
    });
  });

  group('같은 조문 — 두 분야가 인용하면 두 벌이 생긴다 (검사 ak)', () {
    CitationRow at(String domain, String law, String ours) => CitationRow(
          domain: domain,
          where: 'costs.x',
          kind: 'legalBasis',
          cite: '가법 제1조 제1항',
          lawText: law,
          ours: [OurLine('whatIsThis', ours, '보통')],
        );

    const body = '① 수수료는 1건당 5,000원으로 하고, 다음 각 호의 금액으로 한다.';
    const full = '$body 1. 가: 1천원 2. 나: 2천원';

    test('두 분야가 같은 조문을 인용하면 한 자리로 묶인다 — 공통 조각은 뺀다', () {
      final s = sharedCitations([
        at('a', body, '돈'),
        at('b', body, '돈'),
        at('_shared', body, '돈'),
      ]);
      expect(s, hasLength(1));
      expect(s.single.byDomain.keys, ['a', 'b']);
    });

    test('① 발췌 길이만 다르면 괜찮다 — 한쪽이 다른 쪽의 앞부분', () {
      final s = sharedCitations([at('a', body, '돈'), at('b', full, '돈')]).single;
      expect(excerptConflicts(s), isEmpty);
    });

    test('① 항 번호(①)가 붙고 안 붙고는 같은 글로 본다', () {
      final s = sharedCitations([
        at('a', body, '돈'),
        at('b', body.replaceFirst('① ', ''), '돈'),
      ]).single;
      expect(excerptConflicts(s), isEmpty);
    });

    test('① 표의 다른 줄 — 안 겹치면 괜찮다', () {
      final s = sharedCitations([
        at('a', '개인회생사건(개회) 10회', '돈'),
        at('b', '임차권등기명령등사건(카임) 3회', '돈'),
      ]).single;
      expect(excerptConflicts(s), isEmpty);
    });

    test('★ ① 겹치는데 글자가 다르면 걸린다 — 한쪽만 고친 흔적', () {
      final s = sharedCitations([
        at('a', body, '돈'),
        at('b', body.replaceFirst('5,000원', '6,000원'), '돈'),
      ]).single;
      expect(excerptConflicts(s), hasLength(1));
    });

    test('② 분야 사이에 같은 문장이 하나라도 있으면 괜찮다', () {
      final s = sharedCitations([at('a', body, '법원이 서류를 부치는 데 드는 돈이에요'), at('b', body, '법원이 서류를 부치는 데 드는 돈이에요')]).single;
      expect(wordingDiverges(s), isFalse);
    });

    test('★ ② 같은 것을 두 말로 부르면 걸린다', () {
      final s = sharedCitations([at('a', body, '서류를 부치는 데 드는 돈이에요'), at('b', body, '법원이 서류를 부치는 데 드는 돈이에요')]).single;
      expect(wordingDiverges(s), isTrue);
    });
  });
}
