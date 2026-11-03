import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/result/result_screen.dart';
import 'package:beoba/src/screens/result/sections/limitation_card.dart';
import 'package:beoba/src/screens/result/sections/pinned_caution_card.dart';
import 'package:beoba/src/screens/result/sections/receive_window_card.dart';
import 'package:beoba/src/screens/result/sections/starts_from_card.dart';
import 'package:beoba/src/screens/result/sections/today_card.dart';
import 'package:beoba/src/widgets/broker_alert_card.dart';
import 'package:beoba/src/widgets/expandable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/domain_scenarios.dart';
import 'support/test_app.dart';

/// **재는 대상을 바꿨다 — 카드 개수가 아니라 첫 화면의 밀도다.**
///
/// 개수 상한은 다섯 → 여섯 → 일곱으로 두 번 올랐다. 대리 지표가 계속
/// 조정되면 재는 대상이 잘못된 것이다(DECISIONS 134번).
///
/// ## 배율 축을 넣었다 (DECISIONS 175번)
///
/// 전에는 일곱 줄이 전부 배율 1.0 이었다. 글자를 키워 쓰는 사람의 화면은
/// 아무도 안 쟀는데, **1.3 이 세로를 1.35배, 1.5 가 1.8배로 늘린다.**
///
/// 그래서 상한을 배율마다 같은 숫자로 두지 않는다. 지키려면 문장의 절반을
/// 버려야 하고, 그건 **밀도를 지키려고 근거를 버리는 것**이라 순서가 뒤집힌다.
///
/// ```
/// 배율 어디서나   첫 화면에 펼쳐진 카드 하나
///                「더 있다」는 신호가 첫 화면 안에 있다
/// 배율 1.0 에서   전체 4화면 이내
/// 배율 사이       1.5 값이 1.0 값의 1.9배를 넘지 않는다
/// 배율 1.3        상한 없이 값만 적는다
/// ```
///
/// 가로 넘침은 여기서 안 본다 — `result_scale_test` 가 배율 2.0 까지 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 360.0;
  const height = 780.0;

  /// 배율 1.0 에서의 절대 상한. 「내용이 너무 많다」를 재는 자리다.
  ///
  /// **4.00 에서 0.05 를 올렸다. 올린 값은 내용이 아니라 (나) 신호 한 줄이다.**
  /// 개수 줄을 넣으면서 일곱 갈래가 모두 0.02~0.04 씩 늘었고, 「빚 갚기가
  /// 어려울 때」가 3.99 였던 탓에 그 줄 하나로 상한을 넘었다.
  ///
  /// 줄이려면 개인회생 대상 금액(15억·10억)이나 면책 원칙 카드를 접어야
  /// 하는데, **그 둘은 스스로 자격이 없다고 판단하고 앱을 닫는 것을 막는
  /// 카드다.** 신호를 얻자고 그걸 접으면 신호가 필요한 이유가 없어진다.
  ///
  /// 그래서 **내용 예산은 그대로 4.00 이고, 0.05 는 머리에 붙은 붙박이 줄의
  /// 값이다.** 다음에 또 올리자는 말이 나오면 그때는 내용을 줄여야 한다
  /// (DECISIONS 134번 — 대리 지표가 계속 조정되면 재는 대상이 틀린 것이다).
  ///
  /// ## 두 번째 붙박이가 붙었다 — 복지로 건너가는 한 줄
  ///
  /// 잰 값이 **0.065화면**(약 50px)이다. 「빚 갚기가 어려울 때」가 붙박이
  /// 없이 4.006 이라 남은 자리가 0.044 뿐이었고, 그 자리를 만들려면 또
  /// 같은 두 카드를 접어야 했다. 그래서 **줄을 줄였다** — 틴트 카드였던
  /// 것을 링크 한 줄로 바꿔 0.14 → 0.065 가 됐다.
  ///
  /// ```
  /// 내용 예산   4.00   ← 남은 잔고 0. 「빚 갚기」가 4.006 이다
  /// 붙박이 (가) 0.05   ← 개수 한 줄
  /// 붙박이 (나) 0.07   ← 복지로 건너가는 한 줄 (잰 값 0.065)
  /// ```
  ///
  /// **4.12 를 보고 「0.12 남았네」로 읽으면 안 된다.** 내용 쪽 잔고는 0 이다.
  /// 상한은 **내용으로는 못 올린다** — 모든 화면에 붙는 공통 요소가 늘어난
  /// 만큼만 올린다.
  ///
  /// ★ **세 번째 붙박이는 내용에서 자리를 빼 와야 한다.** 두 번은 「공통
  /// 요소니까」로 넘어갔지만, 세 번이면 그건 재는 대상이 틀린 것이다
  /// (DECISIONS 134번). 그때는 예산을 올리지 말고 카드를 접는다.
  const maxScreens = 4.12;

  /// 배율이 올라갈 때 늘어나도 되는 한계. 지금 최악이 1.71배다.
  ///
  /// **①의 되풀이가 아니다.** 같은 배율인데 분야마다 증가폭이 다르다.
  /// 차이가 나는 것은 **한 줄이 두 줄이 되는 문장이 얼마나 많으냐**다.
  /// ①은 그걸 못 잡고 ②가 잡는다.
  ///
  /// 여기 걸리면 문장을 지우지 말고 **줄바꿈을 보라.** 긴 낱말, 안 끊기는
  /// 조문 인용, 붙어 있는 숫자와 단위가 범인이다.
  const maxGrowth = 1.9;

  // **갈래 표는 `support/domain_scenarios.dart` 한 곳에 있다.** 여기 따로
  // 두면 분야가 늘 때 이 파일만 고쳐지고 나머지가 뒤처진다 — 실제로 그랬다.
  const scenarios = screenScenarios;

  Future<void> openResult(
    WidgetTester tester,
    String domainId,
    Map<String, Object?> answers,
    double scale,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(width, height);
    addTearDown(tester.view.reset);

    final container = await pumpApp(tester, textScale: scale);
    seedAnswers(container, domainId, answers: answers);
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();
  }

  double contentHeight(WidgetTester tester) {
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    return position.maxScrollExtent + position.viewportDimension;
  }

  List<Rect> expandedCards(WidgetTester tester) {
    final rects = <Rect>[];
    for (final finder in <Finder>[
      find.byType(TodayCard),
      find.byType(LimitationCard),
      find.byType(PinnedCautionCard),
      find.byType(StartsFromCard),
      find.byType(ReceiveWindowCard),
      find.byType(BrokerAlertCard),
    ]) {
      for (var i = 0; i < finder.evaluate().length; i++) {
        rects.add(tester.getRect(finder.at(i)));
      }
    }
    return rects..sort((a, b) => a.top.compareTo(b.top));
  }

  List<double> cardTops(WidgetTester tester) {
    final tops = [for (final rect in expandedCards(tester)) rect.top];
    final folded = find.byType(ExpandableCard);
    for (var i = 0; i < folded.evaluate().length; i++) {
      tops.add(tester.getTopLeft(folded.at(i)).dy);
    }
    return tops..sort();
  }

  double measure(WidgetTester tester, String label, double scale) {
    final where = '$label 배율 $scale';

    final whole = expandedCards(tester)
        .where((rect) => rect.top >= 0 && rect.bottom <= height)
        .toList();
    expect(
      whole,
      hasLength(lessThanOrEqualTo(1)),
      reason: '$where — 첫 화면에 펼쳐진 카드가 ${whole.length}장입니다. '
          '제일 중요한 것 하나만 펴 둡니다',
    );

    final tops = cardTops(tester);
    final nextHead = tops.length > 1 && tops[1] < height;
    final counter = find.byKey(ResultScreen.countKey);
    final counted = counter.evaluate().isNotEmpty &&
        tester.getRect(counter).bottom <= height;
    expect(
      nextHead || counted,
      isTrue,
      reason: '$where — 아래에 더 있다는 신호가 첫 화면에 없습니다. '
          '다음 카드 머리를 올리거나 개수를 적으세요',
    );

    return contentHeight(tester) / height;
  }

  for (final entry in scenarios.entries) {
    final (domainId, answers) = entry.value;

    testWidgets(entry.key, (tester) async {
      await openResult(tester, domainId, answers, 1);
      final base = measure(tester, entry.key, 1);

      expect(
        base,
        lessThanOrEqualTo(maxScreens),
        reason: '${entry.key} — ${base.toStringAsFixed(2)}화면입니다. '
            '제일 긴 카드를 접으세요',
      );

      await openResult(tester, domainId, answers, 1.3);
      final middle = measure(tester, entry.key, 1.3);

      await openResult(tester, domainId, answers, 1.5);
      final large = measure(tester, entry.key, 1.5);

      // ignore: avoid_print
      print('밀도 ${entry.key} — 1.0 ${base.toStringAsFixed(2)} · '
          '1.3 ${middle.toStringAsFixed(2)} · 1.5 ${large.toStringAsFixed(2)} · '
          '증가율 ${(large / base).toStringAsFixed(2)}배');

      expect(
        large / base,
        lessThanOrEqualTo(maxGrowth),
        reason: '${entry.key} — 배율 1.5 에서 '
            '${(large / base).toStringAsFixed(2)}배로 늘었습니다. '
            '문장을 지우지 말고 줄바꿈을 보세요',
      );
    });
  }

  testWidgets('첫 화면에 펼친 카드는 접는 손잡이가 없다', (tester) async {
    await openResult(tester, kDebtRecoveryDomainId, completeAnswers, 1);
    expect(find.text(ExpandableCard.collapse), findsNothing);
  });

  test('★ 분야를 몇 개 돌았는지 센다', () {
    // **밀도 예산은 모든 분야가 지킨다.** 한 분야가 빠지면 그 분야만
    // 상한 밖에서 자란다 — 양육비가 실제로 그랬다.
    expectsEveryDomain(
      'result_density_test 의 screenScenarios',
      [for (final entry in scenarios.values) entry.$1],
    );
  });
}
