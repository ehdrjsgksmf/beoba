import 'package:beoba/src/providers/crisis_providers.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 지금 걸린 위기 신호 id 들.
Iterable<String> signalIds(
  ProviderContainer container, [
  String domainId = kDebtRecoveryDomainId,
]) =>
    container.read(allCrisisSignalsProvider(domainId)).map((s) => s.id);
