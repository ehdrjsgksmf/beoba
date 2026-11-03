import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import 'tally_consent_sheet.dart';

/// 집계 동의를 **첫 결과를 본 뒤에** 묻는다 (DECISIONS 289번).
///
/// 무엇을 세는지 알려면 이 앱이 무엇을 하는지 먼저 봐야 한다. 그래서 처음
/// 여실 때는 쉬운 말 물음 하나만 묻고, 동의는 결과 화면을 **떠나서 도착한
/// 화면에서** 묻는다.
///
/// ★ **떠나는 것을 막지 않는다.** 뒤로 가려는 순간 상자가 끼어들면 막는 모양이
/// 된다. 주소가 바뀐 **뒤에** 도착한 화면 위에 띄운다.
///
/// ```
/// 결과 → 상세 · 가져가기     안 묻는다 — 아직 결과를 읽는 중이다(주소가 /result/ 안)
/// 결과 → 그 밖의 어디든       묻는다 — 아직 답 안 하셨으면. 첫 실행이어도 묻는다 —
///                           쉬운 말 물음은 이미 한참 전에 닫혔다
/// ```
///
/// ★ 그 결과 한 번은 안 세어진다 — 동의 전이라 아무것도 안 나간다. 세는 것보다
/// 동의가 먼저다.
class ConsentAfterResult extends ConsumerStatefulWidget {
  const ConsentAfterResult({required this.child, super.key});

  final Widget child;

  /// 결과를 읽는 자리. 이 안에서 오가는 것은 떠난 것이 아니다.
  static bool isResultPath(String path) => path.startsWith('/result/');

  @override
  ConsumerState<ConsentAfterResult> createState() => _ConsentAfterResultState();
}

class _ConsentAfterResultState extends ConsumerState<ConsentAfterResult> {
  String _lastPath = Routes.home;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    ref.read(routerProvider).routerDelegate.addListener(_onRoute);
  }

  @override
  void dispose() {
    // 라우터가 먼저 버려졌을 수 있다(테스트가 앱을 갈아 끼울 때).
    try {
      ref.read(routerProvider).routerDelegate.removeListener(_onRoute);
    } on Object {
      // 이미 없다.
    }
    super.dispose();
  }

  void _onRoute() {
    final router = ref.read(routerProvider);
    final path = router.routerDelegate.currentConfiguration.uri.path;
    final left = ConsentAfterResult.isResultPath(_lastPath) &&
        !ConsentAfterResult.isResultPath(path);
    _lastPath = path;
    if (!left || _asked) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _asked) return;
      final navigator = router.routerDelegate.navigatorKey.currentContext;
      if (navigator == null || !navigator.mounted) return;
      _asked = true;
      await TallyConsentSheet.openIfUnanswered(navigator, ref);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
