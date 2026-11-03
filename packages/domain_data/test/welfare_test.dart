import 'dart:convert';
import 'dart:io';

import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

/// 구워진 복지 JSON 을 그대로 읽는다. **정답지는 자료 자체다.**
PublicWelfareCatalog _public() => PublicWelfareCatalog.fromJson(
      jsonDecode(File('assets/welfare/public_services.json').readAsStringSync())
          as Map<String, dynamic>,
    );

PrivateWelfareCatalog _private() => PrivateWelfareCatalog.fromJson(
      jsonDecode(
        File('assets/welfare/private_services.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

CentralWelfareCatalog _central() => CentralWelfareCatalog.fromJson(
      jsonDecode(File('assets/welfare/central.json').readAsStringSync())
          as Map<String, dynamic>,
    );

void main() {
  group('복지 자료 — 두 자료를 섞지 않는다', () {
    test('공공 자료는 목록과 링크까지다', () {
      final catalog = _public();
      expect(catalog.services, isNotEmpty);
      for (final service in catalog.services) {
        expect(service.url, startsWith('https://www.bokjiro.go.kr/'));
        expect(service.name, isNotEmpty);
      }
    });

    test('공공 자료에는 매칭 축이 아예 없다 — 그래서 openPart 로 남긴다', () {
      // **물러난 뒤에도 이 줄은 그대로다.** 자료가 물러난 것과 그 자료에
      // 축이 없다는 것은 다른 사실이라, 뒤엣것으로 앞엣것을 덮지 않는다.
      expect(_public().openPart, contains('중앙부처 복지서비스 상세(지원대상·조건)'));
    });

    test('★ 물러났다는 표시가 openPart 를 덮지 않는다', () {
      final catalog = _public();
      expect(catalog.retired, isTrue);
      expect(catalog.openPart, contains('확인 안 됨'));
      expect(catalog.retiredWhy, isNotNull);
    });

    test('민간 자료에는 지원대상·신청방법이 있다', () {
      final services = _private().services;
      expect(services, isNotEmpty);
      expect(services.where((s) => s.target.isNotEmpty).length,
          greaterThan(services.length ~/ 2));
      expect(services.where((s) => s.howToApply.isNotEmpty).length,
          greaterThan(services.length ~/ 2));
    });

    test('id 가 겹치지 않는다', () {
      final public = _public().services.map((s) => s.id).toSet();
      final private = _private().services.map((s) => s.id).toSet();
      expect(public, hasLength(_public().services.length));
      expect(private, hasLength(_private().services.length));
      expect(public.intersection(private), isEmpty);
    });
  });

  group('빈 축 — 안 적힌 것은 「해당 없음」이 아니다', () {
    test('축이 빈 항목이 실제로 있다', () {
      final services = _private().services;
      expect(services.where((s) => s.lifeStages.isEmpty), isNotEmpty);
      expect(services.where((s) => s.households.isEmpty), isNotEmpty);
    });

    test('빈 축은 걸러지지 않는다 — 안 걸러야 3분의 1이 안 사라진다', () {
      final blank = _private()
          .services
          .firstWhere((s) => s.lifeStages.isEmpty && s.households.isNotEmpty);
      expect(blank.matches(lifeStages: {'노년'}), isTrue);
      expect(blank.unstatedAxes, contains('생애주기'));
    });

    test('적힌 축은 안 걸리면 빠진다', () {
      final filled = _private()
          .services
          .firstWhere((s) => s.lifeStages.contains('노년'));
      expect(filled.matches(lifeStages: {'노년'}), isTrue);
      expect(filled.matches(lifeStages: {'영유아'}),
          filled.lifeStages.contains('영유아'));
    });

    test('아무것도 안 고르면 전부 남는다', () {
      final services = _private().services;
      expect(services.where((s) => s.matches()).length, services.length);
    });

    test('안 적힌 축의 이름을 남긴다 — 화면이 그렇다고 말할 수 있게', () {
      for (final service in _private().services) {
        expect(
          service.unstatedAxes.contains('생애주기'),
          service.lifeStages.isEmpty,
          reason: service.id,
        );
        expect(
          service.unstatedAxes.contains('관심주제'),
          service.topics.isEmpty,
          reason: service.id,
        );
      }
    });
  });

  group('기관이 알려 준 것 — 네 번째 층', () {
    test('출처와 마지막 확인일이 한 줄로 나온다', () {
      final service = _public().services.first;
      expect(
        service.notice.sentence,
        '법에 적힌 게 아니라 ${service.notice.agency}에서 알려 준 내용이에요. '
        '마지막 확인 ${service.notice.checkedAt.toIso()}.',
      );
    });

    test('공공은 항목별 날짜, 민간은 자료 전체 날짜다 — 없는 칸을 있는 척하지 않는다', () {
      expect(
        _public().services.map((s) => s.notice.dateScope).toSet(),
        {NoticeDateScope.record},
      );
      expect(
        _private().services.map((s) => s.notice.dateScope).toSet(),
        {NoticeDateScope.dataset},
      );
      expect(
        _private().services.first.notice.sentence,
        endsWith('(자료 전체 기준).'),
      );
    });

    test('모든 항목에 출처가 붙어 있다. 예외 없다', () {
      for (final service in _public().services) {
        expect(service.notice.agency, isNotEmpty, reason: service.id);
      }
      for (final service in _private().services) {
        expect(service.notice.agency, isNotEmpty, reason: service.id);
      }
    });

    test('공공 자료의 최종수정일은 행마다 다르다', () {
      final dates =
          _public().services.map((s) => s.notice.checkedAt.toIso()).toSet();
      expect(dates.length, greaterThan(1));
    });
  });

  group('청소 — 문장을 고쳐 쓰지 않는다', () {
    test('앞뒤 공백이 없다', () {
      for (final service in _private().services) {
        expect(service.target, service.target.trim(), reason: service.id);
        expect(service.benefit, service.benefit.trim(), reason: service.id);
      }
    });

    test('연속 공백이 없다', () {
      for (final service in _private().services) {
        expect(service.documents, isNot(contains('  ')), reason: service.id);
      }
    });

    test('하이픈 목록이 줄바꿈이 됐다', () {
      final sample = _private()
          .services
          .firstWhere((s) => s.org == '삼성꿈장학재단' && s.name.startsWith('꿈장학'));
      expect(sample.benefit.split('\n'), hasLength(2));
      expect(sample.benefit, isNot(contains(' - ')));
    });

    test('전화번호의 하이픈은 살아 있다 — 애매하면 안 건드린다', () {
      final phones = _private()
          .services
          .where((s) => RegExp(r'\d{3,4}-\d{4}').hasMatch(s.howToApply));
      expect(phones, isNotEmpty);
    });
  });

  group('금지어 — 낱말이 아니라 문장을 막는다', () {
    test('「승소가액」이 들어간 무료법률구조 안내가 목록에 있다', () {
      final aid = _private().services.firstWhere(
            (s) => s.name == '무료법률구조 지원',
            orElse: () => throw StateError('무료법률구조 지원이 빠졌습니다'),
          );
      expect(aid.benefit, contains('승소가액'));
      // 지원 **제외** 기준이다. 우리가 「이길 수 있어요」라고 말하는 것의 정반대다.
      expect(aid.benefit, contains('제외'));
    });

    test('그래도 출처 딱지가 붙어 있다 — 우리 말로 읽히면 안 된다', () {
      final aid =
          _private().services.firstWhere((s) => s.name == '무료법률구조 지원');
      expect(aid.notice.agency, isNotEmpty);
      expect(aid.notice.sentence, startsWith('법에 적힌 게 아니라'));
    });

    test('1인칭 단정은 인용에서도 그대로 막힌다', () {
      for (final service in _private().services) {
        expect(service.benefit, isNot(contains('승소합니다')), reason: service.id);
      }
    });

    test('뺀 것이 있으면 이유가 자료 안에 남는다', () {
      for (final row in _private().excluded) {
        expect(row.reason, isNotEmpty);
        expect(row.field, isNotEmpty);
      }
    });
  });

  group('중앙부처 — API 로 받은 것은 CSV 판보다 깊다', () {
    test('상세를 받은 건에는 지원대상·지원내용이 들어 있다', () {
      final fetched =
          _central().services.where((s) => s.detailFetched).toList();
      expect(fetched, isNotEmpty);
      for (final service in fetched) {
        expect(service.target, isNotEmpty, reason: service.id);
        expect(service.benefit, isNotEmpty, reason: service.id);
      }
    });

    test('★ 목록에 있는 건 다 담는다 — 안 받은 것은 지운 것이 아니다', () {
      final catalog = _central();
      expect(catalog.services, hasLength(catalog.totalCount));
      final waiting =
          catalog.services.where((s) => !s.detailFetched).toList();
      for (final service in waiting) {
        // 이름·요약·링크까지는 있다. 화면은 여기까지만 낸다.
        expect(service.name, isNotEmpty, reason: service.id);
        expect(service.url, startsWith('https://'), reason: service.id);
        expect(service.target, isEmpty, reason: service.id);
      }
    });

    test('우리 사용자에게 닿는 것부터 받는다', () {
      final services = _central().services;
      final first = services.where((s) => s.priority == 1);
      expect(first, isNotEmpty);
      // 1순위는 2순위보다 상세가 더 많이 채워져 있어야 한다.
      double filled(int priority) {
        final rows = services.where((s) => s.priority == priority);
        if (rows.isEmpty) return 0;
        return rows.where((s) => s.detailFetched).length / rows.length;
      }
      expect(filled(1), greaterThanOrEqualTo(filled(0)));
    });

    test('아직 다 안 받았어도 몇 건짜리 자료인지 적어 둔다', () {
      final catalog = _central();
      expect(catalog.totalCount, catalog.services.length);
      expect(
        catalog.detailFetchedCount,
        catalog.services.where((s) => s.detailFetched).length,
      );
      expect(catalog.operations, contains('NationalWelfarelistV001'));
      // **키는 안 적는다.**
      expect(catalog.operations.join(), isNot(contains('serviceKey')));
    });

    test('근거법령 이름을 담는다 — 잇는 건 다음 일이다', () {
      final withLaws = _central().services.where((s) => s.laws.isNotEmpty);
      expect(withLaws, isNotEmpty);
    });

    test('안 받기로 한 법령은 버리지 않되, 왜 안 받는지 적는다', () {
      final catalog = _central();
      final seen = {for (final s in catalog.services) ...s.laws};
      expect(
        {...catalog.matchedLaws, ...catalog.lawsNotTaken},
        seen,
        reason: '받는 것과 안 받는 것을 더하면 나온 이름 전부여야 합니다',
      );
      // **목록만 남기면 다음 사람이 「받아야 하나」로 읽는다.**
      expect(catalog.lawsNotTakenWhy, isNotEmpty);
      expect(catalog.lawsNotTakenWhy, contains('판본'));
    });

    test('지자체 API 는 안 열었다고 이름으로 남긴다', () {
      expect(_central().openPart, contains('지자체복지서비스 API'));
    });

    test('자료가 나눈 줄을 그대로 쓴다 — 셈식을 자르지 않는다', () {
      final pension =
          _central().services.firstWhere((s) => s.name == '기초연금');
      expect(pension.criteria, contains('소득평가액 = {0.7 X (근로소득 - 116만원)}'));
      expect(pension.criteria.split('\n').length, greaterThan(3));
    });

    test('덜 푼 이름표를 마저 푼다', () {
      for (final service in _central().services.where((s) => s.detailFetched)) {
        expect(service.target, isNot(contains('&#')), reason: service.id);
        expect(service.criteria, isNot(contains('&#')), reason: service.id);
        expect(service.benefit, isNot(contains('&divide;')),
            reason: service.id);
      }
    });

    test('제도마다 기준연도가 따로 있다', () {
      final years =
          _central().services.map((s) => s.baseYear).whereType<int>().toSet();
      expect(years, isNotEmpty);
      for (final year in years) {
        expect(year, greaterThan(2000));
      }
    });
  });

  group('세 축 대조표', () {
    test('출처마다 어느 값이 나왔는지 적어 둔다', () {
      final raw = jsonDecode(File('assets/welfare/axes.json').readAsStringSync())
          as Map<String, dynamic>;
      final axes = (raw['axes'] as List).cast<Map<String, dynamic>>();
      expect(axes.map((a) => a['key']), ['lifeStages', 'households', 'topics']);
      for (final axis in axes) {
        expect(axis['values'] as List, isNotEmpty, reason: '${axis['key']}');
      }
      // 코드↔이름은 아직 못 맞춘다. 짝을 지어 보지 않는다.
      // **다만 지금 아무것도 막고 있지 않다** — 받아 놓고 이름으로 거른다.
      expect(raw['openPart'], contains('코드'));
      expect(raw['note'], contains('필요 없습니다'));
    });
  });
}
