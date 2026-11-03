import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../format/formatters.dart';
import '../providers/domain_providers.dart';
import '../safety/safe_text.dart';
import 'plain_mode_switch.dart';

/// 우측 상단의 「오늘 2026년 8월 16일」.
///
/// **기한을 다루는 앱에서 이건 신뢰 장치다.** D-14 가 어디서 나온 숫자인지
/// 사용자가 스스로 검산할 수 있어야 한다. 앱이 오늘을 잘못 알고 있으면 모든
/// 기한이 틀리는데, 날짜를 안 보여주면 그걸 확인할 방법이 없다.
///
/// ## 해외에서 열면 두 줄이 된다
///
/// 재외국민이 쓰면 현지 날짜와 KST 가 다르다. 뉴욕에서 밤에 열면 현지는 15일인데
/// 기한은 16일 기준으로 돈다. **그 어긋남을 숨기면 사용자가 자기 날짜로 D-day 를
/// 센다.**
///
/// **한국 날짜가 위에 크게 온다.** 기한의 기준이 그것이기 때문이다. 현지 날짜를
/// 크게 보여주면 사용자가 그 기준으로 셈을 한다.
///
/// **두 날짜가 같으면 한 줄만 나온다.** 국내 사용자에게 현지 표시는 소음이다.
///
/// 계산은 언제나 KST 다. 여기는 **표시만** 바꾼다.
class TodayPill extends ConsumerWidget {
  const TodayPill({super.key});

  static const String prefix = '오늘';
  static const String kstMark = '한국';
  static const String localMark = '현지';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **계산이 쓰는 그 값이다.** 따로 부르면 자정을 사이에 두고 어긋난다.
    final clock = ref.watch(appClockProvider);
    final kst = ref.watch(todayProvider);
    final local = clock.localToday();
    final theme = Theme.of(context).textTheme;
    final abroad = local != kst;

    final style = theme.labelSmall?.copyWith(
      color: BeobaColors.ink3,
      fontFeatures: kTabularFigures,
    );

    return Padding(
      padding: const EdgeInsets.only(right: BeobaSpace.pageH),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: BeobaColors.surfaceStrong,
          borderRadius: BorderRadius.circular(abroad ? 12 : 100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeText(
              abroad
                  ? '$prefix ${formatKstDate(kst)} ($kstMark)'
                  : '$prefix ${formatKstDate(kst)}',
              where: 'TodayPill.kst',
              style: abroad
                  ? style?.copyWith(
                      color: BeobaColors.ink2,
                      fontWeight: FontWeight.w700,
                    )
                  : style,
            ),
            if (abroad)
              SafeText(
                '${formatKstDate(local)} ($localMark)',
                where: 'TodayPill.local',
                style: style,
              ),
          ],
        ),
      ),
    );
  }
}

/// [TodayPill] 을 단 화면 위쪽 줄. **여덟 화면이 같은 줄을 쓴다.**
///
/// 배율을 키우면 「오늘 2026년 8월 15일」이 줄 폭을 넘는다. 배율 2.0 에서
/// 63px 이 오른쪽으로 잘렸고, **잘린 날짜는 화면에 없는 날짜다** — 기한을
/// 스스로 검산하라고 둔 줄이 정작 검산을 못 하게 된다.
///
/// 두 가지를 같이 한다.
///
/// * `Flexible` — 폭이 모자라면 날짜가 두 줄로 접힌다. 잘리지 않는다
/// * `toolbarHeight` — 접힌 두 줄이 들어가게 줄 높이도 배율을 따라간다
///
/// **임계값을 두지 않는다.** 「배율 1.7 이상이면 접는다」 같은 선은 글꼴이
/// 바뀌면 틀린다. 모자랄 때만 접히게 두면 선이 필요 없다.
AppBar beobaAppBar(
  BuildContext context, {
  bool automaticallyImplyLeading = true,
}) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    // ★ 스위치가 같은 줄에 들어오면서(289) 배율 2.0 에서 둘 다 두 줄로 접혀
    // 18px 이 넘쳤다. 줄 높이를 배율보다 조금 더 가파르게 키운다 — 1.0 에서는
    // 그대로이고 **선이 없다.** 위의 「임계값을 두지 않는다」를 지킨다.
    toolbarHeight: kToolbarHeight * (scale + (scale - 1) * 0.4),
    // ★ 「쉬운 말로 보기」를 **모든 화면 위에** 둔다(DECISIONS 289번). 홈에만
    // 있으면 결과 화면에서 문장이 안 읽히는 분이 켤 길이 없다. 첫 실행 물음의
    // 「화면 위에서 언제든 다시 바꿀 수 있어요」가 이 줄 덕분에 참이다.
    actions: const [
      Flexible(child: PlainModeSwitch()),
      Flexible(child: TodayPill()),
    ],
  );
}

/// 화면 위쪽에 [TodayPill] 만 오른쪽으로 붙인 줄.
///
/// `AppBar` 가 없는 화면(홈)에서 쓴다.
/// 날짜 줄. **왼쪽의 빈자리에 「쉬운 말로 보기」가 들어간다.**
///
/// 스위치를 본문에 넣으면 두 갈래가 첫 화면 밖으로 밀린다. 이 줄은 이미
/// 서 있으므로 여기 넣으면 세로가 늘지 않는다.
class TodayBar extends StatelessWidget {
  const TodayBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Flexible(child: PlainModeSwitch()),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: TodayPill()),
        ),
      ],
    );
  }
}
