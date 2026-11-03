import 'package:domain_data/domain_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/asset_domain_source.dart';
import '../welfare/welfare_match.dart';
import 'domain_providers.dart';

/// 복지 자료를 읽는 곳.
final welfareSourceProvider =
    Provider<AssetWelfareSource>((ref) => const AssetWelfareSource());

/// 중앙부처 복지 자료. **부팅 때 읽지 않는다.**
///
/// `central.json` 이 1.2MB 다. 홈을 여는 데 필요 없는 것을 부팅에 물리면
/// 기다리는 화면이 길어진다 — 그 화면은 짧으려고 만든 것이다.
/// 두 번째 문으로 들어온 사람에게만 읽는다.
final welfareCatalogProvider = FutureProvider<CentralWelfareCatalog>(
  (ref) => ref.watch(welfareSourceProvider).loadCentral(),
);

/// 두 번째 문에서 받은 답. **메모리에만 있다.**
///
/// 주소에도 안 싣고 기기에도 안 남긴다. 홈에서 「저장하지 않아요」라고 한
/// 약속이 이 흐름에도 그대로 적용된다 — 오히려 여기가 더 민감하다.
/// 사건 이야기는 본인이 적은 글이지만, 이건 **우리가 물어서 받은 것**이다.
class WelfareAnswersController extends Notifier<WelfareAnswers> {
  @override
  WelfareAnswers build() => const WelfareAnswers();

  void setBirthYear(int? year) =>
      state = state.copyWith(birthYear: year);

  void setWork(WelfareWork work) => state = state.copyWith(work: work);

  void toggleHousehold(String name) => state = state.copyWith(
        households: _toggled(state.households, name),
      );

  void toggleTopic(String name) => state = state.copyWith(
        topics: _toggled(state.topics, name),
      );

  void setOnlineOnly(bool value) => state = state.copyWith(onlineOnly: value);

  /// 처음부터 다시. 화면을 떠날 때 부른다.
  void clear() => state = const WelfareAnswers();

  static Set<String> _toggled(Set<String> current, String name) {
    final next = {...current};
    if (!next.remove(name)) next.add(name);
    return next;
  }
}

final welfareAnswersProvider =
    NotifierProvider<WelfareAnswersController, WelfareAnswers>(
  WelfareAnswersController.new,
);

/// 자료에 실제로 나오는 가구상황 이름. **우리가 목록을 적어 두지 않는다.**
///
/// 화면에 여섯 개를 손으로 박아 두면 자료가 일곱 개가 되는 날 하나가 조용히
/// 사라진다. 고를 수 있는 것은 **자료가 가진 것**이어야 한다.
final welfareHouseholdNamesProvider = Provider<List<String>>(
  (ref) => _axisNames(ref, (service) => service.households),
);

/// 자료에 실제로 나오는 관심주제 이름. 위와 같은 이유로 자료에서 뽑는다.
final welfareTopicNamesProvider = Provider<List<String>>(
  (ref) => _axisNames(ref, (service) => service.topics),
);

List<String> _axisNames(
  Ref ref,
  List<String> Function(CentralWelfareService) pick,
) {
  final loaded = ref.watch(welfareCatalogProvider);
  if (!loaded.hasValue) return const [];

  final names = <String>{
    for (final service in loaded.requireValue.services) ...pick(service),
  }.toList()
    ..sort();
  return names;
}

/// 어느 분야에서 건너왔는가. 그 분야의 다리를 꺼낸다. 없으면 null.
///
/// **주소의 `from` 에서 온다.** 분야 id 는 공개 정보라 주소에 남아도 되고,
/// 새로고침해도 좁혀 둔 상태가 그대로 살아 있어야 맞다.
WelfareBridge? welfareBridgeOf(Ref ref, String? domainId) {
  if (domainId == null) return null;
  if (!ref.watch(domainBundleProvider).hasValue) return null;
  return requireBundle(ref).domains[domainId]?.welfareBridge;
}

/// 좁힌 결과. 자료가 아직 안 읽혔으면 null.
///
/// 화면이 다시 계산하지 않는다 — 개수 줄과 목록이 **같은 한 값**을 본다.
/// 따로 세면 「87건이 걸렸어요」 아래에 86줄이 놓이는 날이 온다.
final welfareMatchProvider = Provider.family<WelfareMatch?, String?>(
  (ref, from) {
    final loaded = ref.watch(welfareCatalogProvider);
    if (!loaded.hasValue) return null;

    return matchWelfare(
      catalog: loaded.requireValue,
      answers: ref
          .watch(welfareAnswersProvider)
          .copyWith(bridge: welfareBridgeOf(ref, from)),
      today: ref.watch(todayProvider),
    );
  },
);
