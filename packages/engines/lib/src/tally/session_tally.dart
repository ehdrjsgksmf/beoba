/// **집계는 원문 없이 센다.**
///
/// 「어떤 고충으로 많이 오시는가」를 알려면 선택지 값이면 충분하다. 문장은
/// 오히려 필요 없다 — 있으면 위험만 는다.
///
/// ## 조합해도 사람이 특정되지 않는다
///
/// 지역·금액·날짜가 없기 때문이다. 「천안 · 1997년생 · 상속 · 3천만원」이면
/// 특정되지만 「상속 · 받을 쪽 · q_known_date 에서 나감」은 아무도 아니다
/// (DECISIONS 136번).
///
/// ## 제일 값진 것은 [exitAt] 이다
///
/// 「어떤 분야가 많은가」보다 **「어느 질문에서 나가는가」**가 값지다. 그게
/// 단계 줄이기의 근거가 된다. 지금은 순서를 짐작으로 정하고 있다.
///
/// [exitAt] 은 **질문 id** 이지 답이 아니다. 「지급명령을 받았다」는 답이라
/// 여기 들어오면 안 된다.
class SessionTally {
  const SessionTally({
    required this.domain,
    required this.role,
    required this.exitAt,
    required this.reached,
    required this.version,
  });

  /// 분야 id. `wage_theft` · `deposit_return` …
  final String domain;

  /// 역할. 없는 분야도 있어 빈 문자열이 될 수 있다.
  final String role;

  /// 마지막으로 본 자리. **질문 id 다.**
  final String exitAt;

  /// 결과 화면까지 갔는가.
  final bool reached;

  /// 앱 버전.
  final String version;

  /// 보내도 되는 키. **이 다섯뿐이다.**
  ///
  /// 검증기가 이 목록을 소스에서 읽어 [toJson] 과 대조한다. 하나라도 더
  /// 붙으면 실패다 — 「이것도 있으면 좋겠는데」가 한 번 통과하면 그다음이
  /// 쉬워진다.
  static const List<String> allowedKeys = [
    'domain',
    'role',
    'exitAt',
    'reached',
    'version',
  ];

  /// 날짜는 넣지 않는다. **받는 쪽이 찍는다.**
  Map<String, Object?> toJson() => {
        'domain': domain,
        'role': role,
        'exitAt': exitAt,
        'reached': reached,
        'version': version,
      };

  @override
  String toString() => 'SessionTally(${toJson()})';
}
