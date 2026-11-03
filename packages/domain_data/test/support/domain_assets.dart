import 'dart:io';

/// 도메인 JSON 이 들어 있는 디렉터리.
///
/// 테스트 실행 위치(패키지 루트 / 워크스페이스 루트)가 달라도 찾아낸다.
Directory domainAssetsDir() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    final direct = Directory('${dir.path}/assets/domains');
    if (direct.existsSync()) return direct;

    final viaPackage =
        Directory('${dir.path}/packages/domain_data/assets/domains');
    if (viaPackage.existsSync()) return viaPackage;

    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('도메인 JSON 디렉터리를 찾지 못했습니다 (from ${Directory.current.path})');
}

/// `<id>.json` 파일 목록. 파일명 순.
List<File> domainAssetFiles() {
  final files = domainAssetsDir()
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// 파일명에서 도메인 id 를 뽑는다.
String domainIdOf(File file) {
  final name = file.uri.pathSegments.last;
  return name.substring(0, name.length - '.json'.length);
}

String readDomainJson(String domainId) =>
    File('${domainAssetsDir().path}/$domainId.json').readAsStringSync();

/// 용어집 JSON. 도메인 밖에 있다 — **용어는 분야를 가로지른다.**
String readGlossaryJson() => File(
      '${domainAssetsDir().parent.path}/glossary/terms.json',
    ).readAsStringSync();
