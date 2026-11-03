import 'dart:convert';

import 'package:flutter/services.dart';

/// 개인정보처리방침 한 덩어리.
///
/// **속에 서식이 없다.** 굽는 쪽(`build_privacy_page.dart`)이 마크다운을 전부
/// 벗겨서 준다. 화면은 종류에 따라 크기만 고르면 된다 — 그래야 이 글이
/// `SafeText` 하나로 지나간다.
class PolicyBlockData {
  const PolicyBlockData({required this.kind, required this.text});

  /// `title` · `section` · `strong` · `para` · `item`.
  final String kind;
  final String text;
}

/// 앱 안과 웹앱 안이 같이 읽는 방침.
///
/// **여기서 마크다운을 그리지 않는다.** 마크다운 렌더러를 하나 들이면 그
/// 렌더러가 만드는 위젯은 `SafeText` 를 안 거친다 — 문구가 지나는 길이 둘이
/// 된다. 그래서 굽는 쪽이 글자만 남겨 주고 이쪽은 읽기만 한다.
class AssetPolicySource {
  const AssetPolicySource([this._bundle]);

  /// 테스트에서 갈아끼울 자리. 평소에는 [rootBundle].
  final AssetBundle? _bundle;

  /// 생성물이다. `docs/개인정보처리방침.md` 가 원본이고, 어긋나면 검사 (ah) 가
  /// 빨간불을 켠다.
  static const String assetPath = 'assets/policy/privacy.json';

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<List<PolicyBlockData>> load() async {
    final raw = jsonDecode(await _assets.loadString(assetPath));
    final map = raw as Map<String, dynamic>;
    final blocks = (map['blocks'] as List).cast<Map<String, dynamic>>();
    return [
      for (final block in blocks)
        PolicyBlockData(
          kind: block['kind']! as String,
          text: block['text']! as String,
        ),
    ];
  }
}
