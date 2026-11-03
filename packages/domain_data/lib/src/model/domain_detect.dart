import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'hard_stop.dart' show KeywordTest;

part 'domain_detect.freezed.dart';
part 'domain_detect.g.dart';

/// 자유 입력에서 이 분야를 알아채는 규칙.
///
/// **고르는 게 아니라 후보를 좁히는 것이다.** 걸렸다고 바로 넘기지 않는다 —
/// 「이렇게 이해했어요」로 확인받고, 아니면 사용자가 고친다.
///
/// 어간을 줄이지 않고 **활용형을 그대로 나열한다.** 「고소」로 줄였다가
/// 「참기름이 고소한」이 걸린 자리를 기억한다(DECISIONS 39번). 장치는
/// 브로커 경보·하드스톱과 같은 [KeywordTest] · `KeywordMatch` 를 쓴다.
@freezed
abstract class DomainDetect with _$DomainDetect {
  const factory DomainDetect({
    /// 이 분야라고 볼 낱말. 활용형을 그대로 적는다.
    @Default(<String>[]) List<String> patterns,

    /// 걸려도 이 분야가 아닌 자리. 「전세자금대출」이 그렇다.
    @Default(<String>[]) List<String> exceptPatterns,

    /// 알아챈 뒤 미리 채워 둘 답.
    @Default(<PrefillRule>[]) List<PrefillRule> prefill,

    /// **정답지가 없으면 빌드가 깨진다.** 오탐은 사용자를 쫓아낸다.
    @Default(<KeywordTest>[]) List<KeywordTest> tests,
  }) = _DomainDetect;

  factory DomainDetect.fromJson(JsonMap json) => _$DomainDetectFromJson(json);
}

/// 미리 채워 둘 답 하나.
///
/// ## 틀렸을 때 되돌릴 수 없는 것은 미리 채우지 않는다
///
/// 금액을 잘못 채우면 화면에서 보고 고친다. **날짜를 잘못 채우면 사람이 그걸
/// 믿고 안 움직인다.** 그래서 날짜·기한에 닿는 필드는 검증기가 막는다
/// (DECISIONS 130번).
@freezed
abstract class PrefillRule with _$PrefillRule {
  const factory PrefillRule({
    /// 어느 질문의 답인가. 질문 id 라 오타는 검증기가 잡는다.
    required String questionId,

    /// 고를 선택지의 값. [fromAmount] 를 쓰면 비워 둔다.
    String? value,

    /// 금액을 사용자가 쓴 문장에서 읽어 채운다. 「오백만원」도 읽는다.
    @Default(false) bool fromAmount,

    /// 이 낱말이 있을 때만 채운다. 비면 분야가 걸린 것만으로 채운다.
    @Default(<String>[]) List<String> patterns,
  }) = _PrefillRule;

  factory PrefillRule.fromJson(JsonMap json) => _$PrefillRuleFromJson(json);
}
