import 'dart:developer' as developer;

import 'package:engines/engines.dart';
import 'package:flutter/widgets.dart';

/// 화면에서 문구가 차단됐다는 사실을 남긴다.
///
/// 릴리스에서 [SafeText] 는 조용히 문구를 감춘다. 기록이 없으면 **아무도 모른다** —
/// 데이터가 잘못돼 있는데 사용자만 빈 자리를 본다. 그래서 훅을 둔다.
///
/// M1 구현체는 로컬 로그다. M2 에서 원격 보고로 갈아끼운다.
/// `NotificationService` 를 추상화하는 것과 같은 이유로 인터페이스만 열어 둔다.
abstract interface class SafetyReporter {
  void report(
    List<SafetyViolation> violations, {
    required SafetyScope scope,
  });
}

/// 로컬 로그 구현.
///
/// **문구 원문을 남기지 않는다.** 사건 내용이나 사용자가 직접 쓴 문장이 섞여 있을 수
/// 있고, 그건 로그로 나가면 안 되는 개인정보다. 남기는 것은 어디서 · 어떤 패턴에
/// 걸렸는지뿐이다. 그것만으로 데이터를 찾아 고칠 수 있다.
class LoggingSafetyReporter implements SafetyReporter {
  const LoggingSafetyReporter();

  @override
  void report(
    List<SafetyViolation> violations, {
    required SafetyScope scope,
  }) {
    for (final violation in violations) {
      developer.log(
        'blocked scope=${scope.name} '
        'pattern=${violation.pattern} '
        'where=${violation.where ?? '(미상)'}',
        name: 'beoba.safety',
      );
    }
  }
}

/// 아무것도 하지 않는 구현. 테스트에서 호출 여부만 볼 때 갈아끼운다.
class NoopSafetyReporter implements SafetyReporter {
  const NoopSafetyReporter();

  @override
  void report(List<SafetyViolation> violations, {required SafetyScope scope}) {}
}

/// 위젯 트리에 [SafetyReporter] 를 내려보낸다.
///
/// riverpod 이 아니라 `InheritedWidget` 인 이유 — [SafeText] 는 `build` 안에서
/// 동기적으로 부르고, 위젯 하나가 리포터를 얻자고 `ConsumerWidget` 이 될 이유가 없다.
class SafetyReporterScope extends InheritedWidget {
  const SafetyReporterScope({
    required this.reporter,
    required super.child,
    super.key,
  });

  final SafetyReporter reporter;

  /// 조상에 없으면 로컬 로그로 떨어진다. 보고가 없어서 화면이 깨지진 않는다.
  static SafetyReporter of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SafetyReporterScope>()
          ?.reporter ??
      const LoggingSafetyReporter();

  @override
  bool updateShouldNotify(SafetyReporterScope oldWidget) =>
      reporter != oldWidget.reporter;
}
