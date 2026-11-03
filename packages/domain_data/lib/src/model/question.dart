import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'enums.dart';
import 'verification.dart';

part 'question.freezed.dart';
part 'question.g.dart';

/// 인터뷰 질문. **AI는 질문을 생성하지 않는다.** 이 목록에서 고를 뿐이다.
@freezed
abstract class Question with _$Question {
  const factory Question({
    required String id,
    required int order,
    required String text,

    /// 왜 묻는지. **비어 있으면 빌드 실패.** 이게 제품의 차별점이다.
    @Default('') String whyAsk,

    /// 이 질문의 답을 **다음 화면에서 되받는 말.** `{value}` 자리에 답이 들어간다.
    ///
    /// ```
    /// "echo": "{value}이시군요."   →   5,000만원이시군요. 언제까지 받기로 하셨나요?
    /// ```
    ///
    /// **비어 있어도 된다.** 열두 번 다 되받으면 잔소리다. 사용자가 신경 써서 답한
    /// 값(금액·날짜) 뒤에만 붙인다.
    ///
    /// **해석을 붙이지 않는다.** `{value}을 빌려주셨군요` 는 앞 답이 보증금이면
    /// 거짓이 된다. 값을 그대로 되받으면 틀릴 수 없다.
    @Default('') String echo,
    required QuestionType type,

    /// `CaseFacts` 에 저장될 키.
    required String field,

    /// 계산에 안 쓰고 **흐름·정리에만** 쓰는 질문인가.
    ///
    /// 검증기가 「물어 놓고 아무 데서도 안 읽는 필드」를 경고한다. 그런데 묻는
    /// 이유가 계산만은 아니다 — 다음 질문을 고르려고, 또는 사용자가 자기 상황을
    /// 정리하도록 묻는 것도 정당하다.
    ///
    /// **다만 그렇다고 적혀 있어야 한다.** 표시가 없는데 안 읽히면 둘 중
    /// 하나다 — 읽어야 하는데 안 읽는 것이거나(`q_debtor_address_known` 이
    /// 그랬다), 물을 이유가 없는 질문이거나. 둘 다 고칠 값어치가 있다.
    @Default(false) bool flowOnly,

    /// 필수 항목 2, 추가 항목 1.
    @Default(1) int weight,
    @JsonKey(name: 'required') @Default(false) bool isRequired,
    JsonMap? showIf,

    /// `type: date` 일 때 **필수.** 없으면 빌드가 깨진다.
    ///
    /// 기본값을 두지 않는 이유 — 기본값이 있으면 새 날짜 질문이 아무 제약 없이
    /// 조용히 들어온다. 그 질문이 기한 계산에 쓰이면 사용자가 미래 날짜를 넣고도
    /// 아무도 모른다. 매번 정하게 만든다.
    DateRange? dateRange,

    /// `type: date` 일 때 **필수.** 어림값을 받아도 되는 날짜인가.
    ///
    /// 법원 서류를 받은 날은 **서류에 적혀 있으므로** 어림이 있을 수 없다
    /// (`exact`). 돈을 빌려준 날은 대개 어림이다(`approximate`).
    /// 어느 쪽인지는 **분야 지식**이라 JSON 이 정한다 — [DateRange] 와 같은 자리다.
    DatePrecisionPolicy? datePrecision,
    @Default(<QuestionOption>[]) List<QuestionOption> options,
    Verification? verification,
  }) = _Question;

  factory Question.fromJson(JsonMap json) => _$QuestionFromJson(json);
}

@freezed
abstract class QuestionOption with _$QuestionOption {
  const factory QuestionOption({
    required String value,
    required String label,

    /// 이 선택지가 무엇인지 한 줄 풀이. **선택 사항.**
    ///
    /// 여기만 비어도 빌드가 깨지지 않는다 — "곧 준다고 합니다" 같은 선택지에
    /// 억지 설명을 달면 화면만 길어진다. 모르는 말이 든 선택지에만 붙인다.
    String? whatIsThis,

    /// 이 선택지를 골랐을 때 되받는 말. **문장 전체다. `{value}` 를 안 쓴다.**
    ///
    /// ## 왜 [Question.echo] 로 안 되는가
    ///
    /// `Question.echo` 는 `{value}` 자리에 답을 끼우는 틀이라 **답이 문장에
    /// 끼워 넣을 수 있는 값일 때만** 된다. 날짜와 금액이 그렇다 —
    /// 「{value}에 아셨군요」.
    ///
    /// **선택지는 그렇지 않다.** 선택지 글은 물음에 대한 **대답 꼴**로 적혀
    /// 있어서(「일하다가요」·「잘 모르겠어요」) 문장 가운데 끼우면 말이 안 된다.
    /// 그리고 자연스러운 되받기가 **고른 것마다 다르다.**
    ///
    /// ```
    /// 일하다가요                    → 일하다 다치신 거군요.
    /// 오가는 길에요                  → 오가는 길에 다치신 거군요.
    /// 잘 모르겠어요                  → 어느 쪽인지는 아직 모르시는군요.
    /// ```
    ///
    /// 한 틀로 셋을 다 담을 수 없다. 그래서 **선택지에 붙인다.**
    ///
    /// **해석을 붙이지 않는다.** 사실만 되받는다 —
    /// 「일하다 다치셨으니 산재예요」는 판정이라 쓰지 않는다.
    String? echo,

    /// 다른 분야로 이관한다. 예: 임금 → `wage_theft`
    String? redirect,

    /// 이 선택지를 고르면 함께 세팅되는 필드들.
    JsonMap? setsField,
  }) = _QuestionOption;

  factory QuestionOption.fromJson(JsonMap json) => _$QuestionOptionFromJson(json);
}
