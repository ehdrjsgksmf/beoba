import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../widgets/primary_button.dart';

/// 결과 화면 맨 아래의 입구.
///
/// ★ **카드가 아니라 버튼 한 줄이다.** 처음에는 설명을 단 카드로 넣었는데
/// 그것만으로 밀도가 두 분야에서 예산(4.12)을 넘었다 — 「빚 갚기가 어려울
/// 때」 4.163, 「일이 끊겼을 때」 4.174. 설명을 빼도 카드 테두리와 여백만으로
/// 4.149 였다.
///
/// **상한은 내용으로 못 올린다**(DECISIONS 134번). 그래서 카드를 버렸다 —
/// 무엇인지는 눌러서 들어간 화면이 말한다.
///
/// ★ **고정 버튼으로 안 만든다.** 이 화면의 고정 버튼은 「자세히 보기」
/// 하나뿐이라는 규칙이 있다. 둘이 되면 사람이 무엇을 눌러야 하는지 흐려진다.
class TakeAwayLink extends StatelessWidget {
  const TakeAwayLink({required this.domainId, super.key});

  final String domainId;

  static const String label = '정리해서 가져가기';

  @override
  Widget build(BuildContext context) {
    return GhostButton(
      label: label,
      where: 'TakeAwayLink.label',
      icon: Icons.description_outlined,
      onPressed: () => context.push(Routes.takeAway(domainId)),
    );
  }
}
