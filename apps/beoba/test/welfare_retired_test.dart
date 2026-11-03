import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// 중앙부처 CSV 는 물러났다. **그런데 지우지 않았다.**
///
/// 겹치는 362건은 API 가 이긴다 — 상세를 갖고 있기 때문이다. 문제는 **CSV 에만
/// 있는 5건**이다. API 목록 461건에 없다는 것은 둘 중 하나인데 어느 쪽인지
/// 우리가 확인할 방법이 없다.
///
/// ```
/// (가) 그 사이에 없어진 제도다     → 올리면 없는 제도를 안내하는 것이 된다
/// (나) API 목록이 그것을 빠뜨렸다  → 지우면 있는 제도를 영영 잃는다
/// ```
///
/// **확인 안 된 것은 화면에 안 올린다.** 그리고 확인 안 된 것을 지우지도
/// 않는다 — 둘 다 우리 규칙이다(DECISIONS 235번).
///
/// 이 테스트는 **덫**이다. 다섯이 넷이 되거나 여섯이 되면 자료 쪽에서
/// 무언가 움직인 것이고, 그때가 이 다섯을 다시 볼 때다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const source = AssetWelfareSource();

  /// API 목록에 없는 다섯. **id · 이름 · 부처를 그대로 적어 둔다.**
  ///
  /// 이름만 적으면 자료가 이름을 조금 바꿔 적었을 때 못 찾는다.
  const onlyInCsv = <String, String>{
    'WLF00001126': '금융위원회',
    'WLF00001186': '여성가족부',
    'WLF00004659': '고용노동부',
    'WLF00005360': '금융위원회',
    'WLF00005859': '보건복지부',
  };

  test('★ CSV 에만 있는 다섯이 그대로다', () async {
    final public = await source.loadPublic();
    final central = await const AssetWelfareSource().loadCentral();

    final inApi = {for (final s in central.services) s.id};
    final missing = {
      for (final s in public.services)
        if (!inApi.contains(s.id)) s.id: s.ministry,
    };

    expect(
      missing,
      onlyInCsv,
      reason: '숫자가 달라졌으면 자료가 움직인 것입니다. '
          '줄었으면 API 목록이 그 제도를 담기 시작한 것이고(그때 살립니다), '
          '늘었으면 새로 사라진 것입니다. 어느 쪽이든 DECISIONS 235번을 고치세요',
    );
  });

  test('★ 물러났다는 표시가 자료 안에 있다', () async {
    final public = await source.loadPublic();

    // 파일이 살아 있으니 데이터가 스스로 말해야 한다.
    expect(public.retired, isTrue);
    expect(public.retiredWhy, contains('지우지 않고 남긴다'));
    expect(public.openPart, contains('확인 안 됨'));
  });

  test('★ 겹치는 362건은 API 가 이긴다', () async {
    final public = await source.loadPublic();
    final central = await const AssetWelfareSource().loadCentral();

    final inApi = {for (final s in central.services) s.id};
    final both = [
      for (final s in public.services)
        if (inApi.contains(s.id)) s.id,
    ];
    expect(both, hasLength(362));
  });
}
