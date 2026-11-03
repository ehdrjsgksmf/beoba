import 'package:domain_data/domain_data.dart';

import '../core/keyword_match.dart';
import '../core/korean_amount.dart';

/// 자유 입력에서 알아챈 것.
class DetectedDomain {
  const DetectedDomain({required this.domainId, required this.prefill});

  final String domainId;

  /// 질문 id → 미리 채울 답. **비어 있을 수 있다.**
  final Map<String, Object?> prefill;

  @override
  String toString() => 'DetectedDomain($domainId, $prefill)';
}

/// **고르는 게 아니라 후보를 좁힌다.**
///
/// 걸린 분야가 하나면 「이렇게 이해했어요」로 확인받고, 둘 이상이면 그 둘만
/// 놓고 고르게 하고, 하나도 없으면 지금처럼 분야를 고르게 한다.
/// 어느 쪽이든 **바로 넘기지 않는다.**
///
/// 미리 채우는 것은 분야·역할·금액까지다. 날짜와 기한에 닿는 답은 채우지
/// 않는다 — 틀리면 사람이 그걸 믿고 안 움직인다(DECISIONS 130번).
class DomainDetectEngine {
  const DomainDetectEngine();

  /// 사용자가 쓴 문장에서 걸린 분야들. `order` 가 아니라 **분야 목록 순서**다.
  ///
  /// 준비 중(`coming_soon`) 분야도 알아챈다 — 알아채고 창구로 보내는 것이
  /// 못 알아채고 엉뚱한 분야로 끝까지 데려가는 것보다 낫다.
  List<DetectedDomain> detect(Iterable<Domain> domains, String narrative) {
    final text = narrative.trim();
    if (text.isEmpty) return const [];

    final found = <DetectedDomain>[];
    for (final domain in domains) {
      final detect = domain.detect;
      if (detect == null || detect.patterns.isEmpty) continue;

      final hit = KeywordMatch.any(
        [text],
        detect.patterns,
        exceptPatterns: detect.exceptPatterns,
      );
      if (!hit) continue;

      found.add(
        DetectedDomain(
          domainId: domain.id,
          prefill: _prefillFor(domain, detect, text),
        ),
      );
    }
    return found;
  }

  Map<String, Object?> _prefillFor(
    Domain domain,
    DomainDetect detect,
    String text,
  ) {
    final filled = <String, Object?>{};

    for (final rule in detect.prefill) {
      // **질문이 없으면 채우지 않는다.** 검증기가 막지만 화면에서도 막는다.
      final question = domain.questionById(rule.questionId);
      if (question == null) continue;

      if (rule.patterns.isNotEmpty &&
          !KeywordMatch.any([text], rule.patterns)) {
        continue;
      }

      if (rule.fromAmount) {
        final amount = _onlyAmountIn(text);
        if (amount != null) filled[rule.questionId] = amount;
        continue;
      }

      final value = rule.value;
      if (value == null) continue;
      // 선택지에 없는 값은 채우지 않는다. 데이터가 바뀌면 조용히 빠진다.
      if (question.options.every((o) => o.value != value)) continue;
      filled[rule.questionId] = value;
    }

    return filled;
  }

  /// 문장에 **딱 하나** 있는 금액. 둘 이상이면 null 이다.
  ///
  /// 「빌려준 5,000만원 중 300만원만 받았어요」에서 우리가 고르면 그건 계산이
  /// 아니라 짐작이다. 애매하면 안 채우고 사용자가 적게 한다.
  ///
  /// 단위 글자(원·만원·억원)가 붙어 있을 때만 읽는다. 「3월에 빌려줬어요」의
  /// 3을 금액으로 읽으면 안 된다.
  static int? _onlyAmountIn(String text) {
    final found = <int>{};
    for (final match in _wonPhrase.allMatches(text)) {
      final amount = parseKoreanWon(match.group(0)!, unit: 1);
      if (amount == null) continue;
      found.add(amount.won);
      if (found.length > 1) return null;
    }
    return found.isEmpty ? null : found.first;
  }
}

/// 금액으로 읽을 수 있는 조각. **단위 글자로 끝나야 한다.**
final RegExp _wonPhrase = RegExp(
  r'[0-9\s,]*[0-9일이삼사오육칠팔구십백천만억][0-9일이삼사오육칠팔구십백천억\s,]*'
  r'(?:만\s?원|억\s?원|원)',
);
