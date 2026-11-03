import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../providers/domain_providers.dart';
import '../../providers/interview_providers.dart';
import '../../providers/result_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/crisis_banner.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/today_pill.dart';
import '../bootstrap_gate.dart';
import '../../widgets/layer_block.dart';
import 'sections/period_rule_section.dart';

/// 근거 — **이 날짜와 금액이 어디서 나왔는지.**
///
/// ## 여기 남는 것과 요약으로 간 것
///
/// ```
/// 여기   3층(조문 원문 · 이 사건에 대어 본 것 · 확인 안 된 것) · 날짜 세는 법
/// 요약   비용 · 서류 · 관할 · 절차 — 전부 접힌 카드 안으로 들어갔다
/// ```
///
/// 예전에는 이 화면이 요약의 두 배쯤 됐다. 그런데 사용자가 여기까지 오는 이유는
/// 하나뿐이다 — **저 숫자가 맞나 검산하려고.** 검산에 필요 없는 것을 여기 두면
/// 정작 근거가 아래로 밀린다. 요약에서 이미 펼쳐 볼 수 있는 것을 한 번 더
/// 늘어놓지 않는다.
///
/// 라우트로 나누면 뒤로가기의 뜻도 분명해진다 — 여기서 뒤로 가면 요약이고,
/// 요약에서 뒤로 가면 정리 카드다.
class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({required this.domainId, super.key});

  final String domainId;

  static const String title = '이 날짜와 금액이 어디서 나왔는지';
  static const String back = '요약으로 돌아가기';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: beobaAppBar(context),
      body: BootstrapGate(
        child: Consumer(builder: (context, ref, _) => _body(context, ref)),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;

    void goFix(String questionId) {
      final questions = ref.read(applicableQuestionsProvider(domainId));
      final index = questions.indexWhere((q) => q.id == questionId);
      context.push(Routes.interview(domainId, index < 0 ? null : index + 1));
    }

    return PageBody(
      bottom: PrimaryButton(
        label: back,
        where: 'ResultDetailScreen.back',
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(Routes.result(domainId)),
      ),
      children: [
        SafeText(title, where: 'ResultDetailScreen.title', style: theme.headlineSmall),
        const SizedBox(height: 20),
        LayerSection(
          blocks: ref.watch(layerBlocksProvider(domainId)),
          onFix: goFix,
        ),
        // 규칙은 맨 아래다. 이 사건의 이야기가 먼저다.
        PeriodRuleSection(
          rules: ref.watch(periodRulesProvider(domainId)),
          // 어디까지 반영했는지 화면이 말한다. **없는 것을 말하는 자리다.**
          lastCoveredYear: ref
              .watch(domainBundleProvider)
              .requireValue
              .holidays
              .lastCoveredYear,
        ),
        CrisisFooter(domainId: domainId),
      ],
    );
  }
}
