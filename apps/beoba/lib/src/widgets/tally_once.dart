import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tally_providers.dart';

/// 세션 하나에 **한 번만** 센다. 아무것도 그리지 않는다.
///
/// 결과 화면에 닿은 것이 그 자리다 — 여기까지 왔으면 `reached` 가 참이고,
/// 못 온 사람은 `exitAt` 이 남는다. **제일 값진 것이 그 `exitAt` 이다**
/// (DECISIONS 136번).
///
/// 「세지 마세요」를 고르셨거나 아직 안 물어봤으면 아무것도 안 나간다.
/// 보내기 실패도 조용히 넘어간다.
class TallyOnce extends ConsumerStatefulWidget {
  const TallyOnce({required this.domainId, super.key});

  final String domainId;

  @override
  ConsumerState<TallyOnce> createState() => _TallyOnceState();
}

class _TallyOnceState extends ConsumerState<TallyOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sender = ref.read(sessionTallySenderProvider);
      sender.sendOnce(tallyOf(ref, widget.domainId, reached: true));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
