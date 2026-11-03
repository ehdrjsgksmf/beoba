import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../interview/hard_stops.dart';
import '../../providers/domain_providers.dart';
import '../../providers/interview_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/crisis_channels.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';

/// 하드스톱 — 여기서 멈춘다.
///
/// **"계속 진행" 버튼이 없다.** 뒤로가기도 막는다. 다룰 수 없는 문제를 다루는
/// 시늉을 하느니 공적 창구로 넘긴다.
///
/// 다만 **잘못 답해서 온 사람에게는 길을 준다** — 차단을 뚫는 것과 답을 고치는 것은
/// 다르다. 저장이 없는 M1 에서 되돌릴 길이 없으면 12문항을 처음부터 다시 해야 한다.
class HardStopScreen extends ConsumerWidget {
  const HardStopScreen({required this.domainId, super.key});

  final String domainId;

  static const String fallbackTitle = '여기서 멈춥니다';
  static const String fallbackMessage = '이 문제는 마중이가 안내해 드릴 수 없어요.';
  static const String channelsTitle = '이곳에서 도움받으실 수 있습니다';
  static const String checklistTitle = '확인해 보세요';

  /// 오답 정정 경로.
  ///
  /// **"계속 진행" 이 아니다.** 차단을 우회하는 것처럼 읽히면 안 된다.
  /// 고치러 간다는 뜻만 말한다.
  static const String fixAnswer = '잘못 답한 것 같다면 그 질문으로 돌아가기';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final bundle = ref.watch(domainBundleProvider).requireValue;
    final triggered = ref.watch(hardStopsProvider(domainId));

    // 답이 바뀌어 더 이상 걸리지 않는다. 붙잡아 둘 이유가 없다.
    if (triggered.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.interview(domainId));
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final stop = triggered.first.stop;
    final channels = bundle.channelsFor(stop);
    final fixQuestionId = _questionBehind(ref, triggered.first);

    return PopScope(
      // 되돌아가지 않는다. 이 화면은 흐름의 끝이다.
      canPop: false,
      child: Scaffold(
        appBar: beobaAppBar(context, automaticallyImplyLeading: false),
        body: PageBody(
          bottom: fixQuestionId == null
              ? null
              : _FixAnswerLink(domainId: domainId, questionId: fixQuestionId),
          children: [
            SectionCard(
              background: BeobaColors.surfaceSoft,
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ⊖(금지)가 아니다. 사용자가 뭘 잘못한 게 아니라
                      // 우리가 여기서 멈추는 것이다.
                      const Icon(
                        Icons.pause_circle_outline,
                        size: 22,
                        color: BeobaColors.ink2,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SafeText(
                          stop.title ?? fallbackTitle,
                          where: 'HardStop.title',
                          style: theme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SafeText(
                    stop.message ?? fallbackMessage,
                    where: 'HardStop.message',
                    style: theme.bodyMedium?.copyWith(color: BeobaColors.ink2),
                  ),
                ],
              ),
            ),
            if (stop.checklist.isNotEmpty) ...[
              const SectionHeader(
                checklistTitle,
                icon: Icons.checklist_outlined,
              ),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in stop.checklist)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: BeobaColors.ink3,
                            ),
                            const SizedBox(width: 10),
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
                      ),
                  ],
                ),
              ),
            ],
            if (channels.isNotEmpty) ...[
              SectionHeader(channelsTitle, icon: Icons.support_agent_outlined),
              CrisisChannelList(channels: channels),
            ],
          ],
        ),
      ),
    );
  }

  /// 이 차단을 부른 답이 어느 질문에서 나왔는지.
  ///
  /// 필드 트리거일 때만 찾는다. 키워드는 사용자가 확인 화면에서 "네" 라고
  /// **확정한** 것이라 되돌릴 답이 없다.
  String? _questionBehind(WidgetRef ref, TriggeredHardStop triggered) {
    if (triggered.kind != HardStopKind.field) return null;
    final trigger = triggered.stop.trigger;
    if (trigger is! FieldHardStopTrigger) return null;

    final domain =
        ref.watch(domainBundleProvider).requireValue.byId(domainId);
    final session = ref.watch(interviewSessionProvider(domainId));

    for (final step in session.steps) {
      final question = domain.questionById(step.questionId);
      if (question == null) continue;

      // 질문이 그 필드에 직접 답을 담았거나
      if (question.field == trigger.field) return question.id;

      // 고른 선택지의 setsField 가 그 필드를 켰거나
      final selected = step.value is List
          ? (step.value! as List).map((v) => '$v').toSet()
          : {'${step.value}'};
      for (final option in question.options) {
        if (!selected.contains(option.value)) continue;
        if (option.setsField?.containsKey(trigger.field) ?? false) {
          return question.id;
        }
      }
    }
    return null;
  }
}

/// 답을 고치러 돌아가는 길.
class _FixAnswerLink extends ConsumerWidget {
  const _FixAnswerLink({required this.domainId, required this.questionId});

  final String domainId;
  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GhostButton(
      label: HardStopScreen.fixAnswer,
      where: 'HardStopScreen.fixAnswer',
      icon: Icons.edit_outlined,
      onPressed: () {
        final questions = ref.read(applicableQuestionsProvider(domainId));
        final index = questions.indexWhere((q) => q.id == questionId);
        context.go(Routes.interview(domainId, index < 0 ? null : index + 1));
      },
    );
  }
}
