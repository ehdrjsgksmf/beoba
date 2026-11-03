import 'package:domain_data/domain_data.dart' show Glossary, GlossaryTerm;
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';
import 'layer_style.dart';
import 'legal_basis_card.dart';

/// 용어집을 화면 아래로 내려 준다.
///
/// [SafeText] 는 어디서나 쓰이는데 용어집을 인자로 받게 하면 호출부 수십 곳이
/// 용어집을 알아야 한다. 그래서 위에서 한 번 깔고 아래에서 찾아 쓴다.
/// **없으면 밑줄을 안 그린다** — 위젯만 띄우는 테스트가 그대로 돈다.
class GlossaryScope extends InheritedWidget {
  const GlossaryScope({
    required this.glossary,
    required super.child,
    super.key,
  });

  final Glossary glossary;

  static Glossary? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GlossaryScope>()
      ?.glossary;

  @override
  bool updateShouldNotify(GlossaryScope oldWidget) =>
      oldWidget.glossary != glossary;
}

/// 지금 시트가 몇 겹째인가.
///
/// **폰에서 시트가 세 겹 쌓이면 뒤로가기를 세 번 눌러야 원래 자리로
/// 돌아온다.** 그 순간 사람은 자기가 어디에 있었는지 잊는다. 그래서
/// 밑줄은 [maxDepth] 겹까지만 그린다 — 그 아래에서는 같은 글자를 평문으로
/// 그려서 더 깊이 들어갈 문 자체를 없앤다.
///
/// 시트는 `Navigator` 아래 별도 라우트라 위쪽 `InheritedWidget` 이 안 보인다.
/// 그래서 깊이를 시트가 자기 안에 다시 깔아 준다.
class TermDepth extends InheritedWidget {
  const TermDepth({required this.depth, required super.child, super.key});

  /// 화면은 0, 처음 열린 시트가 1.
  final int depth;

  /// 밑줄을 그리는 마지막 겹. 화면(0)과 첫 시트(1)까지다.
  static const int maxDepth = 1;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TermDepth>()?.depth ?? 0;

  /// 여기서 밑줄을 그려도 되는가.
  static bool allowsUnderline(BuildContext context) => of(context) <= maxDepth;

  @override
  bool updateShouldNotify(TermDepth oldWidget) => oldWidget.depth != depth;
}

/// 한 낱말의 뜻. **여기서 열리고 여기서 닫힌다.**
///
/// 순서를 고정한다 — 말 → (🟡이면) 우리 말이라는 고지 → 한 줄 풀이 →
/// (🟢이면) 조문 원문 → 출처 → 닫기.
///
/// **조문을 접지 않는다.** 접으면 아무도 안 연다. 길면 시트 안에서 스크롤한다.
class TermSheet extends StatelessWidget {
  const TermSheet({required this.entry, this.depth = 1, super.key});

  final GlossaryTerm entry;

  /// 몇 겹째로 열린 시트인가. 화면에서 열면 1이다.
  final int depth;

  /// 🟡 맨 위에 반드시 뜨는 줄. **우리 말이라고 먼저 밝힌다.**
  static const String ourWordsNotice =
      '이 말은 법에 뜻이 따로 정해져 있지 않아요. 아래는 저희가 쉽게 풀어 쓴 설명이에요.';
  static const String statuteHeading = '법에는 이렇게 쓰여 있어요';
  static const String closeLabel = '닫기';

  /// 시트를 연다. 누른 자리에서 열리고 그 자리로 돌아온다.
  static Future<void> open(
    BuildContext context,
    GlossaryTerm entry, {
    int depth = 1,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: BeobaColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BeobaSpace.radius),
          ),
        ),
        builder: (_) => TermSheet(entry: entry, depth: depth),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = entry.kind.hasStatute ? LayerStyle.statute : LayerStyle.likely;

    return TermDepth(
      depth: depth,
      child: _body(context, theme, style),
    );
  }

  Widget _body(BuildContext context, TextTheme theme, LayerStyle style) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ① 말
              Row(
                children: [
                  Expanded(
                    child: SafeText(
                      entry.term,
                      where: 'GlossaryTerm.term',
                      style: theme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 그림 대신 글자 배지(DECISIONS 286번).
                  LayerBadge(style: style, where: 'TermSheet.layer'),
                ],
              ),

              // ② 🟡 이면 우리 말이라고 먼저 밝힌다
              if (!entry.kind.hasStatute) ...[
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius:
                        BorderRadius.circular(BeobaSpace.radiusInner),
                  ),
                  child: SafeText(
                    ourWordsNotice,
                    where: 'TermSheet.ourWordsNotice',
                    style: theme.labelMedium?.copyWith(color: style.color),
                  ),
                ),
              ],

              // ③ 한 줄 풀이
              const SizedBox(height: 13),
              SafeText(
                entry.oneLiner,
                where: 'GlossaryTerm.oneLiner',
                style: theme.bodyMedium,
              ),

              // ④ 🟢 이면 조문 원문. **접지 않는다.**
              if (entry.lawRef case final basis?) ...[
                const SizedBox(height: 15),
                SafeText(
                  statuteHeading,
                  where: 'TermSheet.statuteHeading',
                  style: theme.labelSmall?.copyWith(
                    color: BeobaColors.ink3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                LegalBasisCard(
                  basis: basis,
                  where: 'GlossaryTerm.${entry.term}',
                  collapsible: false,
                ),
                for (final also in entry.alsoBasis) ...[
                  const SizedBox(height: 8),
                  LegalBasisCard(
                    basis: also,
                    where: 'GlossaryTerm.${entry.term}.also',
                    collapsible: false,
                  ),
                ],
                // ⑤ 출처 — 어느 판본을 읽었는지.
                if (entry.effective.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  SafeText(
                    _sourceLine(entry),
                    where: 'GlossaryTerm.effective',
                    style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
                  ),
                ],
              ],

              // ⑥ 닫기
              const SizedBox(height: 18),
              SizedBox(
                height: BeobaTapTarget.button,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: SafeText(closeLabel, where: 'TermSheet.closeLabel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「민사소송법 제462조 · 2025-07-12 시행」
///
/// 판본이 매니페스트와 맞는지는 **빌드가 본다.** 앱은 매니페스트를 싣지 않는다.
String _sourceLine(GlossaryTerm entry) {
  final basis = entry.lawRef;
  final law = [basis?.law, basis?.article]
      .where((p) => p != null && p.isNotEmpty)
      .join(' ');
  return '$law · ${entry.effective} 시행';
}
