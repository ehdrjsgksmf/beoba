import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

import 'interview_session.dart';

/// 하드스톱이 어떻게 걸렸는가. **확신도가 다르다.**
enum HardStopKind {
  /// 자유 입력 문장에서 낱말을 주웠다. 추정이다.
  ///
  /// "빌려준 돈을 안 갚아서 고소하겠다고 했더니 연락이 끊겼습니다" 는 명백한 민사인데
  /// `고소` 하나로 형사로 튕겨나간다. 과잉 차단은 사용자를 쫓아낸다.
  keyword,

  /// 사용자가 선택지를 골라 확정했다. 되물을 것이 없다.
  field,
}

/// 걸린 하드스톱 하나.
class TriggeredHardStop {
  const TriggeredHardStop({
    required this.domainId,
    required this.stop,
    required this.kind,
  });

  final String domainId;
  final HardStop stop;
  final HardStopKind kind;

  String get id => stop.id;

  /// 확인 화면을 거쳐야 하는가.
  bool get needsConfirmation => kind == HardStopKind.keyword;
}

/// 분야 도메인과 공용 위기 데이터를 **함께** 본다.
///
/// 하드스톱은 분야마다 따로 적지 않는다. 형사·불법도박 같은 것은 `_shared_crisis`
/// 한 곳에 있고 모든 분야에 적용된다.
///
/// 키워드 검사가 보는 것은 **사용자가 타이핑한 문자열뿐**이다. 분야 도메인의
/// `type: text` 질문은 엔진이 알아서 찾고, 홈 자유 입력은 여기서 더한다.
List<TriggeredHardStop> triggeredHardStops(
  Iterable<Domain> domains,
  CaseFacts facts, {
  InterviewEngine engine = const InterviewEngine(),
  Set<String> dismissedIds = const {},
}) {
  final results = <TriggeredHardStop>[];

  for (final domain in domains) {
    final byId = {for (final stop in domain.hardStops) stop.id: stop};
    final ids = engine.triggeredHardStops(
      domain,
      facts,
      extraTextFields: const {InterviewSession.narrativeField},
    );
    for (final id in ids) {
      final stop = byId[id];
      if (stop == null) continue;

      final kind = switch (stop.trigger) {
        KeywordHardStopTrigger() => HardStopKind.keyword,
        FieldHardStopTrigger() => HardStopKind.field,
      };

      // "아니요" 한 것은 다시 묻지 않는다. 다만 필드로 확정된 것은 되물릴 수 없다.
      if (kind == HardStopKind.keyword && dismissedIds.contains(id)) continue;

      results.add(
        TriggeredHardStop(domainId: domain.id, stop: stop, kind: kind),
      );
    }
  }

  // 확정된 것이 먼저다. 추정 때문에 확정을 뒤로 미루지 않는다.
  results.sort((a, b) => a.kind.index.compareTo(b.kind.index) * -1);
  return results;
}

/// [InterviewSession] 을 리플레이한 사실로 하드스톱을 본다.
List<TriggeredHardStop> hardStopsFor(
  Iterable<Domain> domains,
  InterviewSession session,
  CaseFacts facts,
) =>
    triggeredHardStops(
      domains,
      facts,
      dismissedIds: session.dismissedStopIds,
    );
