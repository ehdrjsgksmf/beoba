import 'package:json_annotation/json_annotation.dart';

/// 도메인 전체의 활성 상태.
enum DomainStatus {
  @JsonValue('active')
  active,
  @JsonValue('beta')
  beta,

  /// 아직 만들지 않았지만 **목록에는 보이는** 분야.
  ///
  /// `disabled`(꺼짐)와 다르다. 준비 중 분야도 이름과 공적 창구를 갖는다 —
  /// 우리가 못 하는 일이어도 **어디로 가면 되는지는 말할 수 있다.**
  @JsonValue('coming_soon')
  comingSoon,
  @JsonValue('disabled')
  disabled,
}

/// 데이터 항목의 검증 상태. **이 앱의 안전장치.**
enum VerificationStatus {
  /// 원문 대조 완료. 정상 표시 + 근거 링크.
  @JsonValue('verified')
  verified,

  /// 🟡 배지 + "확인이 필요한 정보입니다".
  @JsonValue('needs_check')
  needsCheck,

  /// **로더에서 제거된다. UI 도달 금지.**
  @JsonValue('unverified')
  unverified,
}

enum CheckedBy {
  @JsonValue('self')
  self,
  @JsonValue('lawyer')
  lawyer,
  @JsonValue('official')
  official,
}

enum QuestionType {
  @JsonValue('single')
  single,
  @JsonValue('multi')
  multi,
  @JsonValue('number')
  number,
  @JsonValue('money')
  money,
  @JsonValue('date')
  date,
  @JsonValue('text')
  text,
}

/// 날짜 질문이 받을 수 있는 범위.
///
/// **어느 질문이 어느 범위인지는 분야 지식이라 JSON 에 있다.** 변제기는 아직 안
/// 왔을 수 있고(`any`), 요구한 날은 이미 지난 날이다(`past`). 이걸 코드에 박으면
/// 분야가 코드로 새어 나간다 — 분야는 데이터라는 원칙이 깨진다.
///
/// 여기 있는 것은 어휘일 뿐이다. `QuestionType` 과 같은 자리다.
enum DateRange {
  /// 오늘까지. 이미 일어난 일을 묻는다.
  @JsonValue('past')
  past,

  /// 오늘부터. 아직 오지 않은 날을 묻는다.
  @JsonValue('future')
  future,

  /// 제한 없음. 지났을 수도, 안 왔을 수도 있다.
  @JsonValue('any')
  any,
}

/// 이 날짜 질문이 어림값을 받아도 되는가.
///
/// **어느 질문이 어느 쪽인지는 분야 지식이라 JSON 에 있다.** 법원 서류를 받은 날은
/// 서류에 적혀 있으니 어림이 있을 수 없고, 돈을 빌려준 날은 대개 어림이다.
enum DatePrecisionPolicy {
  /// 일 단위까지 받는다. 「모름」을 내주지 않는다.
  @JsonValue('exact')
  exact,

  /// 연·월만 알아도 정식 답으로 받는다.
  @JsonValue('approximate')
  approximate,
}

enum TimeUnit {
  @JsonValue('day')
  day,
  @JsonValue('week')
  week,
  @JsonValue('month')
  month,
  @JsonValue('year')
  year,
}

/// 기한 계산 방식 4종.
enum CalcRule {
  /// 기산일 + offset
  @JsonValue('from_basis')
  fromBasis,

  /// 기산일이 속한 달의 말일 + offset
  @JsonValue('from_month_end')
  fromMonthEnd,

  /// 사용자가 입력한 "안 날" + offset
  @JsonValue('from_known_date')
  fromKnownDate,

  /// 매년 고정 월·일
  @JsonValue('fixed_annual')
  fixedAnnual,
}

/// 날짜가 무엇을 가리키는가.
///
/// **기한과 「언제부터」는 다르다.** 답변서 30일은 지나면 잃는 날이고,
/// 대항력은 그날부터 힘이 생기는 날이다. 같은 카드에 넣으면 「D-13」이
/// 붙어 사람이 쫓기게 되는데, 쫓길 일이 아니다(DECISIONS 135번).
enum DeadlineKind {
  /// 지나면 잃는 날. 「오늘 할 일」 카드가 이것만 센다.
  @JsonValue('deadline')
  deadline,

  /// 그날부터 생기는 것. 세지 않고 나란히 낸다.
  @JsonValue('startsFrom')
  startsFrom,

  /// **그 안에 다 받아야 하는 것.** 신청 기한이 아니라 **받는 기간**이다.
  ///
  /// 구직급여가 그렇다 — 이직일 다음 날부터 12개월이고, 그 안에 소정급여일수를
  /// 한도로 받는다(고용보험법 제48조 제1항). 늦게 신청하면 **신청할 권리를
  /// 잃는 것이 아니라 아직 안 받은 날짜를 잃는다.** 남은 날짜가 있어도 그
  /// 날짜가 지나면 거기서 끝난다.
  ///
  /// 「지나면 잃는 날」과 같은 카드로 그리면 **늦어질수록 줄어든다**는 것이
  /// 안 보이고, 「그날까지 신청하면 다 받는다」로 읽힌다(DECISIONS 189번).
  @JsonValue('receiveWithin')
  receiveWithin,
}

enum Severity {
  @JsonValue('critical')
  critical,
  @JsonValue('warning')
  warning,
  @JsonValue('info')
  info,
}

extension SeverityRank on Severity {
  /// 클수록 위급. 정렬(severity DESC)에 쓴다.
  int get rank => switch (this) {
        Severity.critical => 3,
        Severity.warning => 2,
        Severity.info => 1,
      };
}

/// 브로커 경보 심각도.
/// 화면 무게. **[AlertSeverity] 와 다른 축이다.**
///
/// `severity` 는 **법률 위험도**이고 이것은 **화면을 얼마나 멈춰 세우는가**다.
/// 둘을 한 축으로 쓰면 위험도 높은 것이 여덟이라 큰 카드가 기본이 되고,
/// **기본이 되면 아무것도 못 멈춘다.**
enum AlertDisplay {
  /// 그 자리에 얹는다. 흐름을 끊지 않는다.
  ///
  /// **약해서가 아니다.** 조문·창구·`truth` 는 [stop] 과 똑같이 붙는다.
  /// 멈춰 세워도 사용자가 지금 되돌릴 것이 없어서 인라인이다.
  @JsonValue('inline')
  inline,

  /// 큰 카드로 멈춰 세운다. **최대 3건**이고 넘으면 빌드가 깨진다.
  ///
  /// 기준은 하나다 — **사용자 본인이 형사처벌 대상이 되거나, 지금 움직이면
  /// 되돌릴 수 있는 것.** 「돈을 뜯길 수 있습니다」와 「당신이 처벌받을 수
  /// 있습니다」는 다르다. 앞은 피해자가 되는 것이고 뒤는 전과자가 되는 것이다.
  ///
  /// 차단은 아니다. 브로커를 만났다고 앱을 못 쓰게 하면 그 사람은 브로커에게
  /// 돌아간다.
  @JsonValue('stop')
  stop,

  /// 접지 않고 편다. **겁주는 색이 아니다.**
  ///
  /// [stop] 과 무게는 같은데 방향이 반대인 자리가 있다 — 압류를 당한 사람에게
  /// 「법이 못 가져가게 정해 둔 것이 있어요」를 말할 때다. 물음 버튼 뒤에
  /// 접으면 누르지 않은 사람은 통장이 통째로 묶인 줄 알고 지낸다.
  ///
  /// **겁을 준 뒤에 안심시키는 순서가 되면 안 된다.** 그래서 [stop] 보다
  /// 위에 온다.
  @JsonValue('open')
  open,
}

enum AlertSeverity {
  /// 들으면 100% 불법
  @JsonValue('red')
  red,

  /// 응하면 본인도 처벌
  @JsonValue('orange')
  orange,

  /// 법정 기준 초과 — 계산해 보세요
  @JsonValue('yellow')
  yellow,

  /// 애초에 불가능한 약속
  @JsonValue('blue')
  blue,
}

enum Importance {
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low,
}

extension ImportanceRank on Importance {
  int get rank => switch (this) {
        Importance.high => 3,
        Importance.medium => 2,
        Importance.low => 1,
      };
}
