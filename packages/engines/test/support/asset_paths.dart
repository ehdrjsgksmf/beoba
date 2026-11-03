import 'dart:io';

/// 도메인 JSON 디렉터리. 실행 위치가 어디든 리포를 거슬러 올라가 찾는다.
Directory domainAssetsDir() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    for (final candidate in [
      '${dir.path}/packages/domain_data/assets/domains',
      '${dir.path}/../domain_data/assets/domains',
      '${dir.path}/assets/domains',
    ]) {
      final directory = Directory(candidate);
      if (directory.existsSync()) return directory;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('도메인 JSON 디렉터리를 찾지 못했습니다 (from ${Directory.current.path})');
}

List<File> domainAssetFiles() => domainAssetsDir()
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.json'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String domainIdOf(File file) {
  final name = file.uri.pathSegments.last;
  return name.substring(0, name.length - '.json'.length);
}

/// 도메인 하나의 JSON 파일.
File domainFile(String domainId) =>
    File('${domainAssetsDir().path}/$domainId.json');
