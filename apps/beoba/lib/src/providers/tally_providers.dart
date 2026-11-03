import 'package:engines/engines.dart' show SessionTally;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tally/tally.dart';
import 'interview_providers.dart';

/// 보내는 자리. 지금은 아무 데도 안 보낸다.
final tallySinkProvider = Provider<TallySink>((_) => const NoopTallySink());

/// 「세도 되는지」 답을 남기는 자리.
final consentStoreProvider =
    Provider<ConsentStore>((_) => const PrefsConsentStore());

/// 물어봤는가 · 뭐라고 답했는가. 아직 안 물어봤으면 null.
final tallyConsentProvider =
    AsyncNotifierProvider<TallyConsent, bool?>(TallyConsent.new);

class TallyConsent extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() => ref.read(consentStoreProvider).read();

  Future<void> answer({required bool allowed}) async {
    await ref.read(consentStoreProvider).write(allowed);
    state = AsyncData(allowed);
  }
}

/// 세션 하나에 **한 번만** 보낸다.
///
/// 「세지 마세요」를 고르셨으면 **아무것도 안 나간다.** 아직 안 물어본
/// 상태에서도 안 나간다 — 물어보고 켠다(DECISIONS 137번).
class SessionTallySender {
  SessionTallySender(this._ref);

  final Ref _ref;
  bool _sent = false;

  /// 이미 보냈으면 아무 일도 안 한다. 보냈으면 true.
  Future<bool> sendOnce(SessionTally tally) async {
    if (_sent) return false;
    // 답을 다 읽고 나서 본다. 읽는 중이라고 보내면 안 된다.
    if (await _ref.read(tallyConsentProvider.future) != true) return false;
    _sent = true;
    // 실패는 조용히 넘어간다. 세는 것 때문에 화면이 멈추면 안 된다.
    try {
      await _ref.read(tallySinkProvider).send(tally);
    } on Object {
      return false;
    }
    return true;
  }
}

final sessionTallySenderProvider =
    Provider<SessionTallySender>(SessionTallySender.new);

/// 지금 세션의 집계 한 줄. **원문은 없다.**
///
/// `exitAt` 은 지금 답해야 할 질문의 **id** 다. 답이 아니다 — 「지급명령을
/// 받았다」가 여기 들어오면 안 된다. 결과까지 갔으면 물어볼 것이 없으니
/// 빈 문자열이다.
SessionTally tallyOf(WidgetRef ref, String domainId, {required bool reached}) {
  final questions = ref.read(applicableQuestionsProvider(domainId));
  final step = ref.read(currentStepProvider(domainId));
  final at = step == null ? null : questionAtStep(questions, step);

  return SessionTally(
    domain: domainId,
    role: ref.read(caseFactsProvider(domainId)).get<String>('userRole') ?? '',
    exitAt: at?.id ?? '',
    reached: reached,
    version: kAppVersion,
  );
}

/// 앱 버전. pubspec 과 함께 올린다.
const String kAppVersion = '1.0.0';
