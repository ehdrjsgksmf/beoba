import 'dart:convert';

import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

import 'support/domain_assets.dart';

/// 실제 도메인 JSON 을 읽어 한 군데만 망가뜨린다.
Map<String, dynamic> brokenDebtRecovery(
  void Function(Map<String, dynamic> json) breakIt,
) {
  final json = jsonDecode(readDomainJson('debt_recovery')) as Map<String, dynamic>;
  breakIt(json);
  return json;
}

Map<String, dynamic> firstWhereId(List<dynamic> list, String id) =>
    list.cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == id);

void main() {
  final loader = DomainLoader(today: const KstDate(2026, 8, 15));

  group('SchemaValidator — 빌드를 멈춰야 하는 것', () {
    test('whyAsk 가 비면 실패', () {
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['intake'] as List<dynamic>, 'q_amount')['whyAsk'] = '   ';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          // **첫 줄만 보지 않는다.** 같은 자리를 두 검사가 함께 잡을 수 있다 —
          // 쉬운 말 한 벌이 그 `whyAsk` 를 대신하고 있으면 「대신할 원래 문장이
          // 비었다」가 먼저 걸린다. 둘 다 맞는 말이라 어느 쪽이 먼저 서는지로
          // 검사가 갈리면 안 된다. **재는 것은 순서가 아니라 걸렸는가다.**
          isA<DomainValidationException>().having(
            (e) => e.errors.map((x) => x.message).join(' '),
            'errors',
            contains('whyAsk'),
          ),
        ),
      );
    });

    test('40자를 놓아 주면서 이유를 안 적으면 실패', () {
      // **일부러 놓아 준 것과 그냥 긴 것은 데이터에서 똑같이 생겼다.**
      // 한 줄을 요구해야 그 둘이 갈린다 — expectsEveryDomain 의 skipped 와
      // 같은 꼴이다.
      final json = brokenDebtRecovery((j) {
        j['plainLongOk'] = <String, dynamic>{
          'intake.q_role.whyAsk': '   ',
        };
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.map((x) => x.message).join(' '),
            'errors',
            contains('왜 40자 규칙을 놓아 주는지'),
          ),
        ),
      );
    });

    test('쉬운 문장이 없는 자리를 놓아 주려 하면 실패', () {
      final json = brokenDebtRecovery((j) {
        j['plainLongOk'] = <String, dynamic>{
          'cautions.ct_court_document.question': '열거를 담은 문장이다',
        };
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.map((x) => x.message).join(' '),
            'errors',
            contains('plain 에 없는 자리입니다'),
          ),
        ),
      );
    });

    group('★ 이 길을 만드는 법 — pathLaw / noPathLaw (281)', () {
      Map<String, dynamic> procedureOfDebt(
        String id,
        void Function(Map<String, dynamic> p) breakIt,
      ) =>
          brokenDebtRecovery((j) {
            breakIt(firstWhereId(j['procedures'] as List<dynamic>, id));
          });

      void expectsError(Map<String, dynamic> json, String fragment) {
        expect(
          () => loader.loadFromMap(json),
          throwsA(
            isA<DomainValidationException>().having(
              (e) => e.errors.map((x) => x.message).join(' '),
              'errors',
              contains(fragment),
            ),
          ),
        );
      }

      test('noPathLaw 이유가 비면 실패', () {
        expectsError(
          procedureOfDebt('proc_evidence', (p) {
            p.remove('noPathLaw');
            p['noPathLaw'] = '  ';
          }),
          '왜 이 길을 만드는 법이 없는지',
        );
      });

      test('pathLaw 와 noPathLaw 를 같이 적으면 실패', () {
        expectsError(
          procedureOfDebt('proc_lawsuit', (p) {
            p['noPathLaw'] = '법이 정한 절차가 아니다';
          }),
          '둘 중 하나만 둡니다',
        );
      });

      test('pathLaw 에 조문 원문이 없으면 실패 — 화면엔 이름만 나가도', () {
        expectsError(
          procedureOfDebt('proc_lawsuit', (p) {
            (p['pathLaw'] as Map<String, dynamic>).remove('text');
          }),
          '조문 원문까지 적습니다',
        );
      });

      test('★ legalBasis 와 같은 법을 pathLaw 로 적으면 실패 — 비우고 장부에', () {
        expectsError(
          procedureOfDebt('proc_payment_order', (p) {
            p['pathLaw'] = Map<String, dynamic>.of(
                p['legalBasis'] as Map<String, dynamic>);
          }),
          'legalBasis 와 같은 조문입니다',
        );
      });

      test('같은 법이어도 조가 다르면 둔다 — 문장의 근거와 길의 근거가 다른 자리', () {
        // 조문 글을 여기 손으로 쓰지 않는다 — 같은 절차가 이미 들고 있는
        // 같은 법의 다른 조(alsoBasis)를 그대로 옮겨 쓴다.
        final json = procedureOfDebt('proc_payment_order', (p) {
          final sameLawOtherArticle = (p['alsoBasis'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .firstWhere((b) =>
                  b['law'] == (p['legalBasis'] as Map)['law'] &&
                  b['article'] != (p['legalBasis'] as Map)['article']);
          p['pathLaw'] = Map<String, dynamic>.of(sameLawOtherArticle);
        });
        expect(
          () => loader.loadFromMap(json),
          isNot(throwsA(isA<DomainValidationException>().having(
            (e) => e.errors.map((x) => x.message).join(' '),
            'errors',
            contains('같은 조문입니다'),
          ))),
        );
      });
    });

    group('★ 카드는 근거 없이 못 선다 (274)', () {
      Map<String, dynamic> cautionOfDebt(
        void Function(Map<String, dynamic> c) breakIt,
      ) =>
          brokenDebtRecovery((j) {
            final c = firstWhereId(j['cautions'] as List<dynamic>, 'ct_response_will_pay');
            breakIt(c);
          });

      void expectsError(Map<String, dynamic> json, String fragment) {
        expect(
          () => loader.loadFromMap(json),
          throwsA(
            isA<DomainValidationException>().having(
              (e) => e.errors.map((x) => x.message).join(' '),
              'errors',
              contains(fragment),
            ),
          ),
        );
      }

      test('조문도 기관 안내도 없고 noBasis 도 없으면 실패', () {
        expectsError(
          cautionOfDebt((c) {
            c.remove('legalBasis');
            c.remove('alsoBasis');
          }),
          '조문도 기관 안내도 없습니다',
        );
      });

      test('noBasis 이유가 비면 실패', () {
        expectsError(
          cautionOfDebt((c) {
            c.remove('legalBasis');
            c.remove('alsoBasis');
            c['noBasis'] = '   ';
          }),
          '왜 근거 없이 서는지 적어 주세요',
        );
      });

      test('★ 법 이야기를 하면서 noBasis 를 적으면 실패', () {
        // 이유를 지어내서 통과시키는 길을 막는다(272).
        expectsError(
          cautionOfDebt((c) {
            c.remove('legalBasis');
            c.remove('alsoBasis');
            c['noBasis'] = '창구로 보내기만 하는 카드다';
            c['consequence'] = '법에 그렇게 적혀 있어요.';
          }),
          '법 이야기를 하면 근거가 있어야 합니다',
        );
      });

      test('★ 쉬운 말 한 벌도 같이 본다', () {
        // 보통은 조용한데 쉬운 말에서 법 이야기를 하는 자리가 실제로 있었다(273).
        expectsError(
          brokenDebtRecovery((j) {
            final c = firstWhereId(
                j['cautions'] as List<dynamic>, 'ct_response_will_pay');
            c.remove('legalBasis');
            c.remove('alsoBasis');
            c['noBasis'] = '창구로 보내기만 하는 카드다';
            c['consequence'] = '혼자 감당하지 않으셔도 돼요.';
            (j['plain'] as Map<String, dynamic>)[
                'cautions.ct_response_will_pay.consequence'] = '조문에 그렇게 나와요.';
          }),
          '법 이야기를 하면 근거가 있어야 합니다',
        );
      });

      test('근거가 있는데 noBasis 도 적으면 실패', () {
        expectsError(
          cautionOfDebt((c) {
            c['noBasis'] = '창구로 보내기만 하는 카드다';
          }),
          '둘 중 하나만 둡니다',
        );
      });

      test('기관 안내가 조문 자리를 대신한다', () {
        // ★ 조문 없이도 선다. 그것이 이 칸을 연 까닭이다.
        final json = cautionOfDebt((c) {
          c.remove('legalBasis');
          c.remove('alsoBasis');
          c['notice'] = <String, dynamic>{
            'agency': '국토교통부',
            'checkedAt': '2026-09-16',
            'dateScope': 'visited',
            'dataset': '전세사기피해자 지원 안내',
          };
        });
        final domain = loader.loadFromMap(json);
        final c = domain.cautions.firstWhere((x) => x.id == 'ct_response_will_pay');
        expect(c.legalBasis, isNull);
        expect(c.notice?.agency, '국토교통부');
        expect(c.notice?.sentence, contains('법에 적힌 게 아니라'));
      });

      test('★ 「법원」은 법 이야기가 아니다', () {
        // 창구로 보내는 카드가 「법원 서류를 받았는데」라고 쓰는 것은 주장이 아니다.
        final json = cautionOfDebt((c) {
          c.remove('legalBasis');
          c.remove('alsoBasis');
          c['noBasis'] = '창구로 보내기만 하는 카드다';
          c['consequence'] = '법원에서 받은 서류가 있으시면 아래 창구에서 확인해 보세요.';
        });
        expect(() => loader.loadFromMap(json), returnsNormally);
      });
    });

    test('갈래에 구분이 없으면 실패', () {
      // 구분(label)은 조문 원문이고 detail 은 그 칸의 값이다. 하나가 비면
      // 「어느 칸인지 모르는 금액」이 화면에 나간다.
      final json = jsonDecode(readDomainJson('deposit_return'))
          as Map<String, dynamic>;
      final caution =
          firstWhereId(json['cautions'] as List<dynamic>, 'ct_small_deposit');
      (caution['variants'] as List<dynamic>).cast<Map<String, dynamic>>()
          .first['label'] = '  ';
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('label'),
          ),
        ),
      );
    });

    test('안내에 물음이 없으면 실패', () {
      // 「달라질 수 있는 것」은 물음 버튼으로 나간다. 물음이 없으면 그릴 수 없다.
      // condition 을 대신 넣으면 조건절이 버튼에 들어가고, 화면이 어미를 붙이는
      // 옛 버그가 그 자리에서 되살아난다 (DECISIONS 78).
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['cautions'] as List<dynamic>, 'ct_certified_mail_six_months')
            ['question'] = '  ';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('question'),
          ),
        ),
      );
    });

    test('갈래에는 물음을 요구하지 않는다', () {
      // jurisdictionGuide.branches 도 Caution 이지만 물음이 아니라 갈래다.
      // 셋을 나란히 보여주는 것이 그쪽 규칙이다 (DECISIONS 72).
      final json = brokenDebtRecovery((j) {
        for (final branch
            in (j['jurisdictionGuide'] as Map<String, dynamic>)['branches']
                as List<dynamic>) {
          (branch as Map<String, dynamic>).remove('question');
        }
      });
      expect(() => loader.loadFromMap(json), returnsNormally);
    });

    test('날짜 질문에 dateRange 가 없으면 실패', () {
      // 기본값을 두지 않는다. 기본값이 있으면 새 날짜 질문이 아무 제약 없이
      // 조용히 들어오고, 그게 기한 계산에 쓰이면 아무도 모른다.
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['intake'] as List<dynamic>, 'q_demand_date')
            .remove('dateRange');
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('dateRange'),
          ),
        ),
      );
    });

    test('dateRange 값이 어휘에 없으면 실패', () {
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['intake'] as List<dynamic>, 'q_due_date')['dateRange'] =
            'yesterday';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(isA<DomainValidationException>()),
      );
    });

    test('기한에 tests[] 가 없으면 실패', () {
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['deadlines'] as List<dynamic>, 'dl_answer')['tests'] = [];
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('tests[]'),
          ),
        ),
      );
    });

    test('비용에 tests[] 가 없으면 실패', () {
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['costs'] as List<dynamic>, 'cost_stamp_fee')
            .remove('tests');
      });
      expect(() => loader.loadFromMap(json), throwsA(isA<DomainValidationException>()));
    });

    test('critical 기한이 needs_check 면 실패 — unverified 와 달리 제거되지 않는다', () {
      final json = brokenDebtRecovery((j) {
        final deadline = firstWhereId(j['deadlines'] as List<dynamic>, 'dl_answer');
        (deadline['verification'] as Map<String, dynamic>)['status'] = 'needs_check';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('critical'),
          ),
        ),
      );
    });

    test('verification 이 없으면 실패', () {
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['documents'] as List<dynamic>, 'doc_contract')
            .remove('verification');
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('verification'),
          ),
        ),
      );
    });

    test('기한에 legalBasis 가 없으면 실패', () {
      final json = brokenDebtRecovery((j) {
        firstWhereId(j['deadlines'] as List<dynamic>, 'dl_answer')
            .remove('legalBasis');
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('legalBasis'),
          ),
        ),
      );
    });

    test('id 가 중복되면 실패', () {
      final json = brokenDebtRecovery((j) {
        final costs = j['costs'] as List<dynamic>;
        costs.add(Map<String, dynamic>.from(costs.first as Map));
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('중복'),
          ),
        ),
      );
    });
  });

  group('SchemaValidator — quote scope 면제는 검수된 데이터에만', () {
    test('BrokerAlert 에 verification 이 없으면 실패한다', () {
      final json = jsonDecode(readDomainJson('_shared_crisis')) as Map<String, dynamic>;
      firstWhereId(json['brokerAlerts'] as List<dynamic>, 'ba_upfront_fee')
          .remove('verification');
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('검수한 데이터'),
          ),
        ),
      );
    });

    test('LimitRule 에 verification 이 없으면 실패한다', () {
      final json = jsonDecode(readDomainJson('_shared_crisis')) as Map<String, dynamic>;
      firstWhereId(json['limitRules'] as List<dynamic>, 'lr_brokerage_fee')
          .remove('verification');
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('검수한 데이터'),
          ),
        ),
      );
    });

    test('inputs 의 label 이 비면 실패한다', () {
      final json = jsonDecode(readDomainJson('_shared_crisis')) as Map<String, dynamic>;
      final rule = firstWhereId(json['limitRules'] as List<dynamic>, 'lr_brokerage_fee');
      ((rule['inputs'] as List<dynamic>).first as Map<String, dynamic>)['label'] =
          '   ';
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.path,
            'path',
            endsWith('.inputs[0].label'),
          ),
        ),
      );
    });

    test('inputs 가 옛 문자열 배열이면 실패한다', () {
      final json = jsonDecode(readDomainJson('_shared_crisis')) as Map<String, dynamic>;
      firstWhereId(json['limitRules'] as List<dynamic>, 'lr_brokerage_fee')['inputs'] =
          ['transactionAmount', 'dealType'];
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            contains('{ field, label }'),
          ),
        ),
      );
    });
  });

  group('SchemaValidator — 질문 문구의 법률 수치', () {
    test('금액·기간·조문·비율을 찾아낸다', () {
      expect(SchemaValidator.findLegalNumber('3,000만원 이하면'), '3,000만원');
      expect(SchemaValidator.findLegalNumber('30일 이내에'), '30일');
      expect(SchemaValidator.findLegalNumber('3개월 안에'), '3개월');
      expect(SchemaValidator.findLegalNumber('제1조의2 기준'), '제1조');
      expect(SchemaValidator.findLegalNumber('연 20% 초과'), '20%');
      expect(SchemaValidator.findLegalNumber('1억원까지'), '1억원');
    });

    test('수치가 없는 문구는 그냥 넘어간다', () {
      expect(SchemaValidator.findLegalNumber('어떤 돈을 받지 못하고 계신가요?'), isNull);
      expect(SchemaValidator.findLegalNumber('일부만 주겠다고 합니다'), isNull);
      expect(SchemaValidator.findLegalNumber('상대방은 어떤 사람인가요?'), isNull);
    });

    test('법률 수치가 있는데 verification 이 없으면 실패', () {
      // q_amount 의 whyAsk 에 '3,000만원' 이 있다. 검수 기록을 떼어 내면
      // 그 수치는 출처 없는 숫자가 되므로 로드가 실패해야 한다.
      final json = brokenDebtRecovery((j) {
        final question = firstWhereId(j['intake'] as List<dynamic>, 'q_amount')
          ..remove('verification');
        question['whyAsk'] = '3,000만원 이하면 더 간단한 절차를 쓸 수 있습니다.';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.message,
            'message',
            allOf(contains('법률 수치'), contains('3,000만원')),
          ),
        ),
      );
    });

    test('선택지 라벨에 들어가도 잡는다', () {
      final json = brokenDebtRecovery((j) {
        final question =
            firstWhereId(j['intake'] as List<dynamic>, 'q_debtor_response');
        (question['options'] as List<dynamic>).cast<Map<String, dynamic>>()
            .first['label'] = '30일 안에 준다고 합니다';
      });
      expect(
        () => loader.loadFromMap(json),
        throwsA(
          isA<DomainValidationException>().having(
            (e) => e.errors.first.path,
            'path',
            contains('q_debtor_response.verification'),
          ),
        ),
      );
    });

    test('수치 없는 질문에는 verification 을 요구하지 않는다', () {
      // 문구에 법률 수치가 든 질문만 근거를 진다.
      //   q_seizure_when — 「2026년 2월」. 시행령 부칙 제2조의 적용례다
      //   q_amount       — 「3,000만원」. 소액사건심판규칙 제1조의2 다
      final domain = loader.loadFromJsonString(readDomainJson('debt_recovery'));
      final withVerification =
          domain.intake.where((q) => q.verification != null).map((q) => q.id);
      expect(withVerification, ['q_seizure_when', 'q_amount']);
    });

    test('q_amount 와 proc_small_claim 은 같은 규칙에 기대므로 상태가 같이 간다', () {
      // 규칙 원문을 못 받았을 때 둘을 함께 내렸고, 받은 뒤 함께 되돌렸다.
      // 하나는 내리고 하나는 verified 로 두면 그게 더 이상하다 (DECISIONS 73·76번).
      final domain = loader.loadFromJsonString(readDomainJson('debt_recovery'));
      final question = domain.questionById('q_amount')!;
      final procedure =
          domain.procedures.firstWhere((p) => p.id == 'proc_small_claim');

      expect(question.verification!.status, VerificationStatus.verified);
      expect(question.verification!.source, contains('소액사건심판규칙'));
      expect(question.whyAsk, contains('3,000만원'));
      expect(procedure.verification.status, VerificationStatus.verified);
    });
  });

  group('SchemaValidator — 경고만 내는 것', () {
    test('검수 후 180일이 지나면 경고', () {
      final staleLoader = DomainLoader(today: const KstDate(2027, 8, 15));
      staleLoader.loadFromJsonString(readDomainJson('debt_recovery'));
      expect(
        staleLoader.lastReport.warnings.map((w) => w.message).join(),
        contains('재검수'),
      );
    });

    test('오늘 검수한 데이터는 경고가 없다', () {
      final freshLoader = DomainLoader(today: const KstDate(2026, 8, 15));
      freshLoader.loadFromJsonString(readDomainJson('debt_recovery'));
      expect(
        freshLoader.lastReport.warnings.where((w) => w.message.contains('재검수')),
        isEmpty,
      );
    });
  });
}
