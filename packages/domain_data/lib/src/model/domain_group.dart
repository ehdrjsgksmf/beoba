import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'domain_group.freezed.dart';
part 'domain_group.g.dart';

/// 분야 묶음 하나.
///
/// **이름은 분류가 아니라 사람이 자기 일을 떠올리는 말이다.** 「노동」이 아니라
/// 「일하다 생긴 일」이다. 분류 이름을 쓰면 그 말을 아는 사람만 자기 자리를
/// 찾는다 — 분야 이름을 두 층으로 만든 것과 같은 이유다([194번](../../../../DECISIONS.md)).
@freezed
abstract class DomainGroup with _$DomainGroup {
  const factory DomainGroup({
    required String id,
    required String name,
    String? icon,

    /// 화면에 서는 차례. 작은 것이 위다.
    @Default(0) int order,
  }) = _DomainGroup;

  factory DomainGroup.fromJson(JsonMap json) => _$DomainGroupFromJson(json);
}

/// 묶음 한 벌. **분야가 어느 묶음에 드는지는 여기가 아니라 분야가 적는다.**
///
/// 묶음 쪽에 분야 목록을 적으면 같은 분야가 두 묶음에 실릴 수 있고, 그러면
/// 「같은 것이 두 군데 있네」가 된다. 분야마다 칸이 하나뿐이면 **중복이 구조로
/// 불가능하다** — 검사로 막는 것보다 못 만들게 하는 쪽이 낫다.
@freezed
abstract class DomainGroupCatalog with _$DomainGroupCatalog {
  const DomainGroupCatalog._();

  const factory DomainGroupCatalog({
    @Default(<DomainGroup>[]) List<DomainGroup> groups,
  }) = _DomainGroupCatalog;

  factory DomainGroupCatalog.fromJson(JsonMap json) =>
      _$DomainGroupCatalogFromJson(json);

  DomainGroup? byId(String id) {
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  /// `order` 순. 같은 자리면 id 로 가른다 — 파일 읽는 차례에 안 기댄다.
  List<DomainGroup> get inOrder => [...groups]..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
}
