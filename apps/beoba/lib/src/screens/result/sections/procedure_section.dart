import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/fee_schedule_view.dart';
import '../../../widgets/plain_title.dart';
import '../../../widgets/say_this_card.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// 절차 — 어디에 · 어떤 순서로 내는가.
///
/// `detail` · `officialLinks` 가 스키마에 있는데 화면에 안 나오고 있었다.
/// 공개된 절차 정보이므로 그대로 보여준다.
///
/// **선은 여기다.**
/// ```
/// ⭕  어디에 · 몇 부 · 어떤 순서로 내는가     공개된 절차 정보
/// ❌  이 서류가 있으면 유리한가              평가. 하지 않는다
/// ```
class ProcedureSection extends StatelessWidget {
  const ProcedureSection({
    required this.procedures,
    this.showHeader = true,
    super.key,
  });

  final List<Procedure> procedures;

  /// 머리글을 그릴지. **접힌 카드 안에 들어갈 때는 끈다** — 카드가 이미 제목을
  /// 달고 있어서 머리글이 둘이 되면 카드 하나가 두 장으로 보인다.
  final bool showHeader;

  static const String title = '밟을 수 있는 절차';

  /// **순서를 권하지 않는다.** 「먼저 내용증명, 안 되면 조정」은 그 사건에 대한
  /// 판단이다 — 관할 세 갈래를 나란히 두는 것과 같은 자리다 (DECISIONS 72).
  static const String hint = '순서대로 해야 하는 것은 아니에요. 조건을 보고 고르세요.';
  static const String empty = '지금 정보로는 절차를 추릴 수 없어요.';
  static const String whenLabel = '이럴 때 씁니다';
  static const String cautionLabel = '주의하세요';
  static const String linkLabel = '공식 사이트';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          const SectionHeader(title, icon: Icons.alt_route_outlined),
        if (procedures.length > 1) ...[
          SafeText(
            hint,
            where: 'ProcedureSection.hint',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: BeobaColors.ink3),
          ),
          const SizedBox(height: 8),
        ],
        if (procedures.isEmpty)
          const NoticeBox(text: empty, where: 'ProcedureSection.empty')
        else
          for (final procedure in procedures)
            Padding(
              padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
              child: _ProcedureCard(procedure: procedure),
            ),
      ],
    );
  }
}

class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({required this.procedure});

  final Procedure procedure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final basis = procedure.legalBasis;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlainTitle(
            label: procedure.label,
            whatIsThis: procedure.whatIsThis,
            where: 'Procedure',
            titleStyle: theme.titleMedium?.copyWith(fontSize: 17),
          ),
          // ★ **창구에서 그대로 내밀 화면.** 이름이 없으면 안 선다 —
          // 지어낸 이름을 크게 보여 주는 것이 아무것도 안 보여 주는 것보다
          // 나쁘다(DECISIONS 233번).
          if (procedure.sayThis case final SayThis say)
            SayThisCard(say: say, where: 'Procedure.${procedure.id}.sayThis'),
          _Line(
            label: ProcedureSection.whenLabel,
            text: procedure.whenApplicable,
            where: 'Procedure.whenApplicable',
          ),
          _Line(text: procedure.detail, where: 'Procedure.detail'),
          _Line(
            label: ProcedureSection.cautionLabel,
            text: procedure.caution,
            where: 'Procedure.caution',
            emphasis: true,
          ),
          _Line(text: procedure.noticeToUser, where: 'Procedure.noticeToUser'),
          // **법원이 움직이는 눈금.** 기한이 아니라 D-day 를 안 붙인다 —
          // 사용자가 할 일이 하나도 없는 줄이다(DECISIONS 150번).
          if (procedure.courtTerms.isNotEmpty) _CourtTerms(terms: procedure.courtTerms),
          // 드는 돈의 **구성**. 총액이 아니다 — 우리가 더할 수 없는 자리다.
          if (procedure.fees case final FeeSchedule fees)
            FeeScheduleView(fees: fees),
          if (procedure.officialLinks.isNotEmpty) ...[
            const SizedBox(height: 10),
            SafeText(
              ProcedureSection.linkLabel,
              where: 'ProcedureSection.linkLabel',
              style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
            ),
            for (final link in procedure.officialLinks)
              _LinkRow(link: link),
          ],
          if (basis != null) ...[
            const SizedBox(height: 10),
            LegalBasisCard(basis: basis, where: 'Procedure.${procedure.id}'),
          ],
          // 요건이 든 조문과 돈이 든 조문이 갈라져 있다. 하나만 보여주면
          // **인지를 두 번 내지 않는다는 사실이 근거 없이 떠 있게 된다.**
          for (final (index, also) in procedure.alsoBasis.indexed) ...[
            const SizedBox(height: 10),
            LegalBasisCard(
              basis: also,
              where: 'Procedure.${procedure.id}.also$index',
            ),
          ],
          VerificationBadge(status: procedure.verification.status),
        ],
      ),
    );
  }
}

/// 법원이 지키는 처리기간. **날짜를 계산하지 않는다.**
///
/// 조문이 말하는 기산점과 일수를 그대로 옮긴다. 계산해서 날짜를 내면 그건
/// 기한이 되고, 여기는 기한이 아니다.
class _CourtTerms extends StatefulWidget {
  const _CourtTerms({required this.terms});

  final List<CourtTerm> terms;

  static const String title = '법원은 이 눈금으로 움직여요';
  static const String hint = '여기서 하실 일은 없어요.';

  @override
  State<_CourtTerms> createState() => _CourtTermsState();
}

class _CourtTermsState extends State<_CourtTerms> {
  /// **접어 둔다.** 세 눈금에 예외가 다섯 붙어 열댓 줄이고, 「여기서 하실 일은
  /// 없어요」인 줄이다. 화면을 넘기게 만드는 것은 「중요하냐」가 아니라
  /// 「기냐」다(DECISIONS 134·142번).
  ///
  /// 밀도 검사에는 안 잡힌다 — 절차 카드 자체가 접혀 있어 안이 아예 안 그려진다.
  /// **검사가 안 잡는다고 안 해도 되는 것은 아니다.** 펼친 사람이 보는 화면이다.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ordered = [...widget.terms]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: BeobaTapTarget.minimum),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: SafeText(
                        _CourtTerms.title,
                        where: 'CourtTerm.title',
                        style: theme.labelSmall?.copyWith(
                          color: BeobaColors.ink3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: BeobaColors.ink3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            SafeText(
              _CourtTerms.hint,
              where: 'CourtTerm.hint',
              style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
            ),
          if (_open)
            for (final term in ordered) ...[
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 15,
                  color: BeobaColors.ink3,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SafeText(
                        term.within,
                        where: 'CourtTerm.within',
                        style: theme.labelSmall
                            ?.copyWith(color: BeobaColors.ink3),
                      ),
                      SafeText(
                        term.label,
                        where: 'CourtTerm.label',
                        style: theme.labelMedium
                            ?.copyWith(color: BeobaColors.ink2),
                      ),
                      // **예외를 함께 낸다.** 눈금만 보여주면 「가만히 있어도
                      // 굴러간다」로 읽힌다. 예납을 안 하면 절차가 멈춘다.
                      for (final except in term.exceptWhen)
                        SafeText(
                          '· $except',
                          where: 'CourtTerm.exceptWhen',
                          style: theme.labelSmall?.copyWith(
                            color: BeobaColors.severityWarning,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 있을 때만 그리는 한 줄. 없는 것을 자리로 만들지 않는다.
class _Line extends StatelessWidget {
  const _Line({
    required this.text,
    required this.where,
    this.label,
    this.emphasis = false,
  });

  final String? text;
  final String where;
  final String? label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final body = text;
    if (body == null || body.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            SafeText(
              label!,
              where: '$where.label',
              style: theme.labelSmall?.copyWith(
                color: emphasis ? BeobaColors.severityWarning : BeobaColors.ink3,
                fontWeight: FontWeight.w700,
              ),
            ),
          SafeText(
            body,
            where: where,
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
          ),
        ],
      ),
    );
  }
}

/// 공식 사이트 한 줄.
///
/// **주소는 데이터에만 있다.** 화면 이름이나 진입 경로를 코드에 적지 않는다 —
/// 사이트 구조는 바뀌고, 박아 두면 반년 뒤 틀린 안내가 된다.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final LinkRef link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse(link.url),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.open_in_new,
                size: 16,
                color: BeobaColors.brand2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SafeText(
                  link.label,
                  where: 'LinkRef.label',
                  style: theme.labelMedium?.copyWith(
                    color: BeobaColors.brand2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 주소를 글자로도 보여준다. 링크가 안 열리는 환경이 있다.
              Flexible(
                child: SafeText(
                  link.url,
                  where: 'LinkRef.url',
                  style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
