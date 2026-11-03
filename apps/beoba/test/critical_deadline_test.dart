import 'package:beoba/src/format/formatters.dart';
import 'package:beoba/src/safety/safe_text.dart';
import 'package:beoba/src/screens/result/sections/deadline_section.dart';
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// SafeText 가 문구를 숨기면 사용자는 그 정보가 **있었다는 사실조차** 모른다.
/// 기한에서 그 일이 일어나면 이의신청 기간을 통째로 놓친다.
///
/// 설명은 숨기더라도 날짜 · D-day · 근거 조문은 반드시 남아야 한다.
void main() {
  approximateDeadlineTests();
  TestWidgetsFlutterBinding.ensureInitialized();

  const basis = LegalBasis(
    law: '민사소송법',
    article: '제470조 제1항',
    text: '이의신청은 지급명령이 송달된 날부터 2주 이내에 하여야 한다.',
  );

  DeadlineResult deadline({
    required String label,
    Severity severity = Severity.critical,
  }) =>
      DeadlineResult(
        id: 'dl_objection',
        label: label,
        dueDate: const KstDate(2026, 8, 29),
        daysRemaining: 14,
        severity: severity,
        basis: basis,
        verification: VerificationStatus.verified,
      );

  group('critical 기한 — 문구가 막혀도 기한은 남는다', () {
    testWidgets('라벨이 금지 표현이어도 날짜와 D-day 를 보여준다', (tester) async {
      // 데이터가 잘못 들어온 상황을 만든다. 이때도 기한은 사라지면 안 된다.
      const bad = '지급명령 이의신청 — 무조건 하세요';
      expect(SafetyFilter.isSafe(bad), isFalse);

      SafeText.debugAssertOnViolation = false;
      addTearDown(() => SafeText.debugAssertOnViolation = true);

      await pumpWidgetOnly(tester, DeadlineCard(deadline: deadline(label: bad)));

      expect(tester.takeException(), isNull);

      // 문구는 사라진다
      expect(find.text(bad), findsNothing);
      expect(find.text(DeadlineCard.labelBlocked), findsOneWidget);

      // 그러나 기한 자체는 남는다
      expect(find.text(formatKstDate(const KstDate(2026, 8, 29))), findsOneWidget);
      expect(find.text('14일 남음'), findsOneWidget);
      expect(find.text('민사소송법 제470조 제1항'), findsOneWidget);
    });

    testWidgets('정상 라벨은 그대로 보인다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: deadline(label: '지급명령 이의신청')),
      );

      expect(find.text('지급명령 이의신청'), findsOneWidget);
      expect(find.text(DeadlineCard.labelBlocked), findsNothing);
      expect(find.text('14일 남음'), findsOneWidget);
    });

    testWidgets('심각도는 색이 아니라 한글 라벨로도 전달된다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: deadline(label: '지급명령 이의신청')),
      );
      expect(find.text('꼭 지켜야 합니다'), findsOneWidget);

      await pumpWidgetOnly(
        tester,
        DeadlineCard(
          deadline: deadline(label: '소멸시효 확인', severity: Severity.info),
        ),
      );
      expect(find.text('참고하세요'), findsOneWidget);
    });
  });
}

/// 기산일이 어림이면 **기한도 단정하지 않는다.**
///
/// 확신에 찬 거짓이 가장 나쁜 결과다. "3월쯤" 이라고 답한 사람이
/// "2035년 3월 15일 (D-3,120)" 을 받으면 그 날짜를 믿는다.
void approximateDeadlineTests() {
  const basis = LegalBasis(
    law: '민법',
    article: '제162조',
    text: '10년간 행사하지 아니하면 소멸시효가 완성한다.',
  );

  DeadlineResult result({required bool approximate}) => DeadlineResult(
        id: 'dl_statute',
        label: '소멸시효',
        whatIsThis: '너무 오래 두면 달라고 할 수 없게 돼요',
        dueDate: const KstDate(2033, 3, 1),
        dueDateLatest:
            approximate ? const KstDate(2033, 3, 31) : const KstDate(2033, 3, 1),
        daysRemaining: 2390,
        severity: Severity.warning,
        basis: basis,
        verification: VerificationStatus.verified,
      );

  group('어림 기한 — 범위로 보여준다', () {
    testWidgets('날짜가 범위로 나온다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: result(approximate: true)),
      );
      expect(find.text('2033년 3월 1일 ~ 3월 31일'), findsOneWidget);
    });

    testWidgets('범위라는 사실을 말한다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: result(approximate: true)),
      );
      expect(find.text('이 기한은 범위로만 알 수 있어요'), findsOneWidget);
    });

    testWidgets('확실하면 그 말이 나오지 않는다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: result(approximate: false)),
      );
      expect(find.text('2033년 3월 1일'), findsOneWidget);
      expect(find.text('이 기한은 범위로만 알 수 있어요'), findsNothing);
    });

    testWidgets('D-day 는 가장 이른 날 기준이다', (tester) async {
      // 이른 날에 맞춰 움직이면 어느 해석에서도 늦지 않는다.
      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: result(approximate: true)),
      );
      expect(find.text('2390일 남음'), findsOneWidget);
    });

    testWidgets('심각도는 낮아지지 않는다', (tester) async {
      // 심각도는 결과의 무게이지 확실성이 아니다.
      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: result(approximate: true)),
      );
      expect(find.text('주의하세요'), findsOneWidget);
    });

    testWidgets('배율 2.0 에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpWidgetOnly(
        tester,
        DeadlineCard(deadline: result(approximate: true)),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
