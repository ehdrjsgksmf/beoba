/// dart:io 를 쓰는 구현. **웹에서는 임포트하지 말 것.**
///
/// 앱(Flutter)은 `AssetDomainSource` 를 쓴다. 이 라이브러리는 테스트·CLI 전용이다.
library;

import 'dart:io';

import 'src/loader/domain_source.dart';

export 'src/loader/domain_source.dart';

/// 파일 시스템에서 도메인 JSON 을 읽는다.
class FileDomainSource implements DomainSource {
  const FileDomainSource(this.directory);

  /// `packages/domain_data/assets/domains` 같은 디렉터리.
  final Directory directory;

  @override
  Future<String> read(String domainId) {
    final file = File('${directory.path}${Platform.pathSeparator}$domainId.json');
    if (!file.existsSync()) {
      throw FileSystemException('도메인 파일을 찾을 수 없습니다', file.path);
    }
    return file.readAsString();
  }

  @override
  Future<List<String>> list() async {
    final ids = <String>[];
    for (final entity in directory.listSync()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final name = entity.uri.pathSegments.last;
        ids.add(name.substring(0, name.length - '.json'.length));
      }
    }
    ids.sort();
    return ids;
  }
}
