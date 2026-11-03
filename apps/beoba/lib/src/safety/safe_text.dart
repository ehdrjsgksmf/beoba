import 'package:engines/engines.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../widgets/term_sheet.dart';
import 'safety_reporter.dart';

/// 사용자에게 보이는 모든 문구는 이 위젯을 거친다 (CONTRIBUTING.md 규칙 5).
///
/// `apps/beoba/lib/src/screens/` · `widgets/` 에서 `Text(` 를 직접 쓰면
/// `verify_domains.dart` 가 빌드를 세운다. 규칙을 기억에 맡기지 않는다.
///
/// - 디버그·테스트: `assert` 로 즉시 실패한다. 위젯 테스트가 잡는다
/// - 릴리스: 문구를 **그리지 않고** [BlockedNotice] 로 대체한 뒤 기록을 남긴다
///
/// 부실한 문구를 보여주느니 안 보여주는 편이 낫다. 다만 기한처럼 못 보면 권리를
/// 잃는 정보는 예외다 — 그건 호출부가 [DeadlineCard] 처럼 따로 지킨다.
class SafeText extends StatelessWidget {
  const SafeText(
    this.data, {
    required this.where,
    this.scope = SafetyScope.strict,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.selectable = false,
    super.key,
  });

  /// 인용 문구(조문 원문 · 상한 안내)를 그릴 때.
  ///
  /// `scopeFor('LegalBasis', 'text')` 처럼 필드로 scope 를 고르는 대신
  /// 타입·필드 이름을 그대로 넘긴다. scope 매핑은 코드에만 있다 (DECISIONS.md 5번).
  SafeText.forField(
    this.data, {
    required String typeName,
    required String fieldName,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.selectable = false,
    super.key,
  })  : scope = scopeFor(typeName, fieldName),
        where = '$typeName.$fieldName';

  final String data;

  /// 어느 필드·화면인지. 차단 기록에 남는다. 문구 자체는 남기지 않는다.
  final String where;
  final SafetyScope scope;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// 사용자가 글자를 손으로 골라 갈 수 있게 할지.
  ///
  /// **복사가 막힌 환경의 되돌림 자리다.** 웹 클립보드는 보안 컨텍스트가
  /// 아니면 아예 없어서(엔진이 `navigator.clipboard` 하나만 쓴다) 버튼이
  /// 조용히 실패한다. 그때 **글자를 고를 수 있게 띄우면 사람이 직접 가져간다.**
  /// 버튼이 있는데 안 되는 것보다 낫다.
  ///
  /// 밑줄 낱말(`[[…]]`)이 섞여 있어도 **대괄호를 뗀 문장**을 고르게 한다 —
  /// 고른 글자에 우리 표시가 딸려 가면 안 된다.
  final bool selectable;

  /// 디버그에서 위반을 예외로 올릴지.
  ///
  /// 예외가 올라가면 위젯이 끝까지 그려지지 않아 **릴리스 동작(대체 안내)을 볼 수
  /// 없다.** 그 경로를 확인하는 테스트에서만 끈다. 평소에는 켜 둔다.
  @visibleForTesting
  static bool debugAssertOnViolation = true;

  @override
  Widget build(BuildContext context) {
    // **검사는 대괄호를 뗀 문장을 본다.** `[[` 가 끼면 낱말이 갈라져 금지어가
    // 빠져나간다. 사용자가 읽는 것도 이쪽이다.
    final shown = stripTerms(data);

    // 스캔은 한 번만 돈다. isSafe 와 assertSafe 를 겹쳐 부르면 같은 일을 두 번 한다.
    final violations = SafetyFilter.scan(shown, scope: scope, where: where);
    if (violations.isEmpty) {
      // **고를 수 있게 띄우는 자리에서는 밑줄 낱말을 그리지 않는다.**
      // 사람이 끌어가는 것은 창구에 내밀 글자이고, 거기에 우리 표시가
      // 섞이면 안 된다.
      if (selectable) {
        return SelectableText(
          shown,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
        );
      }
      final spans = parseTerms(data);
      if (spans.any((s) => s.isTerm)) {
        return _TermRichText(
          spans: spans,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      }
      return Text(
        shown,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // 보고가 먼저다. assert 가 앞서면 디버그에서 던져 버려 report 가 영영 불리지
    // 않고, flutter test 는 디버그로 돌기 때문에 이 경로를 테스트할 수 없게 된다.
    SafetyReporterScope.of(context).report(violations, scope: scope);
    if (debugAssertOnViolation) {
      assert(
        false,
        '$where — 금지 표현 ${violations.map((v) => v.pattern).join(', ')}',
      );
    }
    return const BlockedNotice();
  }
}

/// 문구를 그리지 못했을 때 그 자리에 놓는 안내.
///
/// 빈 자리를 남기지 않는다. 무언가 있었는데 못 보여준다는 사실은 알려야 한다.
class BlockedNotice extends StatelessWidget {
  const BlockedNotice({super.key});

  /// 화면 문구. `verify_domains` 의 한글 문자열 검사도 통과해야 한다.
  static const String message = '표시할 수 없는 문구입니다. 확인 후 다시 안내드립니다.';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: BeobaColors.surfaceStrong,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: BeobaColors.ink3),
          const SizedBox(width: 8),
          Flexible(
            // ignore: avoid_redundant_argument_values
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// 밑줄이 섞인 문장.
///
/// **점선 밑줄이다. 파란 글씨 링크로 하지 않는다** — 누르면 다른 데로 간다는
/// 뜻으로 읽힌다. 여기서 열리고 여기서 닫힌다.
///
/// 용어집이 위에 안 깔려 있으면 밑줄 없이 그냥 그린다. 위젯만 띄우는 테스트가
/// 용어집을 몰라도 되게 하려는 것이다.
class _TermRichText extends StatefulWidget {
  const _TermRichText({
    required this.spans,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final List<TermSpan> spans;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<_TermRichText> createState() => _TermRichTextState();
}

class _TermRichTextState extends State<_TermRichText> {
  /// 낱말마다 하나씩. **다시 만들지 않는다.**
  ///
  /// 빌드마다 새로 만들면 손가락이 눌렸다 떼는 사이에 앞의 것이 버려져
  /// 탭이 통째로 사라진다. 시트가 열리며 아래 화면이 다시 그려지는 자리라
  /// 실제로 그 일이 났다.
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // **한 겹까지만 연다.** 더 깊은 자리에서는 밑줄을 안 그려서 들어갈 문
    // 자체를 없앤다 — 시트가 쌓이면 사람이 자기가 어디 있었는지 잊는다.
    final depth = TermDepth.of(context);
    final glossary =
        TermDepth.allowsUnderline(context) ? GlossaryScope.maybeOf(context) : null;
    // **같은 말은 첫 번째만 밑줄.** 한 문장에 세 번 나오면 밑줄 밭이 된다.
    final marked = <String>{};
    final children = <InlineSpan>[];

    for (final span in widget.spans) {
      final term = span.term;
      final entry = term == null ? null : glossary?.byTerm(term);
      if (entry == null || !marked.add(term!)) {
        children.add(TextSpan(text: span.text));
        continue;
      }
      final recognizer = _recognizers[term] ??= TapGestureRecognizer();
      recognizer.onTap = () => TermSheet.open(context, entry, depth: depth + 1);
      children.add(
        TextSpan(
          text: span.text,
          recognizer: recognizer,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: BeobaColors.ink3,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: children),
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
