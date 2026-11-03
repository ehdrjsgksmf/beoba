import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/converters.dart';
import '../common/json_map.dart';
import '../common/kst_date.dart';
import 'enums.dart';

part 'verification.freezed.dart';
part 'verification.g.dart';

/// 모든 데이터 항목의 필수 필드. **예외 없다.**
///
/// - [VerificationStatus.verified] → 정상 표시 + 근거 링크
/// - [VerificationStatus.needsCheck] → 🟡 배지 + "확인이 필요한 정보입니다"
/// - [VerificationStatus.unverified] → 로더에서 제거. UI 도달 금지
@freezed
abstract class Verification with _$Verification {
  const factory Verification({
    required VerificationStatus status,
    String? source,
    String? sourceUrl,
    @KstDateConverter() KstDate? checkedAt,
    CheckedBy? checkedBy,

    /// **무엇이 아직 확인 전인가.** 한 항목의 일부만 열려 있을 때 그 조각의 이름.
    ///
    /// [status] 는 항목 전체의 **바닥값**이다. 조각 하나가 열려 있으면 항목은
    /// `needsCheck` 다 — 그건 그대로 둔다. 다만 「확인이 필요한 정보입니다」만
    /// 달아 두면 **확정된 부분까지 못 믿을 것으로 읽힌다.** 송달료가 그랬다:
    /// 회차와 수송달자는 예규 [별표 1] 원문으로 대조를 마쳤는데 1회 금액 하나
    /// 때문에 줄 전체가 🟡 였다. **아는 것을 모른다고 적는 것**이다.
    ///
    /// 여기에 이름을 적으면 배지가 그 조각만 가리킨다.
    String? openPart,

    /// **[openPart] 를 사람이 전화로 읽을 수 있는 질문 한 문장으로.**
    ///
    /// [openPart] 는 **우리 장부**다 — 무엇을 못 닫았는지의 기록이고,
    /// 「원문 미확보」·「제42조 제1항 단서」처럼 우리끼리 쓰는 말이다.
    /// 창구에서 그대로 읽으면 못 알아듣는다.
    ///
    /// ```
    /// openPart   평균임금의 뜻(근로기준법 제2조) — 원문 미확보
    /// askThis    평균임금이 얼마로 잡히나요?
    /// ```
    ///
    /// **둘을 한 필드로 합치지 않는다.** 합치는 순간 「우리가 못 닫은 것」을
    /// 세는 자리가 사라진다 — 인수인계가 매주 보는 값이다.
    ///
    /// ★ **우리 사정을 적지 않는다.** 「미확보」·「매니페스트」 같은 말이
    /// 들어가면 검사가 막는다. 사람이 물어야 할 것만 적는다.
    String? askThis,

    /// **이 값이 어느 사건부터 적용되는가.** 조문의 시행일이 아니다.
    ///
    /// 부칙에는 시행일 말고 **적용례**가 따로 있다. 민사집행법 시행령
    /// 부칙 제2조가 그렇다 — 「이 영 시행 이후 접수되는 압류명령
    /// 신청사건부터 적용한다」. 오늘 시행 중인 조문이라도 **내 사건에
    /// 적용되는지는 따로**다.
    ///
    /// 관할표에서 이미 같은 것을 겪었다. 표에 이름이 있어도 시행일이 오늘
    /// 이후면 없는 법원이다. 이번엔 시행일이 아니라 적용례다.
    ///
    /// 금액을 내는 항목에는 이 값이 있어야 한다 — 없으면 검증기가 센다.
    @KstDateConverter() KstDate? appliesFrom,
    String? note,
  }) = _Verification;

  factory Verification.fromJson(JsonMap json) => _$VerificationFromJson(json);
}

/// [Verification] 을 가진 모든 모델의 공통 인터페이스.
///
/// 로더가 타입을 몰라도 `verification.status` 만 보고 걸러낼 수 있게 한다.
abstract interface class Verifiable {
  Verification get verification;

  /// 로그·검증 메시지에 쓰는 식별자.
  String get id;
}
