import 'package:domain_data/domain_data.dart';

/// 결과 화면의 세 층 (SPEC §8.1).
///
/// 시각적으로 섞지 않는다. 타입도 섞지 않는다.
enum LegalLayer {
  /// 🟢 법에 있는 내용 — 조문 원문 + 근거.
  statute,

  /// 🟡 적용될 가능성 — 조건절 필수. 🟢 참조 없이 만들 수 없다.
  likely,

  /// 🔴 확인 안 된 것 — 되돌아갈 질문 링크.
  unknown,
}

/// 🟢 법에 있는 내용.
///
/// 조문을 그대로 인용한다. 앱이 해석하지 않는다.
class GreenBlock {
  const GreenBlock({
    required this.id,
    required this.title,
    required this.basis,
    required this.quotedText,
  });

  final String id;

  /// 법령명·조문. `LegalBasis.citation` 을 그대로 쓴다.
  final String title;

  /// 근거는 **필수**다. 없으면 이 블록을 만들 수 없다 (CONTRIBUTING.md 규칙 6).
  final LegalBasis basis;

  /// 조문 원문. `quote` scope 로 그린다.
  final String quotedText;
}

/// 🟡 적용될 가능성.
///
/// **자유 문장을 받지 않는다.** 조건과 결과를 따로 받는다. 화면은 둘을 잇기만 한다.
///
/// 왜 이렇게 하는가 — 처음에는 완성된 문장을 받고 조건절 정규식으로 검사하려 했다.
/// 그런데 한국어에서 `하면` 은 조건절이 아닌 자리에 더 많이 나온다:
///
/// ```
/// "지금 신청하면 됩니다"   ← 지시문인데 통과
/// "확인하면 됩니다"        ← 지시문인데 통과
/// ```
///
/// 검사가 헐거우면 단정문이 그대로 새어 나가 안전장치가 무력해진다.
/// 자유 문자열로 조립하는 경로를 아예 두지 않으면 검사할 것이 없다.
class YellowBlock {
  const YellowBlock({
    required this.greenRefId,
    required this.condition,
    required this.consequence,
  });

  /// 참조하는 🟢 블록. 없는 id 면 렌더링에서 걸러진다.
  final String greenRefId;

  /// **완성된 조건절이다.** 「이자를 받기로 하셨다면」 · 「기산일이 8월 15일이라면」.
  ///
  /// 화면이 어미를 덧붙이지 않는다. 예전에는 여기에 서술어 없는 조각을 담고
  /// 그리는 쪽에서 `라면` 을 붙였는데, 데이터에서 온 문장이 이미 `~다면` 으로
  /// 끝나 **「이자를받기로하셨다면라면」** 이 화면에 나갔다.
  /// 말은 데이터에서 온다 — 화면은 문장을 만들지 않는다.
  final String condition;

  /// "기한은 2026년 9월 14일입니다"
  final String consequence;
}

/// 🔴 확인 안 된 것.
///
/// 막다른 골목을 만들지 않는다. 항상 되돌아갈 질문을 함께 준다.
class RedBlock {
  const RedBlock({
    required this.label,
    required this.questionId,
    this.field,
  });

  /// 무엇을 확인하지 못했는지. 질문 문구를 그대로 쓴다.
  final String label;

  /// 되돌아갈 질문.
  final String questionId;

  /// 어느 사실이 비었는지. 디버깅용.
  final String? field;
}

/// 한 화면에 실릴 세 층.
class LayerBlocks {
  const LayerBlocks({
    this.green = const [],
    this.yellow = const [],
    this.red = const [],
  });

  final List<GreenBlock> green;
  final List<YellowBlock> yellow;
  final List<RedBlock> red;

  bool get isEmpty => green.isEmpty && yellow.isEmpty && red.isEmpty;

  Set<String> get greenIds => {for (final block in green) block.id};

  /// 🟢 참조가 살아 있는 🟡 만.
  ///
  /// SPEC §8.1 — "🟡 블록은 🟢 블록 참조 없이 생성 불가 → 렌더링 차단".
  List<YellowBlock> get renderableYellow =>
      yellow.where((y) => greenIds.contains(y.greenRefId)).toList();
}

/// 🟡 의 두 조각을 한 줄로 잇는다. **잇기만 한다.**
///
/// 어미도 조사도 붙이지 않는다. 붙일 것이 있으면 문장을 만드는 쪽 —
/// 데이터이거나 `LayerAssembler` — 이 이미 붙여 두었다.
String renderYellow(YellowBlock block) => '${block.condition}, ${block.consequence}';
