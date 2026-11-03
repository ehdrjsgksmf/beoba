/// **461건을 다 받지 않는다. 우리 사용자에게 닿는 것부터 받는다.**
///
/// 목록에는 농어업·문화예술·국방까지 들어 있다. 우리를 찾아오는 사람은
/// 임금이 밀렸거나, 일이 끊겼거나, 빚에 눌렸거나, 속아서 돈을 잃은 사람이다.
/// 한도가 창(窓)당 100회뿐이라 순서가 곧 무엇을 갖느냐다.
///
/// ## 이름으로 거른다
///
/// 응답의 세 축은 **이름 문자열**로 온다(`intrsThemaArray="서민금융,주거"`).
/// 요청 필터는 코드로 보내야 하고 코드↔이름 대응을 우리는 모르지만,
/// **받아 놓고 이름으로 거르는 데는 그 대응이 필요 없다.**
/// 그래서 `openPart` 의 코드↔이름은 지금 아무것도 막지 않는다.
///
/// ## 이건 우리 판단이다
///
/// 어느 주제가 우리 사용자에게 닿느냐는 자료가 말해 주지 않는다. 우리가
/// 정한 것이므로 **코드 한 곳에 모아 두고, 구운 자료에도 순위를 적어 둔다** —
/// 나중에 「왜 이건 상세가 없지」를 자료만 보고 알 수 있게.
library;

/// 1순위 — 반드시.
const Set<String> priorityOneTopics = {
  '서민금융',
  '일자리',
  '주거',
  '법률',
  '안전·위기',
};

const Set<String> priorityOneHouseholds = {
  '저소득',
  '한부모·조손',
};

/// 2순위 — 여유 있으면.
const Set<String> priorityTwoLifeStages = {
  '청년',
  '중장년',
  '노년',
};

const Set<String> priorityTwoTopics = {
  '생활지원',
  '보호·돌봄',
};

/// 1 · 2 · 0. **작을수록 먼저 받는다.**
///
/// 0 은 「안 받는다」가 아니라 「맨 뒤」다. 한도가 남으면 받는다.
int welfarePriority({
  required Set<String> topics,
  required Set<String> households,
  required Set<String> lifeStages,
}) {
  if (topics.intersection(priorityOneTopics).isNotEmpty ||
      households.intersection(priorityOneHouseholds).isNotEmpty) {
    return 1;
  }
  if (lifeStages.intersection(priorityTwoLifeStages).isNotEmpty ||
      topics.intersection(priorityTwoTopics).isNotEmpty) {
    return 2;
  }
  return 0;
}

/// 순위를 매길 때 쓰는 정렬 자리. 1 → 2 → 0.
int prioritySortKey(int priority) => priority == 0 ? 3 : priority;
