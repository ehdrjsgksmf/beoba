/// 도메인 JSON 원문을 가져오는 통로.
///
/// 구현체는 플랫폼별로 다르다:
/// - `AssetDomainSource` (Flutter, rootBundle) — 앱
/// - `FileDomainSource` (dart:io) — 테스트·CLI. `package:domain_data/io.dart`
/// - 원격 캐시 — M5
///
/// **로더·엔진은 어디서 온 문자열인지 알지 못한다.**
abstract interface class DomainSource {
  /// 도메인 id 로 JSON 원문을 읽는다.
  Future<String> read(String domainId);

  /// 사용할 수 있는 도메인 id 목록.
  Future<List<String>> list();
}
