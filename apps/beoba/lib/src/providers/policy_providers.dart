import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/asset_policy_source.dart';

/// 방침을 읽는 자리. 테스트에서 갈아끼운다.
final policySourceProvider = Provider<AssetPolicySource>(
  (_) => const AssetPolicySource(),
);

/// 방침 덩어리.
///
/// **앱 시작 때 읽지 않는다.** 방침은 사람이 눌러서 들어오는 자리라, 시작을
/// 늦출 이유가 없다. 도메인 번들과 달리 부트스트랩에 끼우지 않는다.
final policyBlocksProvider = FutureProvider<List<PolicyBlockData>>(
  (ref) => ref.watch(policySourceProvider).load(),
);
