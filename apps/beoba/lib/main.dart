import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';

/// M1 — 화면이 붙었다.
///
/// M0 의 콘솔 파이프라인은 `packages/engines/bin/m0_pipeline.dart` 에 남아 있다.
/// 엔진 결과를 화면 없이 보고 싶으면 그쪽을 쓴다.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BeobaApp()));
}
