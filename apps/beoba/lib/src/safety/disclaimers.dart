/// 앱이 **하지 않는 일**을 밝히는 문구. 여기 말고 다른 곳에 두지 않는다.
///
/// 이 문구들은 금지어를 부정문으로 담는다 — "승소 가능성은 안내하지 않습니다" 는
/// 예측이 아니라 예측을 하지 않겠다는 선언이다. 그런데 `SafetyFilter` 는 부분
/// 문자열 검사라 부정문을 구분하지 못하고 `승소` 하나로 막는다.
///
/// 마커 주석을 여기저기 뿌려 예외를 만드는 대신 **파일 하나에 모았다.**
/// `verify_domains.dart` 는 이 파일만 문구 검사에서 제외한다. 예외가 한 곳에
/// 모여 있으면 리뷰할 수 있다. 흩어지면 못 한다.
///
/// 규칙 — 여기에 들어올 수 있는 것은 "우리는 X 를 하지 않습니다" 뿐이다.
/// 화면에 그릴 때는 반드시 `SafetyScope.disclaimer` 를 쓴다. 그 scope 도
/// `가능성이 높습니다` · `유리합니다` 같은 단정 표현은 그대로 막는다.
library;

abstract final class Disclaimers {
  /// 홈 화면 기능 소개 자리. AI기본법 고지와 짝이 된다.
  static const String noOutcomePrediction = '승소 가능성은 안내하지 않습니다';

  /// 결과 화면 머리말.
  static const String noJudgement =
      '법령과 계산 기준을 그대로 옮긴 것입니다. 사건의 결과를 예측하거나 유불리를 판단하지 않습니다.';

  /// 인터뷰가 끝났을 때.
  static const String noAdvice = '이 안내는 법률 상담이 아닙니다. 변호사의 조언을 대신하지 않습니다.';

  /// 홈 화면 「도울 수 없어요」 자리. 같은 뜻을 마중이 말투로 적은 것이다.
  ///
  /// [noAdvice] 와 두 벌인 이유 — 화면마다 말투가 다르다. 결과 화면 머리말은
  /// 법적 고지라 단정형이 맞고, 홈에서 마중이가 자기를 소개하는 자리는 아니다.
  /// 뜻이 같으므로 **둘 다 이 파일에서만 관리한다.**
  static const String noAdviceSoft = '법률 상담이 아니라, 순서를 짚어드리는 도구예요';
}

/// 이 파일이 담고 있는 문구 **전부**.
///
/// 예외의 범위는 "이 파일" 이 아니라 **"지금 이 목록"** 이어야 한다.
/// 파일 단위로 열어 두면 나중에 한 줄 더 넣는 것만으로 SafetyFilter 를 조용히
/// 우회할 수 있다. `disclaimers_test.dart` 가 이 목록을 통째로 박아 두므로
/// 문구를 더하거나 고치면 테스트가 **먼저** 깨진다 — 변경이 사람 눈을 거친다.
const List<String> kAllDisclaimers = [
  Disclaimers.noOutcomePrediction,
  Disclaimers.noJudgement,
  Disclaimers.noAdvice,
  Disclaimers.noAdviceSoft,
];
