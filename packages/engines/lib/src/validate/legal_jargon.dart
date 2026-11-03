import '../core/keyword_match.dart';

/// 어려운 말을 어떻게 다룰 것인가.
///
/// 가르는 기준은 하나다 — **사용자가 그 말을 마주치는가.**
/// `label` 을 공식 용어로 두기로 한 것과 같은 원칙이라 앱 전체가 한 기준으로 묶인다
/// (DECISIONS 40번).
enum JargonKind {
  /// **쉬운 말로 갈아탄다.** 사용자가 이 말을 마주칠 일이 없다.
  ///
  /// 우리가 설명하려고 꺼낸 말일 뿐이므로 그냥 바꾸면 된다.
  /// `송달받은 → 받은` · `소송절차 → 재판` · `변제금액 → 갚을 금액`
  replace,

  /// **공식 용어라 남기되 풀이를 붙인다.** 서류·법원·신청서에서 이 말을 마주친다.
  ///
  /// 갈아치우면 사용자가 현장에서 그 이름을 못 찾는다.
  /// `이의신청(다투겠다는 신고)` 처럼 괄호 하나를 붙인다.
  annotate,
}

/// 어려운 말 하나.
class JargonTerm {
  const JargonTerm(this.word, this.kind, {this.except = const []});

  final String word;
  final JargonKind kind;

  /// 이 낱말이 **다른 말 안에 숨어 있을 때** 무효로 할 패턴.
  ///
  /// 겹칠 때만 무효다 — 문장 저 끝의 예외가 무관한 히트까지 지우지 않는다.
  final List<String> except;
}

/// 걸린 결과.
class JargonHit {
  const JargonHit(this.word, this.kind);

  final String word;
  final JargonKind kind;

  /// 다음 단계에서 무엇을 할지.
  String get action =>
      kind == JargonKind.replace ? '쉬운 말로 갈아타세요' : '풀이를 붙이세요';
}

/// 화면에 나가는 문장에서 어려운 말을 찾는다.
///
/// ## 왜 낱말 목록이 아니라 구조인가
///
/// 같은 함정을 **네 번** 겪었다:
///
/// ```
/// 각하 ⊂ 생각하다     최고 = 최고예요
/// 인가 ⊂ 인가요       소가 ⊂ 주소가
/// ```
///
/// 낱말을 하나씩 늘리고 좁히는 것으로는 계속 새 나온다. 그래서 위기 키워드에서 쓴
/// **예외 패턴 방식**을 그대로 가져왔다([39번](#39)) — 낱말마다 `except` 를 두고,
/// 예외가 히트를 덮으면 **그 히트만** 무효로 한다. 다른 낱말의 히트는 살아 있다.
///
/// 그리고 [음성 골든셋](legal_jargon_test.dart)이 목록을 지킨다. 목록을 늘릴 때마다
/// 사람이 눈으로 확인하는 것은 오래 못 간다.
abstract final class LegalJargon {
  /// 사용자가 마주칠 일 없는 말. 그냥 갈아탄다.
  static const List<JargonTerm> replaceTerms = [
    // 소송 절차 — 우리가 설명에 꺼내 쓸 뿐이다
    // `공시송달` 은 제도 이름이라 남기고 풀이를 붙인다(annotateTerms).
    // 그 안의 `송달` 까지 갈아타라고 하면 제도 이름을 쓸 수가 없다.
    JargonTerm('송달', JargonKind.replace, except: ['공시송달']),
    JargonTerm('소송절차', JargonKind.replace),
    JargonTerm('변제', JargonKind.replace),
    JargonTerm('상계', JargonKind.replace, except: ['상계좌']),
    // 「이행강제금」·「이행기한」은 노동위원회 결정문에 그 이름으로 적혀 온다.
    // 갈아탈 말이 아니라 **풀이를 붙일 말**이다 — 뒤 목록에 따로 둔다.
    //
    // 「이행명령」도 같다 — 가사소송법 제64조가 붙인 이름이고 결정문에 그대로
    // 적혀 온다. 「이행관리원」은 기관 이름이다(양육비법 제7조 제1항). **기관
    // 이름을 갈아타라고 하면 그 창구를 못 찾는다.**
    JargonTerm('이행', JargonKind.replace,
        except: ['이행권고', '이행강제금', '이행기한', '이행명령', '이행관리원']),
    JargonTerm('청구취지', JargonKind.replace),
    JargonTerm('청구원인', JargonKind.replace),
    JargonTerm('소송물', JargonKind.replace),
    JargonTerm('변론', JargonKind.replace),
    JargonTerm('준비서면', JargonKind.replace),
    JargonTerm('기판력', JargonKind.replace),
    JargonTerm('보전처분', JargonKind.replace),
    JargonTerm('제척기간', JargonKind.replace),
    JargonTerm('기산일', JargonKind.replace),
    JargonTerm('도과', JargonKind.replace),

    // 결정 형태 — 사용자는 결과만 알면 된다
    // `각하` 는 **생각하다** 안에 숨는다. 서술형으로 좁힌다.
    JargonTerm('각하되', JargonKind.replace),
    JargonTerm('각하 결정', JargonKind.replace),
    JargonTerm('기각', JargonKind.replace),

    // `최고` 는 "가장 좋다" 로 훨씬 자주 쓰인다. 서류 이름으로 좁힌다.
    JargonTerm('최고장', JargonKind.replace),

    // 관할 — 어느 법원인지만 알면 된다
    JargonTerm('보통재판적', JargonKind.replace),
    JargonTerm('특별재판적', JargonKind.replace),
    JargonTerm('이송', JargonKind.replace),

    // 당사자 호칭 — 우리 문장에서는 "상대방" 이면 된다
    JargonTerm('채무자', JargonKind.replace, except: ['채무자대리인']),
    JargonTerm('채권자', JargonKind.replace),
    JargonTerm('구상권', JargonKind.replace),
    JargonTerm('연대보증', JargonKind.replace),
  ];

  /// 서류·법원·신청서에서 마주치는 말. 남기고 풀이를 붙인다.
  ///
  /// **애매하면 이쪽에 둔다.** 남기고 설명하는 것이 지우는 것보다 안전하다 —
  /// 지웠는데 사용자가 그 말을 현장에서 만나면 앱이 아무 도움이 안 된다.
  static const List<JargonTerm> annotateTerms = [
    // 받는 서류 · 내는 서류. 손에 든 종이에 이 이름이 적혀 있다
    JargonTerm('지급명령', JargonKind.annotate),
    JargonTerm('이의신청', JargonKind.annotate),
    JargonTerm('소장', JargonKind.annotate, except: ['소장품', '이사장', '소장하']),
    JargonTerm('답변서', JargonKind.annotate),
    JargonTerm('판결', JargonKind.annotate),
    JargonTerm('내용증명', JargonKind.annotate),
    JargonTerm('확정판결', JargonKind.annotate),
    JargonTerm('이행권고', JargonKind.annotate),
    JargonTerm('공시송달', JargonKind.annotate),

    // 소장에 "원고" · "피고" 라고 적혀 있다. 지우면 자기가 어느 쪽인지 못 찾는다
    JargonTerm('원고', JargonKind.annotate, except: ['원고지', '원고료']),
    JargonTerm('피고', JargonKind.annotate, except: ['피고용']),

    // 제도 이름. 신청하려면 이 이름으로 찾아야 한다
    JargonTerm('채권추심', JargonKind.annotate),
    JargonTerm('채무자대리인', JargonKind.annotate),
    JargonTerm('강제집행', JargonKind.annotate),
    JargonTerm('이행강제금', JargonKind.annotate),
    JargonTerm('이행기한', JargonKind.annotate),
    // 가정법원이 「이행명령」이라는 이름으로 결정한다. 갈아치우면 그 이름으로
    // 신청할 수가 없다.
    JargonTerm('이행명령', JargonKind.annotate),
    JargonTerm('임차권등기명령', JargonKind.annotate),
    JargonTerm('전입신고', JargonKind.annotate),
    JargonTerm('확정일자', JargonKind.annotate),
    JargonTerm('배당요구', JargonKind.annotate),
    // 받은 종이에 이 이름으로 적혀 온다 — 갈아치우면 그 종이를 못 찾는다.
    // 전세사기 시행규칙 제3조 제1항 다목이 첨부 서류로 든다. 「최고」 한 글자
    // 낱말은 넣지 않는다 — 시효의 최고(내용증명)와 뜻이 달라 공통 조각이
    // 손으로 풀이를 붙여 두었다. 전세사기를 지을 때 이 말이 목록에 없어 풀이 없이 나갔다.
    JargonTerm('최고서', JargonKind.annotate),
    // 위와 같은 까닭이다 — 받은 종이에 이 이름으로 적혀 온다. 풀이는 국세징수법
    // 제75조 제1항에서 왔다(세무서가 공매공고를 한 뒤 알리는 통지).
    JargonTerm('공매통지서', JargonKind.annotate),
    JargonTerm('공탁', JargonKind.annotate),
    // 인지대가 10분의 9로 깎인다. 이 이름을 알아야 그 창구를 찾는다
    JargonTerm('전자소송', JargonKind.annotate),

    // 집행 — 실제로 겪게 되는 일이다
    JargonTerm('압류', JargonKind.annotate),
    JargonTerm('가압류', JargonKind.annotate),
    JargonTerm('가처분', JargonKind.annotate),
    JargonTerm('경매', JargonKind.annotate),

    // 기간 · 관할 — 법원에서 이 말로 안내받는다
    JargonTerm('소멸시효', JargonKind.annotate),
    JargonTerm('시효', JargonKind.annotate, except: ['소멸시효', '공소시효']),
    JargonTerm('관할', JargonKind.annotate),

    // 회생·파산 절차에서 마주친다. `인가` 는 **인가요?** 안에 숨는다
    JargonTerm('인가', JargonKind.annotate, except: ['인가요', '인가유']),
    JargonTerm('회생', JargonKind.annotate),
    JargonTerm('지연이자', JargonKind.annotate),
    JargonTerm('채권', JargonKind.annotate, except: ['채권추심', '회사채권', '채권자']),
    // 「한국신용정보원」은 기관 이름이다. 이름 안에 낱말이 들었다고 풀이를
    // 요구하면, 우리가 그 기관이 무엇을 하는지 정의하게 된다 — 신용정보법
    // 원문이 없어서 못 하는 말이다.
    JargonTerm('신용정보', JargonKind.annotate, except: ['한국신용정보원']),

    // `소가` 는 **주소가** 안에 숨는다
    JargonTerm('소가', JargonKind.annotate, except: ['주소가', '장소가', '요소가']),
    JargonTerm('집행권원', JargonKind.annotate),
    // 「채무명의」는 여기 없다. 풀이를 붙일 말이 아니라 **쓰지 않을 말**이다 —
    // 지금 법의 이름은 집행권원이다(민사집행법 제56조 제목). 화면에서 0건인지는
    // `verify_domains.dart` 의 `_retiredWords` 가 본다.
  ];

  static List<JargonTerm> get allTerms => [...replaceTerms, ...annotateTerms];

  /// [text] 안에서 처음 걸리는 어려운 말. 없으면 null.
  ///
  /// [labels] 는 `whatIsThis` 전용이다 — "풀이 안에서 다른 항목을 참조하지 마라".
  /// **일반 문장에는 넘기지 않는다.** `계좌이체 내역` 은 어려운 말이 아니고,
  /// 자동 수집에는 그걸 가릴 방법이 없다.
  ///
  /// [self] 는 자기 자신의 `label`. 동어반복은 설명이 아니고, 자기 항목의 안내문에서
  /// 자기 이름을 쓰는 것은 당연하다.
  static JargonHit? find(
    String text, {
    Iterable<String> labels = const [],
    String? self,
  }) {
    if (self != null && self.isNotEmpty && text.contains(self)) {
      return JargonHit(self, JargonKind.annotate);
    }

    for (final label in labels) {
      if (label.isEmpty) continue;
      if (text.contains(label)) return JargonHit(label, JargonKind.annotate);
    }

    for (final term in allTerms) {
      if (KeywordMatch.occurs(text, term.word, exceptPatterns: term.except)) {
        return JargonHit(term.word, term.kind);
      }
    }
    return null;
  }

  /// 걸리는 것을 **전부** 찾는다. 목록을 뽑을 때 쓴다.
  static List<JargonHit> findAll(String text, {String? self}) {
    final hits = <JargonHit>[];
    for (final term in allTerms) {
      if (self != null && self.contains(term.word)) continue;
      if (KeywordMatch.occurs(text, term.word, exceptPatterns: term.except)) {
        hits.add(JargonHit(term.word, term.kind));
      }
    }
    return hits;
  }
}
