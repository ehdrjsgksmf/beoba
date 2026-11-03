import 'package:domain_data/domain_data.dart';

/// 사용자가 답한 사실들. field → value.
///
/// 값 타입은 JSON 에서 온 그대로다(`int`, `String`, `bool`, `List`, [KstDate]).
/// 읽을 때 타입을 강제한다 — 금액이 `double` 로 들어오면 **거부**한다.
class CaseFacts {
  const CaseFacts([this.values = const {}]);

  final Map<String, Object?> values;

  bool has(String field) => values[field] != null;

  T? get<T>(String field) {
    final value = values[field];
    return value is T ? value : null;
  }

  /// 원 단위 금액. `double` 은 반올림 사고를 부르므로 받지 않는다.
  int? money(String field) {
    final value = values[field];
    return switch (value) {
      null => null,
      final int i => i,
      final double d => throw ArgumentError.value(
          d,
          field,
          '금액은 int(원 단위)여야 합니다. double 금지',
        ),
      final String s => int.tryParse(s.replaceAll(',', '')),
      _ => throw ArgumentError.value(value, field, '금액으로 읽을 수 없습니다'),
    };
  }

  /// 요율·비율처럼 소수가 허용되는 값.
  num? number(String field) {
    final value = values[field];
    return switch (value) {
      null => null,
      final num n => n,
      final String s => num.tryParse(s),
      _ => null,
    };
  }

  /// 정밀도까지 담은 날짜. 「2023년 3월」 같은 어림값도 여기로 온다.
  ApproxDate? approxDate(String field) {
    final value = values[field];
    return switch (value) {
      null => null,
      final ApproxDate a => a,
      final KstDate d => ApproxDate.exact(d),
      final String s => ApproxDate.tryParse(s),
      final DateTime dt => ApproxDate.exact(KstDate.fromUtcInstant(dt.toUtc())),
      _ => null,
    };
  }

  /// **정확한 날짜일 때만** 값을 돌려준다. 어림값이면 null 이다.
  ///
  /// 어림값을 정확한 날짜인 척 내주지 않는 것이 이 함수의 일이다. 어림값을 아직
  /// 배우지 않은 엔진은 값이 **없는 것으로 본다** — 결과가 안 나오는 것은 정직한
  /// 실패이고, 어림값으로 계산해 놓고 단정하는 것은 조용한 거짓이다.
  ///
  /// 범위가 필요하면 [approxDate] 를 쓴다.
  KstDate? date(String field) => approxDate(field)?.exact;

  String? text(String field) => values[field]?.toString();

  /// 선택지의 `setsField` 처럼 값을 덧씌운다.
  CaseFacts merge(Map<String, Object?> patch) =>
      CaseFacts({...values, ...patch});

  /// JSONLogic 이 읽을 수 있는 형태. 날짜는 ISO 문자열로 편다.
  ///
  /// 어림값도 축약 ISO 라 문자열 비교가 그대로 된다. 다만 정밀도가 다른 값을
  /// 부등호로 비교하는 규칙은 지금 없다 — 필요해지면 그때 정한다.
  Map<String, dynamic> toJsonLogicData() => values.map(
        (key, value) => MapEntry(key, switch (value) {
          final KstDate d => d.toIso(),
          final ApproxDate a => a.toIso(),
          _ => value,
        }),
      );

  @override
  String toString() => 'CaseFacts($values)';
}
