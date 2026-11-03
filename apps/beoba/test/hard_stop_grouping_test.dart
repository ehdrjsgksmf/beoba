import 'package:domain_data/domain_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 확인 화면에서 "아니요" 를 누르면 **같은 `screen` 을 가리키는 키워드 하드스톱을
/// 한꺼번에** 내린다 (DECISIONS 25번). 그 동작이 안전한 것은
/// **"같은 screen = 사용자에게 같은 질문" 이 참일 때뿐이다.**
///
/// 지금은 참이다. 이 테스트가 그 전제를 잠근다 — 전제가 깨지면 빌드가 선다.
///
/// 깨졌다면 고칠 곳은 이 테스트가 아니라 코드다. `HardStop` 에 `group` 필드를
/// 추가하고 dismiss 키를 `screen` 에서 `group` 으로 옮긴다. "같은 종류" 판단을
/// 코드가 추론하지 않고 **데이터가 선언하게** 한다 (CONTRIBUTING.md — 분야는 데이터다).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<(String domainId, HardStop stop)> allStops;

  setUpAll(() async {
    final bundle = await loadTestBundle();
    allStops = [
      for (final domain in [bundle.crisis, ...bundle.selectable])
        for (final stop in domain.hardStops) (domain.id, stop),
    ];
  });

  test('하드스톱이 실제로 존재한다 (조사 자체가 비면 의미가 없다)', () {
    expect(allStops, isNotEmpty);
  });

  test('같은 screen 을 쓰는 하드스톱은 사용자에게 같은 질문이다', () {
    final byScreen = <String, List<HardStop>>{};
    for (final (_, stop) in allStops) {
      byScreen.putIfAbsent(stop.screen, () => []).add(stop);
    }

    for (final entry in byScreen.entries) {
      if (entry.value.length < 2) continue;

      // 확인 화면은 제목을 그대로 되묻는다. 제목이 다르면 다른 질문이다.
      final titles = entry.value.map((s) => s.title).toSet();
      expect(
        titles,
        hasLength(1),
        reason: 'screen "${entry.key}" 에 뜻이 다른 하드스톱이 섞였습니다: $titles\n'
            '지금 코드는 하나를 내리면 나머지도 함께 내립니다 — 안전층 ① 의 구멍입니다.\n'
            'HardStop 에 group 필드를 추가하고 dismiss 키를 group 으로 옮기세요.',
      );
    }
  });

  test('다루지 않는 분야끼리는 screen 을 공유하지 않는다', () {
    // "임금체불은 아직 안 다룹니다" 와 "상속 분쟁은 아직 안 다룹니다" 는
    // 사용자에게 **서로 다른 질문**이다. 하나에 "아니요" 했다고 나머지까지
    // 내려가면 안 된다. 이름이 통(`hardstop_out_of_scope`)이면 다음 분야가
    // 전부 거기로 들어오므로, 계열마다 screen 을 나눈다.
    final outOfScope = [
      for (final (_, stop) in allStops)
        if (stop.screen.startsWith('hardstop_out_of_scope')) stop,
    ];

    expect(
      outOfScope.map((s) => s.screen).toSet(),
      hasLength(outOfScope.length),
      reason: '다루지 않는 분야가 screen 을 공유하고 있습니다. '
          'hardstop_out_of_scope_<계열> 로 나누세요.',
    );
  });

  test('screen 별 구성이 기록과 일치한다', () {
    final counts = <String, int>{};
    for (final (_, stop) in allStops) {
      counts[stop.screen] = (counts[stop.screen] ?? 0) + 1;
    }

    // 새 하드스톱이 들어오면 여기가 먼저 깨진다. 그때 물어야 할 것은 하나다 —
    // **이 상황에 우리가 해 줄 게 정말 하나도 없는가.** 하나라도 있으면
    // 하드스톱이 아니라 stop 경고다(DECISIONS 121번).
    //
    // hardstop_court 는 그 물음에서 떨어져 나갔다. 막았던 상황에 셀 수 있는
    // 기한이 있었고, 차단이 그것을 가리고 있었다.
    expect(counts, {
      'hardstop_criminal': 2, // hs_criminal · hs_criminal_fraud — 같은 질문
      'hardstop_out_of_scope_family': 1,
      // **유류분을 가족 사건에서 떼어 냈다.** 둘은 「왜 막히는가」가 다르다 —
      // 이혼·양육권은 우리가 안 다루는 갈래이고, 유류분은 **옆 칸(상속재산
      // 나누기)이 열린 뒤로 「아직 안 연 것」**이 됐다. 그 사람에게는 옆길이
      // 있고 이혼 쪽에는 없으므로, 한 문구로 묶으면 한쪽이 반드시 틀린다.
      'hardstop_out_of_scope_inheritance': 1,
    });
  });
}
