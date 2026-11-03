/// 법령 PDF **파일명**을 읽는 규칙. `build_law_manifest.dart` 가 쓴다.
///
/// 따로 떼어 둔 이유는 하나다 — **테스트가 이걸 부를 수 있어야 한다.**
/// PDF 원본(`law/`)은 저장소에 없어서 CI 는 파일을 볼 수 없다. 파일명 규칙만은
/// 파일 없이도 검사할 수 있다.
library;

/// `민법(법률)(제21454호)(20260317).pdf`
///
/// 이름이 **비탐욕**이라 `대부업 … 법률 시행령(대통령령)(...)` 도 이름과 종류가
/// 제대로 갈린다.
/// 고시·훈령의 번호에는 **붙임표가 들어간다** — `제2026-45호`.
/// `제[\d]+호` 로만 잡으면 고시가 통째로 안 읽힌다.
final RegExp lawFileNamePattern =
    RegExp(r'^(.+?)\((.+?)\)\((제[\d\-]+호)\)\((\d{8})\)\.pdf$');

/// `우편법 일부개정 2026.03.31 [법률 제21498호, 시행 2026.3.31.] 과기정통부.pdf`
///
/// 국가법령정보센터가 개정문을 내려줄 때 쓰는 다른 꼴이다. **드물지 않다** —
/// 이름 규칙에 안 맞는다고 넘기면 인용해도 매니페스트에 안 잡힌다.
final RegExp amendedFileNamePattern = RegExp(
  r'^(.+?)\s+(?:일부|전부)개정\s+[\d.]+\s*'
  r'\[(.+?)\s+(제[\d\-]+호),\s*시행\s*(\d{4})\.\s*(\d{1,2})\.\s*(\d{1,2})\.?\]',
);

/// 별표 파일. 두 꼴이 있다.
///
/// ```
/// [별표 5] 가정법원과 그 지원의 관할구역(각급 법원의 설치와 …에 관한 법률).pdf
/// 송달료규칙의 시행에 따른 업무처리요령 [별표 1] 사건별 당사자 1인당 ….pdf
/// ```
///
/// **별표는 법령이 아니라 별표다.** `laws` 가 아니라 `tables` 로 간다 —
/// 판본을 다는 방식이 다르기 때문이다(DECISIONS 116번).
final RegExp annexLeadingPattern =
    RegExp(r'^\[?<?별표\s*(\d*)>?\]?\s*(.*?)\(([^()]+)\)[^()]*\.pdf$');
final RegExp annexInlinePattern =
    RegExp(r'^(.+?)\s+\[?<?별표\s*(\d*)>?\]?\s+(.+)\.pdf$');

/// 세 번째 꼴. **별표 표시가 맨 뒤 괄호 안에 붙어 온다.**
///
/// ```
/// 근로기준법 시행령(대통령령)(제35436호)(20251023)(별표1).pdf
/// 근로기준법 시행령(대통령령)(제35436호)(20251023) (별표 3).pdf
/// ```
///
/// 앞 두 꼴로는 안 읽혀서 「이름을 못 읽음」으로 셋이 쌓여 있었다.
/// **읽을 파일을 이름으로 고르지 않는다**(DECISIONS 118번) — 못 읽은 것을
/// 세어 두었기 때문에 눈에 띄었다.
final RegExp annexTrailingPattern = RegExp(
  r'^(.+?)\((?:[^()]+)\)\((제[\d\-]+호)\)\(\d{8}\)\s*'
  r'\(\s*\[?<?별표\s*(\d*)>?\]?\s*\)\.pdf$',
);

/// 파일명에서 읽어낸 판본.
///
/// **파일명이 곧 판본이라는 전제 위에 서 있다.** 국가법령정보센터가 「공포 후
/// 시행전 개정된 사항을 모두 포함한」 판본을 내려주면서 파일명에는 현행 시행일을
/// 적는 경우가 있어서, 그때는 `overrides.json` 이 헤더 값을 덮어쓴다.
class LawFileName {
  const LawFileName({
    required this.name,
    required this.kind,
    required this.number,
    required this.effective,
    required this.sourceFile,
  });

  final String name;
  final String kind;
  final String number;

  /// `2026-03-17` 꼴.
  final String effective;
  final String sourceFile;
}

/// 이 파일이 가리키는 별표의 이름. 「<법령명> [별표 N]」 꼴. 아니면 null.
///
/// **표기를 하나로 모은다.** `[별표 1]` · `[별표1]` · `<별표>` 가 파일마다
/// 다르게 적혀 있는데, 등록해 놓고도 못 찾으면 없는 것과 같다.
String? parseAnnexFileName(String fileName) {
  final leading = annexLeadingPattern.firstMatch(fileName);
  if (leading != null) {
    return annexKey(leading.group(3)!.trim(), leading.group(1)!);
  }
  final inline = annexInlinePattern.firstMatch(fileName);
  if (inline != null) {
    return annexKey(inline.group(1)!.trim(), inline.group(2)!);
  }
  final trailing = annexTrailingPattern.firstMatch(fileName);
  if (trailing != null) {
    return annexKey(trailing.group(1)!.trim(), trailing.group(3)!);
  }
  return null;
}

/// 별표 이름표를 **한 가지 꼴로** 만든다. 번호가 없으면 「[별표]」다.
String annexKey(String law, String number) =>
    number.isEmpty ? '$law [별표]' : '$law [별표 $number]';

LawFileName? parseLawFileName(String fileName) {
  final amended = amendedFileNamePattern.firstMatch(fileName);
  if (amended != null) {
    final month = amended.group(5)!.padLeft(2, '0');
    final day = amended.group(6)!.padLeft(2, '0');
    return LawFileName(
      name: amended.group(1)!.trim(),
      kind: amended.group(2)!.trim(),
      number: amended.group(3)!,
      effective: '${amended.group(4)}-$month-$day',
      sourceFile: fileName,
    );
  }

  final match = lawFileNamePattern.firstMatch(fileName);
  if (match == null) return null;
  final raw = match.group(4)!;
  return LawFileName(
    name: match.group(1)!.trim(),
    kind: match.group(2)!,
    number: match.group(3)!,
    effective:
        '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6)}',
    sourceFile: fileName,
  );
}

/// 같은 법령명을 가진 파일이 둘 이상인가. 이름 → 파일명들.
///
/// ## 왜 이것이 실패여야 하는가
///
/// `overrides.json` 은 **법령명으로** 찾는다. 같은 이름의 PDF 가 둘 있으면 손으로
/// 적은 헤더 값이 **양쪽 모두에** 붙는다. 한쪽에만 맞는 값이 다른 판본에도 붙는
/// 것이다. 인용을 이어 붙일 때도 `firstOrNull` 이 먼저 온 파일을 집으므로,
/// 어느 판본을 인용한 것인지가 **정렬 순서로 정해진다.**
///
/// 조용히 틀린 매니페스트는 아무도 못 잡는다. 매니페스트 자체가 「우리가 인용한
/// 조문이 어느 판본인가」를 답하려고 만든 파일이기 때문이다. 그래서 던진다.
Map<String, List<String>> duplicateLawNames(Iterable<LawFileName> files) {
  final byName = <String, List<String>>{};
  for (final file in files) {
    (byName[file.name] ??= <String>[]).add(file.sourceFile);
  }
  byName.removeWhere((_, files) => files.length < 2);
  return byName;
}
