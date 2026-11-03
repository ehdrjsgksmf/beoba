/// `law/특일정보_공휴일_YYYY.xml` → `assets/holidays/YYYY.json`.
///
/// PDF 에서 조문을 옮기는 것과 같은 흐름이다.
///
/// ```
/// law/특일정보_공휴일_2026.xml      원문. 저장소에 없다(.gitignore)
/// tool/build_holidays.dart          이 파일. 커밋한다
/// assets/holidays/2026.json         결과. 커밋한다. **앱이 읽는 것**
/// ```
///
/// **앱은 API 를 부르지 않는다.** 네트워크가 끊긴 사람에게 기한이 안 나오면
/// 안 된다. 커밋된 JSON 이 진짜 데이터다.
///
/// ## 왜 세 해뿐인가
///
/// 원문은 2015~2027 을 받아 뒀지만 **넣는 것은 2025·2026·2027 셋뿐**이다.
/// 과거 연도는 대체공휴일 규정이 여러 번 바뀌었는데 우리는 **현행 판본만**
/// 갖고 있어 검산할 수 없다. 검산 못 하는 데이터는 「잘못 넣으면 기한이
/// 늦어지는」 쪽 위험을 그대로 받는다.
///
/// ## 안전 방향이 뒤집힌다
///
/// ```
/// 공휴일을 적게 알면      → 덜 민다 → 기한이 이르다 → 안전
/// 공휴일을 **잘못 넣으면** → 더 민다 → 기한이 늦다  → 위험
/// ```
///
/// **틀린 날을 넣느니 빼는 게 맞다.**
library;

import 'dart:convert';
import 'dart:io';

/// 앱에 싣는 해. 늘릴 때는 그 해의 원문과 **검산할 규정 판본**이 함께 있어야 한다.
const List<int> kBundledYears = [2025, 2026, 2027];

const String kSource = '한국천문연구원 특일 정보 (공공데이터포털 dataset 15012690) ' // not-a-legal-number: 공공데이터포털 자료 번호. 법률 수치가 아니다.
    'SpcdeInfoService.getRestDeInfo';

void main(List<String> args) {
  final root = _repoRoot();
  final lawDir = Directory('${root.path}/law');
  final outDir = Directory('${root.path}/packages/domain_data/assets/holidays');

  if (!lawDir.existsSync()) {
    stderr.writeln('law/ 가 없습니다. 원문이 있는 곳에서 돌리세요.');
    exit(2);
  }

  // 오늘 날짜를 인자로 받는다. `DateTime.now()` 를 직접 부르지 않는다.
  final fetchedAt = args.isEmpty ? null : args.first;
  if (fetchedAt == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fetchedAt)) {
    stderr.writeln('받은 날짜를 주세요: dart run tool/build_holidays.dart 2026-08-18');
    exit(2);
  }

  outDir.createSync(recursive: true);
  var total = 0;

  for (final year in kBundledYears) {
    final file = File('${lawDir.path}/특일정보_공휴일_$year.xml');
    if (!file.existsSync()) {
      stderr.writeln('$year 원문이 없습니다: ${file.path}');
      exit(2);
    }

    final days = _parse(file.readAsStringSync(), year);
    if (days.isEmpty) {
      stderr.writeln('$year 에서 공휴일을 하나도 못 읽었습니다. 원문 형식을 보세요.');
      exit(2);
    }

    final json = <String, Object?>{
      'year': year,
      'source': kSource,
      'fetchedAt': fetchedAt,
      'days': days,
    };
    File('${outDir.path}/$year.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(json)}\n',
    );
    total += days.length;
    stdout.writeln('$year — ${days.length}건');
  }

  stdout.writeln('공휴일 ${kBundledYears.length}개 해 · $total건');
  stdout.writeln('→ ${outDir.path}');
}

/// `<item>` 을 훑는다. `isHoliday` 가 `Y` 인 것만 싣는다.
///
/// `dateName` 에 「대체공휴일」이 들어 있는지로 종류를 가른다. **그건 표기이지
/// 규정이 아니다** — 재계산 대조는 규정 제3조로 따로 한다.
List<Map<String, Object?>> _parse(String xml, int year) {
  final item = RegExp(r'<item>(.*?)</item>', dotAll: true);
  final days = <Map<String, Object?>>[];
  final seen = <String>{};

  for (final match in item.allMatches(xml)) {
    final body = match.group(1)!;
    if (_tag(body, 'isHoliday') != 'Y') continue;

    final locdate = _tag(body, 'locdate');
    if (locdate == null || locdate.length != 8) continue;
    if (!locdate.startsWith('$year')) {
      stderr.writeln('$year 파일에 다른 해가 섞였습니다: $locdate');
      exit(2);
    }

    final date = '${locdate.substring(0, 4)}-'
        '${locdate.substring(4, 6)}-${locdate.substring(6)}';
    if (!seen.add(date)) continue;

    final name = _tag(body, 'dateName') ?? '';
    days.add({
      'date': date,
      'name': name,
      'kind': name.contains('대체공휴일') ? 'substitute' : 'statutory',
    });
  }

  days.sort((a, b) => (a['date']! as String).compareTo(b['date']! as String));
  return days;
}

String? _tag(String body, String name) =>
    RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(body)?.group(1);

Directory _repoRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    if (Directory('${dir.path}/packages/domain_data').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  stderr.writeln('저장소 뿌리를 못 찾았습니다.');
  exit(2);
}
