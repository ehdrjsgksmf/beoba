import 'package:domain_data/domain_data.dart';

/// **네 번째 층 — 「기관이 알려 준 것」.**
///
/// [LegalLayer] 에 값을 더하지 않았다. 일부러다. 🟢 법에 있는 내용 · 🟡 적용될
/// 가능성 · 🔴 확인 안 된 것은 **조문을 축으로 갈린 셋**이고, 복지제도 안내는
/// 그 축 위에 없다. 조문을 대조한 적이 없고 대조할 원문도 우리에게 없다.
///
/// 이 층을 🟢 옆에 두면 그 자리에서 「법에 적힌 것만 말한다」가 깨진다.
/// 사용자는 나란히 놓인 두 카드를 같은 무게로 읽기 때문이다.
///
/// **[notice] 없이는 만들 수 없다.** `LegalBasisCard` 가 `legalBasis` 없이
/// 못 만들어지는 것과 같은 자리다 — 이 층에서 출처와 날짜를 빼면 남는 것은
/// 근거 없는 단정이다.
class AgencyBlock {
  const AgencyBlock({
    required this.id,
    required this.title,
    required this.notice,
    this.body = '',
    this.url,
  });

  final String id;

  /// 제도 이름. 기관이 붙인 이름 그대로.
  final String title;

  /// 안내 본문. 기관이 적은 말 그대로. 없을 수 있다 — 공공 자료가 그렇다.
  final String body;

  /// 더 볼 곳. 복지로 상세 링크.
  final String? url;

  /// 출처와 마지막 확인일. **필수.**
  final AgencyNotice notice;

  /// 화면에 반드시 함께 나가는 한 줄. 문장은 [AgencyNotice] 가 만든다.
  String get disclosure => notice.sentence;
}
