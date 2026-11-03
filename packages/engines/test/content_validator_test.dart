import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

BrokerAlert alertFixture({
  required String id,
  required String phrase,
  required String truth,
}) =>
    BrokerAlert(
      id: id,
      severity: AlertSeverity.red,
      phrase: phrase,
      truth: truth,
      verification: verifiedFixture,
    );

void main() {
  const validator = ContentValidator();

  group('형벌은 조문 없이 말하지 않는다', () {
    const basis = LegalBasis(
      law: '전자금융거래법',
      article: '제49조 제4항',
      text: '다음 각 호의 어느 하나에 해당하는 자는 5년 이하의 징역 또는 '
          '3천만원 이하의 벌금에 처한다.',
    );

    test('근거 없이 징역을 말하면 잡는다', () {
      // 실제로 이러고 있었다 — 「적발 시 부정수급액의 최대 5배 환수와
      // 10년 이하 징역이 따릅니다」가 legalBasis 없이 화면에 있었다.
      final domain = domainFixture().copyWith(
        brokerAlerts: [
          alertFixture(
            id: 'ba_x',
            phrase: '지원금 100% 받아 드립니다',
            truth: '적발 시 부정수급액의 최대 5배 환수와 10년 이하 징역이 따릅니다.',
          ),
        ],
      );

      final issues = validator.validate(domain);
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('근거 조문 없이 형벌'));
    });

    test('죄명을 단정해도 잡는다', () {
      final domain = domainFixture().copyWith(
        brokerAlerts: [
          alertFixture(
            id: 'ba_x',
            phrase: '연체기록 지워 드립니다',
            truth: '돈을 받으면 사기라서 처벌됩니다.',
          ),
        ],
      );
      expect(validator.validate(domain), hasLength(1));
    });

    test('근거가 있으면 통과한다', () {
      final domain = domainFixture().copyWith(
        brokerAlerts: [
          alertFixture(
            id: 'ba_x',
            phrase: '통장만 잠깐 빌려주세요',
            truth: '잔액이 0원이어도 본인이 처벌받습니다.',
          ).copyWith(legalBasis: basis),
        ],
      );
      expect(validator.validate(domain), isEmpty);
    });

    test('alsoBasis 만 있어도 통과한다', () {
      // 숫자가 든 조문과 효과가 든 조문이 갈라져 있는 경우가 흔하다.
      final domain = domainFixture().copyWith(
        brokerAlerts: [
          alertFixture(
            id: 'ba_x',
            phrase: '통장만 잠깐 빌려주세요',
            truth: '잔액이 0원이어도 본인이 처벌받습니다.',
          ).copyWith(alsoBasis: const [basis]),
        ],
      );
      expect(validator.validate(domain), isEmpty);
    });

    test('손해와 창구는 조문이 없어도 말할 수 있다', () {
      // (b) 로 갈 때 남는 문장이 이것이다. 걸리면 안 된다.
      final domain = domainFixture().copyWith(
        brokerAlerts: [
          alertFixture(
            id: 'ba_x',
            phrase: '지원금 100% 받아 드립니다',
            truth: '대행료를 내면 그 돈만 잃습니다. 아래 창구에서 확인해 보세요.',
          ),
        ],
      );
      expect(validator.validate(domain), isEmpty);
    });

    test('안내(Caution)에도 같은 규칙이 걸린다', () {
      final domain = domainFixture().copyWith(
        cautions: [
          const Caution(
            id: 'ct_x',
            question: '이자를 받기로 하셨나요?',
            condition: '이자를 받기로 하셨다면',
            consequence: '상한을 넘겨 받으면 처벌받습니다.',
            verification: verifiedFixture,
          ),
        ],
      );

      final issues = validator.validate(domain);
      expect(issues, hasLength(1));
      expect(issues.single.path, contains('cautions'));
    });
  });

  group('ContentValidator — 앱이 말하는 문구 (strict)', () {
    test('질문의 whyAsk 가 판단으로 읽히면 잡는다', () {
      final domain = domainFixture(
        intake: [
          questionFixture(id: 'q1', order: 1, field: 'f')
              .copyWith(whyAsk: '이 답에 따라 승소 가능성이 달라집니다.'),
        ],
      );
      final issues = validator.validate(domain);
      expect(issues, hasLength(1));
      expect(issues.single.path, contains('whyAsk'));
      expect(issues.single.message, contains('승소'));
    });

    test('절차 설명의 단정 표현을 잡는다', () {
      final domain = domainFixture().copyWith(
        procedures: [
          const Procedure(
            id: 'proc',
            step: 1,
            label: '지급명령',
            whatIsThis: '신청하면 무조건 받을 수 있습니다.',
            verification: verifiedFixture,
          ),
        ],
      );
      expect(validator.validate(domain), hasLength(1));
    });

    test('사실 안내는 통과한다', () {
      final domain = domainFixture(
        intake: [questionFixture(id: 'q1', order: 1, field: 'f')],
        documents: [documentFixture(id: 'doc')],
      );
      expect(validator.validate(domain), isEmpty);
    });
  });

  group('ContentValidator — 인용 문구 (quote)', () {
    test('사기꾼 멘트는 원문 그대로 통과한다', () {
      final domain = domainFixture().copyWith(
        brokerAlerts: [
          alertFixture(
            id: 'ba_subsidy',
            phrase: '정부지원금 100% 받아 드립니다 / 합격 보장합니다',
            truth: '선입금 요구는 100% 사기입니다.',
          ),
        ],
      );
      expect(validator.validate(domain), isEmpty);
    });

    test('인용이어도 1인칭 단정은 잡는다', () {
      final domain = domainFixture().copyWith(
        brokerAlerts: [
          alertFixture(
            id: 'ba_bad',
            phrase: '맡기시면 승소합니다',
            truth: '걱정하지 마시고 진행하세요.',
          ),
        ],
      );
      final issues = validator.validate(domain);
      expect(issues, hasLength(2));
    });

    test('같은 문구라도 앱이 말하는 필드에 있으면 잡는다', () {
      final domain = domainFixture().copyWith(
        procedures: [
          const Procedure(
            id: 'proc',
            step: 1,
            label: '정부지원금 100% 받기',
            verification: verifiedFixture,
          ),
        ],
      );
      expect(validator.validate(domain), hasLength(1));
    });
  });

  group('ContentValidator — 실제 도메인 데이터', () {
    test('경로가 어디서 났는지 알려준다', () {
      final domain = domainFixture(
        intake: [
          questionFixture(id: 'q_amount', order: 1, field: 'claimAmount')
              .copyWith(whyAsk: '확실히 계산해 드립니다.'),
        ],
      );
      expect(
        validator.validate(domain).single.path,
        'test_domain.intake.q_amount.whyAsk',
      );
    });
  });
}
