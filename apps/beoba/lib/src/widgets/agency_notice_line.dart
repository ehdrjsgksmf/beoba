import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show scopeFor;
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// **네 번째 층의 딱지 — 「기관이 알려 준 것」.**
///
/// 🟢/🟡/🔴 어디에도 안 들어간다. 조문이 아니기 때문이다. 그래서 색도
/// 그 셋을 안 쓴다 — [BeobaColors.surfaceSoft] 회색이다. 초록 옆에 두면
/// 그 자리에서 「법에 적힌 것만 말한다」가 깨진다.
///
/// **문장은 [AgencyNotice.sentence] 가 만든다.** 여기서 조립하지 않는다 —
/// 화면마다 조립하면 어느 화면이 날짜를 빼먹었는지 알 수 없게 된다.
///
/// 이 위젯은 [notice] 없이 만들 수 없다. `LegalBasisCard` 가 `legalBasis`
/// 없이 못 만들어지는 것과 같은 자리다.
class AgencyNoticeLine extends StatelessWidget {
  const AgencyNoticeLine({required this.notice, super.key}) : sentence = null;

  /// 목록 **머리**에 놓는 줄. 건마다 기관이 달라 한 곳을 적을 수 없다.
  ///
  /// 문장은 [CentralWelfareCatalog.sentence] 가 만든다 — 이쪽도 받은 날짜가
  /// 필수 필드라 날짜 없는 줄이 나갈 수 없다.
  AgencyNoticeLine.forCatalog({
    required CentralWelfareCatalog catalog,
    super.key,
  })  : sentence = catalog.sentence,
        notice = null;

  /// 항목 하나의 출처. 목록 머리에서는 null 이다.
  final AgencyNotice? notice;

  /// 자료 전체의 출처 한 줄. 항목에서는 null 이다.
  final String? sentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: BeobaColors.surfaceStrong,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: BeobaColors.ink3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SafeText(
              sentence ?? notice!.sentence,
              where: 'AgencyNotice.sentence',
              // 기관 이름이 문장 안에 들어간다.
              scope: scopeFor('AgencyNotice', 'agency'),
              style: theme.labelMedium?.copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
