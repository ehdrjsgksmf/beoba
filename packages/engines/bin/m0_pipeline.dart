import 'dart:io';

import 'package:domain_data/domain_data.dart';
import 'package:domain_data/io.dart';
import 'package:engines/engines.dart';

/// M0 통합 확인 — 화면 없이 파이프라인 전체를 돌린다.
///
/// ```
/// dart run packages/engines/bin/m0_pipeline.dart
/// dart run packages/engines/bin/m0_pipeline.dart --date 2026-08-15
/// ```
///
/// 도메인 JSON 로드 → `unverified` 제거 → 스키마 검증 → 엔진 전체 → 콘솔 출력.
/// 같은 리포트를 Flutter 앱 `main.dart` 도 찍는다 (`buildEngineReport`).
Future<void> main(List<String> args) async {
  final today = _todayFrom(args);
  final source = FileDomainSource(_assetsDir());

  stdout.writeln('도메인 경로: ${_assetsDir().path}');
  stdout.writeln('기준일(KST): ${today.toIso()}');
  stdout.writeln('입력: $_demoDescription\n');

  final loader = DomainLoader(today: today);
  final Domain debt;
  try {
    debt = loader.loadFromJsonString(await source.read('debt_recovery'));
  } on DomainValidationException catch (e) {
    stderr.writeln(e);
    exit(1);
  }
  final loadReport = loader.lastReport;

  final crisis = DomainLoader(today: today)
      .loadFromJsonString(await source.read('_shared_crisis'));

  stdout.writeln(
    buildEngineReport(
      domain: debt,
      crisis: crisis,
      facts: demoFacts(today),
      clock: FixedKstClock(today),
      loadReport: loadReport,
    ),
  );
}

/// 리포트 머리에 찍는 한 줄 요약.
const String _demoDescription =
    '가상의 사건 하나 (실제 사건 아님 · 엔진 확인용 고정값)';

/// 데모 입력값. **여기 있는 숫자는 전부 지어낸 것이다.**
///
/// 법률 수치가 아니라 "이런 사건이 들어오면 엔진이 이렇게 답한다" 를 보여주기 위한
/// 입력일 뿐이다. 실제 법정 기준은 전부 도메인 JSON 에 있다.
///
/// 시나리오: 6년 전 5,000만원을 빌려줬다가 못 받았고, 오늘 지급명령을 송달받았다.
/// 전자소송으로 진행할 생각이다. 여기에 더해 ② 방어 층을 함께 보려고
/// 부동산 임대차·대출 상황을 한 사람에게 몰아넣었다 (실제로는 따로 들어온다).
CaseFacts demoFacts(KstDate today) => CaseFacts({
      // ④ 행동 — 기한 · 비용 · 서류 계산에 쓰인다
      'claimType': 'loan', // 빌려준 돈
      'claimAmount': 50000000, // not-a-legal-number: 청구액 5,000만원 (지어낸 값)
      'dueDate': today.addYears(-6), // 6년 전에 갚기로 했다
      'courtDocument': 'payment_order', // 지급명령을 받았다
      'hasCourtDocument': true, // ↑ 선택지의 setsField 가 채우는 값
      'hasPaymentOrder': true,
      'paymentOrderServedDate': today, // 오늘 송달받았다 → D-14 가 나온다
      'procedure': 'payment_order', // 지급명령으로 진행
      'useEfiling': true, // 전자소송 (인지대 10분의 9)

      // ② 방어 — LimitChecker 확인용. 위 사건과 직접 관계는 없다
      'transactionAmount': 150000000, // not-a-legal-number: 임대차 보증금 1억 5천만원
      'dealType': 'lease', // 임대차 (중개보수 구간표 선택)
      'requestedAmount': 900000, // not-a-legal-number: 상대가 요구한 금액 90만원
      'annualRate': 0.24, // not-a-legal-number: 연 24% 이자 요구
    });

KstDate _todayFrom(List<String> args) {
  final index = args.indexOf('--date');
  if (index >= 0 && index + 1 < args.length) {
    return KstDate.parse(args[index + 1]);
  }
  return const SystemKstClock().today();
}

Directory _assetsDir() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    for (final candidate in [
      '${dir.path}/packages/domain_data/assets/domains',
      '${dir.path}/../domain_data/assets/domains',
    ]) {
      final directory = Directory(candidate);
      if (directory.existsSync()) return directory;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  stderr.writeln('도메인 JSON 디렉터리를 찾지 못했습니다 (from ${Directory.current.path})');
  exit(2);
}
