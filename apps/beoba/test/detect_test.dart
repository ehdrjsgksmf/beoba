import 'package:beoba/src/screens/detected/detected_screen.dart';
import 'package:beoba/src/screens/domain_select/domain_select_screen.dart';
import 'package:beoba/src/screens/hardstop/hardstop_confirm_screen.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/interview/interview_screen.dart';
import 'dart:io';

import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 자유 입력에서 분야를 알아챈다. **고르는 게 아니라 후보를 좁힌다.**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> startWith(WidgetTester tester, String narrative) async {
    await pumpApp(tester);
    if (narrative.isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, narrative);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(HomeScreen.start));
    await tester.pumpAndSettle();
  }

  group('걸린 개수로 갈린다', () {
    testWidgets('하나 걸리면 「이렇게 이해했어요」', (tester) async {
      await startWith(tester, '사장이 월급을 두 달째 안 줍니다');

      expect(find.text(DetectedScreen.title), findsOneWidget);
      // 분야를 우리가 확정하지 않는다. 바꿀 문이 붙어 있다.
      expect(find.text(DetectedScreen.otherDomain), findsOneWidget);
      expectScreenText(tester, '못 받은 임금');
    });

    testWidgets('둘 이상 걸리면 그 둘만 놓고 고르게 한다', (tester) async {
      await startWith(tester, '전세 보증금이 필요하다고 해서 빌려준 돈이에요');

      expect(find.text(DomainSelectScreen.narrowedTitle), findsOneWidget);
      expect(find.text('떼인 돈 받기'), findsOneWidget);
      expect(find.text('전세·월세 보증금'), findsOneWidget);
      // 좁힌 것이 틀릴 수 있다. 나가는 문이 있다.
      expect(find.text(DomainSelectScreen.showAll), findsOneWidget);
      // 안 걸린 분야는 목록에 없다.
      expect(find.text('못 받은 임금'), findsNothing);
    });

    testWidgets('전부 보기를 누르면 다시 다 나온다', (tester) async {
      await startWith(tester, '전세 보증금이 필요하다고 해서 빌려준 돈이에요');
      await tester.tap(find.text(DomainSelectScreen.showAll));
      await tester.pumpAndSettle();

      // 전부 보기는 **묶음 목록**으로 돌아간다. 좁힌 것을 풀었다는 뜻이지
      // 카드를 다 펴 놓는다는 뜻이 아니다.
      expect(find.text(DomainSelectScreen.title), findsOneWidget);
      expect(find.text('일하다 생긴 일'), findsOneWidget);

      // 좁힘이 풀렸는지는 **묶음을 열어 보면** 안다. 좁혀 있었다면 이
      // 묶음에서 「못 받은 임금」이 안 보인다.
      await tester.tap(find.text('일하다 생긴 일'));
      await tester.pumpAndSettle();
      expect(find.text('못 받은 임금'), findsOneWidget);
    });

    testWidgets('하나도 안 걸리면 지금처럼 분야 목록', (tester) async {
      await startWith(tester, '무슨 일인지 잘 모르겠어요');

      expect(find.text(DomainSelectScreen.title), findsOneWidget);
      expect(find.text(DomainSelectScreen.narrowedTitle), findsNothing);
    });

    testWidgets('아무것도 안 적어도 분야 목록', (tester) async {
      await startWith(tester, '');

      expect(find.text(DomainSelectScreen.title), findsOneWidget);
    });
  });

  group('★ 경보가 먼저다', () {
    testWidgets('형사 낱말이 있으면 확인 카드보다 먼저 되묻는다', (tester) async {
      // 「빌려준」이 걸려 분야를 알아채지만, 그것보다 하드스톱이 먼저다.
      await startWith(tester, '빌려준 돈을 안 갚아서 사기죄로 고소하려고 합니다');

      expect(find.text(HardStopConfirmScreen.title), findsOneWidget);
      expect(find.text(DetectedScreen.title), findsNothing);
    });

    testWidgets('위기 신호는 그보다도 먼저다', (tester) async {
      await startWith(tester, '빌려준 돈 때문에 죽고 싶습니다');

      expect(find.text(DetectedScreen.title), findsNothing);
      expect(find.text(HardStopConfirmScreen.title), findsNothing);
      // 위기 화면은 전체를 덮는다.
      expectScreenText(tester, '109');
    });
  });

  group('★ 문은 하나, 하드스톱은 그물', () {
    /// 문을 하나로 모아도 주소를 직접 치면 그 문을 안 지난다. 그래서
    /// 가드가 세션 경로 전부에서 다시 본다(DECISIONS 132번).
    testWidgets('주소를 직접 쳐도 하드스톱이 걸린다', (tester) async {
      final container = await pumpApp(tester);

      // 세션을 열지 않고 답만 심는다. 딥링크로 들어온 것과 같은 상태다.
      seedAnswers(container, kDebtRecoveryDomainId, answers: const {
        'q_role': 'creditor',
        'q_court_document': 'complaint',
      });
      container
          .read(routerProvider)
          .go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      // 지금 데이터에는 되묻지 않는 하드스톱이 없다. 그물이 걸러 낼 것이
      // 없다는 것까지가 이 테스트가 잠그는 것이다 — 하나라도 생기면 깨진다.
      for (final stop in container.read(hardStopsProvider(kDebtRecoveryDomainId))) {
        expect(
          stop.needsConfirmation,
          isTrue,
          reason: '${stop.stop.id} — 되묻지 않는 하드스톱이 생겼습니다. '
              '가드가 덮는지 여기서 확인하세요',
        );
      }
    });

    testWidgets('세션을 여는 자리는 소스에 하나뿐이다', (tester) async {
      // 검증기 (n) 이 같은 것을 본다. 여기서는 사람이 눈으로 읽을 수 있게 센다.
      final lib = Directory('lib');
      final doors = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains('start(narrative)')) {
          doors.add(entity.uri.pathSegments.last);
        }
      }
      expect(doors, ['domain_select_screen.dart']);
    });
  });

  group('미리 채운 답', () {
    testWidgets('역할과 금액이 카드에 실린다', (tester) async {
      await startWith(tester, '오백만원을 빌려줬는데 안 갚아요');

      expectScreenText(tester, '제가 받아야 할 돈입니다');
      expectScreenText(tester, '5,000,000원');
    });

    testWidgets('★ 날짜는 카드에 없다', (tester) async {
      // 금액을 잘못 채우면 화면에서 보고 고친다. **날짜를 잘못 채우면
      // 사람이 그걸 믿고 안 움직인다**(DECISIONS 130번).
      await startWith(tester, '2026년 8월 1일에 지급명령을 받았습니다');

      expect(find.text(DetectedScreen.title), findsOneWidget);
      expectNoScreenText(tester, '2026년 8월 1일');
      expectNoScreenText(tester, '받으신 날');
    });

    testWidgets('계속하기를 누르면 인터뷰로 간다', (tester) async {
      await startWith(tester, '오백만원을 빌려줬는데 안 갚아요');
      await tester.tap(find.text(DetectedScreen.next));
      await tester.pumpAndSettle();

      // 미리 채운 답은 그대로 남고, 안 채운 질문부터 묻는다.
      expect(find.text(InterviewScreen.next), findsOneWidget);
      expectNoScreenText(tester, '받아야 할 돈인가요, 갚아야 할 돈인가요?');
    });
  });
}
