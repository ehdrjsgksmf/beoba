import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'legal_basis.dart';
import 'verification.dart';

part 'glossary.freezed.dart';
part 'glossary.g.dart';

/// 용어가 서는 자리. **3층 표시와 같은 축이다.**
///
/// ```
/// statute   🟢 법에 그 말의 뜻이나 효력이 적혀 있다 → 조문 원문을 싣는다
/// ourWords  🟡 법이 쓰기는 하는데 뜻을 정해 두지 않았다 → 풀이는 우리 말이다
/// ```
///
/// **🟡 에 근거 배지를 붙이면 안 된다.** 우리 말에 조문 이름을 달면 법이
/// 그렇게 정했다는 뜻이 된다. 대신 시트 맨 위에서 우리 말이라고 먼저 밝힌다.
enum GlossaryKind {
  @JsonValue('statute')
  statute,
  @JsonValue('our_words')
  ourWords;

  bool get hasStatute => this == GlossaryKind.statute;
}

/// 용어 하나.
///
/// [term] 이 곧 키다. 문장에 `[[지급명령]]` 이라고 박으면 이 항목을 찾는다.
/// **화면 문자열을 훑어 자동으로 붙이지 않는다** — 우리가 쓴 문장이므로
/// 우리가 쓸 때 표시하면 된다.
@freezed
abstract class GlossaryTerm with _$GlossaryTerm {
  const factory GlossaryTerm({
    /// 문장에 박는 낱말 그대로. 시트의 제목이기도 하다.
    required String term,
    required GlossaryKind kind,

    /// 한 줄 풀이. **40자를 넘으면 빌드가 선다.**
    ///
    /// 시트를 여는 사람은 한 낱말이 막혀서 연다. 길면 그 자리에서 또 막힌다.
    required String oneLiner,

    /// 🟢 만 갖는다. 🟡 에 넣으면 검증기가 막는다.
    LegalBasis? lawRef,

    /// 함께 볼 조문. 뜻은 한 조문에, 효력은 다른 조문에 있는 일이 잦다.
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,

    /// 시행일. **매니페스트의 판본과 맞는지 검증기가 대조한다.**
    ///
    /// 앱은 매니페스트를 싣지 않는다(네트워크도 안 부르고 크기도 아깝다).
    /// 그래서 값은 데이터에 적고, 그 값이 맞는지는 빌드가 본다.
    @Default('') String effective,
    required Verification verification,
  }) = _GlossaryTerm;

  factory GlossaryTerm.fromJson(JsonMap json) => _$GlossaryTermFromJson(json);
}

/// 용어집 전체. `assets/glossary/terms.json` 하나에 대응한다.
@freezed
abstract class Glossary with _$Glossary {
  const Glossary._();

  const factory Glossary({
    @Default(<GlossaryTerm>[]) List<GlossaryTerm> terms,
  }) = _Glossary;

  factory Glossary.fromJson(JsonMap json) => _$GlossaryFromJson(json);

  /// 문장에 박힌 키로 찾는다. 없으면 null — 화면은 밑줄 없이 그냥 그린다.
  GlossaryTerm? byTerm(String term) {
    for (final entry in terms) {
      if (entry.term == term) return entry;
    }
    return null;
  }
}
