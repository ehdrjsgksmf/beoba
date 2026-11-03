import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../providers/domain_providers.dart';
import '../safety/safe_text.dart';

/// 「쉬운 말로 보기」 스위치.
///
/// ★ **기기 언어로 자동으로 켜지 않는다.** 한국어로 맞춰 둔 기기를 쓰는
/// 외국인이 많고, 한국 사람이 영어 기기를 쓰기도 한다. 자동으로 고르면
/// 둘 다 틀리고, 틀렸다는 것을 사람이 되돌릴 방법도 없다.
///
/// ★ **스위치 이름부터 쉬운 말이어야 한다.** 「간이 표현 모드」라고 적으면
/// 이 스위치가 필요한 사람이 스위치를 못 읽는다.
///
/// ★ **첫 화면 맨 위에 둔다 — 그리고 2026-09-16 부터 모든 화면 위 줄에도**
/// (DECISIONS 289번). 켠 것은 기기에 기억한다.
///
/// ★ **첫 화면 맨 위에 둔다.** 이 스위치가 필요한 사람은 아래 글을 읽기
/// 전에 켜야 한다. 설정 안에 넣으면 읽을 수 있는 사람만 찾아낸다.
/// 다만 **자리를 많이 차지하면 두 갈래를 첫 화면 밖으로 민다** — 그래서
/// 날짜 줄 왼쪽의 빈자리에 들어간다. 세로가 늘지 않는 유일한 자리다.
///
/// 켜면 **우리가 쓴 문장**만 짧은 문장으로 바뀐다. 조문 원문과 기관·서식
/// 이름은 그대로다 — 창구에서 그 말을 그대로 써야 하기 때문이다.
///
/// 색 하나로 상태를 말하지 않는다. 켜지면 **√ 표시가 함께 붙는다.**
class PlainModeSwitch extends ConsumerWidget {
  const PlainModeSwitch({super.key});

  static const String label = '쉬운 말로 보기';

  /// 탭 타깃 최소치. 이 아래로 내리지 않는다.
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plain = ref.watch(plainModeProvider);
    final theme = Theme.of(context).textTheme;

    return Semantics(
      toggled: plain,
      button: true,
      child: InkWell(
        onTap: () => ref.read(plainModeProvider.notifier).toggle(),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.only(right: 12),
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: plain ? BeobaColors.brandSoft : BeobaColors.surfaceStrong,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  plain ? Icons.check : Icons.subject,
                  size: 15,
                  color: plain ? BeobaColors.brand : BeobaColors.ink3,
                ),
                const SizedBox(width: 5),
                // 화면 위 줄에서는 날짜와 폭을 나눠 쓴다. 모자라면 접힌다.
                Flexible(
                  child: SafeText(
                    label,
                    where: 'PlainModeSwitch.label',
                    style: theme.labelMedium?.copyWith(
                      fontWeight: plain ? FontWeight.w700 : FontWeight.w500,
                      color: plain ? BeobaColors.brand : BeobaColors.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
