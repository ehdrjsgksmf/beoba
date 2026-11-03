import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'enums.dart';
import 'hard_stop.dart';
import 'legal_basis.dart';
import 'verification.dart';
import 'welfare.dart';

part 'broker.freezed.dart';
part 'broker.g.dart';

/// ② 방어 — 브로커·사기 경보.
///
/// [phrase] 와 [truth] 는 **사기꾼이 하는 말의 인용**이다. 앱의 주장이 아니다.
/// 따라서 SafetyFilter 는 이 두 필드에 `quote` scope 를 적용한다
/// (검수된 데이터에만 허용 — [verification] 필수).
@freezed
abstract class BrokerAlert with _$BrokerAlert implements Verifiable {
  const factory BrokerAlert({
    required String id,
    /// **법률 위험도.** 화면 무게가 아니다 — 그건 [display] 다.
    required AlertSeverity severity,

    /// **화면 무게.** 기본은 인라인이다.
    ///
    /// 새 경보를 더할 때 아무것도 안 적으면 화면을 안 멈춘다. 멈추는 쪽이
    /// 기본이면 목록이 늘 때마다 조용히 무거워진다.
    @Default(AlertDisplay.inline) AlertDisplay display,

    /// 상대가 하는 말.
    required String phrase,

    /// 사실은 이렇다.
    required String truth,

    /// 이 단어가 나오면 경보를 띄운다.
    ///
    /// **사용자가 직접 타이핑한 문장에만** 맞춘다 (`userTypedText`). 선택지 값이나
    /// `setsField` 부산물에 맞추면 우리가 쓴 말이 사용자가 쓴 말로 둔갑한다.
    ///
    /// 낱말은 **틀릴 수 없는 것만** 담는다. 이 파일은 모든 분야가 공유하므로
    /// 한 분야에서 자연스러운 말이 다른 분야에서 경보가 된다 — 「보증금」은
    /// 전세 분야의 일상어이고, 「일당 30만」은 임금체불의 일상어다.
    @Default(<String>[]) List<String> triggers,

    /// 이 낱말이 히트를 **덮고 있으면** 그 히트만 무효 ([AutoTrigger.exceptPatterns] 와 같다).
    ///
    /// 「금융거래법」은 **「전자금융거래법」의 부분 문자열**이다. 우리가 인용하는
    /// 실존 법률이라 사용자가 그 이름을 그대로 적을 수 있다. 낱말을 버리지 않고
    /// 겹치는 자리만 덮는다.
    @Default(<String>[]) List<String> exceptTriggers,

    /// 낱말 검사의 **정답지. 비어 있으면 빌드 실패.**
    ///
    /// 음성 사례(걸리면 안 되는 문장)가 양성보다 많아야 정상이다. 오탐은 사람이
    /// 문장을 실제로 써 보기 전에는 드러나지 않는다.
    @Default(<KeywordTest>[]) List<KeywordTest> tests,
    ActionRef? action,
    LegalBasis? legalBasis,

    /// 근거가 하나로 안 끝날 때 이어 붙이는 조문. [Caution.alsoBasis] 와 같다.
    ///
    /// 통장 대여는 금지 조문(제6조)과 처벌 조문(제49조)이 따로 있고, 채권추심은
    /// 대상 채권을 시행령이 정하고 그 시행령이 다시 민사집행법을 가리킨다.
    /// **하나만 달면 나머지 법령이 매니페스트에서 사라진다.**
    /// **기관이 알려 준 것이면 딱지를 단다** — 네 번째 층([AgencyNotice]).
    ///
    /// 조문이 아닌 금액·절차가 여기 있을 수 있다. 신용회복위원회 채무조정
    /// 신청비가 그렇다 — 법령이 아니라 기관 공지다. 그 사실 자체가 이 항목의
    /// 정보이므로 숨기지 않고 **어디서 왔는지 적는다.**
    ///
    /// 검사 (aa)가 이 딱지를 본다 — 딱지가 있으면 그 금액을 조문 인용 대신
    /// 「기관 이름 + 확인한 날」로 견준다.
    AgencyNotice? notice,
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,
    required Verification verification,
  }) = _BrokerAlert;

  factory BrokerAlert.fromJson(JsonMap json) => _$BrokerAlertFromJson(json);
}

/// 사무실·업체 판별 체크리스트. [threshold] 개 이상 해당하면 멈추라고 안내한다.
@freezed
abstract class BrokerChecklist with _$BrokerChecklist implements Verifiable {
  const factory BrokerChecklist({
    required String id,
    required String title,
    String? source,
    @Default(<String>[]) List<String> items,
    @Default(1) int threshold,
    @Default('') String thresholdMessage,
    ChecklistAsk? askThis,
    required Verification verification,
  }) = _BrokerChecklist;

  factory BrokerChecklist.fromJson(JsonMap json) => _$BrokerChecklistFromJson(json);
}

/// "이렇게 물어보세요" — 사용자가 상대에게 직접 던질 질문.
@freezed
abstract class ChecklistAsk with _$ChecklistAsk {
  const factory ChecklistAsk({
    required String question,
    @Default('') String why,
    Verification? verification,
  }) = _ChecklistAsk;

  factory ChecklistAsk.fromJson(JsonMap json) => _$ChecklistAskFromJson(json);
}
