import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

import '../format/formatters.dart';
import '../interview/interview_session.dart';

/// **정리해서 가져가는 글 한 장.**
///
/// ## 이 글의 성격
///
/// ★ **우리가 보내는 게 아니라, 사람이 넘겨 주는 것이다.** 만드는 것은 글
/// 한 장이고 그다음은 사람의 손이다. 카카오톡에 붙이든 창구에 내밀든
/// 전화하며 읽든 **우리는 거기 없다.**
///
/// ```
/// ⭕ 「나를 위한 정리」            ❌ 「상대에게 보내는 문서」
/// ⭕ 이런 상황 · 이런 절차 · 근거   ❌ 「나는 ~을 요구한다」
/// ❌ 받는 사람 칸 · 상대방 이름
/// ❌ 신청서·내용증명 모양          그 순간 서류 대행이 된다
/// ```
///
/// 받는 사람 칸이 없는 것과 만든 날짜를 크게 다는 것이 같은 이유에서 나온다 —
/// **화면은 열 때마다 최신이지만 보내진 글은 박제된다.**
///
/// ## 받아 읽는 사람이 다르다
///
/// ★★ **화면은 사용자에게 말을 걸고, 이 글은 창구 직원이 읽는다.** 그래서
/// 되받는 말(「~군요」)을 글에서 전부 뺐다 — 화면에서 한 번은 보듬는 말이지만
/// 종이에 다섯 줄 찍히면 고개를 다섯 번 끄덕이는 것으로 읽힌다. 1절은 말을
/// 걸지 않고 **물음과 답을 적어 둔 것**이다(DECISIONS 290번).
///
/// ## 두 벌로 낸다
///
/// ```
/// 짧은 것   조문은 이름만            기본. 카카오톡·전화·창구용   상한 1,600자
/// 긴 것     조문 이름 아래 원문      사람이 고르면              상한 없음
/// ```
///
/// 쓰는 자리마다 필요한 것이 다르다. 지인에게 넘길 때 조문 원문은 안 읽히고
/// 오히려 방해다 — 전문을 다 실으면 양육비에서 글의 3분의 2가 조문이 된다.
/// **상담 창구에는 조문 이름이면 닿는다.** 원문은 앱에 그대로 있다.
///
/// ★★ **근거에서 이름을 빼지 않는다. 자르지 않는다.** 줄이는 것은 원문이고,
/// 이름 목록은 늘 통째로 실린다.
///
/// ★ **상한은 내용으로 못 올린다.** 화면 밀도와 같은 규칙이다(134번) —
/// 분야가 늘어 넘치면 절을 줄이는 것이 아니라 **그 분야의 문장을 다듬는다.**
/// 다만 「달라질 수 있는 것」은 길이가 분야마다 크게 달라서, 거기서만
/// **앞에서부터 담다가 넘치면 멈추고 몇 가지를 못 실었는지 말한다.**
/// 자른 것을 사람이 모르는 것이 제일 나쁘다.
///
/// ## 무엇이 들어가는가
///
/// **그 사람의 답으로 실제로 뜬 것 전부.** 접혔든 펼쳐졌든 상관없다 —
/// 자리가 모자라서 접은 것이지 안 보여 주려고 접은 것이 아니다(134·246번).
/// 안 뜬 것은 안 들어간다. **화면이 이미 고른 것을 그대로 쓴다.**
///
/// ★ **3층 표시가 글에도 그대로 간다.** 글은 검은 글자라 색이 사라지므로
/// **한글 라벨이 층을 나른다** — 화면에서도 색 단독으로 쓰지 않고 늘 라벨을
/// 함께 다는 그 원칙이 여기서 그대로 작동한다.
///
/// ## 근거는 「이 글이 말한 것」의 근거다
///
/// ★★ 「달라질 수 있는 것」은 예전에 **근거만 올라가고 문장은 한 줄도 안
/// 실렸다.** 305개 인용 가운데 227개가 그런 자리였다 — 글이 말하지 않은 것의
/// 근거가 글 끝에 서 있었다. 그러면 읽는 사람이 조문과 글을 맞대 볼 수 없다.
/// (am)이 「이 카드는 무엇 위에 서 있는가」를 보는 것의 거울상이다.
///
/// 규칙은 하나다 — **글이 그 말을 안 했으면 그 조문은 글의 근거가 아니다.**
///
/// ```
/// 그 사람의 답 때문에 뜬 것(showIf 가 있다)   물음과 답을 싣는다. 근거도 싣는다
/// 늘 뜨는 것(showIf 가 없다)                 물음만 〔가서 물어보실 것〕으로
///                                            보내고 **근거에서 뺀다**
/// ```
///
/// 앱에서는 아무것도 안 사라진다. 종이에서만 빠진다(DECISIONS 290번).
///
/// ## 「(없음)」은 안 쓴다
///
/// 한 낱말에 셋이 섞인다 — 조문에 원래 없는 것, 우리가 아직 못 한 것,
/// 우리가 못 세는 것. [Domain.emptySections] 가 그것을 가른다.
class TakeAwaySheet {
  const TakeAwaySheet({required this.short, required this.full});

  /// 기본. 조문은 이름만 실린다.
  final String short;

  /// 「조문까지 붙이기」를 켠 것. 같은 글에 원문이 붙는다.
  final String full;

  /// 짧은 것의 상한. **내용으로 못 올린다.**
  static const int shortLimit = 1600;

  String get all => full;

  /// 사람이 고르는 자리에 나가는 한 줄.
  static const String askBasis = '법에 적힌 원문도 같이 넣으시겠어요?';

  /// 절이 비었는데 왜 비었는지 데이터에 없을 때. **안전한 쪽이 기본이다.**
  static const String notYet = '저희가 아직 정리하지 못했어요.';

  /// 〔법에 적힌 것〕 머리의 한 줄.
  ///
  /// **이 글에 적은 것의 근거만 있다는 말을 글 안에서 한다.** 앱에는 더
  /// 있는데, 이 줄이 없으면 빠진 것이 없는 줄로 읽힌다.
  static const String basisNote = '이 종이에 적은 것의 근거예요. 앱에는 더 있어요.';

  /// 상한에 걸려 못 실은 「달라질 수 있는 것」이 있을 때.
  ///
  /// **자른 것을 말한다.** 어느 것을 싣고 어느 것을 접을지 순서를 정하지
  /// 않는다 — 급한 것을 우리가 고르기 시작하면 그게 판단이다(242·283번).
  /// 데이터 차례 그대로 앞에서부터 담다가 거기서 멈춘다.
  static String moreCautions(int count) =>
      '걸릴 수 있는 것이 $count가지 더 있어요. 앱에서 보실 수 있어요.';

  /// 꼬리말. **글의 맨 끝이다.**
  ///
  /// 긴 조문 더미 앞에 있으면 안 읽힌다. 마지막 한마디는 마지막에 있어야 한다.
  static const String tail = '법률 자문이 아니에요. 법에 적힌 것을 옮겨 드린 거예요.';

  /// **분야에는 있는데 이 답으로 안 뜬 절.**
  ///
  /// [Domain.emptySections] 와 **층이 다르다.** 그쪽은 분야에 적는 정적인
  /// 사실이고 이것은 **그 사람의 답에 따라 달라지는 것**이다. 떼인 돈에는
  /// 기한이 셋 있는데 갚는 쪽으로 답하면 하나도 안 뜬다 — 거기서
  /// 「저희가 아직 정리하지 못했어요」가 나가면 **거짓이다.**
  ///
  /// **「답을 다시 보세요」류를 쓰지 않는다.** 글에는 돌아갈 화면이 없다.
  /// **조사를 이어 붙이지 않는다.** 절마다 문장을 통째로 둔다 — 「기한이」와
  /// 「절차가」는 조사가 다르고, 코드가 그것을 고르기 시작하면 한국어를
  /// 코드가 짓게 된다.
  static const Map<String, String> _notApplicable = {
    '기한': '고르신 내용으로는 해당하는 기한이 없어요.',
    '절차': '고르신 내용으로는 해당하는 절차가 없어요.',
    '서류': '고르신 내용으로는 따로 챙기실 서류가 없어요.',
    '비용': '고르신 내용으로는 계산해 드릴 비용이 없어요.',
    '창구': '고르신 내용으로는 안내해 드릴 창구가 없어요.',
  };

  static String notApplicable(String what) => _notApplicable[what]!;

  /// **빈 절을 글에서 빼고 그 자리를 대신하는 물음.**
  ///
  /// 창구에 들고 가는 종이에 「아직 정리하지 못했어요」가 두 칸 연달아 있으면
  /// 종이가 덜 된 것으로 보인다. 그리고 그 아래 〔가서 물어보실 것〕에 같은
  /// 말이 또 적히는 자리가 있었다.
  ///
  /// ★ **화면에서는 그대로 둔다**(268번). 화면에는 왜 비었는지가 적혀 있어야
  /// 하고, 그 문장이 우리가 어디까지 했는지를 말한다. **글에서만 물음으로
  /// 바꾼다** — 받아 읽는 사람이 다르다.
  ///
  /// 「아직 정리하지 못했어요」가 나오는 절은 지금 이 둘뿐이다(25갈래에서
  /// 25곳, 전부 서류·비용). 기한의 「며칠부터 세는지를 저희가 모르기
  /// 때문이에요」처럼 **못 세는 까닭이 적힌 절은 그대로 싣는다** — 그건 덜 된
  /// 것이 아니라 조문이 그렇게 생긴 것이다(243·248·250번).
  static const Map<String, String> notYetAsk = {
    'documents': '낼 때 무슨 서류를 챙겨야 하나요?',
    'costs': '돈이 드나요?',
  };

  /// 글의 절 순서. **「위」·「아래」가 맞는지는 이 순서로만 정해진다.**
  ///
  /// 순서를 바꾸면 데이터에 적힌 「아래 창구」 같은 말이 통째로 어긋난다 —
  /// 검사 (af)가 이 상수를 보고 판정한다(DECISIONS 251번).
  ///
  /// ★ **이름은 2026-09-09 에 바꿨고 순서는 안 바꿨다.** 순서를 그대로 두면
  /// 데이터에 적힌 「아래 창구」가 그대로 맞는다(DECISIONS 268번).
  ///
  /// ★★ **2026-10-13 에 셋을 건드렸다**(DECISIONS 290번).
  ///
  /// ```
  /// 말씀해 주신 것 → 제가 말씀드린 것   창구에 내미는 사람이 한 말이다
  /// 달라질 수 있는 것                   화면과 같은 이름. 창구 두 절보다 위
  /// 물어볼 곳                           1350·132 는 가는 곳이 아니다
  /// ```
  ///
  /// 「달라질 수 있는 것」을 창구 두 절보다 **위**에 둔 것은 데이터에 적힌
  /// 「아래 창구에서 확인해 주세요」가 글에서도 참이어야 하기 때문이다.
  static const List<String> sectionOrder = [
    '제가 말씀드린 것',
    '언제까지 하셔야 하는지',
    '먼저 하실 일',
    '달라질 수 있는 것',
    '어디로 가시면 되는지',
    '물어볼 곳',
    '챙기실 것',
    '드는 돈',
    '가서 물어보실 것',
    '법에 적힌 것',
    '꼬리말',
  ];

  /// 절 이름을 감싸는 것. **번호를 안 붙인다.**
  ///
  /// 「1. 내 상황」은 민원 서식처럼 읽힌다. 번호는 우리가 절을 세려고 붙인
  /// 것이지 읽는 사람에게 필요한 것이 아니었다.
  ///
  /// ★ **마크다운 기호를 안 쓴다.** 카카오톡은 마크다운을 읽지 않아서
  /// `#` 과 `- ` 가 글자 그대로 화면에 남는다. 우리가 만든 것은 문서가
  /// 아니라 **사람이 넘겨 주는 글 한 장**이다(DECISIONS 268번).
  static String heading(String name) => '〔$name〕';
}

/// 글을 만든다. **화면이 아니라 데이터에서 만든다.**
///
/// 여기서 금액·날짜를 다시 계산하지 않는다. 결과는 이미 엔진이 냈고 이
/// 함수는 옮겨 적기만 한다.
TakeAwaySheet buildTakeAwaySheet({
  required Domain domain,
  required InterviewSession session,
  required List<DeadlineResult> deadlines,
  required List<Procedure> procedures,
  required List<DocumentResult> documents,
  required List<ScenarioCostResult> costs,
  required JurisdictionGuide? guide,
  required List<JurisdictionResult> places,
  required List<Caution> cautions,
  required List<PublicChannel> channels,
  required KstDate today,
}) {
  /// 빈 절의 한 줄. **세 갈래를 가른다.**
  ///
  /// ```
  /// 분야에 아예 없다        emptySections 의 why (없으면 안전한 쪽)
  /// 분야에는 있는데 안 떴다  「고르신 내용으로는 …이 없어요」
  /// 조문에 원래 없다        절을 제목째 뺀다
  /// ```
  ///
  /// 둘째를 첫째로 내면 **거짓이 된다** — 우리가 못 한 것이 아니라 그 사람에게
  /// 해당이 없는 것이다. `notYet` 이 참이면 그것이 「우리 쪽 사정」이라는
  /// 뜻이고, 글에서는 그 절을 빼고 물음으로 바꿀 수 있다.
  ({String text, bool notYet})? blank(
    String section, {
    required bool inDomain,
    required String what,
  }) {
    if (inDomain) {
      return (text: TakeAwaySheet.notApplicable(what), notYet: false);
    }
    final row = domain.emptySections[section];
    if (row?.kind == EmptySectionKind.none) return null;
    return (text: row?.why ?? TakeAwaySheet.notYet, notYet: true);
  }

  // **그 사람의 답 때문에 뜬 것과 늘 뜨는 것을 가른다.** `showIf` 가 있으면
  // 그 사람의 답(또는 그 답으로 센 기한)을 보고 통과한 것이다 —
  // `cautionsProvider` 가 이미 걸러서 넘겨 준다.
  final answered = <Caution>[for (final c in cautions) if (c.showIf != null) c];
  final always = <Caution>[for (final c in cautions) if (c.showIf == null) c];

  // **기한을 센 가정은 기한 바로 옆에 있어야 한다.** 종이만 들고 간 사람은
  // 뒤쪽 물음까지 안 읽는다. 어느 것이 그 기한의 이야기인지는 **같은 조문에
  // 서 있는가**로 가른다 — 코드가 짝을 지어내지 않는다. 부당해고의
  // 「들은 날과 마지막 근무일이 다르면요?」가 기한과 같은 제28조 제2항이다.
  final nextToDeadline = <String, List<Caution>>{};
  final loose = <Caution>[];
  final deadlineCitations = <String>{
    for (final line in deadlines)
      if (line.basis.citation case final String citation) citation,
  };
  for (final caution in answered) {
    final citation = caution.legalBasis?.citation;
    if (citation != null && deadlineCitations.contains(citation)) {
      (nextToDeadline[citation] ??= <Caution>[]).add(caution);
    } else {
      loose.add(caution);
    }
  }

  /// 「달라질 수 있는 것」 가운데 [keep] 가지만 싣는다. [withText] 면 조문
  /// 원문이 근거 절에 붙는다.
  String compose({required int keep, required bool withText}) {
    final b = StringBuffer();
    final shown = loose.take(keep).toList();
    final printedCautions = <Caution>[
      for (final list in nextToDeadline.values) ...list,
      ...shown,
    ];

    b.writeln(domain.name);
    b.writeln('${formatKstDate(today)}에 정리했어요');
    b.writeln();

    // **말을 걸지 않는다.** 되받는 말은 화면이 하고, 여기는 적어 둔 것이다.
    b.writeln(TakeAwaySheet.heading('제가 말씀드린 것'));
    for (final step in session.steps) {
      final question = domain.questionById(step.questionId);
      if (question == null) continue;
      // **짧은 칸 이름을 지어내지 않는다.** 데이터에는 물음 전문과 되받는 말
      // 둘뿐이고 「들은 날」 같은 칸은 없다. 없는 것을 코드가 만들면 그 순간
      // 우리가 사실을 지은 것이 된다. 짧은 칸 이름은 데이터에 칸을 만들 때
      // 하는 일이다.
      b.writeln('  ${question.text} — ${formatAnswer(question, step.value)}');
    }
    b.writeln();

    final noDeadline = deadlines.isEmpty
        ? blank('deadlines', inDomain: domain.deadlines.isNotEmpty, what: '기한')
        : null;
    if (deadlines.isNotEmpty || noDeadline != null) {
      b.writeln(TakeAwaySheet.heading('언제까지 하셔야 하는지'));
      if (noDeadline != null) {
        b.writeln('  ${noDeadline.text}');
      } else {
        final said = <String>{};
        for (final line in deadlines) {
          b.writeln('  ${line.label} · ${formatKstDate(line.dueDate)}까지'
              ' · ${formatDDay(line)}');
          final citation = line.basis.citation;
          for (final caution in nextToDeadline[citation] ?? const <Caution>[]) {
            if (!said.add(caution.id)) continue;
            b.writeln('    ${caution.question} — ${caution.consequence}');
          }
          // **조문 이름은 덩이 끝에 한 번만.** 문장 끝마다 「법에 적혀
          // 있어요」를 붙이는 대신 칸에 이름을 적는다(DECISIONS 290번).
          if (citation != null) b.writeln('    $citation');
        }
      }
      b.writeln();
    }

    // **절이 소리 없이 없어지지 않는다.** 사라지면 읽는 사람은 그런 절이
    // 있는 줄도 모른다.
    final noStep = procedures.isEmpty
        ? blank('procedures',
            inDomain: domain.procedures.isNotEmpty, what: '절차')
        : null;
    if (procedures.isNotEmpty || noStep != null) {
      b.writeln(TakeAwaySheet.heading('먼저 하실 일'));
      if (noStep != null) {
        b.writeln('  ${noStep.text}');
      } else {
        final first = procedures.first;

        // **같은 사실을 세 번 말하지 않는다.** 「공단에 요양급여 신청서 내기 —
        // 근로복지공단에 요양급여를 신청하는 것이에요」 아래에 곧바로 「어디로:
        // 근로복지공단 / 무엇을: 요양급여 신청서」가 붙으면 기관 이름이 두 번,
        // 서식 이름이 두 번이다. 되풀이가 글을 서식처럼 만든다.
        //
        // ★ **지우는 쪽은 설명이지 창구 말이 아니다.** `sayThis` 는 창구에서
        // 그대로 말해야 하는 낱말이라 한 글자도 못 바꾼다(`kPlainTargets` 밖).
        // 그래서 겹칠 때 접는 것은 `whatIsThis` 다.
        //
        // 좁게 건다 — 지금 `sayThis` 가 있는 절차 11개 중 걸리는 것은
        // `work_injury.proc_care_claim` 하나다. 데이터를 안 고치고 글이 고른다.
        final say = first.sayThis;
        final repeats = say != null &&
            (first.whatIsThis.contains(say.agency) ||
                (say.form != null && first.whatIsThis.contains(say.form!)));
        b.writeln(repeats
            ? '  ${first.label}'
            : '  ${first.label} — ${first.whatIsThis}');
        if ((first.detail ?? '').isNotEmpty) b.writeln('    ${first.detail}');
        if (say != null) {
          b.writeln('    어디로: ${say.agency}');
          if (say.form case final String form) b.writeln('    무엇을: $form');
        }
        if (first.legalBasis?.citation case final String citation) {
          b.writeln('    $citation');
        }
      }
      b.writeln();
    }

    final over = loose.length - shown.length;
    if (shown.isNotEmpty || over > 0) {
      b.writeln(TakeAwaySheet.heading('달라질 수 있는 것'));
      for (final caution in shown) {
        b.writeln('  ${caution.question} — ${caution.consequence}');
      }
      if (over > 0) b.writeln('  ${TakeAwaySheet.moreCautions(over)}');
      b.writeln();
    }

    final hasPlace = guide != null || places.isNotEmpty;
    final noPlace = hasPlace || channels.isNotEmpty
        ? null
        : blank('jurisdiction',
            inDomain: domain.jurisdiction.isNotEmpty, what: '창구');
    if (hasPlace || noPlace != null) {
      b.writeln(TakeAwaySheet.heading('어디로 가시면 되는지'));
      if (!hasPlace) {
        b.writeln('  ${noPlace!.text}');
      } else {
        // ★ **「달라진다」고 말해 놓고 바로 답을 내지 않는다.** 「어느
        // 지방노동위원회인지는 일하던 곳에 따라 달라져요」 다음 줄에
        // 「서울지방노동위원회」가 오면 앞줄이 뒷줄을 지운다. 관할이 정해진
        // 사람에게는 그 줄을 뺀다 — 왜 서울인지는 1절의 「어디에서
        // 일하셨나요? — 서울특별시」가 이미 말한다(DECISIONS 290번).
        //
        // 안 정해진 사람에게는 그대로 남는다. 그게 참말이다.
        //
        // ★ **줄이 있는 것과 정해진 것은 다르다.** 답을 안 하셨으면 관할
        // 줄이 「주된 사업장이 있는 곳을 맡는 지방노동위원회」처럼 규칙으로
        // 나온다 — 그건 아직 안 정해진 것이라 설명이 그대로 있어야 한다.
        // 기관 이름이 나온 자리에서만 뺀다.
        final named = places.isNotEmpty && places.every((p) => p.court != null);
        if (guide != null && !named) b.writeln('  ${guide.lookupNote}');
        for (final place in places) {
          b.writeln('  ${place.label}: ${place.court ?? place.rule}');
        }
      }
      b.writeln();
    }

    // ★ **전화는 가는 곳이 아니다.** 1350·132 가 「어디로 가시면 되는지」에
    // 섞여 있으면 거기로 가라는 말로 읽힌다.
    if (channels.isNotEmpty) {
      b.writeln(TakeAwaySheet.heading('물어볼 곳'));
      for (final channel in channels) {
        b.writeln('  ${channel.org} ${channel.phone ?? ''}'.trimRight());
      }
      b.writeln();
    }

    final noDoc = documents.isEmpty
        ? blank('documents', inDomain: domain.documents.isNotEmpty, what: '서류')
        : null;
    final dropDoc = noDoc != null &&
        noDoc.notYet &&
        TakeAwaySheet.notYetAsk.containsKey('documents');
    if (documents.isNotEmpty || (noDoc != null && !dropDoc)) {
      b.writeln(TakeAwaySheet.heading('챙기실 것'));
      if (noDoc != null) {
        b.writeln('  ${noDoc.text}');
      } else {
        for (final document in documents) {
          b.writeln('  ${document.label} — ${document.whatIsThis}');
        }
      }
      b.writeln();
    }

    final noCost = costs.isEmpty
        ? blank('costs', inDomain: domain.costs.isNotEmpty, what: '비용')
        : null;
    final dropCost = noCost != null &&
        noCost.notYet &&
        TakeAwaySheet.notYetAsk.containsKey('costs');
    if (costs.isNotEmpty || (noCost != null && !dropCost)) {
      b.writeln(TakeAwaySheet.heading('드는 돈'));
      if (noCost != null) {
        b.writeln('  ${noCost.text}');
      } else {
        for (final scenario in costs) {
          // **갈래 이름만 쓰면 같은 줄이 두 번 나온다.** 화면에서는 나란히
          // 놓여 구분되지만 글에서는 「지급명령으로 하면: 89,000원」이 두 줄이
          // 되어 그냥 모순으로 보인다. 가르는 축(`option`)을 붙인다.
          final name = [scenario.label, scenario.option]
              .whereType<String>()
              .where((part) => part.isNotEmpty)
              .join(' · ');
          b.writeln('  ${name.isEmpty ? '드는 돈' : name}: '
              '${formatWon(scenario.result.guidedTotal)}');
        }
      }
      b.writeln();
    }

    // **우리 약점이 그대로 기능이 되는 자리다.** openPart 는 우리가 못 닫은
    // 것이고, 그건 곧 사람이 전화해서 물어야 할 것이다.
    //
    // ★ **위에 물음과 답을 실은 항목의 `askThis` 는 여기 안 온다.** 같은
    // 말이 두 번 실린다 — 「명령을 안 지키면 어떻게 되나요?」를 싣고 나서
    // 「이행강제금은 언제부터 얼마로 정해지나요?」가 또 오는 자리가 그것이다.
    final asks = <String>{};
    for (final caution in always) {
      // 늘 뜨는 것은 **물음만** 간다. 답을 실으면 그 조문 위에 서는 것이 되고,
      // 그 사람의 답과 상관없이 뜬 것이라 글이 그 말을 할 자리가 아니다.
      if (caution.question.isNotEmpty) asks.add(caution.question);
      final ask = caution.verification.askThis;
      if (ask != null) asks.add(ask);
    }
    for (final procedure in procedures) {
      final ask = procedure.verification.askThis;
      if (ask != null) asks.add(ask);
    }
    // 빈 절을 뺀 자리를 대신하는 물음. **이미 그 말을 하는 줄이 있으면 안
    // 넣는다** — 「구제신청을 내는 데 돈이 드나요?」가 있는 자리에
    // 「돈이 드나요?」를 또 넣으면 같은 말이 두 번이다.
    for (final section in [
      if (dropDoc) 'documents',
      if (dropCost) 'costs',
    ]) {
      final ask = TakeAwaySheet.notYetAsk[section]!;
      if (asks.any((line) => line.contains(ask))) continue;
      asks.add(ask);
    }
    if (asks.isNotEmpty) {
      b.writeln(TakeAwaySheet.heading('가서 물어보실 것'));
      for (final ask in asks) {
        b.writeln('  $ask');
      }
      b.writeln();
    }

    // **이 글이 말한 것의 근거만.** 법령별로 묶고 그 안에서 조문 번호 순으로
    // 한 번에 정한다 — 등장 순도 번호 순도 아닌 차례로 쌓여 있었다.
    final seen = <String>{};
    final order = <String>[];
    final byLaw = <String, List<LegalBasis>>{};
    void addBasis(LegalBasis? base) {
      if (base == null) return;
      final citation = base.citation;
      if (citation == null || !seen.add(citation)) return;
      final law = base.law ?? '';
      if (!byLaw.containsKey(law)) {
        byLaw[law] = <LegalBasis>[];
        order.add(law);
      }
      byLaw[law]!.add(base);
    }

    for (final line in deadlines) {
      addBasis(line.basis);
      line.alsoBasis.forEach(addBasis);
    }
    // **글에 실린 절차 하나의 근거다.** 뜬 절차가 여섯이어도 글은 첫째만
    // 말한다 — 안 말한 다섯의 조문을 근거로 세우면 그만큼이 거짓이다.
    if (procedures.isNotEmpty) {
      addBasis(procedures.first.legalBasis);
      procedures.first.alsoBasis.forEach(addBasis);
    }
    for (final caution in printedCautions) {
      addBasis(caution.legalBasis);
      caution.alsoBasis.forEach(addBasis);
    }

    if (order.isNotEmpty) {
      b.writeln(TakeAwaySheet.heading('법에 적힌 것'));
      b.writeln('  ${TakeAwaySheet.basisNote}');
      for (final law in order) {
        final list = byLaw[law]!..sort(_byArticle);
        for (final base in list) {
          b.writeln('  ${base.citation}');
          if (withText) {
            if (base.text case final String text) b.writeln('    $text');
          }
        }
      }
      b.writeln();
    }

    // **꼬리말에는 이름표를 안 단다.** 여기는 절이 아니라 마지막 한마디다.
    // 날짜는 머리글에서 한 번 말했다 — 두 번 말하지 않는다.
    b.write(TakeAwaySheet.tail);
    return b.toString();
  }

  // 앞에서부터 담다가 넘치면 거기서 멈춘다. **기한 옆에 붙는 것은 안
  // 줄인다** — 그 기한을 어떻게 셌는지는 그 기한과 한 덩이다.
  var keep = loose.length;
  var short = compose(keep: keep, withText: false);
  while (keep > 0 && short.length > TakeAwaySheet.shortLimit) {
    keep--;
    short = compose(keep: keep, withText: false);
  }
  return TakeAwaySheet(
    short: short,
    full: compose(keep: keep, withText: true),
  );
}

/// 조문 번호 순. `제28조 제2항` · `제7조의2` · `[별표 1]`.
///
/// **번호가 없는 것은 뒤로 보낸다.** 별표·부칙이 그렇다 — 조문 사이에 끼면
/// 번호 순이 깨진 것처럼 보인다.
int _byArticle(LegalBasis a, LegalBasis b) {
  (int, int, int) key(LegalBasis base) {
    final article = base.article ?? '';
    final jo = RegExp(r'제(\d+)조(?:의(\d+))?').firstMatch(article);
    if (jo == null) return (1 << 30, 0, 0);
    final hang = RegExp(r'제(\d+)항').firstMatch(article);
    return (
      int.parse(jo.group(1)!),
      int.parse(jo.group(2) ?? '0'),
      hang == null ? 0 : int.parse(hang.group(1)!),
    );
  }

  final first = key(a);
  final second = key(b);
  if (first.$1 != second.$1) return first.$1.compareTo(second.$1);
  if (first.$2 != second.$2) return first.$2.compareTo(second.$2);
  if (first.$3 != second.$3) return first.$3.compareTo(second.$3);
  return (a.article ?? '').compareTo(b.article ?? '');
}
