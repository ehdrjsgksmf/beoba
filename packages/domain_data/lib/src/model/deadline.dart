import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/approx_date.dart';
import '../common/converters.dart';
import '../common/json_map.dart';
import '../common/kst_date.dart';
import 'enums.dart';
import 'legal_basis.dart';
import 'verification.dart';

part 'deadline.freezed.dart';
part 'deadline.g.dart';

/// 기한. 모든 날짜 연산은 KST 자정 기준.
@freezed
abstract class Deadline with _$Deadline implements Verifiable {
  const factory Deadline({
    required String id,
    required String label,

    /// 이 날짜가 무엇인가. **기본은 기한이다.**
    ///
    /// [DeadlineKind.startsFrom] 은 「그날부터 생기는 것」이다 — 대항력이
    /// 그렇다. 「오늘 할 일」 카드가 세지 않고, D-day 도 붙지 않는다.
    @Default(DeadlineKind.deadline) DeadlineKind kind,
    @Default('') String whatIsThis,
    required Severity severity,

    /// 기산일이 담긴 `CaseFacts` 필드명.
    required String basisField,

    /// `from_known_date` 에서 "안 날"이 담긴 필드명. 없으면 [basisField] 를 쓴다.
    String? knownDateField,
    required Offset offset,
    required CalcRule calcRule,

    /// `fixed_annual` 전용 — 매년 이 월/일.
    int? fixedMonth,
    int? fixedDay,
    JsonMap? showIf,

    /// 이 기한이 **언제 생기는지** 한 줄.
    ///
    /// 기한이 하나도 안 걸렸을 때 빈 화면을 그냥 두지 않으려고 있다. 빈 화면은
    /// 정상 동작이어도 **실패처럼 보인다.** 왜 없는지와 언제 생기는지를 말한다.
    ///
    /// showIf 가 있으면 **필수**다 — 조건부 기한은 자기가 언제 걸리는지
    /// 설명할 수 있어야 한다.
    @Default('') String appearsWhen,

    /// 이 기한이 속한 `ExclusiveGroup` 의 id. 같은 묶음에서는 하나만 맞아야 한다.
    String? exclusiveGroup,
    required LegalBasis legalBasis,

    /// 근거가 하나로 안 끝날 때. [Caution.alsoBasis] 와 같다.
    ///
    /// 재심 10일이 그렇다 — 기간은 근로기준법 제31조 제1항에 있고,
    /// **그 기간을 늘려주지 않는다는 것**은 노동위원회법 제26조 제3항에 있다.
    /// 하나만 달면 나머지는 `verification.source` 로 내려가고 법령 매니페스트에서
    /// 사라진다 — 개정이 나도 아무도 모른다(DECISIONS 160번).
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,

    /// 며칠 전에 알릴지. 예: `[30, 7, 3, 1]`
    @Default(<int>[]) List<int> notify,
    required Verification verification,

    /// **정답지. 비어 있으면 빌드 실패.**
    @Default(<DeadlineTest>[]) List<DeadlineTest> tests,
  }) = _Deadline;

  factory Deadline.fromJson(JsonMap json) => _$DeadlineFromJson(json);
}

@freezed
abstract class Offset with _$Offset {
  const factory Offset({
    required int value,
    required TimeUnit unit,
  }) = _Offset;

  factory Offset.fromJson(JsonMap json) => _$OffsetFromJson(json);
}

/// `{ "basis": "2026-08-15", "expected": "2026-08-29" }`
///
/// 기산일이 어림이면 답도 범위다:
/// `{ "basis": "2026-08", "expected": "2026-09-01", "expectedLatest": "2026-09-30" }`
///
/// **어림 기산일도 정답지로 잠근다.** 잠기지 않으면 회귀를 못 잡는다.
@freezed
abstract class DeadlineTest with _$DeadlineTest {
  const factory DeadlineTest({
    @RequiredApproxDateConverter() required ApproxDate basis,
    @RequiredKstDateConverter() required KstDate expected,

    /// 범위의 늦은 끝. 없으면 [expected] 와 같다 — 정확한 기산일이라는 뜻이다.
    @KstDateConverter() KstDate? expectedLatest,

    /// showIf 를 만족시키기 위해 함께 넣을 값들 (선택).
    JsonMap? facts,
  }) = _DeadlineTest;

  factory DeadlineTest.fromJson(JsonMap json) => _$DeadlineTestFromJson(json);
}
