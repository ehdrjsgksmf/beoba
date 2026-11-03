import 'package:test/test.dart';

import 'support/domain_assets.dart';

/// 도메인 JSON 은 이 앱이 AI 를 쓴다고 말하지 않는다 (DECISIONS 32번).
///
/// M1 은 도메인 JSON 과 결정론적 엔진뿐이다. 같은 입력에 언제나 같은 답이 나온다.
/// 안 쓰는 것을 쓴다고 적으면 "AI 가 지어내지 않는다" 는 제품의 안전 논리가
/// 데이터에서부터 무너진다.
///
/// 실제로 `hs_court_document.message` 가 "AI가 정리한 정보만으로..." 라고 말하고
/// 있었다. 화면 문구를 고쳐도 JSON 이 남아 있으면 그대로 사용자에게 나간다.
///
/// **필드 목록을 세지 않고 파일 전문을 본다.** 어느 필드가 화면에 나가는지는
/// 시간이 지나면 바뀌지만, 파일 전체를 보면 목록이 어긋날 일이 없다.
/// `note` 처럼 화면에 안 나가는 필드도 함께 지킨다 — 거기가 다음 문구의 출처다.
///
/// **되돌릴 조건** — 생성형 AI 를 제품에 넣는 시점. 그때는 이 테스트를 지우는 것이
/// 아니라 **AI기본법 제31조를 다시 읽고** 무엇을 고지해야 하는지부터 확인한다.
void main() {
  final banned = <RegExp>[
    RegExp(r'\bAI\b'),
    RegExp('인공지능'),
    RegExp('챗봇'),
    RegExp(r'\bGPT\b', caseSensitive: false),
    RegExp('생성형'),
  ];

  for (final file in domainAssetFiles()) {
    final name = file.uri.pathSegments.last;

    test('$name — AI 를 쓴다고 말하지 않는다', () {
      final source = file.readAsStringSync();

      for (final pattern in banned) {
        final match = pattern.firstMatch(source);
        expect(
          match,
          isNull,
          reason: '$name 에 "${match?.group(0)}" 가 있습니다. '
              'M1 은 AI 를 쓰지 않습니다 (DECISIONS 32번).',
        );
      }
    });
  }
}
