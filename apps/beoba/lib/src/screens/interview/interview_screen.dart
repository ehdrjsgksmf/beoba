import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../format/formatters.dart';
import '../../interview/interview_session.dart';
import '../../providers/interview_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/broker_alert_card.dart';
import '../../widgets/crisis_banner.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/progress_header.dart';
import '../../widgets/verification_badge.dart';
import '../../widgets/why_ask_card.dart';
import '../bootstrap_gate.dart';
import 'answers/answer_input.dart';
import 'redirect_notice.dart';

/// 인터뷰 — 한 화면에 질문 하나, **한 라우트에 질문 하나**.
///
/// 질문마다 라우트를 주면 브라우저 뒤로가기와 Android 하드웨어 뒤로가기가
/// 저절로 질문 단위로 움직인다. 커서를 상태로 들고 가로채는 방식은 앱 안 버튼과
/// 시스템 버튼이 서로 다르게 움직이게 만든다.
///
/// 주소에는 **순번만** 넣는다 (`/interview/debt_recovery/3`). 질문 id 를 넣으면
/// 무엇을 물었는지가 주소창과 히스토리에 남는다.
class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({
    required this.domainId,
    required this.step,
    this.fromSummary = false,
    super.key,
  });

  final String domainId;

  /// 1부터 시작하는 순번. 라우터 가드가 유효한 값만 넘긴다.
  final int step;

  /// 정리 카드에서 "고치기" 로 왔다. 저장하면 정리 카드로 돌아간다.
  final bool fromSummary;

  static const String next = '다음';
  static const String save = '고친 내용 저장';

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  /// 화면에서 만지는 중인 값. "다음" 을 눌러야 세션에 들어간다.
  Object? _draft;
  String? _draftFor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: beobaAppBar(context),
      body: BootstrapGate(
        child: Column(
          children: [
            CrisisPinnedBar(domainId: widget.domainId),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final domainId = widget.domainId;

    // 다른 분야로 넘겨야 하는 답을 골랐다. M1 에는 옮겨 갈 곳이 없어 안내로 끝낸다.
    final redirect = ref.watch(redirectDomainProvider(domainId));
    if (redirect != null) {
      return RedirectNotice(domainId: domainId, targetDomainId: redirect);
    }

    final questions = ref.watch(applicableQuestionsProvider(domainId));
    final question = questionAtStep(questions, widget.step);
    // 가드가 교정하는 사이 한 프레임 비는 경우가 있다.
    if (question == null) return const SizedBox.shrink();

    _syncDraft(question);

    final state = ref.watch(interviewStateProvider(domainId));
    final session = ref.watch(interviewSessionProvider(domainId));
    final theme = Theme.of(context).textTheme;
    final editing = session.stepFor(question.id) != null;
    final ready = hasAnswer(question, _draft) || !question.isRequired;

    return PageBody(
      bottom: PrimaryButton(
        label: editing ? InterviewScreen.save : InterviewScreen.next,
        where: 'InterviewScreen.next',
        onPressed: ready ? () => _submit(question, questions.length) : null,
      ),
      children: [
        ProgressHeader(
          answered: widget.step - 1,
          total: questions.length,
          state: state,
        ),
        const SizedBox(height: 20),
        CrisisBanners(domainId: domainId),
        // ② 방어. 브로커의 말이 사용자 문장에 있으면 그 자리에서 되짚는다.
        // **차단이 아니다** — 닫으면 하던 일을 계속한다.
        BrokerAlerts(domainId: domainId),
        // 직전 답을 한 줄 되받는다. 아무 반응 없이 다음 질문으로 가면 시험지가
        // 된다. 되받을 것이 없으면 아무것도 안 나온다.
        if (_echo(questions, session) case final String line) ...[
          SafeText(
            line,
            where: 'Question.echo',
            style: theme.bodyMedium?.copyWith(
              color: BeobaColors.ink2,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SafeText(
          question.text,
          where: 'Question.text',
          style: theme.headlineSmall,
        ),
        if (question.verification != null)
          VerificationBadge(status: question.verification!.status),
        const SizedBox(height: 18),
        AnswerInput(
          // 질문이 바뀌면 입력 위젯의 내부 상태를 버린다.
          key: ValueKey(question.id),
          question: question,
          value: _draft,
          onChanged: (value) => setState(() => _draft = value),
        ),
        WhyAskCard(whyAsk: question.whyAsk),
      ],
    );
  }

  /// 바로 앞 질문의 답을 되받는 말. 되받을 것이 없으면 null.
  ///
  /// **직전 하나만** 본다. 여러 개를 나열하면 그건 요약이지 대화가 아니다.
  /// 화면 순서로 앞 질문을 잡으므로 되돌아가서 고치는 중에도 흔들리지 않는다.
  ///
  /// 홈의 자유 서술은 되받지 않는다. 가장 사적인 문장이라 화면에 다시 띄우면
  /// 옆사람이 본다.
  ///
  /// ★ **화면에서는 금액·날짜만 되받는다.** 데이터에는 거의 모든 물음에
  /// 되받는 말이 있는데, 그건 **정리해서 가져가는 글**의 「내 상황」 절을
  /// 만들려고 채운 것이다. 글에는 다 들어가야 하고 화면에는 그러면 안 된다 —
  /// 열두 번 다 되받으면 잔소리다.
  ///
  /// **한 자리가 두 곳에 쓰이는 것이지, 두 곳이 같은 규칙인 것은 아니다.**
  /// 거르는 것은 여기서 한다. 데이터를 두 벌로 나누지 않는다.
  String? _echo(List<Question> questions, InterviewSession session) {
    final index = widget.step - 2;
    if (index < 0 || index >= questions.length) return null;
    final previous = questions[index];
    if (previous.type != QuestionType.money &&
        previous.type != QuestionType.date) {
      return null;
    }
    final step = session.stepFor(previous.id);
    if (step == null) return null;
    return formatEcho(previous, step.value);
  }

  /// 질문이 바뀌었으면 이전 답을 초안에 채운다. 되돌아왔을 때 그대로 보인다.
  void _syncDraft(Question question) {
    if (_draftFor == question.id) return;
    _draftFor = question.id;
    _draft = ref
        .read(interviewSessionProvider(widget.domainId))
        .stepFor(question.id)
        ?.value;
  }

  void _submit(Question question, int total) {
    final domainId = widget.domainId;
    ref.read(interviewSessionProvider(domainId).notifier).answer(
          question.id,
          _draft,
        );

    // 답 하나로 하드스톱이 걸릴 수 있다. 다음 질문을 그리기 전에 본다.
    final stops = ref.read(hardStopsProvider(domainId));
    if (stops.isNotEmpty) {
      if (stops.first.needsConfirmation) {
        // 확인 화면은 되물을 뿐이다. 뒤로 나갈 수 있어야 한다.
        context.push(Routes.hardStopConfirm(domainId));
      } else {
        // 차단은 흐름의 끝이다. push 로 열면 뒤로가기로 빠져나온다.
        context.go(Routes.hardStop(domainId));
      }
      return;
    }

    // 정리 카드에서 고치러 왔으면 고친 뒤 정리 카드로 돌아간다.
    if (widget.fromSummary) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.summary(domainId));
      }
      return;
    }

    // 다음 질문. 답을 고쳐 목록이 줄었으면 가드가 유효한 자리로 데려간다.
    final current = ref.read(currentStepProvider(domainId));
    if (current == null) {
      context.push(Routes.summary(domainId));
      return;
    }
    context.push(Routes.interview(domainId, current));
  }
}
