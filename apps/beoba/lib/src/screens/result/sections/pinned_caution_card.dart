import 'package:domain_data/domain_data.dart' show AlertDisplay, Caution;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/agency_notice_line.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// **되돌릴 수 없는 것은 접지 않는다.**
///
/// 「달라질 수 있는 것」은 물음 버튼 뒤에 접혀 있다. 궁금한 사람만 누르면
/// 되는 것들이라 그게 맞다. 그런데 상속에는 **누르지 않은 사람이 그대로
/// 저지르는** 자리가 하나 있다 — 장례를 치르며 고인의 통장에서 돈을 빼는
/// 일이다. 그 순간 단순승인으로 볼 수 있고(민법 제1026조 제1호) 되돌릴 수
/// 없다.
///
/// 브로커 경보의 `stop` 과 **같은 무게, 같은 enum**이다. 다른 점은 상대가
/// 사기꾼이 아니라 **아직 아무도 아니라는 것**뿐이다.
///
/// ## 접지 않는 자리가 둘이다
///
/// [AlertDisplay.stop] 은 멈춰 세운다. [AlertDisplay.open] 은 **반대로 편다** —
/// 압류를 당한 사람에게 「법이 못 가져가게 정해 둔 것이 있어요」를 말하는
/// 자리다. 무게는 같고 방향이 반대라 색과 아이콘만 갈린다. 빨강으로 칠하면
/// 안심시키는 말이 겁주는 말이 된다.
class PinnedCautionCard extends StatelessWidget {
  const PinnedCautionCard({required this.caution, super.key});

  final Caution caution;

  bool get _isStop => caution.display == AlertDisplay.stop;

  /// 조문을 펴 둘지. **멈춰 세우는 말일수록 근거가 보여야 한다** — 다만
  /// 그건 조문이 짧을 때 이야기다.
  ///
  /// 제566조는 호가 아홉이라 통째로 펴면 그 카드 하나가 한 화면을 넘는다.
  /// 우리 말이 이미 다섯을 앞에 냈으므로 원문은 **눌러서 보는 것**으로
  /// 충분하다(DECISIONS 142번). 길이로 가르는 이유는 하나다 — 화면을
  /// 넘기게 만드는 것이 「멈춤이냐」가 아니라 「기냐」이기 때문이다.
  static const int _foldOver = 200;

  bool _foldsBasis(String? text) =>
      !_isStop || (text ?? '').length > _foldOver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: SectionCard(
        background: _isStop ? BeobaColors.redSoft : BeobaColors.greenSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _isStop ? Icons.pan_tool_outlined : Icons.shield_outlined,
                  size: 18,
                  color: _isStop ? BeobaColors.red : BeobaColors.green,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: SafeText(
                    caution.condition,
                    where: 'Caution.condition',
                    style: theme.labelLarge?.copyWith(
                      color: _isStop ? BeobaColors.red : BeobaColors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            SafeText(
              caution.consequence,
              where: 'Caution.consequence',
              style: theme.bodyMedium?.copyWith(height: 1.62),
            ),
            // **눈으로 볼 것은 눈으로 보라고 한다.** 사건번호도 원고·피고도
            // 종이에만 있다. 세는 것은 이 카드 위에서 이미 세어 두었다.
            for (final item in caution.checklist) ...[
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 5, color: BeobaColors.ink3),
                  const SizedBox(width: 9),
                  Expanded(
                    child: SafeText.forField(
                      item,
                      typeName: 'BrokerChecklist',
                      fieldName: 'items',
                      style: theme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            // **멈춰 세우는 말일수록 근거가 보여야 한다.** 다만 그건 stop
            // 이야기다 — open 은 여섯 장이 나란히 오는 자리라, 조문을 다
            // 펴 두면 결과 화면이 8.7화면이 됐다. 우리 말은 그대로 보이고
            // 조문만 눌러서 본다(DECISIONS 134번).
            if (caution.legalBasis case final basis?) ...[
              const SizedBox(height: 11),
              LegalBasisCard(
                basis: basis,
                where: 'Caution.${caution.id}',
                collapsible: _foldsBasis(basis.text),
              ),
            ],
            for (final also in caution.alsoBasis) ...[
              const SizedBox(height: 8),
              LegalBasisCard(
                basis: also,
                where: 'Caution.${caution.id}.also',
                collapsible: _foldsBasis(also.text),
              ),
            ],
            // **조문이 없는 자리를 기관 안내가 대신한다.** 조문 뒤에 놓는다 —
            // 🟢 옆이 아니라 아래다(DECISIONS 274번).
            if (caution.notice case final notice?) ...[
              const SizedBox(height: 8),
              AgencyNoticeLine(notice: notice),
            ],
            // 창구는 화면 아래 「도움받을 수 있는 곳」이 한 번만 모아 낸다.
            // 같은 목록을 두 번 그리지 않는다.
            VerificationBadge(status: caution.verification.status),
          ],
        ),
      ),
    );
  }
}
