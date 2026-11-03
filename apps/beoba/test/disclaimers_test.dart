import 'package:beoba/src/safety/disclaimers.dart';
import 'package:engines/engines.dart';
import 'package:flutter_test/flutter_test.dart';

/// `disclaimers.dart` 는 `verify_domains.dart` 의 문구 검사에서 **제외된 유일한 앱
/// 파일**이다 (DECISIONS 23번). 파일 단위로 열어 두면 나중에 누가 문구를 하나 더
/// 넣는 순간 SafetyFilter 를 조용히 우회한다.
///
/// 그래서 예외의 범위를 파일이 아니라 **"지금 들어 있는 문자열 목록"** 으로 좁힌다.
/// 아래 목록은 손으로 박아 둔 것이다. 문구를 더하거나 고치면 이 테스트가 먼저
/// 깨지고, 고치는 사람은 무엇을 면제하는지 눈으로 보게 된다.
void main() {
  test('면제 문구 목록이 바뀌지 않았다', () {
    expect(
      kAllDisclaimers,
      equals(<String>[
        '승소 가능성은 안내하지 않습니다',
        '법령과 계산 기준을 그대로 옮긴 것입니다. 사건의 결과를 예측하거나 유불리를 판단하지 않습니다.',
        '이 안내는 법률 상담이 아닙니다. 변호사의 조언을 대신하지 않습니다.',
        '법률 상담이 아니라, 순서를 짚어드리는 도구예요',
      ]),
      reason: '면제 문구를 바꾸려면 이 목록을 함께 고치세요. '
          '무엇을 SafetyFilter 밖에 두는지가 한눈에 보여야 합니다.',
    );
  });

  test('면제가 필요한 문구만 들어 있다', () {
    // strict 를 통과하는 문구는 여기 있을 이유가 없다. 면제를 최소로 유지한다.
    final needsExemption =
        kAllDisclaimers.where((text) => !SafetyFilter.isSafe(text)).toList();

    expect(
      needsExemption,
      [Disclaimers.noOutcomePrediction],
      reason: 'strict 를 그냥 통과하는 문구는 일반 화면 코드에 두세요. '
          '면제 파일이 커질수록 안전장치의 구멍도 커집니다.',
    );
  });

  test('면제 문구도 disclaimer scope 는 통과해야 한다', () {
    // disclaimer scope 는 `승소` 낱말 하나만 푼다. 단정 표현은 여기서도 막힌다.
    for (final text in kAllDisclaimers) {
      expect(
        SafetyFilter.isSafe(text, scope: SafetyScope.disclaimer),
        isTrue,
        reason: '"$text" 가 disclaimer scope 에서도 막힙니다. '
            '고지가 아니라 단정으로 읽히는 문장입니다.',
      );
    }
  });
}
