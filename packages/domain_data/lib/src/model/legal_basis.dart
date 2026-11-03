import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'legal_basis.freezed.dart';
part 'legal_basis.g.dart';

/// 근거 조문. 법률 정보를 보여주는 위젯은 이것 없이 만들 수 없다.
@freezed
abstract class LegalBasis with _$LegalBasis {
  const factory LegalBasis({
    String? law,
    String? article,
    String? text,
    String? url,
  }) = _LegalBasis;

  factory LegalBasis.fromJson(JsonMap json) => _$LegalBasisFromJson(json);
}

extension LegalBasisDisplay on LegalBasis {
  /// "민사소송법 제470조 제1항" 형태. 둘 다 없으면 null.
  String? get citation {
    final parts = [law, article].where((p) => p != null && p.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// 사용자가 바로 누를 수 있는 행동(전화·링크).
@freezed
abstract class ActionRef with _$ActionRef {
  const factory ActionRef({
    required String label,
    String? phone,
    String? url,
  }) = _ActionRef;

  factory ActionRef.fromJson(JsonMap json) => _$ActionRefFromJson(json);
}

/// 공식 안내 링크.
@freezed
abstract class LinkRef with _$LinkRef {
  const factory LinkRef({
    required String label,
    required String url,
  }) = _LinkRef;

  factory LinkRef.fromJson(JsonMap json) => _$LinkRefFromJson(json);
}
