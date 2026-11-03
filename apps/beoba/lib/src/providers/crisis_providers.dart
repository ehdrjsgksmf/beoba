import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crisis/crisis_signal.dart';
import 'domain_providers.dart';
import 'interview_providers.dart';

/// 걸린 위기 신호 **전부**. 닫은 것도 포함한다.
///
/// 결과·정리 카드 하단이 이걸 쓴다. 급할 때 닫았다가 나중에 찾는 사람이 있다.
final allCrisisSignalsProvider =
    Provider.family<List<CrisisSignal>, String>((ref, domainId) {
  final bundle = requireBundle(ref);
  return crisisSignalsFor(
    bundle.crisis,
    bundle.byId(domainId),
    ref.watch(interviewSessionProvider(domainId)),
    ref.watch(caseFactsProvider(domainId)),
  );
});

/// 아직 닫지 않은 신호. 배너로 밀어 보여줄 대상.
final openCrisisSignalsProvider =
    Provider.family<List<CrisisSignal>, String>((ref, domainId) {
  final dismissed =
      ref.watch(interviewSessionProvider(domainId)).dismissedSignalIds;
  return [
    for (final signal in ref.watch(allCrisisSignalsProvider(domainId)))
      if (!dismissed.contains(signal.id)) signal,
  ];
});

/// 전체 화면으로 덮어야 하는 신호. 닫으면 사라진다.
///
/// 라우터 가드가 이걸 본다 — 화면마다 부르면 새 화면을 만들 때 빠뜨린다.
final priorityCrisisSignalProvider =
    Provider.family<CrisisSignal?, String>((ref, domainId) {
  for (final signal in ref.watch(openCrisisSignalsProvider(domainId))) {
    if (signal.isPriority) return signal;
  }
  return null;
});

/// 닫힌 뒤에도 남는 priority 신호. 상단 고정 줄이 이걸 쓴다.
///
/// **닫기는 제거가 아니라 강등이다.** 자살 신호를 세션에 한 번만 보여주고 마는 것은
/// 위험하다 — 급해서 닫은 사람과 필요 없어서 닫은 사람을 구분할 수 없다.
final pinnedCrisisSignalProvider =
    Provider.family<CrisisSignal?, String>((ref, domainId) {
  final dismissed =
      ref.watch(interviewSessionProvider(domainId)).dismissedSignalIds;
  for (final signal in ref.watch(allCrisisSignalsProvider(domainId))) {
    if (signal.isPriority && dismissed.contains(signal.id)) return signal;
  }
  return null;
});

/// 배너로 보여줄 신호 (priority 아닌 것 중 안 닫은 것).
final bannerCrisisSignalsProvider =
    Provider.family<List<CrisisSignal>, String>((ref, domainId) {
  return [
    for (final signal in ref.watch(openCrisisSignalsProvider(domainId)))
      if (!signal.isPriority) signal,
  ];
});
