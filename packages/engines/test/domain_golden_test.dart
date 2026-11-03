import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/asset_paths.dart';

/// 도메인 JSON 의 `tests[]` 를 읽어 테스트를 **자동 생성**한다.
///
/// 분야가 늘어도 이 파일은 고치지 않는다. JSON 에 `tests[]` 를 적으면
/// 그게 곧 CI 에서 실행되는 정답지가 된다.
///
/// `keepAll` 로 읽는 이유: `unverified` 항목도 계산이 맞는지는 확인해야 한다.
/// (화면에 나가지 않을 뿐, 숫자가 틀린 채로 방치하지는 않는다)
void main() {
  const clock = FixedKstClock(KstDate(2026, 8, 15));
  const deadlineEngine = DeadlineEngine(clock);
  const costEngine = CostEngine();
  const limitChecker = LimitChecker();

  for (final file in domainAssetFiles()) {
    final domainId = domainIdOf(file);
    final domain = DomainLoader(policy: VerificationPolicy.keepAll)
        .loadFromJsonString(file.readAsStringSync());

    group('$domainId · 기한', () {
      for (final deadline in domain.deadlines) {
        for (final testCase in deadline.tests) {
          test(
            '${deadline.id} ${testCase.basis.toIso()} → ${testCase.expected.toIso()}',
            () {
              final facts = CaseFacts({
                deadline.basisField: testCase.basis,
                if (deadline.knownDateField != null)
                  deadline.knownDateField!: testCase.basis,
                ...?testCase.facts,
              });
              final result = deadlineEngine.computeOne(deadline, facts);
              expect(result, isNotNull, reason: '기산일을 읽지 못했습니다');
              // 정답지는 **민법 157·159·160 의 답**이다. 제161조(말일이 토요일·
              // 공휴일이면 익일)는 그 뒤에 붙는 별개의 규칙이라 따로 잠근다.
              // 여기서 섞으면 정답지가 달력에 따라 흔들린다.
              expect(result!.statutoryDue, testCase.expected);
              // 정확한 기산일이면 양 끝이 같아야 한다. 하나라도 벌어지면
              // 어림값 도입이 기존 계산을 건드린 것이다.
              expect(
                result.statutoryDueLatest,
                testCase.expectedLatest ?? testCase.expected,
                reason: '범위의 늦은 끝',
              );
              expect(
                result.isApproximate,
                !testCase.basis.isExact,
                reason: '기산일 정밀도와 결과의 확실성이 어긋납니다',
              );
            },
          );
        }
      }
    });

    group('$domainId · 비용', () {
      for (final cost in domain.costs) {
        for (final testCase in cost.tests) {
          test('${cost.id} ${testCase.input} → ${testCase.expected}원', () {
            final line = costEngine.computeOne(cost, CaseFacts(testCase.input));
            expect(line, isNotNull, reason: '계산 입력이 부족합니다');
            expect(line!.amount, testCase.expected);
          });
        }
      }
    });

    group('$domainId · 법정 상한', () {
      for (final rule in domain.limitRules) {
        for (final testCase in rule.tests) {
          test('${rule.id} ${testCase.input}', () {
            final result = limitChecker.check(rule, testCase.input);
            final expected = testCase.expected;

            expect(result.verdict.name, expected.verdict);
            if (expected.legalMax != null) {
              expect(result.legalMax, expected.legalMax);
            }
            if (expected.excess != null) {
              expect(result.excess, expected.excess);
            }
          });
        }
      }
    });
  }

  group('정답지가 실제로 존재하는지', () {
    test('기한·비용 항목에는 tests[] 가 하나 이상 있다', () {
      for (final file in domainAssetFiles()) {
        final domain = DomainLoader(policy: VerificationPolicy.keepAll)
            .loadFromJsonString(file.readAsStringSync());
        for (final deadline in domain.deadlines) {
          expect(deadline.tests, isNotEmpty, reason: deadline.id);
        }
        for (final cost in domain.costs) {
          // **모르는 금액에는 정답지가 없다.** 0 을 정답으로 적으면
          // 「0원이다」가 정답지에 박히고, 나중에 표가 와도 그 줄이 맞는
          // 것처럼 통과한다(DECISIONS 155번).
          if (cost.formula is UnknownCostFormula) {
            expect(cost.tests, isEmpty, reason: cost.id);
            expect(cost.verification.openPart, isNotNull, reason: cost.id);
            continue;
          }
          expect(cost.tests, isNotEmpty, reason: cost.id);
        }
      }
    });
  });
}
