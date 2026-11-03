import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../providers/result_providers.dart';
import '../../safety/safe_text.dart';
import '../../sheet/take_away_sheet.dart';
import '../../widgets/copy_block.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/today_pill.dart';

/// 「정리해서 가져가기」.
///
/// ## 데이터를 다 채우기 전에 화면을 먼저 만든다
///
/// 덜 찬 분야는 **「저희가 아직 정리하지 못했어요」로 정직하게 나간다.**
/// 감출 것이 없으니 미완성인 채로 내보내도 된다. 그리고 화면이 있어야
/// 실제로 써 보고 무엇이 부족한지 안다.
///
/// ## 여기서 안 하는 것
///
/// 인쇄 · 파일로 내보내기 · 이미지 · 링크 공유. **인쇄는 지금 못 쓴다** —
/// CanvasKit 이라 화면이 캔버스 하나이고, 브라우저 인쇄는 보이는 화면 한 장의
/// 그림이 된다. 쪽 나눔도 글자 선택도 없다.
///
/// 남는 길은 **글자를 넘겨 주는 것**뿐이고, 그것이 이 기능의 성격과 맞는다 —
/// 우리가 보내는 게 아니라 사람이 넘겨 준다.
class TakeAwayScreen extends ConsumerStatefulWidget {
  const TakeAwayScreen({required this.domainId, super.key});

  final String domainId;

  static const String title = '정리해서 가져가기';
  static const String intro = '답해 주신 것을 한 장으로 모았어요. '
      '복사해서 보내시거나, 전화하실 때 보시거나, 창구에서 보여 주셔도 돼요.';

  /// **판단이 아니라 옮겨 적기라는 것을 글 밖에서도 말한다.**
  static const String notJudgement = '이 글은 법에 적힌 것을 옮겨 적은 거예요. '
      '유리한지 불리한지는 저희가 말하지 않아요.';

  @override
  ConsumerState<TakeAwayScreen> createState() => _TakeAwayScreenState();
}

class _TakeAwayScreenState extends ConsumerState<TakeAwayScreen> {
  /// 근거를 같이 넣을지. **기본은 꺼져 있다** — 지인에게 넘기는 쪽이 흔하고,
  /// 거기서는 조문 원문이 안 읽히고 오히려 방해다.
  bool _withBasis = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sheet = ref.watch(takeAwaySheetProvider(widget.domainId));
    final text = _withBasis ? sheet.all : sheet.short;

    return Scaffold(
      appBar: beobaAppBar(context),
      body: PageBody(
        children: [
          SafeText(
            TakeAwayScreen.title,
            where: 'TakeAwayScreen.title',
            style: theme.headlineSmall,
          ),
          const SizedBox(height: 8),
          SafeText(
            TakeAwayScreen.intro,
            where: 'TakeAwayScreen.intro',
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
          ),
          const SizedBox(height: 6),
          SafeText(
            TakeAwayScreen.notJudgement,
            where: 'TakeAwayScreen.notJudgement',
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink3),
          ),
          const SizedBox(height: 14),

          // **고르는 자리를 글 위에 둔다.** 켜면 글이 그 자리에서 길어지는
          // 것을 바로 본다. 아래 두면 이미 다 읽고 나서 만난다.
          SectionCard(
            background: BeobaColors.brandSoft,
            child: Row(
              children: [
                Expanded(
                  child: SafeText(
                    TakeAwaySheet.askBasis,
                    where: 'TakeAwayScreen.askBasis',
                    style: theme.bodyMedium,
                  ),
                ),
                Switch(
                  value: _withBasis,
                  onChanged: (on) => setState(() => _withBasis = on),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // **글은 언제나 고를 수 있다.** 복사가 되든 안 되든
                // 사람이 직접 끌어갈 수 있어야 한다.
                SafeText.forField(
                  text,
                  typeName: 'SayThis',
                  fieldName: 'agency',
                  selectable: true,
                  style: theme.bodyMedium?.copyWith(height: 1.62),
                ),
                const SizedBox(height: 10),
                CopyBlock(text: text, where: 'TakeAwayScreen'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
