import 'package:beoba/src/screens/crisis/crisis_screen.dart';
import 'package:beoba/src/screens/domain_select/domain_select_screen.dart';
import 'package:beoba/src/screens/hardstop/hardstop_confirm_screen.dart';
import 'package:beoba/src/screens/hardstop/hardstop_screen.dart';
import 'package:beoba/src/screens/home/home_screen.dart';

import 'package:beoba/src/screens/interview/redirect_notice.dart';
import 'package:beoba/src/screens/result/not_ready_view.dart';
import 'package:beoba/src/screens/result/result_screen.dart';
import 'package:beoba/src/screens/summary/summary_screen.dart';
import 'package:beoba/src/screens/welfare/welfare_ask_screen.dart';
import 'package:beoba/src/screens/welfare/welfare_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// **화면 이름은 서로 겹치지 않는다. 버튼은 도착지 이름을 쓴다** (DECISIONS 34번).
///
/// 실제로 겹쳤었다 — 인터뷰 마지막 버튼이 "정리한 내용 보기" 였는데 도착지는 사건
/// 정리 카드였고, "정리한 내용입니다" 는 **두 화면 뒤** 결과 화면의 제목이었다.
/// 누른 사람은 거기로 갈 줄 안다.
///
/// 화면이 늘면 또 겹친다. 사람 눈에 맡기지 않는다.
void main() {
  /// 화면 제목. 새 화면을 만들면 여기 한 줄 추가한다.
  const titles = <String, String>{
    'HomeScreen': HomeScreen.lead,
    'DomainSelectScreen': DomainSelectScreen.title,
    'SummaryScreen': SummaryScreen.title,
    'CrisisScreen': CrisisScreen.title,
    'ResultScreen': ResultScreen.title,
    'NotReadyView': NotReadyView.title,
    'HardStopConfirmScreen': HardStopConfirmScreen.title,
    'HardStopScreen': HardStopScreen.fallbackTitle,
    'RedirectNotice': RedirectNotice.title,
    'WelfareAskScreen': WelfareAskScreen.title,
    'WelfareListScreen': WelfareListScreen.title,
  };

  /// 다른 화면으로 데려가는 버튼만. 같은 화면에 머무는 버튼(다음·저장)은 제외.
  const navigationButtons = <String, String>{
    'HomeScreen.start': HomeScreen.start,
    'SummaryScreen.next': SummaryScreen.next,
    'SummaryScreen.fixRow': SummaryScreen.fixRow,
    'NotReadyView.back': NotReadyView.backToInterview,
    'RedirectNotice.back': RedirectNotice.back,
    'HardStopConfirmScreen.yes': HardStopConfirmScreen.yes,
    'HardStopConfirmScreen.no': HardStopConfirmScreen.no,
    'HardStopScreen.fixAnswer': HardStopScreen.fixAnswer,
    'CrisisScreen.close': CrisisScreen.close,
    'HomeScreen.welfareDoor': HomeScreen.welfareDoor,
    'WelfareAskScreen.next': WelfareAskScreen.next,
  };

  test('화면 제목이 서로 겹치지 않는다', () {
    final seen = <String, String>{};
    titles.forEach((screen, title) {
      final owner = seen[title];
      expect(
        owner,
        isNull,
        reason: '"$title" 를 $owner 와 $screen 이 함께 씁니다',
      );
      seen[title] = screen;
    });
  });

  test('버튼 이름이 다른 화면의 제목과 같지 않다', () {
    navigationButtons.forEach((where, label) {
      titles.forEach((screen, title) {
        expect(
          label,
          isNot(title),
          reason: '$where 버튼이 $screen 의 제목과 같습니다. '
              '누른 사람은 그 화면으로 갈 줄 압니다',
        );
      });
    });
  });

  test('버튼 이름이 서로 겹치지 않는다', () {
    final seen = <String, String>{};
    navigationButtons.forEach((where, label) {
      final owner = seen[label];
      expect(owner, isNull, reason: '"$label" 를 $owner 와 $where 가 함께 씁니다');
      seen[label] = where;
    });
  });

  test('결과 화면 제목이 무엇을 계산했는지 말한다', () {
    // 이 화면이 제품이 약속한 것을 내놓는 자리다. 제목이 아무 말도 하지 않으면
    // 사용자는 뭘 받은 건지 모른다. 다만 판단·예측으로 읽혀서는 안 된다.
    expect(ResultScreen.title, contains('언제까지'));
    expect(ResultScreen.title, contains('계산'));
    for (final word in ['판단', '예측', '전망', '유리', '불리']) {
      expect(ResultScreen.title, isNot(contains(word)));
    }
  });
}
