import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../defense/broker_watch.dart';
import 'domain_providers.dart';
import 'interview_providers.dart';

/// 지나오면서 걸린 브로커 경보 **전부**. 닫은 것도 포함한다.
///
/// 결과 화면이 이걸 쓴다. 인터뷰 중에 한 번 보고 넘어간 사람이 결과 화면에서
/// 다시 봐야 한다 — **브로커는 결과를 본 뒤에 연락한다.**
final allBrokerWarningsProvider =
    Provider.family<List<BrokerWarning>, String>((ref, domainId) {
  final bundle = requireBundle(ref);
  return brokerWarningsFor(
    bundle.crisis,
    bundle.byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  );
});

/// 아직 닫지 않은 경보. 인터뷰 중에 그 자리에 띄울 대상.
///
/// 닫기를 두는 이유는 하나다 — 홈에서 한 번 걸린 경보가 질문 열세 개 내내
/// 같은 자리를 차지하면 사용자는 다음부터 그 자리를 안 본다. **닫아도 결과
/// 화면에는 남는다.**
final openBrokerWarningsProvider =
    Provider.family<List<BrokerWarning>, String>((ref, domainId) {
  final dismissed =
      ref.watch(interviewSessionProvider(domainId)).dismissedSignalIds;
  return [
    for (final warning in ref.watch(allBrokerWarningsProvider(domainId)))
      if (!dismissed.contains(warning.id)) warning,
  ];
});
