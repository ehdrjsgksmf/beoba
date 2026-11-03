import 'package:domain_data/domain_data.dart' show Procedure;
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/missing_guide_view.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// 서류 체크리스트.
///
/// 확보율은 사용자가 직접 체크한 것을 센다. M1 은 저장하지 않으므로 앱을 닫으면
/// 사라진다. 그 사실을 숨기지 않고 적어 둔다.
class DocumentSection extends StatelessWidget {
  const DocumentSection({
    required this.documents,
    required this.checked,
    required this.onToggle,
    this.procedureById = _noProcedure,
    this.showHeader = true,
    super.key,
  });

  /// `ifMissing.seeProcedure` 가 가리키는 절차를 찾아 준다.
  ///
  /// **같은 말을 두 번 하지 않으려고** 위젯이 문구를 만들지 않는다 —
  /// 공정증서의 조건은 그 절차가 이미 들고 있다.
  static Procedure? _noProcedure(String id) => null;

  final List<DocumentResult> documents;

  /// 체크한 서류 id. **이 위젯이 들고 있지 않다.**
  ///
  /// 접힌 카드가 「5개 중 1개 챙기셨어요」를 접힌 채로 보여줘야 하는데, 세는 것이
  /// 펼쳐야 만들어지는 위젯 안에 있으면 접었을 때 그 수가 사라진다.
  final Set<String> checked;
  final void Function(String documentId) onToggle;
  final Procedure? Function(String procedureId) procedureById;

  /// 머리글을 그릴지. **접힌 카드 안에 들어갈 때는 끈다.**
  final bool showHeader;

  static const String title = '준비할 서류';
  static const String empty = '준비할 서류를 아직 추릴 수 없어요.';
  static const String progressLabel = '확보';
  static const String online = '온라인 발급';

  /// **목록에서 지우지 않는다.** 지우면 사용자가 「내가 뭘 냈더라」를 못 본다.
  /// 표시만 바꾼다.
  static const String alreadyHave = '있다고 하셨어요';

  /// **문을 닫지 않는다.** 없다고 답한 사람이 여기서 멈추면 이 화면은
  /// 「못 하는 일의 목록」이 된다.
  static const String missingAction = '없으면 어떻게 하나요';
  static const String notice = '체크한 내용은 저장되지 않아요.';

  static const Map<Importance, String> _importanceLabel = {
    Importance.high: '꼭 필요',
    Importance.medium: '있으면 좋음',
    Importance.low: '참고',
  };

  static const Map<Importance, Color> _importanceColor = {
    Importance.high: BeobaColors.red,
    Importance.medium: BeobaColors.severityWarning,
    Importance.low: BeobaColors.ink3,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          const SectionHeader(
            DocumentSection.title,
            icon: Icons.folder_outlined,
          ),
        if (documents.isEmpty)
          const NoticeBox(
            text: DocumentSection.empty,
            where: 'DocumentSection.empty',
          )
        else ...[
          _Progress(done: checked.length, total: documents.length),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                for (final document in documents)
                  _DocumentRow(
                    document: document,
                    checked: checked.contains(document.id),
                    last: document == documents.last,
                    importanceLabel:
                        _importanceLabel[document.importance] ?? '',
                    importanceColor:
                        _importanceColor[document.importance] ??
                            BeobaColors.ink3,
                    onToggle: () => onToggle(document.id),
                    procedureById: procedureById,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const NoticeBox(
            text: DocumentSection.notice,
            where: 'DocumentSection.notice',
          ),
        ],
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SafeText(
              DocumentSection.progressLabel,
              where: 'DocumentSection.progressLabel',
              style: theme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SafeText(
              formatProgress(done, total),
              where: 'DocumentSection.progress',
              style: theme.labelSmall?.copyWith(
                color: BeobaColors.green,
                fontWeight: FontWeight.w800,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 11,
            color: BeobaColors.green,
          ),
        ),
      ],
    );
  }
}

/// 서류 한 줄.
///
/// **없다고 답한 서류는 그 자리에서 펼친다.** 별도 화면으로 보내면 없는 사람이
/// 한 번 더 이동해야 하고, 거기서 나간다.
class _DocumentRow extends StatefulWidget {
  const _DocumentRow({
    required this.document,
    required this.checked,
    required this.last,
    required this.importanceLabel,
    required this.importanceColor,
    required this.onToggle,
    required this.procedureById,
  });

  final DocumentResult document;
  final bool checked;
  final bool last;
  final String importanceLabel;
  final Color importanceColor;
  final VoidCallback onToggle;
  final Procedure? Function(String procedureId) procedureById;

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final document = widget.document;
    final checked = widget.checked;
    final last = widget.last;
    final importanceLabel = widget.importanceLabel;
    final importanceColor = widget.importanceColor;
    final onToggle = widget.onToggle;
    final hint = document.hint;

    // **없다고 답한 것에만 펼친다.** 아직 답을 안 한 사람에게 「없으시군요」로
    // 시작하는 안내를 펴는 것은 그 자체로 틀린 말이다.
    final guide = document.isMissing ? document.ifMissing : null;

    return InkWell(
      onTap: onToggle,
      child: Container(
        constraints: const BoxConstraints(minHeight: BeobaTapTarget.minimum),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: BeobaColors.line2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              checked: checked,
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: checked ? BeobaColors.brand : BeobaColors.bg,
                  border: Border.all(
                    color: checked ? BeobaColors.brand : BeobaColors.control,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: checked
                    ? const Icon(Icons.check, size: 18, color: BeobaColors.bg)
                    : null,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SafeText(
                        document.label,
                        where: 'DocumentResult.label',
                        style: theme.titleSmall?.copyWith(fontSize: 16),
                      ),
                      _Chip(label: importanceLabel, color: importanceColor),
                      if (document.alreadyHave)
                        const _Chip(
                          label: DocumentSection.alreadyHave,
                          color: BeobaColors.green,
                        ),
                      if (document.onlineAvailable)
                        const _Chip(
                          label: DocumentSection.online,
                          color: BeobaColors.green,
                        ),
                    ],
                  ),
                  if (document.whatIsThis.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    SafeText(
                      document.whatIsThis,
                      where: 'DocumentResult.whatIsThis',
                      style: theme.labelMedium,
                    ),
                  ],
                  if (document.issuedBy.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    SafeText(
                      document.issuedBy,
                      where: 'DocumentResult.issuedBy',
                      style: theme.labelMedium,
                    ),
                  ],
                  if (hint != null && hint.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    SafeText(
                      hint,
                      where: 'DocumentResult.hint',
                      style: theme.labelMedium,
                    ),
                  ],
                  if (guide != null) ...[
                    const SizedBox(height: 4),
                    Semantics(
                      button: true,
                      expanded: _open,
                      child: InkWell(
                        onTap: () => setState(() => _open = !_open),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: BeobaTapTarget.minimum,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SafeText(
                                DocumentSection.missingAction,
                                where: 'DocumentSection.missingAction',
                                style: theme.labelSmall?.copyWith(
                                  color: BeobaColors.brand2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Icon(
                                _open ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                                color: BeobaColors.brand2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_open)
                      MissingGuideView(
                        guide: guide,
                        documentId: document.id,
                        seeAlso: guide.seeProcedure == null
                            ? null
                            : widget.procedureById(guide.seeProcedure!),
                      ),
                  ],
                  VerificationBadge(status: document.verification),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SafeText(
        label,
        where: 'DocumentSection.chip',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
