import 'package:engines/engines.dart' show SafetyScope;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../providers/domain_providers.dart';
import '../safety/safe_text.dart';

/// 처음 여실 때 한 번 — **쉬운 문장으로 볼지 묻는다** (DECISIONS 289번).
///
/// ★★ **버튼 글자 자체가 쉬운 말이다.** 「쉬운 말로 보기」 스위치는 그게
/// 필요한 분에게 안 읽힌다. 물음으로 앞에 세우면 스위치를 찾을 필요가 없다.
///
/// ## 지키는 것
///
/// ```
/// 버튼 둘    둘 다 회색 · 같은 크기 — 한쪽을 색으로 밀지 않는다(288)
/// 닫기       뒤로 가기 · 바깥 누름으로 안 닫힌다 — 고르셔야 닫힌다
/// 순서       기기 글자를 1.3배 넘게 키웠으면 「쉬운 말로 볼게요」가 앞에 온다.
///            **순서만** 바꾼다. 저절로 켜지 않는다 — 틀렸을 때 모르고 넘어간다
/// ```
///
/// ★ **「어려운 말을」이라고 묻지 않는다.** 쉬운 말 모드는 낱말을 안 바꾸고
/// 문장을 바꾼다 — 용어집의 낱말을 빼는 쉬운 말 문장은 0개다. 그리고
/// 「짧고」도 안 쓴다 — 쉬운 말 369곳 중 190곳이 원문보다 길다.
///
/// ★ **보기는 데이터에서 온다.** 지어 쓰지 않는다. 그 물음이나 쉬운 말이
/// 없어지면 보기 줄이 빠진다 — `plain_mode_ask_test` 가 실제 데이터에 둘이
/// 있는지 본다.
class PlainModeAskSheet extends ConsumerWidget {
  const PlainModeAskSheet({super.key});

  static const String title = '설명을 더 쉬운 문장으로 보여드릴까요?';
  static const String examplePrefix = '예)';
  static const String body = '저희가 쓴 설명만 바꿔요. '
      '법에 쓰인 말과 기관 이름은 창구에서 그대로 쓰셔야 해서 안 바꿔요. '
      '화면 위에서 언제든 다시 바꿀 수 있어요.';
  static const String keep = '그대로 볼게요';
  static const String plain = '쉬운 말로 볼게요';

  /// 보기 한 쌍이 있는 자리. **분야 id 와 물음 id 는 공개된 구조다** — 문장은
  /// 데이터에 있다.
  static const String exampleDomain = 'estate_division';
  static const String exampleQuestion = 'q_will_direction';

  /// 이 배율을 넘으면 「쉬운 말로 볼게요」를 앞에 둔다.
  // not-a-legal-number: 글자 배율 눈금. 법률 수치가 아니다.
  static const double largeTextScale = 1.3;

  /// 원문과 쉬운 말. 데이터에 없으면 null — 보기 줄을 안 그린다.
  static (String, String)? exampleFrom(DomainBundle bundle) {
    final domain = bundle.domains[exampleDomain];
    final question = domain?.intake
        .where((q) => q.id == exampleQuestion)
        .firstOrNull;
    final plainText = domain?.plain['intake.$exampleQuestion.text'];
    if (question == null || plainText == null) return null;
    if (question.text == plainText) return null;
    return (question.text, plainText);
  }

  /// 아직 한 번도 안 고르셨으면 연다. **열었으면 true.**
  static Future<bool> openIfUnanswered(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final saved = await ref.read(plainModeSavedProvider.future);
    if (saved != null) return false;
    if (!context.mounted) return false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 고르셔야 닫힌다. 실수로 닫히면 무엇을 고르신 건지 모른다.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: BeobaColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BeobaSpace.radius),
        ),
      ),
      builder: (_) => const PlainModeAskSheet(),
    );
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final bundle = ref.watch(domainBundleProvider).value;
    final example = bundle == null ? null : exampleFrom(bundle);
    final large =
        MediaQuery.textScalerOf(context).scale(1) > largeTextScale;

    void answer(bool on) {
      ref.read(plainModeProvider.notifier).set(on);
      Navigator.of(context).pop();
    }

    Widget button(String label, bool on, String where) => Expanded(
          child: OutlinedButton(
            onPressed: () => answer(on),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(BeobaTapTarget.button),
            ),
            child: SafeText(label, where: where, textAlign: TextAlign.center),
          ),
        );

    final keepButton = button(keep, false, 'PlainModeAskSheet.keep');
    final plainButton = button(plain, true, 'PlainModeAskSheet.plain');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeText(
              title,
              where: 'PlainModeAskSheet.title',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (example case (final before, final after)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BeobaColors.surfaceStrong,
                  borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      '$examplePrefix  $before',
                      where: 'PlainModeAskSheet.example.before',
                      scope: SafetyScope.quote,
                      style: theme.bodyMedium?.copyWith(
                        color: BeobaColors.ink2,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SafeText(
                      '→  $after',
                      where: 'PlainModeAskSheet.example.after',
                      scope: SafetyScope.quote,
                      style: theme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SafeText(
              body,
              where: 'PlainModeAskSheet.body',
              style: theme.bodyMedium?.copyWith(
                color: BeobaColors.ink2,
                height: 1.62,
              ),
            ),
            const SizedBox(height: 20),
            // **같은 무게다.** 한쪽만 크게 · 파랗게 만들지 않는다.
            Row(
              children: large
                  ? [plainButton, const SizedBox(width: 10), keepButton]
                  : [keepButton, const SizedBox(width: 10), plainButton],
            ),
          ],
        ),
      ),
    );
  }
}
