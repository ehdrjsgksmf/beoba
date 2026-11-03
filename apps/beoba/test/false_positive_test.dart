import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/crisis_helpers.dart';
import 'support/test_app.dart';

/// Chrome 확인에서 나온 오탐 12건. **하나라도 걸리면 빌드가 깨진다.**
///
/// 문자열 매칭은 문맥을 모른다. 넓게 잡는 그물은 반드시 헛것을 잡는다:
/// 빚을 다루는 앱에서 `일수` 는 날짜를 세는 말이고, `고소` 는 참기름 맛이며,
/// `혼자살고` 안에는 `자살` 이 들어 있다.
///
/// 위기 안내가 헛돌면 사용자는 앱이 자기 말을 못 알아듣는다고 느끼고,
/// 그다음부터는 **진짜 안내도 무시한다.** 안내를 한 번 놓치는 것보다 신뢰를 잃는
/// 것이 더 크다. 하드스톱이면 아예 쫓아낸다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    container = await bootstrappedContainer();
  });

  /// 걸려서는 안 되는 문장들. 위기 신호도 하드스톱도 0건이어야 한다.
  const mustNotFire = <String>[
    // 자살 — 낱말이 다른 말 안에 숨어 있거나 예방·통계 이야기
    '혼자살고있어요',
    '자살예방 캠페인에서 봤어요',
    // 일수 — 빚 앱에서 날짜를 세는 말
    '대출 일수가 30일이에요',
    '근무일수를 계산해주세요',
    // 부정문 — 없다고 말하는데 있다고 읽던 것들
    '굶주린 적은 없어요',
    '협박한 적은 없습니다',
    '집에서 쫓겨난 적 없어요',
    '대마초는 안 했어요',
    // 남의 이야기 · 다른 뜻
    '노숙인 지원 봉사를 합니다',
    '토토로 만화 봤어요',
    '카지노 근처 호텔에서 일해요',
    '월급이 밀려서 돈이 없다고 들었어요',
    // 하드스톱 쪽
    '참기름이 고소한 냄새가 납니다',
    '형사 드라마를 봤어요',
    '계약에 구속력이 있나요',
    '고소할 생각은 없습니다',
  ];

  /// 반드시 걸려야 하는 문장들. 좁히다가 바닥까지 잃으면 안 된다.
  const mustFire = <String, String>{
    '돈 때문에 죽고 싶습니다': 'trg_mental',
    '혼자살고 있는데 죽고싶어요': 'trg_mental',
    '도박 때문에 돈을 빌렸어요': 'trg_gambling',
    '마약 때문에 돈이 필요했습니다': 'trg_drug',
    '돈이 없어서 굶고 있습니다': 'trg_money_crisis',
    '사채를 썼는데 갚기 어렵습니다': 'trg_illegal_loan',
    '일수 대출을 받았습니다': 'trg_illegal_loan',
    '협박당하고 있습니다': 'trg_illegal_loan',
  };

  group('걸리면 안 되는 문장', () {
    for (final text in mustNotFire) {
      test('"$text" 로는 아무것도 뜨지 않는다', () {
        container
            .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
            .start(text);

        expect(
          signalIds(container),
          isEmpty,
          reason: '위기 안내가 잘못 떴습니다',
        );
        expect(
          container
              .read(hardStopsProvider(kDebtRecoveryDomainId))
              .map((s) => s.id),
          isEmpty,
          reason: '하드스톱이 잘못 걸렸습니다',
        );
      });
    }
  });

  group('걸려야 하는 문장', () {
    mustFire.forEach((text, expectedId) {
      test('"$text" 는 $expectedId 로 이어진다', () {
        container
            .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
            .start(text);

        expect(signalIds(container), contains(expectedId));
      });
    });
  });

  test('음성 사례가 양성보다 많다', () {
    // 좁히는 방향으로 가기로 했으므로 음성이 많은 것이 정상이다.
    expect(mustNotFire.length, greaterThan(mustFire.length));
  });
}
