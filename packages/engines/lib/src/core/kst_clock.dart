import 'package:domain_data/domain_data.dart';

/// 오늘이 며칠인지 알려주는 유일한 통로.
///
/// **엔진·화면 어디서도 `DateTime.now()` 를 직접 부르지 않는다.**
/// 시계를 주입해야 기한 계산을 테스트할 수 있다.
abstract interface class KstClock {
  /// KST 기준 오늘. **모든 기한 계산은 이것만 쓴다.**
  KstDate today();

  /// 실제 UTC 시각. 로그·알림 스케줄에 쓴다.
  DateTime nowUtc();

  /// 기기가 있는 곳의 달력 날짜.
  ///
  /// **계산에 쓰지 않는다. 표시 전용이다.** 재외국민이 쓰면 현지 날짜와 KST 가
  /// 다르다 — 뉴욕에서 밤에 열면 현지는 15일인데 기한은 16일 기준으로 돈다.
  /// 그 어긋남을 숨기면 사용자가 자기 날짜로 D-day 를 센다.
  ///
  /// 여기가 `DateTime.now()` 를 기기 시간대로 읽는 **유일한 통로**다. 화면이
  /// 직접 읽으면 규칙이 뚫린다.
  KstDate localToday();
}

/// 실제 시계. **이 프로젝트에서 `DateTime.now()` 를 부르는 유일한 곳.**
class SystemKstClock implements KstClock {
  const SystemKstClock();

  @override
  // ignore: avoid_dynamic_calls
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  KstDate today() => KstDate.fromUtcInstant(nowUtc());

  @override
  KstDate localToday() {
    // `toUtc()` 를 붙이지 않는다. 기기 시간대 그대로가 필요하다.
    // ignore: avoid_dynamic_calls
    final local = DateTime.now();
    return KstDate(local.year, local.month, local.day);
  }
}

/// 고정 시계. 테스트 전용.
///
/// [localToday] 를 따로 주면 **해외 접속을 흉내낼 수 있다.** 기본값은 KST 와
/// 같은 날 — 국내 사용자다.
class FixedKstClock implements KstClock {
  const FixedKstClock(this._today) : _localToday = null;

  /// 해외 접속을 흉내낸다. KST 는 [kst], 기기가 보는 날짜는 [local].
  const FixedKstClock.abroad({required KstDate kst, required KstDate local})
      : _today = kst,
        _localToday = local;

  final KstDate _today;
  final KstDate? _localToday;

  @override
  KstDate today() => _today;

  @override
  KstDate localToday() => _localToday ?? _today;

  @override
  DateTime nowUtc() => _today.toUtcInstantAtMidnight();
}
