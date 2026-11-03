import 'package:json_annotation/json_annotation.dart';

import 'approx_date.dart';
import 'kst_date.dart';

/// `"2026-08-15"` ↔ [KstDate]. null 허용.
class KstDateConverter implements JsonConverter<KstDate?, String?> {
  const KstDateConverter();

  @override
  KstDate? fromJson(String? json) => KstDate.tryParse(json);

  @override
  String? toJson(KstDate? object) => object?.toIso();
}

/// `"2026-08-15"` ↔ [KstDate]. 값이 반드시 있어야 하는 필드용.
class RequiredKstDateConverter implements JsonConverter<KstDate, String> {
  const RequiredKstDateConverter();

  @override
  KstDate fromJson(String json) => KstDate.parse(json);

  @override
  String toJson(KstDate object) => object.toIso();
}

/// `"2023"` · `"2023-03"` · `"2023-03-15"` ↔ [ApproxDate]. 값이 반드시 있는 필드용.
///
/// 정답지(`tests[]`)의 기산일이 이걸 쓴다. 어림 기산일도 정답지로 잠글 수 있어야
/// 한다 — 잠기지 않으면 회귀를 못 잡는다.
class RequiredApproxDateConverter implements JsonConverter<ApproxDate, String> {
  const RequiredApproxDateConverter();

  @override
  ApproxDate fromJson(String json) {
    final parsed = ApproxDate.tryParse(json);
    if (parsed == null) {
      throw FormatException('날짜 형식이 YYYY · YYYY-MM · YYYY-MM-DD 가 아닙니다', json);
    }
    return parsed;
  }

  @override
  String toJson(ApproxDate object) => object.toIso();
}
