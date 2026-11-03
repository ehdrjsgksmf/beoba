import 'package:domain_data/domain_data.dart'
    show AlertDisplay, FieldHardStopTrigger;
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/screens/domain_select/domain_select_screen.dart';
import 'package:beoba/src/screens/hardstop/hardstop_confirm_screen.dart';
import 'package:beoba/src/screens/hardstop/hardstop_screen.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/interview/interview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 하드스톱은 두 단계다 — **추정과 확정은 다르다.**
///
/// 키워드는 자유 입력에 대한 부분 문자열 스캔이라 오탐이 난다. 확인 없이 차단하면
/// 민사 사건을 들고 온 사람이 형사로 튕겨나간다. 선택지로 확정된 것은 다르다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 홈에 서술을 넣고 분야를 고른다.
  Future<void> startWith(WidgetTester tester, String narrative) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, narrative);
    // **한 프레임만 그리고 누르지 않는다.** 글을 적으면 선택 손잡이가
    // 오버레이에 얹히는데, 첫 프레임에는 아직 캐럿 자리로 못 가 있어서
    // 하단 버튼을 덮는다. 사람은 16밀리초 안에 버튼을 누르지 못한다.
    //
    // **자판은 내리지 않는다.** 내리고 누르는 것은 개발자 습관이지 사람의
    // 습관이 아니다 — 그 경로만 시험하면 실제 상황을 비켜 간다.
    await tester.pumpAndSettle();
    await tester.tap(find.text(HomeScreen.start));
    await tester.pumpAndSettle();

    // **경보가 감지보다 먼저다.** 자유 입력에서 분야를 알아채면 홈이 바로
    // 그 분야를 여는데, 그 자리에서 하드스톱이 먼저 걸린다 — 그러면 분야
    // 목록을 지나가지 않는다(DECISIONS 131번).
    // 첫 화면에는 묶음 줄만 선다(DECISIONS 237번). 묶음을 거쳐 들어간다.
    if (find.text(DomainSelectScreen.title).evaluate().isNotEmpty) {
      await pickDomainFromList(tester, kDebtRecoveryDomainId);
    }
  }

  group('키워드 — 확인을 거친다', () {
    testWidgets('형사 낱말이 있으면 바로 막지 않고 되묻는다', (tester) async {
      await startWith(tester, '빌려준 돈을 안 갚아서 사기죄로 고소하려고 합니다');

      expect(find.text(HardStopConfirmScreen.title), findsOneWidget);
      expect(find.text(HardStopConfirmScreen.yes), findsOneWidget);
      expect(find.text(HardStopConfirmScreen.no), findsOneWidget);
    });

    testWidgets('확인 단계는 사건 종류를 특정하지 않는다', (tester) async {
      // 아직 낱말 하나로 추정한 단계다. "경찰 조사를 받은 적이 있다" 는 참고인일 수도
      // 있고 지난 일일 수도 있다. 확정 전에 사건을 규정하지 않는다.
      await startWith(tester, '경찰 조사를 받은 적이 있습니다');

      expect(find.text(HardStopConfirmScreen.prompt), findsOneWidget);
      expect(find.text('형사 사건은 다루지 않습니다'), findsNothing);
      for (final word in ['형사', '고소', '사기죄', '마약', '도박']) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '확인 화면이 "$word" 로 사건을 특정하고 있습니다',
        );
      }
    });

    testWidgets('"네" 를 누른 뒤에는 무엇인지 밝힌다', (tester) async {
      // 확정된 다음에는 얼버무리지 않는다. 왜 멈추는지 알아야 다른 데로 갈 수 있다.
      await startWith(tester, '경찰 조사를 받은 적이 있습니다');
      await tester.tap(find.text(HardStopConfirmScreen.yes));
      await tester.pumpAndSettle();

      expect(find.text('형사 사건은 다루지 않습니다'), findsOneWidget);
    });

    testWidgets('"네" 를 누르면 차단 화면으로 간다', (tester) async {
      await startWith(tester, '사기죄로 고소하려고 합니다');

      await tester.tap(find.text(HardStopConfirmScreen.yes));
      await tester.pumpAndSettle();

      expect(find.text('형사 사건은 다루지 않습니다'), findsOneWidget);
      // 계속 진행 버튼이 없다. 이 화면은 흐름의 끝이다.
      expect(find.text(InterviewScreen.next), findsNothing);
      expect(find.text(HardStopConfirmScreen.no), findsNothing);
    });

    testWidgets('오탐이면 "아니요" 로 흐름이 이어진다', (tester) async {
      // 명백한 민사 사건인데 '고소' 하나로 걸린다. 여기서 쫓아내면 안 된다.
      // "형사 사건" 이 들어 있지만 형사 사건에 들어간 것이 아니라 걱정하는 것이다.
      // 패턴을 좁혀도 이런 것은 남는다. 그래서 확인 화면이 있다.
      await startWith(tester, '형사 사건으로 번질까 걱정입니다');

      expect(find.text(HardStopConfirmScreen.title), findsOneWidget);

      await tester.tap(find.text(HardStopConfirmScreen.no));
      await tester.pumpAndSettle();

      expect(find.text('받아야 할 돈인가요, 갚아야 할 돈인가요?'), findsOneWidget);
    });

    testWidgets('"아니요" 한 것은 다시 묻지 않는다', (tester) async {
      final container = await pumpApp(tester);
      await tester.enterText(
        find.byType(TextField).first,
        '형사 사건으로 번질까 걱정입니다',
      );
      await tester.pumpAndSettle();
      // **여기만 자판을 내리고 누른다.** 그렇게 하는 사람도 있으므로 그
      // 경로도 한 번은 지나간다. 나머지는 전부 자판을 켠 채로 누른다.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();
      await pickDomainFromList(tester, kDebtRecoveryDomainId);

      await tester.tap(find.text(HardStopConfirmScreen.no));
      await tester.pumpAndSettle();

      // 답을 더 넣어도 같은 하드스톱이 되살아나면 안 된다.
      await tester.tap(find.text('제가 받아야 할 돈입니다'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(InterviewScreen.next));
      await tester.pumpAndSettle();

      expect(find.text(HardStopConfirmScreen.title), findsNothing);
      expect(
        container.read(hardStopsProvider(kDebtRecoveryDomainId)),
        isEmpty,
      );
    });
  });

  group('필드 — 지금은 아무것도 막지 않는다', () {
    /// **하드스톱은 우리가 해 줄 게 하나도 없을 때만이다.**
    ///
    /// 유일한 필드 트리거였던 `hs_court_document` 가 내려갔다. 막았던 그
    /// 상황이 정확히 우리가 셀 수 있는 기한이 있는 상황이었고, 차단이 먼저
    /// 와서 지급명령 이의신청 2주를 통째로 가렸다(DECISIONS 121번).
    testWidgets('법원 서류를 골라도 차단되지 않는다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(
        container,
        kDebtRecoveryDomainId,
        answers: const {
          'q_role': 'debtor',
          'q_debtor_situation': 'court_document',
          'q_court_document': 'complaint',
        },
      );

      expect(container.read(hardStopsProvider(kDebtRecoveryDomainId)), isEmpty);
    });

    testWidgets('막는 대신 기한 아래에 stop 경고로 남는다', (tester) async {
      final container = await pumpApp(tester);
      final caution = container
          .read(domainBundleProvider)
          .requireValue
          .byId(kDebtRecoveryDomainId)
          .cautions
          .firstWhere((c) => c.id == 'ct_court_document');

      expect(caution.display, AlertDisplay.stop);
      // 하드스톱이 들고 있던 것을 그대로 물려받았다.
      expect(caution.checklist, hasLength(5));
      expect(caution.channels, isNotEmpty);
    });

    testWidgets('어느 분야에도 필드 트리거 하드스톱이 없다', (tester) async {
      final container = await pumpApp(tester);
      final bundle = container.read(domainBundleProvider).requireValue;

      for (final domain in bundle.domains.values) {
        for (final stop in domain.hardStops) {
          expect(
            stop.trigger,
            isNot(isA<FieldHardStopTrigger>()),
            reason: '${domain.id}.${stop.id} — 답 하나로 막기 전에 '
                '「해 줄 게 정말 하나도 없는가」를 다시 보세요',
          );
        }
      }
    });

    testWidgets('키워드로 확정된 차단에는 정정 경로가 없다', (tester) async {
      // 사용자가 확인 화면에서 "네" 라고 확정했다. 되돌릴 답이 없다.
      await startWith(tester, '사기죄로 고소하려고 합니다');
      await tester.tap(find.text(HardStopConfirmScreen.yes));
      await tester.pumpAndSettle();

      expect(find.byType(HardStopScreen), findsOneWidget);
      expect(find.text(HardStopScreen.fixAnswer), findsNothing);
    });
  });
}
