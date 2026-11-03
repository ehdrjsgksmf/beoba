import 'package:domain_data/domain_data.dart' show JurisdictionGuide, Procedure;
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/expandable_card.dart';
import '../../../widgets/section_card.dart';
import 'cost_section.dart';
import 'document_section.dart';
import 'jurisdiction_guide_view.dart';
import 'jurisdiction_section.dart';
import 'near_miss_notice.dart';
import 'procedure_section.dart';

/// 요약의 접힌 카드 넷.
///
/// 제목은 **물음**이다. 「비용」이 아니라 「얼마나 드나요」다 — 사용자가 머릿속으로
/// 하는 말과 같은 모양이라야 자기가 찾는 카드를 고를 수 있다.
///
/// 접혀도 **핵심은 보인다.** 접힘이 「이 카드에 뭐가 있는지 모르게 하는 것」이
/// 되면 사용자는 그 정보가 있다는 사실 자체를 모른다.

/// 얼마나 드나요 — 갈래별 합계는 접혀도 보이고, 항목별 내역은 펼쳐야 나온다.
class CostCard extends StatelessWidget {
  const CostCard({required this.scenarios, super.key});

  final List<ScenarioCostResult> scenarios;

  static const String title = '얼마나 드나요';
  static const String empty = '금액을 계산할 만한 정보가 아직 없어요.';

  @override
  Widget build(BuildContext context) {
    if (scenarios.isEmpty) return const SizedBox.shrink();
    final priced = scenarios.where((s) => s.result.lines.isNotEmpty).toList();

    return ExpandableCard(
      title: title,
      where: 'CostCard',
      icon: Icons.calculate_outlined,
      summary: priced.isEmpty
          ? const NoticeBox(text: empty, where: 'CostCard.empty')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final scenario in priced)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _ScenarioTotal(scenario: scenario),
                  ),
              ],
            ),
      child: CostSection(scenarios: scenarios, showHeader: false),
    );
  }
}

/// 갈래 하나의 합계 한 줄.
///
/// **하나의 숫자로 내지 않는다.** 어느 절차로 갈지 아직 안 정한 사람에게 한
/// 숫자를 주면 그 숫자는 절반 넘는 사람에게 틀린 값이다 — 지급명령·전자소송과
/// 소장·종이는 11배 차이가 난다.
class _ScenarioTotal extends StatelessWidget {
  const _ScenarioTotal({required this.scenario});

  final ScenarioCostResult scenario;

  /// 한 줄에 들어가는지 **재어 본다.** 임계 배율을 박지 않는다 —
  /// 「배율 1.4 이상이면 접는다」는 폰 폭이 다르면 또 어긋난다.
  static double _widthOf(String text, TextStyle? style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// 이름과 금액 사이의 최소 틈.
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final option = scenario.option;
    final name = scenario.label.isEmpty
        ? ''
        : option == null
            ? scenario.label
            : '${scenario.label} · $option';
    // **조문대로의 값이 아니라 안내할 값이다.** 둘은 다른 층이다.
    final amount = formatWon(scenario.result.guidedTotal);

    final nameStyle = theme.labelMedium?.copyWith(color: BeobaColors.ink2);
    final amountStyle = theme.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: BeobaColors.brand,
      fontFeatures: kTabularFigures,
    );

    final nameText = SafeText(
      name,
      where: 'CostScenario.label',
      style: nameStyle,
    );
    final amountText = SafeText(
      amount,
      where: 'CostResult.total',
      style: amountStyle,
    );

    if (name.isEmpty) return amountText;

    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final needed = _widthOf(name, nameStyle, scaler) +
            _gap +
            _widthOf(amount, amountStyle, scaler);

        // 한 줄에 들어가면 그대로 둔다. 배율 1.0 의 모습이 안 바뀐다.
        if (needed <= box.maxWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: nameText),
              amountText,
            ],
          );
        }

        // **안 들어가면 좁히지 않고 두 줄로 떨어뜨린다.**
        //
        // 금액 쪽을 좁히는 선택지는 없다 — 잘린 근거는 없는 것이 되지만
        // **잘린 숫자는 다른 숫자가 된다**(DECISIONS 179번).
        // 이름 쪽만 좁히면 이름이 서너 줄로 접히고 금액이 그 옆에 혼자
        // 붙어서, 갈래가 여섯일 때 **어느 금액이 어느 이름 것인지가
        // 흐려진다.** 이름과 금액은 짝이다(DECISIONS 180번).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            nameText,
            const SizedBox(height: 2),
            Align(alignment: Alignment.centerRight, child: amountText),
          ],
        );
      },
    );
  }
}

/// 뭘 준비해야 하나요 — 몇 개 중 몇 개인지가 접혀도 보인다.
class DocumentCard extends StatefulWidget {
  const DocumentCard({
    required this.documents,
    required this.procedures,
    super.key,
  });

  final List<DocumentResult> documents;

  /// `ifMissing.seeProcedure` 를 풀기 위해서다. **같은 말을 두 번 하지
  /// 않으려고** 조건을 그 절차에서 그대로 가져온다.
  final List<Procedure> procedures;

  static const String title = '뭘 준비해야 하나요';
  static const String empty = '준비할 서류를 아직 추릴 수 없어요.';

  /// 「5개 중 1개 챙기셨어요」 — 조사가 붙는 자리가 없다.
  static String haveLine(int done, int total) => '$total개 중 $done개 챙기셨어요';

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  /// 체크한 서류.
  ///
  /// **이미 갖고 있다고 답한 것은 체크된 채로 연다.** 그게 원래 그 질문을 한
  /// 이유다 — 차용증이 있다고 답한 사람에게 「차용증을 준비하세요」를 다시
  /// 내밀고 있었다. 사용자는 물론 체크를 풀 수 있다.
  final Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(DocumentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 정리 카드에서 답을 고치면 목록이 바뀐다. **푼 체크를 되살리지는 않는다** —
    // 새로 「있다」가 된 것만 더한다.
    _seed();
  }

  void _seed() {
    for (final document in widget.documents) {
      if (document.alreadyHave) _checked.add(document.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.documents.isEmpty) return const SizedBox.shrink();
    final documents = widget.documents;
    final theme = Theme.of(context).textTheme;

    return ExpandableCard(
      title: DocumentCard.title,
      where: 'DocumentCard',
      icon: Icons.folder_outlined,
      summary: documents.isEmpty
          ? const NoticeBox(
              text: DocumentCard.empty,
              where: 'DocumentCard.empty',
            )
          : SafeText(
              DocumentCard.haveLine(_checked.length, documents.length),
              where: 'DocumentCard.have',
              style: theme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
              ),
            ),
      child: DocumentSection(
        documents: documents,
        checked: _checked,
        showHeader: false,
        procedureById: (id) {
          for (final procedure in widget.procedures) {
            if (procedure.id == id) return procedure;
          }
          return null;
        },
        onToggle: (id) => setState(() {
          if (!_checked.remove(id)) _checked.add(id);
        }),
      ),
    );
  }
}

/// 항목이 하나도 없으면 그리지 않는다. **값이 미정인 것과는 다르다.**
///
/// 「금액을 계산할 만한 정보가 아직 없어요」는 답을 더 하면 채워지는 자리에서
/// 정직한 신호다. 그런데 갚을 쪽에는 비용 항목 자체가 없다 — `showIf` 로
/// 걸러져 하나도 안 남는다. 거기에 같은 문구를 내면 **「아직」이 영영 안
/// 끝나는 약속**이 되고, 빈 칸은 0으로 읽힌다(DECISIONS 125번).
/// 어디에 내나요 — 한 줄만. 세 갈래는 펼쳐야 나온다.
///
/// 갈래를 다 보여주는 규칙은 그대로다 (DECISIONS 72). **요약에서만 접힌다.**
class JurisdictionCard extends StatelessWidget {
  const JurisdictionCard({
    required this.guide,
    required this.results,
    super.key,
  });

  final JurisdictionGuide? guide;
  final List<JurisdictionResult> results;

  static const String title = '어디에 내나요';
  static const String empty = '어느 법원에 내는지 아직 안내하지 못해요.';

  @override
  Widget build(BuildContext context) {
    if (guide == null && results.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;
    // 한 줄은 데이터가 준다. 화면이 만들지 않는다.
    final line = guide?.lookupNote ?? '';

    return ExpandableCard(
      title: title,
      where: 'JurisdictionCard',
      icon: Icons.account_balance_outlined,
      summary: line.isEmpty
          ? const NoticeBox(text: empty, where: 'JurisdictionCard.empty')
          : SafeText(
              line,
              where: 'JurisdictionGuide.lookupNote',
              style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JurisdictionGuideView(guide: guide, showHeader: false),
          JurisdictionSection(results: results, showHeader: false),
        ],
      ),
    );
  }
}

/// 어떻게 진행되나요 — 다음 한 칸만. 절차 전체는 펼쳐야 나온다.
///
/// 경계 알림도 여기 있다. **독립 섹션으로 두면 또 위로 올라간다** — 새 기능을
/// 넣을 때마다 「위에 두면 눈에 띄겠지」로 기한이 두 번 밀렸다 (DECISIONS 70).
/// 경계 알림이 하는 말은 「이 절차는 쓸 수 없어요」라 이 카드가 제자리다.
class ProcedureCard extends StatelessWidget {
  const ProcedureCard({
    required this.procedures,
    required this.misses,
    super.key,
  });

  final List<Procedure> procedures;
  final List<NearMiss> misses;

  static const String title = '어떻게 진행되나요';
  static const String empty = '지금 정보로는 절차를 추릴 수 없어요.';
  static const String nextLabel = '다음 한 칸';

  @override
  Widget build(BuildContext context) {
    if (procedures.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;
    final next = procedures.isEmpty ? null : procedures.first;

    return ExpandableCard(
      title: title,
      where: 'ProcedureCard',
      icon: Icons.alt_route_outlined,
      summary: next == null
          ? const NoticeBox(text: empty, where: 'ProcedureCard.empty')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  nextLabel,
                  where: 'ProcedureCard.nextLabel',
                  style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
                ),
                SafeText(
                  next.label,
                  where: 'Procedure.label',
                  style: theme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NearMissNotice(misses: misses),
          ProcedureSection(procedures: procedures, showHeader: false),
        ],
      ),
    );
  }
}
