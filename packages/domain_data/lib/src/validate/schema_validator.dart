import '../common/json_map.dart';
import '../common/kst_date.dart';
import '../model/cost_formula.dart';
import '../model/domain.dart';
import '../model/enums.dart';
import '../model/plain_korean.dart';
import '../model/question.dart';
import 'schema_issue.dart';

/// 도메인 JSON 구조 검증기.
///
/// **문구(SafetyFilter) 검증은 여기서 하지 않는다.** engines 의 `ContentValidator` 담당.
/// 이 클래스는 순수 Dart 이고 어떤 분야도 알지 못한다.
/// 분야마다 있어야 하는 **찾는 말**의 최소 개수.
///
/// 셋이면 홈에 그대로 다 내놓을 수 있는 수이기도 하다.
// not-a-legal-number: 낱말 개수. 법률 수치가 아니다.
const int _minSearchTerms = 3;

class SchemaValidator {
  const SchemaValidator();

  /// `verification` 이 반드시 있어야 하는 리스트.
  static const List<String> verificationRequiredLists = [
    'deadlines',
    'documents',
    'costs',
    'jurisdiction',
    'procedures',
    'resources',
    'brokerAlerts',
    'brokerChecklists',
    'lookupTools',
    'limitRules',
  ];

  /// SafetyFilter 의 `quote` scope(인용 문구 면제)를 받는 리스트.
  ///
  /// 면제는 **사람이 검수한 데이터에만** 주어진다. `verification` 없이는 쓸 수 없다.
  static const List<String> quoteScopeLists = [
    'brokerAlerts',
    'brokerChecklists',
    'limitRules',
  ];

  /// 도메인 데이터가 오래되면 경고하는 기준.
  static const int staleAfterDays = 180;

  /// 결과 화면에 나오는 항목 = 일상어 풀이가 필요한 항목.
  ///
  /// 인지대·송달료·지급명령·관할을 아는 사람은 이 앱이 필요 없다.
  /// `Question` 에 `whyAsk` 가 있듯 여기에는 `whatIsThis` 가 있어야 한다.
  static const List<String> plainLanguageLists = [
    'costs',
    'documents',
    'deadlines',
    'jurisdiction',
    'procedures',
  ];

  /// 한 줄 풀이의 길이 상한 (공백 포함).
  ///
  /// **40자 안에 설명이 안 되면 아직 설명이 안 된 것이다.**
  static const int whatIsThisMaxLength = 40;

  /// 법률 수치로 볼 만한 표현.
  ///
  /// 금액(`3,000만원`) · 기간(`30일`, `3개월`) · 조문(`제1조의2`) · 비율(`20%`).
  /// 질문 문구에 이런 게 들어 있으면 제도가 바뀔 때 같이 바뀌므로 검수 대상이다.
  static final RegExp legalNumberPattern = RegExp(
    r'\d[\d,]*\s*(억원|억|천만원|만원|천원|원|퍼센트|%)'
    r'|\d[\d,]*\s*(개월|일|년|주)'
    r'|제\s?\d+\s?(조|항|호)',
  );

  /// 문구에서 처음 발견한 법률 수치. 없으면 null.
  static String? findLegalNumber(String text) =>
      legalNumberPattern.firstMatch(text)?.group(0)?.trim();

  /// 파싱 **전** 원본 JSON 검사. 필수 필드 누락을 알아볼 수 있는 메시지로 바꾼다.
  List<SchemaIssue> validateRaw(JsonMap json) {
    final issues = <SchemaIssue>[];
    final domainId = json['id'] as String? ?? '(id 없음)';

    if (json['id'] is! String || (json['id'] as String).isEmpty) {
      issues.add(const SchemaIssue(path: 'id', message: '도메인 id 가 없습니다'));
    }
    if (json['name'] is! String || (json['name'] as String).isEmpty) {
      issues.add(SchemaIssue(path: '$domainId.name', message: '도메인 이름이 없습니다'));
    }

    for (final listName in verificationRequiredLists) {
      final items = _itemsOf(json, listName);
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final path = '$domainId.$listName[$i]';
        final itemId = item['id'] as String?;
        if (itemId == null || itemId.isEmpty) {
          issues.add(SchemaIssue(path: path, message: 'id 가 없습니다'));
        }
        if (item['verification'] is! Map) {
          issues.add(
            SchemaIssue(
              path: '${itemId == null ? path : '$domainId.$listName.$itemId'}'
                  '.verification',
              message: quoteScopeLists.contains(listName)
                  ? 'verification 이 없습니다. 인용 문구(quote scope) 면제는 '
                      '사람이 검수한 데이터에만 주어집니다'
                  : 'verification 은 모든 데이터 항목의 필수 필드입니다',
            ),
          );
        }
      }
    }

    // publicChannels 는 문자열 참조 또는 전체 객체. 객체라면 verification 필수.
    final channels = json['publicChannels'];
    if (channels is List) {
      for (var i = 0; i < channels.length; i++) {
        final entry = channels[i];
        if (entry is Map && entry['verification'] is! Map) {
          issues.add(
            SchemaIssue(
              path: '$domainId.publicChannels[$i].verification',
              message: 'verification 은 모든 데이터 항목의 필수 필드입니다',
            ),
          );
        }
      }
    }

    // 「달라질 수 있는 것」은 물음 버튼으로 나간다. 물음이 없으면 그릴 수 없다.
    // condition 을 대신 넣으면 조건절이 버튼에 들어가고, 화면이 어미를 붙이는
    // 옛 버그가 그 자리에서 되살아난다.
    for (final (index, caution) in _itemsOf(json, 'cautions').indexed) {
      final id = caution['id'] as String? ?? '[$index]';
      final ask = caution['question'];
      if (ask is! String || ask.trim().isEmpty) {
        issues.add(
          SchemaIssue(
            path: '$domainId.cautions.$id.question',
            message: 'question 이 비어 있습니다. '
                '물음으로 바꿔 낼 수 없는 안내는 화면에 낼 자리가 없습니다',
          ),
        );
      }

      // 갈래를 줄로 낼 때 **구분과 값이 둘 다 있어야 한다.** 하나가 비면
      // 「어느 칸인지 모르는 금액」이거나 「값이 없는 칸」이 화면에 나간다.
      final variants = caution['variants'];
      if (variants is List) {
        for (final (at, variant) in variants.indexed) {
          if (variant is! Map) continue;
          for (final field in const ['key', 'label', 'detail']) {
            final value = variant[field];
            if (value is String && value.trim().isNotEmpty) continue;
            issues.add(
              SchemaIssue(
                path: '$domainId.cautions.$id.variants[$at].$field',
                message: '$field 이 비어 있습니다. 구분(label)은 조문 원문이고 '
                    'detail 은 그 칸의 값입니다. 둘 다 있어야 표가 됩니다',
              ),
            );
          }
        }
      }
    }

    // ── 쉬운 말 한 벌 ────────────────────────────────────────────────
    //
    // **키가 가리키는 자리가 실제로 있어야 한다.** 오타 하나면 그 문장만
    // 조용히 안 바뀌고, 쉬운 말 모드가 반쯤 켜진 화면이 나간다.
    // 그리고 **바꿀 수 없는 자리**(조문 원문·기관 이름·서식 이름)는 여기서
    // 막는다 — `kPlainTargets` 에 적힌 자리만 연다.
    final plain = json['plain'];
    if (plain is Map) {
      for (final entry in plain.entries) {
        final key = '${entry.key}';
        final path = '$domainId.plain.$key';
        final value = entry.value;

        if (value is! String || value.trim().isEmpty) {
          issues.add(SchemaIssue(
            path: path,
            message: '쉬운 문장이 비어 있습니다. 쉬운 말이 없으면 '
                '빈 문장을 넣지 말고 이 줄을 지웁니다 — 없으면 원래 문장이 '
                '그대로 나갑니다',
          ));
          continue;
        }

        final parts = key.split('.');
        final section = parts.length == 1 ? '' : parts.first;
        final field = parts.last;
        final allowed = kPlainTargets[section];
        if (allowed == null ||
            !allowed.contains(field) ||
            (section.isEmpty ? parts.length != 1 : parts.length != 3)) {
          issues.add(SchemaIssue(
            path: path,
            message: '쉬운 말로 바꿀 수 없는 자리입니다. 조문 원문과 '
                '기관·서식 이름은 그대로 두어야 합니다. 열려 있는 자리: '
                '${_plainTargetNames.join(' · ')}',
          ));
          continue;
        }

        final String? original;
        if (section.isEmpty) {
          original = json[field] as String?;
        } else {
          final item = _itemsOf(json, section)
              .where((it) => it['id'] == parts[1])
              .firstOrNull;
          if (item == null) {
            issues.add(SchemaIssue(
              path: path,
              message: '${parts[1]} 이라는 항목이 $section 에 없습니다',
            ));
            continue;
          }
          original = item[field] as String?;
        }

        if (original == null || original.trim().isEmpty) {
          issues.add(SchemaIssue(
            path: path,
            message: '대신할 원래 문장이 비어 있습니다. 없는 문장을 '
                '쉬운 말로 새로 짓지 않습니다',
          ));
        } else if (original.trim() == value.trim()) {
          issues.add(SchemaIssue(
            path: path,
            message: '원래 문장과 똑같습니다. 같으면 이 줄을 지웁니다',
          ));
        }
      }
    }

    // ── 40자 규칙을 놓아 주는 자리 ──────────────────────────────────
    //
    // ★ **놓아 주는 것을 데이터에 적게 한다.** 검사를 느슨하게 하면 모든
    // 분야에서 느슨해지고, 그때부터 40자는 아무것도 안 막는다. 그 자리
    // 하나만, 이유를 적고 놓아 준다.
    //
    // 이유를 요구하는 까닭은 `expectsEveryDomain` 의 `skipped` 와 같다 —
    // **일부러 놓아 준 것과 그냥 긴 것이 데이터에서 똑같이 생겼기 때문이다.**
    final longOk = json['plainLongOk'];
    if (longOk is Map) {
      final plainKeys = plain is Map
          ? {for (final k in plain.keys) '$k'}
          : const <String>{};
      for (final entry in longOk.entries) {
        final key = '${entry.key}';
        final path = '$domainId.plainLongOk.$key';
        final reason = entry.value;

        if (reason is! String || reason.trim().isEmpty) {
          issues.add(SchemaIssue(
            path: path,
            message: '왜 40자 규칙을 놓아 주는지 적어 주세요. 이유가 없으면 '
                '일부러 놓아 준 것과 그냥 긴 것이 구별되지 않습니다',
          ));
          continue;
        }
        if (!plainKeys.contains(key)) {
          issues.add(SchemaIssue(
            path: path,
            message: 'plain 에 없는 자리입니다. 쉬운 문장이 없는 자리에는 '
                '놓아 줄 규칙도 없습니다',
          ));
        }
      }
    }

    // ── 카드는 근거 없이 못 선다 ────────────────────────────────────
    //
    // **조문(`legalBasis`·`alsoBasis`)이나 기관 안내(`notice`) 가운데 하나는
    // 있어야 한다.** 셋 다 없으면 남는 것은 근거 없는 단정이다 —
    // `LegalBasisCard` 가 `legalBasis` 없이 못 만들어지는 것과 같은 자리다.
    //
    // ★ **다만 셋이 다 필요 없는 카드가 실제로 있다.** 「법원 서류를 받았는데
    // 어떻게 하나요?」처럼 **창구로 보내기만 하는 카드**는 법에 대해 아무 주장도
    // 안 한다. 그런 카드는 `noBasis` 에 왜 그런지를 적는다.
    //
    // ★★ **적어 놓고 법 이야기를 하면 실패한다.** 이유를 지어내서 통과시키는
    // 길을 막는다(DECISIONS 272·274번).
    for (final (index, caution) in _itemsOf(json, 'cautions').indexed) {
      final id = caution['id'] as String? ?? '[$index]';
      final path = '$domainId.cautions.$id';
      final hasBasis = caution['legalBasis'] != null ||
          ((caution['alsoBasis'] as List<dynamic>?) ?? const []).isNotEmpty ||
          caution['notice'] != null;
      final noBasis = caution['noBasis'];

      if (!hasBasis && noBasis == null) {
        issues.add(SchemaIssue(
          path: path,
          message: '조문도 기관 안내도 없습니다. legalBasis · alsoBasis · notice '
              '가운데 하나를 달거나, 법에 대해 아무 말도 안 하는 카드라면 '
              'noBasis 에 왜 그런지 적으세요',
        ));
        continue;
      }
      if (noBasis == null) continue;

      if (noBasis is! String || noBasis.trim().isEmpty) {
        issues.add(SchemaIssue(
          path: '$path.noBasis',
          message: '왜 근거 없이 서는지 적어 주세요. 이유가 없으면 일부러 비운 것과 '
              '빠뜨린 것이 구별되지 않습니다',
        ));
        continue;
      }
      if (hasBasis) {
        issues.add(SchemaIssue(
          path: '$path.noBasis',
          message: '근거가 있는데 noBasis 도 적혀 있습니다. 둘 중 하나만 둡니다',
        ));
      }
      final said = [
        caution['question'],
        caution['condition'],
        caution['consequence'],
        for (final v in plainLanguageOf(json, 'cautions', id)) v,
      ].whereType<String>().join(' ');
      final claim = _legalClaim.firstMatch(said);
      if (claim != null) {
        issues.add(SchemaIssue(
          path: '$path.noBasis',
          message: '법에 대해 아무 말도 안 한다고 적어 놓고 「${claim.group(0)}」 '
              '라고 말합니다. 법 이야기를 하면 근거가 있어야 합니다',
        ));
      }
    }

    // ── 이 길을 만드는 법 ────────────────────────────────────────────
    //
    // `legalBasis` 는 「카드의 문장이 기대는 조문」이고 `pathLaw` 는 「이 길을
    // 만드는 법」이다. 대개 같아서 `pathLaw` 는 **다를 때만** 적는다
    // (DECISIONS 281번). 여기서는 모양만 본다 — 비어 있는 것이 사람이 판정한
    // 「같다」인지는 `verify_domains` 가 `review/path_law.json` 과 맞대 본다.
    for (final (index, procedure) in _itemsOf(json, 'procedures').indexed) {
      final id = procedure['id'] as String? ?? '[$index]';
      final path = '$domainId.procedures.$id';
      final pathLaw = procedure['pathLaw'];
      final noPathLaw = procedure['noPathLaw'];

      if (pathLaw != null && noPathLaw != null) {
        issues.add(SchemaIssue(
          path: '$path.noPathLaw',
          message: '길을 만드는 법을 적었는데 noPathLaw 도 적혀 있습니다. '
              '둘 중 하나만 둡니다',
        ));
      }
      if (noPathLaw != null &&
          (noPathLaw is! String || noPathLaw.trim().isEmpty)) {
        issues.add(SchemaIssue(
          path: '$path.noPathLaw',
          message: '왜 이 길을 만드는 법이 없는지 적어 주세요. 이유가 안 써지면 '
              '법이 없는 게 아니라 인용을 안 한 것일 수 있습니다',
        ));
      }
      if (pathLaw is Map) {
        for (final field in const ['law', 'article', 'text']) {
          final value = pathLaw[field];
          if (value is! String || value.trim().isEmpty) {
            issues.add(SchemaIssue(
              path: '$path.pathLaw.$field',
              message: '길을 만드는 법은 조문 원문까지 적습니다 — 화면에는 법 '
                  '이름만 나가도 검사는 조와 글을 봅니다',
            ));
          }
        }
        // **같은 법이어도 조가 다르면 둔다.** 신용회복위원회 카드가 그렇다 —
        // 문장이 기대는 조문은 조정의 방법(제73조)이고 길을 세우는 조문은
        // 위원회의 일(제60조 제4호)이다. 화면엔 같은 이름이 나가도 검사는
        // 조를 본다(DECISIONS 282번). 법과 조가 둘 다 같을 때만 군더더기다.
        final basis = procedure['legalBasis'];
        if (basis is Map &&
            basis['law'] == pathLaw['law'] &&
            basis['article'] == pathLaw['article']) {
          issues.add(SchemaIssue(
            path: '$path.pathLaw',
            message: '「${pathLaw['law']} ${pathLaw['article']}」 — legalBasis 와 같은 '
                '조문입니다. 같으면 비우고 review/path_law.json 에 판정을 적습니다',
          ));
        }
      }
    }

    // ── 창구에서 그대로 보여 줄 이름 ────────────────────────────────
    //
    // ★ **지어낸 이름을 못 쓰게 한다.** 여기 적는 말은 그 절차가 이미 들고
    // 있는 글 안에 글자 그대로 있어야 한다. 창구에 내밀 화면이라 틀린 이름은
    // 사람을 엉뚱한 곳에 보낸다.
    for (final (index, procedure) in _itemsOf(json, 'procedures').indexed) {
      final id = procedure['id'] as String? ?? '[$index]';
      final say = procedure['sayThis'];
      if (say is! Map) continue;

      final own = StringBuffer();
      for (final field in const ['label', 'whatIsThis', 'detail']) {
        own.write(' ${procedure[field] ?? ''}');
      }
      for (final basis in [
        procedure['legalBasis'],
        ...?(procedure['alsoBasis'] as List?),
      ]) {
        if (basis is Map) own.write(' ${basis['text'] ?? ''}');
      }
      final haystack = own.toString();

      for (final field in const ['agency', 'form']) {
        final name = say[field];
        if (name == null && field == 'form') continue;
        if (name is! String || name.trim().isEmpty) {
          issues.add(SchemaIssue(
            path: '$domainId.procedures.$id.sayThis.$field',
            message: '이름이 비어 있습니다. 확인 안 된 이름은 '
                '지어 쓰지 말고 이 칸을 뺍니다 — 빼면 카드가 안 섭니다',
          ));
          continue;
        }
        if (!haystack.contains(name.trim())) {
          issues.add(SchemaIssue(
            path: '$domainId.procedures.$id.sayThis.$field',
            message: '「${name.trim()}」이 이 절차의 글 어디에도 없습니다. '
                '창구에 그대로 내미는 이름이라 지어 쓸 수 없습니다',
          ));
        }
      }
    }

    // **이름은 두 층이다.** 큰 글씨는 상황을 그리는 우리 말이고, 작은 글씨는
    // 사람이 실제로 찾을 때 치는 말이다. 작은 글씨가 없으면 그 분야는
    // **자기 이름으로만 찾히고**, 우리 이름은 아무도 안 치는 말이다
    // (DECISIONS 194번). 나중에 자유 입력 감지를 붙일 때 그대로 걸림말이 된다.
    final status = json['status'];
    final terms = json['searchTerms'];
    if (status != 'comingSoon' && !domainId.startsWith('_')) {
      if (terms is! List || terms.length < _minSearchTerms) {
        issues.add(
          SchemaIssue(
            path: '$domainId.searchTerms',
            message: '사람이 실제로 쓰는 낱말이 $_minSearchTerms개는 있어야 합니다. '
                '우리가 지은 이름만으로는 아무도 못 찾습니다',
          ),
        );
      } else {
        for (final (at, term) in terms.indexed) {
          if (term is String && term.trim().isNotEmpty) continue;
          issues.add(
            SchemaIssue(
              path: '$domainId.searchTerms[$at]',
              message: '빈 낱말이 있습니다',
            ),
          );
        }
      }
    }

    for (final (index, question) in _itemsOf(json, 'intake').indexed) {
      final id = question['id'] as String? ?? '[$index]';
      final whyAsk = question['whyAsk'];
      if (whyAsk is! String || whyAsk.trim().isEmpty) {
        issues.add(
          SchemaIssue(
            path: '$domainId.intake.$id.whyAsk',
            message: 'whyAsk 가 비어 있습니다. 왜 묻는지 설명하지 못하는 질문은 넣지 않습니다',
          ),
        );
      }

      // 날짜 질문은 범위를 밝혀야 한다. 변제기는 아직 안 왔을 수 있고 요구한 날은
      // 지난 날이다. **기본값을 두지 않는다** — 기본값이 있으면 새 날짜 질문이
      // 아무 제약 없이 조용히 들어오고, 그게 기한 계산에 쓰이면 아무도 모른다.
      // 되받기는 **답을 되돌려 주는 말**이다. `{value}` 가 없으면 답과 무관하게
      // 늘 같은 말을 하는 것이고, 그건 되받기가 아니라 추임새다.
      final echo = question['echo'];
      if (echo is String && echo.trim().isNotEmpty && !echo.contains('{value}')) {
        issues.add(
          SchemaIssue(
            path: '$domainId.intake.$id.echo',
            message: 'echo 에 {value} 가 없습니다. 답을 되받지 않는 말은 되받기가 아닙니다',
          ),
        );
      }

      // **선택지의 되받기는 반대다 — 문장 전체라 `{value}` 가 없어야 한다.**
      // 선택지 글은 대답 꼴로 적혀 있어서(「잘 모르겠어요」) 틀에 끼우면
      // 말이 안 된다. 끼우려고 `{value}` 를 쓴 것이 보이면 그 자리에서 막는다.
      for (final raw in (question['options'] as List<dynamic>? ?? const [])) {
        if (raw is! Map<String, dynamic>) continue;
        final line = raw['echo'];
        if (line == null) continue;
        final where = '$domainId.intake.$id.options.${raw['value']}.echo';
        if (line is! String || line.trim().isEmpty) {
          issues.add(
            SchemaIssue(
              path: where,
              message: '선택지의 echo 가 비어 있습니다. 안 쓸 거면 줄을 지우세요',
            ),
          );
          continue;
        }
        if (line.contains('{value}')) {
          issues.add(
            SchemaIssue(
              path: where,
              message: '선택지의 echo 는 문장 전체입니다. {value} 를 쓰지 않습니다 — '
                  '선택지 글은 대답 꼴이라 틀에 끼우면 말이 안 됩니다',
            ),
          );
        }
      }

      if (question['type'] == 'date') {
        const allowed = {'past', 'future', 'any'};
        final range = question['dateRange'];
        if (range is! String || !allowed.contains(range)) {
          issues.add(
            SchemaIssue(
              path: '$domainId.intake.$id.dateRange',
              message: 'type 이 date 인데 dateRange 가 없습니다. '
                  'past · future · any 중 하나를 정하세요',
            ),
          );
        }

        // 어림값을 받아도 되는 날짜인지도 밝혀야 한다. 기본값을 두면 새 날짜
        // 질문이 조용히 정확한 날짜를 강요하게 되고, 사용자는 아무 날이나 찍는다.
        const precisions = {'exact', 'approximate'};
        final precision = question['datePrecision'];
        if (precision is! String || !precisions.contains(precision)) {
          issues.add(
            SchemaIssue(
              path: '$domainId.intake.$id.datePrecision',
              message: 'type 이 date 인데 datePrecision 이 없습니다. '
                  'exact · approximate 중 하나를 정하세요',
            ),
          );
        }
      }

      // 질문 자체는 검수 대상이 아니지만, 문구에 법률 수치가 들어가는 순간 달라진다.
      // 예: "3,000만원 이하면 더 간단한 절차를 쓸 수 있습니다" (소액사건심판규칙 제1조의2)
      // 이 기준은 바뀐 전례가 있으므로 검수 없이 두면 안 된다.
      final found = _findLegalNumberInQuestion(question);
      if (found != null && question['verification'] is! Map) {
        issues.add(
          SchemaIssue(
            path: '$domainId.intake.$id.verification',
            message: '질문 문구에 법률 수치("$found")가 있습니다. '
                '제도가 바뀌면 함께 바뀌므로 근거와 함께 verification 을 채우세요',
          ),
        );
      }
    }

    for (final (index, deadline) in _itemsOf(json, 'deadlines').indexed) {
      final id = deadline['id'] as String? ?? '[$index]';
      final path = '$domainId.deadlines.$id';
      if (deadline['legalBasis'] is! Map) {
        issues.add(
          SchemaIssue(path: '$path.legalBasis', message: '근거 조문(legalBasis) 이 없습니다'),
        );
      }
      _requireTests(issues, deadline, path);
    }

    for (final (index, cost) in _itemsOf(json, 'costs').indexed) {
      final id = cost['id'] as String? ?? '[$index]';
      final path = '$domainId.costs.$id';
      final formula = cost['formula'];
      if (formula is! Map) {
        issues.add(SchemaIssue(path: '$path.formula', message: '계산식(formula) 이 없습니다'));
      }
      // **모르는 금액에는 정답지가 없다.** 0 을 정답으로 적으면 「0원이다」가
      // 정답지에 박히고, 나중에 표가 와도 그 줄이 맞는 것처럼 통과한다.
      if (formula is Map && formula['type'] == 'unknown') continue;
      _requireTests(issues, cost, path);
    }

    for (final (index, rule) in _itemsOf(json, 'limitRules').indexed) {
      final id = rule['id'] as String? ?? '[$index]';
      _requireLabeledInputs(issues, rule, '$domainId.limitRules.$id');
    }

    for (final (index, stop) in _itemsOf(json, 'hardStops').indexed) {
      final id = stop['id'] as String? ?? '[$index]';
      final trigger = stop['trigger'];
      if (trigger is Map && trigger['type'] == 'keyword') {
        _requireKeywordTests(issues, stop, '$domainId.hardStops.$id');
      }
    }

    for (final (index, trigger) in _itemsOf(json, 'autoTriggers').indexed) {
      final id = trigger['id'] as String? ?? '[$index]';
      _requireKeywordTests(issues, trigger, '$domainId.autoTriggers.$id');
    }

    // 브로커 경보도 낱말 검사다. 이 파일은 **모든 분야가 공유**하므로 한 분야에서
    // 자연스러운 말이 다른 분야에서 경보가 된다 — 정답지 없이는 그걸 알 길이 없다.
    for (final (index, alert) in _itemsOf(json, 'brokerAlerts').indexed) {
      final id = alert['id'] as String? ?? '[$index]';
      final triggers = alert['triggers'];
      if (triggers is List && triggers.isNotEmpty) {
        _requireKeywordTests(issues, alert, '$domainId.brokerAlerts.$id');
      }
    }

    for (final listName in plainLanguageLists) {
      for (final (index, item) in _itemsOf(json, listName).indexed) {
        final id = item['id'] as String? ?? '[$index]';
        _requirePlainLanguage(issues, item, '$domainId.$listName.$id');
      }
    }

    // 선택지 풀이는 **선택 사항**이지만, 적었다면 길이는 지켜야 한다.
    // 「달라질 수 있는 것」은 물음 버튼으로 나간다. 물음이 없으면 그릴 수 없다.
    // condition 을 대신 넣으면 조건절이 버튼에 들어가고, 화면이 어미를 붙이는
    // 옛 버그가 그 자리에서 되살아난다.
    for (final (index, caution) in _itemsOf(json, 'cautions').indexed) {
      final id = caution['id'] as String? ?? '[$index]';
      final ask = caution['question'];
      if (ask is! String || ask.trim().isEmpty) {
        issues.add(
          SchemaIssue(
            path: '$domainId.cautions.$id.question',
            message: 'question 이 비어 있습니다. '
                '물음으로 바꿔 낼 수 없는 안내는 화면에 낼 자리가 없습니다',
          ),
        );
      }
    }

    for (final (index, question) in _itemsOf(json, 'intake').indexed) {
      final id = question['id'] as String? ?? '[$index]';
      final options = question['options'];
      if (options is! List) continue;
      for (var i = 0; i < options.length; i++) {
        final option = options[i];
        if (option is! Map) continue;
        _checkLength(
          issues,
          option['whatIsThis'],
          '$domainId.intake.$id.options[$i].whatIsThis',
          whatIsThisMaxLength,
        );
      }
    }

    return issues;
  }

  /// 결과에 나오는 용어는 일상어 풀이를 갖는다.
  void _requirePlainLanguage(
    List<SchemaIssue> issues,
    JsonMap item,
    String path,
  ) {
    final whatIsThis = item['whatIsThis'];
    if (whatIsThis is! String || whatIsThis.trim().isEmpty) {
      issues.add(
        SchemaIssue(
          path: '$path.whatIsThis',
          message: 'whatIsThis 가 비어 있습니다. 이 용어를 모르는 사람은 '
              '이 항목이 무엇인지 알 방법이 없습니다',
        ),
      );
    } else {
      _checkLength(issues, whatIsThis, '$path.whatIsThis', whatIsThisMaxLength);
    }
  }

  void _checkLength(
    List<SchemaIssue> issues,
    Object? value,
    String path,
    int max,
  ) {
    if (value is! String || value.isEmpty) return;
    if (value.runes.length <= max) return;
    issues.add(
      SchemaIssue(
        path: path,
        message: '$max자를 넘습니다 (${value.runes.length}자). '
            '길어진다면 아직 쉬운 말을 찾지 못한 것입니다',
      ),
    );
  }

  /// 낱말 검사에는 **정답지가 필수**이고, 음성 사례가 하나는 있어야 한다.
  ///
  /// 문자열 매칭은 놓치는 것보다 **잘못 잡는 것이 더 나쁘다** — 위기 안내가 헛돌면
  /// 사용자는 앱이 자기 말을 못 알아듣는다고 느끼고 진짜 안내도 무시한다.
  /// 그런데 오탐은 사람이 문장을 실제로 써 보기 전에는 드러나지 않는다.
  /// 그래서 "걸리지 않아야 하는 문장" 을 데이터에 남기게 한다.
  void _requireKeywordTests(
    List<SchemaIssue> issues,
    JsonMap item,
    String path,
  ) {
    final tests = item['tests'];
    if (tests is! List || tests.isEmpty) {
      issues.add(
        SchemaIssue(
          path: '$path.tests',
          message: 'tests[] 가 비어 있습니다. 낱말 검사는 걸릴 문장과 '
              '걸리지 않아야 할 문장을 함께 적어야 합니다',
        ),
      );
      return;
    }

    var negatives = 0;
    for (var i = 0; i < tests.length; i++) {
      final test = tests[i];
      if (test is! Map) {
        issues.add(
          SchemaIssue(
            path: '$path.tests[$i]',
            message: 'tests 항목은 { text, expected } 객체여야 합니다',
          ),
        );
        continue;
      }
      final text = test['text'];
      if (text is! String || text.trim().isEmpty) {
        issues.add(
          SchemaIssue(path: '$path.tests[$i].text', message: 'text 가 비어 있습니다'),
        );
      }
      final expected = test['expected'];
      if (expected is! bool) {
        issues.add(
          SchemaIssue(
            path: '$path.tests[$i].expected',
            message: 'expected 는 true 또는 false 여야 합니다',
          ),
        );
        continue;
      }
      if (!expected) negatives++;
    }

    if (negatives == 0) {
      issues.add(
        SchemaIssue(
          path: '$path.tests',
          message: '걸리지 않아야 할 문장(expected: false)이 하나도 없습니다. '
              '오탐은 걸릴 문장만 적어서는 드러나지 않습니다',
        ),
      );
    }
  }

  /// `inputs` 는 `{ field, label }` 객체 배열이다.
  ///
  /// 라벨이 없으면 화면이 필드명(`transactionAmount`)을 그대로 노출하게 된다.
  /// `whyAsk` 를 강제하는 것과 같은 이유로 빌드를 세운다 — 데이터가 화면을 책임진다.
  void _requireLabeledInputs(List<SchemaIssue> issues, JsonMap item, String path) {
    final inputs = item['inputs'];
    if (inputs == null) return;
    if (inputs is! List) {
      issues.add(
        SchemaIssue(path: '$path.inputs', message: 'inputs 는 배열이어야 합니다'),
      );
      return;
    }

    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      if (input is! Map) {
        issues.add(
          SchemaIssue(
            path: '$path.inputs[$i]',
            message: 'inputs 항목은 { field, label } 객체여야 합니다. '
                '한글 라벨은 코드가 아니라 데이터에 있어야 합니다',
          ),
        );
        continue;
      }
      for (final key in const ['field', 'label']) {
        final value = input[key];
        if (value is! String || value.trim().isEmpty) {
          issues.add(
            SchemaIssue(
              path: '$path.inputs[$i].$key',
              message: '$key 가 비어 있습니다',
            ),
          );
        }
      }
    }
  }

  /// 파싱·필터링 **후** 모델 검사.
  ///
  /// [today] 를 주면 `lastVerifiedAt` 경과를 함께 본다.
  /// [enforceCriticalVerified] 는 `VerificationPolicy.keepAll` 에서만 끈다 —
  /// 그때는 unverified 항목이 남아 있고, 계산 정확성만 보는 것이 목적이기 때문이다.
  List<SchemaIssue> validate(
    Domain domain, {
    Domain? shared,
    KstDate? today,
    bool enforceCriticalVerified = true,
  }) {
    final issues = <SchemaIssue>[];
    final id = domain.id;

    // ── 중복 id ──
    _checkDuplicateIds(issues, id, 'intake', domain.intake.map((q) => q.id));
    _checkDuplicateIds(issues, id, 'deadlines', domain.deadlines.map((d) => d.id));
    _checkDuplicateIds(issues, id, 'costs', domain.costs.map((c) => c.id));
    _checkDuplicateIds(issues, id, 'documents', domain.documents.map((d) => d.id));
    _checkDuplicateIds(issues, id, 'procedures', domain.procedures.map((p) => p.id));
    _checkDuplicateIds(issues, id, 'limitRules', domain.limitRules.map((r) => r.id));

    // ── critical 기한은 verified 여야 한다 ──
    // unverified 는 이미 로더가 제거했으므로 여기 걸리는 것은 needs_check 뿐이다.
    for (final deadline in domain.deadlines) {
      if (enforceCriticalVerified &&
          deadline.severity == Severity.critical &&
          deadline.verification.status != VerificationStatus.verified) {
        issues.add(
          SchemaIssue(
            path: '$id.deadlines.${deadline.id}.verification',
            message: 'severity=critical 인 기한은 verified 여야 합니다 '
                '(현재: ${deadline.verification.status.name})',
          ),
        );
      }
      if (deadline.tests.isEmpty) {
        issues.add(
          SchemaIssue(
            path: '$id.deadlines.${deadline.id}.tests',
            message: 'tests[] 가 비어 있습니다',
          ),
        );
      }
      // 조건부 기한은 **자기가 언제 걸리는지 설명할 수 있어야 한다.** 없으면
      // 기한이 안 걸렸을 때 화면이 빈 채로 남고, 빈 화면은 실패처럼 보인다.
      if (deadline.showIf != null && deadline.appearsWhen.trim().isEmpty) {
        issues.add(
          SchemaIssue(
            path: '$id.deadlines.${deadline.id}.appearsWhen',
            message: 'showIf 가 있는데 appearsWhen 이 비어 있습니다. '
                '이 기한이 언제 생기는지 한 줄로 적으세요',
          ),
        );
      }
    }

    for (final cost in domain.costs) {
      // **모르는 금액에는 정답지가 없다.** 0 을 정답으로 적으면 「0원이다」가
      // 정답지에 박히고, 나중에 표가 와도 그 줄이 맞는 것처럼 통과한다.
      if (cost.formula is UnknownCostFormula) continue;
      if (cost.tests.isEmpty) {
        issues.add(
          SchemaIssue(path: '$id.costs.${cost.id}.tests', message: 'tests[] 가 비어 있습니다'),
        );
      }
    }

    for (final question in domain.intake) {
      if (question.whyAsk.trim().isEmpty) {
        issues.add(
          SchemaIssue(
            path: '$id.intake.${question.id}.whyAsk',
            message: 'whyAsk 가 비어 있습니다',
          ),
        );
      }
    }

    // ── 참조 무결성 (경고. 로더가 끊긴 참조를 정리한다) ──
    final costIds = domain.costs.map((c) => c.id).toSet();
    final deadlineIds = domain.deadlines.map((d) => d.id).toSet();
    final documentIds = domain.documents.map((d) => d.id).toSet();
    for (final procedure in domain.procedures) {
      final path = '$id.procedures.${procedure.id}';
      _checkRefs(issues, '$path.costRefs', procedure.costRefs, costIds);
      _checkRefs(issues, '$path.deadlineRefs', procedure.deadlineRefs, deadlineIds);
      _checkRefs(issues, '$path.documentRefs', procedure.documentRefs, documentIds);
    }

    final channelIds = {
      ...domain.publicChannels.map((c) => c.id),
      if (shared != null) ...shared.publicChannels.map((c) => c.id),
    };
    for (final hardStop in domain.hardStops) {
      _checkRefs(
        issues,
        '$id.hardStops.${hardStop.id}.channels',
        hardStop.channels,
        channelIds,
      );
    }
    for (final trigger in domain.autoTriggers) {
      _checkRefs(
        issues,
        '$id.autoTriggers.${trigger.id}.show',
        trigger.show,
        channelIds,
      );
    }

    // ── 임계값 sanity ──
    final scoring = domain.scoring;
    if (scoring != null && scoring.yellowThreshold > scoring.greenThreshold) {
      issues.add(
        SchemaIssue(
          path: '$id.scoring',
          message: 'yellowThreshold 가 greenThreshold 보다 큽니다',
        ),
      );
    }

    // ── 검수 경과 ──
    final lastVerifiedAt = domain.lastVerifiedAt;
    if (today != null && lastVerifiedAt != null) {
      final elapsed = today.differenceInDays(lastVerifiedAt);
      if (elapsed > staleAfterDays) {
        issues.add(
          SchemaIssue.warning(
            path: '$id.lastVerifiedAt',
            message: '마지막 검수 후 $elapsed일이 지났습니다 (기준 $staleAfterDays일). 재검수가 필요합니다',
          ),
        );
      }
    }

    return issues;
  }

  /// 질문의 사용자 노출 문구(질문 · 왜 묻는지 · 선택지)를 전부 훑는다.
  String? _findLegalNumberInQuestion(JsonMap question) {
    final texts = <String>[
      question['text'] as String? ?? '',
      question['whyAsk'] as String? ?? '',
      if (question['options'] is List)
        ...(question['options'] as List<dynamic>)
            .whereType<Map>()
            .map((o) => o['label'] as String? ?? ''),
    ];

    for (final text in texts) {
      final found = findLegalNumber(text);
      if (found != null) return found;
    }
    return null;
  }

  void _requireTests(List<SchemaIssue> issues, JsonMap item, String path) {
    final tests = item['tests'];
    if (tests is! List || tests.isEmpty) {
      issues.add(
        SchemaIssue(
          path: '$path.tests',
          message: 'tests[] 가 없습니다. 계산 항목은 정답지 없이 넣지 않습니다',
        ),
      );
    }
  }

  void _checkDuplicateIds(
    List<SchemaIssue> issues,
    String domainId,
    String listName,
    Iterable<String> ids,
  ) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        issues.add(
          SchemaIssue(path: '$domainId.$listName.$id', message: 'id 가 중복됩니다'),
        );
      }
    }
  }

  void _checkRefs(
    List<SchemaIssue> issues,
    String path,
    List<String> refs,
    Set<String> known,
  ) {
    for (final ref in refs) {
      if (!known.contains(ref)) {
        issues.add(
          SchemaIssue.warning(path: path, message: '"$ref" 를 찾을 수 없습니다'),
        );
      }
    }
  }

  List<JsonMap> _itemsOf(JsonMap json, String listName) {
    final value = json[listName];
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// 한 번에 하나만 맞아야 하는 묶음이 **겹치지도 빠지지도 않는지** 본다.
  ///
  /// 소멸시효가 그렇다. 겹치면 카드가 두 장 뜨고 사용자는 긴 쪽을 믿는다.
  /// 빠지면 시효가 조용히 사라진다. 둘 다 지금까지 아무도 막지 않았다.
  ///
  /// ## 좁은 모양에서만 검사한다
  ///
  /// 임의의 JSONLogic 두 개가 겹치는지는 판정할 수 없다. 그래서
  /// **같은 필드에 대한 `==` · `in`** 이라는 한 모양에서만 값 집합으로 비교한다
  /// (`NearMissChecker` 가 `<=` · `<` 만 보는 것과 같은 태도다).
  ///
  /// **검사할 수 없는 모양은 조용히 통과시키지 않는다.** 경고로 남겨서
  /// "검사됐다" 와 "검사 못 했다" 를 구별할 수 있게 한다.
  /// 이 검사는 **거르기 전 데이터**에 돌려야 한다.  를 걷어낸 뒤에 보면
  /// 「아직 확인 안 된 항목」이 「빠뜨린 항목」으로 둔갑한다. 그 둘은 다르다 —
  /// 하나는 예정된 상태이고 하나는 실수다.
  List<SchemaIssue> checkExclusiveGroups(Domain domain) {
    final issues = <SchemaIssue>[];
    final id = domain.id;

    // 있지도 않은 묶음을 가리키는 항목부터 잡는다.
    final declared = {for (final g in domain.exclusiveGroups) g.id};
    for (final deadline in domain.deadlines) {
      final group = deadline.exclusiveGroup;
      if (group != null && !declared.contains(group)) {
        issues.add(
          SchemaIssue(
            path: '$id.deadlines.${deadline.id}.exclusiveGroup',
            message: '선언되지 않은 묶음 "$group" 을 가리킵니다. '
                'exclusiveGroups 에 먼저 적으세요',
          ),
        );
      }
    }

    for (final group in domain.exclusiveGroups) {
      final path = '$id.exclusiveGroups.${group.id}';
      final members =
          domain.deadlines.where((d) => d.exclusiveGroup == group.id).toList();

      // 묶음을 선언해 놓고 아무도 안 들어 있으면 검사가 헛돈다.
      if (members.isEmpty) {
        issues.add(
          SchemaIssue.warning(
            path: path,
            message: '이 묶음에 든 항목이 없습니다. 아직 안 만들었다면 그대로 두어도 됩니다',
          ),
        );
      }

      // 이 묶음이 가르는 필드를 묻는 질문. 없으면 덮었는지 알 수 없다.
      final question = domain.intake
          .where((q) => q.field == group.field)
          .cast<Question?>()
          .firstWhere((q) => true, orElse: () => null);
      if (question == null) {
        issues.add(
          SchemaIssue.warning(
            path: '$path.field',
            message: '"${group.field}" 을 묻는 질문이 없어 빠짐을 검사하지 못했습니다',
          ),
        );
        continue;
      }

      final seen = <String, String>{};
      var checkable = true;

      for (final deadline in members) {
        final where = '$id.deadlines.${deadline.id}.showIf';
        final values = _equalityValues(deadline.showIf, group.field);
        if (values == null) {
          // 여기서 조용히 넘어가면 "검사 통과" 와 구별이 안 된다.
          checkable = false;
          issues.add(
            SchemaIssue.warning(
              path: where,
              message: '"${group.field}" 에 대한 == · in 모양이 아니라 '
                  '겹침·빠짐을 검사하지 못했습니다',
            ),
          );
          continue;
        }
        for (final value in values) {
          final owner = seen[value];
          if (owner != null) {
            issues.add(
              SchemaIssue(
                path: where,
                message: '"$value" 를 "$owner" 도 맡고 있습니다. '
                    '같은 묶음에서는 하나만 맞아야 합니다',
              ),
            );
            continue;
          }
          seen[value] = deadline.id;
        }
      }

      // 모른다고 적은 값을 동시에 맡고 있으면 둘 중 하나가 거짓말이다.
      for (final value in group.unknownValues) {
        final owner = seen[value];
        if (owner != null) {
          issues.add(
            SchemaIssue(
              path: '$path.unknownValues',
              message: '"$value" 는 "$owner" 가 맡고 있는데 '
                  '모르는 값으로도 적혀 있습니다',
            ),
          );
        }
      }

      if (!checkable) continue;

      // 선택지를 전부 덮었는가. **빠뜨린 것과 모른다고 적은 것은 다르다.**
      //
      // 다른 분야로 넘기는 선택지는 빼고 센다. `redirect` 를 고른 사람은 이 분야를
      // 떠나므로 여기서 맡을 것이 없다 — 요구하면 있지도 않은 항목을 만들게 된다.
      final options = question.options
          .where((o) => o.redirect == null)
          .map((o) => o.value)
          .toSet();
      final covered = {...seen.keys, ...group.unknownValues};
      final missing = options.difference(covered).toList()..sort();
      if (missing.isNotEmpty) {
        issues.add(
          SchemaIssue(
            path: path,
            message: '선택지 ${missing.join(' · ')} 를 아무도 맡지 않습니다. '
                '항목을 만들거나 unknownValues 에 적으세요',
          ),
        );
      }

      // 선택지에 없는 값을 맡고 있으면 오타이거나 옛 값이다.
      final unknownToQuestion = covered.difference(options).toList()..sort();
      if (unknownToQuestion.isNotEmpty) {
        issues.add(
          SchemaIssue(
            path: path,
            message: '${unknownToQuestion.join(' · ')} 는 '
                '"${question.id}" 의 선택지에 없습니다',
          ),
        );
      }
    }

    return issues;
  }

  /// `{"==": [{"var": f}, "a"]}` · `{"in": [{"var": f}, ["a","b"]]}` 에서 값을 뽑는다.
  ///
  /// 그 모양이 아니거나 다른 필드를 보고 있으면 **null** — 모르는 것을 추측하지 않는다.
  static Set<String>? _equalityValues(JsonMap? showIf, String field) {
    if (showIf == null || showIf.length != 1) return null;
    final op = showIf.keys.first;
    final args = showIf[op];
    if (args is! List || args.length != 2) return null;

    final left = args[0];
    if (left is! Map) return null;
    final variable = left['var'];
    if (variable is! String || variable != field) return null;

    final right = args[1];
    if (op == '==' && right is String) return {right};
    if (op == 'in' && right is List && right.every((e) => e is String)) {
      return right.cast<String>().toSet();
    }
    return null;
  }
}

/// 쉬운 말을 쓸 수 있는 자리를 사람이 읽는 꼴로. **오류 문구에 그대로 나간다.**
///
/// 「여기는 안 됩니다」만 말하고 어디가 되는지 안 말하면 다음 사람이 다시 찍는다.
final List<String> _plainTargetNames = [
  for (final entry in kPlainTargets.entries)
    for (final field in entry.value)
      entry.key.isEmpty ? field : '${entry.key}.<id>.$field',
];


/// **우리 문장이 법에 대해 말하고 있는가.**
///
/// **법이라는 출처를 이름으로 대는 말만 본다.** 「법원」은 안 걸린다 —
/// 「법에」·「법이」·「법은」만 본다. 창구로 보내는 카드가 「법원 서류를
/// 받았는데」라고 쓰는 것은 법에 대한 주장이 아니다.
///
/// ★ **처음에는 「적혀 있」·「쓰여 있」·「정해져 있」도 넣었다가 뺐다.** 첫 사용에서
/// `ct_court_document` 의 「기한이 정해져 있어요」가 걸렸는데, 그것은 **그 서류에**
/// 기한이 있다는 말이지 법이 그렇다는 말이 아니다. 저 셋은 목적어가 있어야 법
/// 주장이 되고, 그 목적어(법·조문·시행령)는 아래 낱말이 이미 잡는다.
///
/// ★★ **좁힌 것이 느슨해진 것은 아니다.** 「조문에 적혀 있어요」는 「조문」이,
/// 「제3조에 적혀 있어요」는 「제3조」가 잡는다. 안 잡히는 것은 **법을 안 부르면서
/// 사실만 말하는 문장**이고, 그건 원래 이 검사가 찾는 것이 아니다.
final RegExp _legalClaim = RegExp(
  '법에|법이|법은|법령|조문|시행령|시행규칙|규칙에|부칙|제[0-9]+조',
);

/// 그 항목의 쉬운 말 한 벌. 없으면 빈 목록.
List<String> plainLanguageOf(
  Map<String, dynamic> json,
  String section,
  String id,
) {
  final plain = json['plain'];
  if (plain is! Map) return const [];
  return [
    for (final e in plain.entries)
      if ('${e.key}'.startsWith('$section.$id.') && e.value is String)
        e.value as String,
  ];
}
