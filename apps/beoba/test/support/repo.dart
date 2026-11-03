/// 저장소 뿌리를 찾는다. **경로를 상수로 박지 않는다.**
///
/// `flutter test` 와 `melos run test` 의 작업 디렉터리가 다를 수 있고,
/// 그때 조용히 빈 값이 되면 이 파일들이 막으려는 바로 그 일이 벌어진다
/// (DECISIONS 244번). 못 찾으면 던진다.
library;

import 'dart:io';

Directory repoRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    if (Directory('${dir.path}/packages/domain_data/assets').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    '저장소 뿌리를 못 찾았습니다 (${Directory.current.path} 에서 시작). '
    '못 찾으면 세는 대상이 0이 되고, 그건 검사가 아무것도 안 본다는 뜻입니다',
  );
}
