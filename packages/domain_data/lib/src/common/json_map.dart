/// 도메인 JSON의 원본 조각.
///
/// `showIf` / `condition` 같은 JSONLogic 식은 모델로 변환하지 않고
/// 이 형태 그대로 보관한다. 평가는 engines 의 `JsonLogic` 이 한다.
typedef JsonMap = Map<String, dynamic>;
