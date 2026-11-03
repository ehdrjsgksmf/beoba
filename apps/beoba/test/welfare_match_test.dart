import 'package:beoba/src/welfare/welfare_match.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// 복지 자료를 좁히는 규칙. **화면 없이 잰다.**
void main() {
  const today = KstDate(2026, 8, 15);

  const notice = AgencyNotice(
    agency: '보건복지부',
    checkedAt: KstDate(2026, 8, 22),
    dateScope: NoticeDateScope.dataset,
    dataset: '중앙부처복지서비스',
  );

  CentralWelfareService make(
    String id, {
    List<String> lifeStages = const [],
    List<String> households = const [],
    List<String> topics = const [],
    bool detail = true,
    bool online = false,
    int views = 0,
  }) =>
      CentralWelfareService(
        id: id,
        name: id,
        ministry: '보건복지부',
        detailFetched: detail,
        onlineApply: online,
        views: views,
        lifeStages: lifeStages,
        households: households,
        topics: topics,
        notice: notice,
      );

  CentralWelfareCatalog catalogOf(List<CentralWelfareService> services) =>
      CentralWelfareCatalog(
        dataset: '중앙부처복지서비스',
        source: '한국사회보장정보원',
        releasedAt: const KstDate(2026, 8, 22),
        totalCount: services.length,
        services: services,
      );

  group('생애주기 — 태어난 해로 나눈다', () {
    test('경계는 겹친다. 한 줄로 자르지 않는다', () {
      // 1991년생은 올해 35세다. 청년으로도 중장년으로도 볼 수 있다.
      expect(
        lifeStagesFor(1991, today),
        {WelfareLifeStage.youth, WelfareLifeStage.middle},
      );
    });

    test('가운데 나이는 하나만 나온다', () {
      expect(lifeStagesFor(1996, today), {WelfareLifeStage.youth});
    });

    test('★ 임신·출산은 나이로 알 수 없으므로 절대 안 켜진다', () {
      for (var year = 1930; year <= 2026; year++) {
        expect(
          lifeStagesFor(year, today),
          isNot(contains(WelfareLifeStage.pregnancy)),
          reason: '$year년생에서 임신·출산이 켜졌습니다. 나이로 알 수 없는 것입니다',
        );
      }
    });
  });

  group('빈 축 — 안 적힌 것을 없는 것으로 바꾸지 않는다', () {
    test('기관이 축을 안 적었으면 통과시킨다', () {
      final match = matchWelfare(
        catalog: catalogOf([make('빈칸'), make('노년만', lifeStages: ['노년'])]),
        answers: const WelfareAnswers(birthYear: 1996),
        today: today,
      );

      // 청년으로 걸렀는데 축이 빈 것은 남고 노년만 적은 것은 빠진다.
      expect(match.detailed.map((s) => s.id), ['빈칸']);
    });

    test('아무것도 안 고르면 — 조건 없는 것은 먼저, 조건 붙은 것은 접는다. 사라지는 것은 없다', () {
      // 예전에는 전부 먼저 보였다. 장애인이 아닌 분에게 장애 제도가 같이 나오던
      // 자리라 가구상황이 적힌 것은 접는다. **빈 목록이 기본이 아니다** — 접힌 것까지
      // 합하면 전부다(DECISIONS 287번).
      final match = matchWelfare(
        catalog: catalogOf([make('가'), make('나', households: ['저소득'])]),
        answers: const WelfareAnswers(),
        today: today,
      );

      expect(match.detailed.map((s) => s.id), ['가']);
      expect(match.folded.map((s) => s.id), ['나']);
      expect(match.matched + match.folded.length, 2);
    });
  });

  group('★ 「지금 일하고 있는지」는 거르지 않는다', () {
    test('일이 끊겨도 주거·서민금융이 사라지지 않는다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('주거', topics: ['주거']),
          make('일자리', topics: ['일자리']),
          make('서민금융', topics: ['서민금융']),
        ]),
        answers: const WelfareAnswers(work: WelfareWork.notWorking),
        today: today,
      );

      expect(match.matched, 3, reason: '한 주제로 좁히면 나머지가 통째로 사라집니다');
    });

    test('대신 일자리가 맨 위로 올라온다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('가주거', topics: ['주거']),
          make('하일자리', topics: ['일자리']),
        ]),
        answers: const WelfareAnswers(work: WelfareWork.notWorking),
        today: today,
      );

      expect(match.detailed.first.id, '하일자리');
    });

    test('일하고 있으면 일자리를 안 올린다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('가주거', topics: ['주거']),
          make('하일자리', topics: ['일자리']),
        ]),
        answers: const WelfareAnswers(work: WelfareWork.working),
        today: today,
      );

      expect(match.detailed.first.id, '가주거');
    });
  });

  group('★ 두 층 — 안 받은 것을 지운 것으로 만들지 않는다', () {
    test('상세가 없는 것도 걸린 건수에 들어간다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('있음'),
          make('없음', detail: false),
        ]),
        answers: const WelfareAnswers(),
        today: today,
      );

      expect(match.detailed.map((s) => s.id), ['있음']);
      expect(match.listOnly.map((s) => s.id), ['없음']);
      expect(match.matched, 2);
    });

    test('전체 건수는 자료 전체다. 걸린 것만 세지 않는다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('걸림', households: ['저소득']),
          make('안걸림', households: ['보훈대상자']),
        ]),
        answers: const WelfareAnswers(households: {'저소득'}),
        today: today,
      );

      expect(match.matched, 1);
      expect(match.total, 2);
    });
  });

  group('가구상황 — 고를수록 좁아진다', () {
    test('고른 것 중 하나만 맞아도 남는다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('한부모', households: ['한부모·조손']),
          make('보훈', households: ['보훈대상자']),
        ]),
        answers: const WelfareAnswers(households: {'저소득', '한부모·조손'}),
        today: today,
      );

      expect(match.detailed.map((s) => s.id), ['한부모']);
    });

    test('★ 안 고르신 조건에 걸리는 것은 지우지 않고 접는다', () {
      // 장애인이 아닌데 장애 제도가 같이 나왔다(카사님). 다만 조건을 잘못
      // 고르셨을 수도 있다 — 못 받는 것이 성가신 것보다 훨씬 나쁘다.
      final match = matchWelfare(
        catalog: catalogOf([
          make('저소득', households: ['저소득']),
          make('장애', households: ['장애인']),
          make('누구나'),
        ]),
        answers: const WelfareAnswers(households: {'저소득'}),
        today: today,
      );

      expect(match.detailed.map((s) => s.id), unorderedEquals(['저소득', '누구나']));
      expect(match.folded.map((s) => s.id), ['장애']);
    });
  });

  group('★ 좁히는 축은 자료에 있는 것만 쓴다', () {
    test('주제 칩 건수는 이미 고른 주제를 빼고 센다', () {
      // 주제로 좁힌 뒤에 세면 안 고른 주제가 전부 0건이 되어 칩이 사라진다.
      final match = matchWelfare(
        catalog: catalogOf([
          make('주거하나', topics: ['주거']),
          make('일자리하나', topics: ['일자리']),
        ]),
        answers: const WelfareAnswers(topics: {'주거'}),
        today: today,
      );

      expect(match.matched, 1);
      expect(match.topicCounts['일자리'], 1, reason: '고른 뒤에 세고 있습니다');
      expect(match.topicCounts['주거'], 1);
    });

    test('0건짜리 주제는 아예 안 나온다', () {
      final match = matchWelfare(
        catalog: catalogOf([make('주거하나', topics: ['주거'])]),
        answers: const WelfareAnswers(),
        today: today,
      );

      expect(match.topicCounts.keys, ['주거']);
    });

    test('집에서 신청할 수 있는 것만 보기', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('집에서', online: true),
          make('가야함'),
        ]),
        answers: const WelfareAnswers(onlineOnly: true),
        today: today,
      );

      expect(match.detailed.map((s) => s.id), ['집에서']);
    });

    test('★ 켜기 전에도 몇 건인지 알 수 있다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('집에서', online: true),
          make('가야함'),
        ]),
        answers: const WelfareAnswers(),
        today: today,
      );

      expect(match.matched, 2);
      expect(match.onlineCount, 1);
    });
  });

  group('★ 많이 찾아본 순으로 놓는다', () {
    test('이름 순이 아니라 조회수 순이다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('가적게본것', views: 10),
          make('하많이본것', views: 900),
        ]),
        answers: const WelfareAnswers(),
        today: today,
      );

      expect(match.detailed.map((s) => s.id), ['하많이본것', '가적게본것']);
    });

    test('일자리를 올리는 것이 조회수보다 먼저다', () {
      final match = matchWelfare(
        catalog: catalogOf([
          make('많이본것', views: 900),
          make('일자리', views: 1, topics: ['일자리']),
        ]),
        answers: const WelfareAnswers(work: WelfareWork.notWorking),
        today: today,
      );

      expect(match.detailed.first.id, '일자리');
    });
  });
}
