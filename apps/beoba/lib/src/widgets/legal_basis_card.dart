import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show SafetyScope, scopeFor;
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';
import 'layer_style.dart';

/// 근거 조문 표시.
///
/// [basis] 는 **nullable 이 아니다.** 법률 정보 위젯은 근거 없이 만들 수 없다
/// (CONTRIBUTING.md 규칙 6). `CostLine.basis` 처럼 없을 수 있는 자리는 이 위젯을
/// 만들지 않고 계산 결과로만 보여준다 — null 을 억지로 채우지 않는다.
///
/// ## 원문은 눌러서 본다
///
/// 조문 원문은 길다. 폰에서 보면 근거 하나가 화면 한 장을 다 먹고, 정작 읽어야
/// 할 금액과 날짜가 저 아래로 밀린다. 그래서 접힌 상태에서는 **조문 이름 한
/// 줄**만 두고 누르면 원문이 나온다.
///
/// **🟢 라벨은 접히지 않는다.** 접힌 상태에서도 「법에 있는 내용」이 붙어 있다 —
/// 이 앱이 화면에 약속한 것이 3층 표시이고, 접었다고 그 약속이 없어지지 않는다.
///
/// [collapsible] 을 끄는 자리가 있다. **위기 창구와 브로커 경보**다. 거기서는
/// 그 자리에서 조문을 읽고 판단해야 하므로 한 번 더 누르게 하지 않는다.
class LegalBasisCard extends StatefulWidget {
  const LegalBasisCard({
    required this.basis,
    this.where = 'LegalBasis',
    this.collapsible = true,
    super.key,
  });

  final LegalBasis basis;
  final String where;

  /// 원문을 접을 수 있는가. 끄면 언제나 펼쳐진 채로 그린다.
  final bool collapsible;

  /// 접힌 상태에서 원문을 여는 말.
  static const String open = '조문 원문 보기';
  static const String close = '조문 접기';

  @override
  State<LegalBasisCard> createState() => _LegalBasisCardState();
}

class _LegalBasisCardState extends State<LegalBasisCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final citation = widget.basis.citation;
    final text = widget.basis.text;
    final hasText = text != null && text.isNotEmpty;
    final canFold = widget.collapsible && hasText;
    final showText = hasText && (!widget.collapsible || _open);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 접혀도 3층 표시는 남는다 — 배지 하나로(DECISIONS 286번).
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 조문 카드는 한 화면에 여러 번 선다 — 작은 배지(DECISIONS 286번).
              const LayerBadge(
                style: LayerStyle.statute,
                where: 'LegalBasisCard.layer',
                compact: true,
              ),
              const SizedBox(height: 3),
              if (citation != null)
                SafeText(
                  citation,
                  where: '${widget.where}.citation',
                  // 조문 표기는 인용이다. strict 로 보면 인용 자체가 막힌다.
                  scope: scopeFor('LegalBasis', 'text'),
                  style: theme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        if (canFold)
          Icon(
            _open ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: BeobaColors.ink3,
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canFold)
          Semantics(
            button: true,
            expanded: _open,
            label: _open ? LegalBasisCard.close : LegalBasisCard.open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: BeobaTapTarget.minimum),
                alignment: Alignment.centerLeft,
                child: header,
              ),
            ),
          )
        else
          header,
        if (showText) ...[
          const SizedBox(height: 10),
          _Quote(text: text, where: '${widget.where}.text'),
        ],
      ],
    );
  }
}

/// 조문 원문. 왼쪽 세로 막대 + 반투명 흰 배경.
///
/// 이 앱에서 좌측 액센트 바가 붙는 자리는 **여기 하나뿐이다.**
class _Quote extends StatelessWidget {
  const _Quote({required this.text, required this.where});

  final String text;
  final String where;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: const BoxDecoration(
        color: Color(0xBFFFFFFF),
        border: Border(
          left: BorderSide(color: Color(0x21000000), width: 3),
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: SafeText(
        text,
        where: where,
        // 사람이 검수한 조문 원문이다. quote scope 로 본다 (DECISIONS.md 5번).
        scope: SafetyScope.quote,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
