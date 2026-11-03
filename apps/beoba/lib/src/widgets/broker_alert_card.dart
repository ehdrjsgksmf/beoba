import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show scopeFor;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../defense/broker_watch.dart';
import '../providers/broker_providers.dart';
import '../providers/interview_providers.dart';
import '../safety/safe_text.dart';
import 'agency_notice_line.dart';
import 'legal_basis_card.dart';
import 'section_card.dart';

/// ② 방어 — 브로커가 한 말을 그대로 되짚어 준다.
///
/// ## 말은 전부 데이터에서 온다
///
/// `phrase`(브로커가 하는 말) · `truth`(실제로 어떻게 되는지) · 조문 · 창구.
/// **새 문구를 만들지 않는다.** 데이터가 이미 선을 지키고 있다 —
/// 사용자를 탓하지 않고, 되돌릴 수 있다고 단정하지 않는다.
///
/// ## `phrase` 는 사용자가 한 말이 아니다
///
/// 사용자는 그 말을 **옮겨 적은 것**이다. 「~라고 하셨네요」로 쓰면 사용자가 한
/// 말이 되고, 그건 사실이 아닌 데다 탓하는 것처럼 읽힌다. 그래서 머리글이
/// 「혹시 이런 말 들으셨나요?」이고 `phrase` 는 인용부호 안에 둔다.
class BrokerAlertCard extends StatelessWidget {
  const BrokerAlertCard({required this.warning, this.onDismiss, super.key});

  final BrokerWarning warning;

  /// 닫기. 결과 화면에서는 주지 않는다 — 거기서는 닫히지 않는다.
  final VoidCallback? onDismiss;

  static const String heading = '혹시 이런 말 들으셨나요?';

  /// 멈춰 세우는 경보의 머리글.
  ///
  /// **덜 중요해서 인라인이 아니다.** 조문·창구·`truth` 는 양쪽에 똑같이
  /// 붙는다. 다른 것은 화면을 멈추느냐뿐이고, 멈추는 기준은 「사용자 본인이
  /// 형사처벌 대상이 되거나 지금 움직이면 되돌릴 수 있는 것」이다.
  static const String stopHeading = '이건 그냥 넘기지 마세요';
  static const String close = '닫기';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final alert = warning.alert;
    // 축이 둘이라 표현도 둘로 나눈다 — **색은 법률 위험도, 크기는 화면 무게.**
    final stop = warning.isStop;
    final risky = warning.isHighRisk;
    final action = alert.action;

    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: SectionCard(
        background: risky ? BeobaColors.redSoft : BeobaColors.amberSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 색만으로 알리지 않는다. 아이콘과 한글 라벨을 함께 단다.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  risky ? Icons.report_outlined : Icons.warning_amber_outlined,
                  size: stop ? 21 : 18,
                  color: risky ? BeobaColors.red : BeobaColors.severityWarning,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: SafeText(
                    stop ? stopHeading : heading,
                    where: 'BrokerAlertCard.heading',
                    style: (stop ? theme.titleMedium : theme.labelLarge)
                        ?.copyWith(
                      color: risky
                          ? BeobaColors.red
                          : BeobaColors.severityWarning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: close,
                    icon: const Icon(Icons.close, size: 20),
                    color: BeobaColors.ink3,
                    onPressed: onDismiss,
                  ),
              ],
            ),
            if (stop) ...[
              const SizedBox(height: 4),
              SafeText(
                heading,
                where: 'BrokerAlertCard.heading',
                style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
              ),
            ],
            const SizedBox(height: 8),
            _Quoted(phrase: alert.phrase),
            const SizedBox(height: 11),
            SafeText(
              alert.truth,
              where: 'BrokerAlert.truth',
              // 검수된 인용이다. strict 로 보면 「불법입니다」가 막힌다.
              scope: scopeFor('BrokerAlert', 'truth'),
              style: (stop ? theme.bodyMedium : theme.labelMedium)?.copyWith(
                color: BeobaColors.ink2,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              _ActionButton(action: action, risky: risky),
            ],
            // **판단에 쓰는 조문 하나는 접지 않는다.** 그 자리에서 읽어야 한다.
            if (alert.legalBasis case final LegalBasis basis) ...[
              const SizedBox(height: 12),
              LegalBasisCard(
                basis: basis,
                where: 'BrokerAlert.${alert.id}',
                collapsible: false,
              ),
            ],
            // **조문이 아닌 것에는 조문 딱지를 안 단다.** 네 번째 층이다 —
            // 신복위 신청비처럼 기관 공지가 근거인 자리가 있고, 그 사실
            // 자체가 이 항목의 정보다(DECISIONS 245).
            if (alert.notice case final notice?) ...[
              const SizedBox(height: 12),
              AgencyNoticeLine(notice: notice),
            ],
            // **사슬은 접는다.** 채권추심은 「추심업이란」 → 「대상 채권이란」 →
            // 시행령 → 민사집행법의 **네 단**이다. 다 펼치면 경보 하나가 화면
            // 두 장을 넘고, 그러면 정작 읽어야 할 `truth` 가 안 보인다.
            //
            // 접혀도 **조문 이름과 🟢 라벨은 남는다.** 무엇을 근거로 하는지는
            // 보이고, 검산하려는 사람만 한 번 더 누른다.
            for (final (index, also) in alert.alsoBasis.indexed) ...[
              const SizedBox(height: 10),
              LegalBasisCard(
                basis: also,
                where: 'BrokerAlert.${alert.id}.also$index',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 브로커가 한 말. **인용부호 안에 둔다.**
class _Quoted extends StatelessWidget {
  const _Quoted({required this.phrase});

  final String phrase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: const BoxDecoration(
        color: Color(0xBFFFFFFF),
        border: Border(left: BorderSide(color: Color(0x21000000), width: 3)),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: SafeText(
        phrase,
        where: 'BrokerAlert.phrase',
        // 사기꾼이 하는 말의 인용이다. 앱의 주장이 아니다.
        scope: scopeFor('BrokerAlert', 'phrase'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

/// 창구 버튼. **「신고하세요」를 앞세우지 않는다** — 말은 `action.label` 이 한다.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.risky});

  final ActionRef action;

  /// 법률 위험도. **창구는 무게와 무관하게 언제나 붙는다.**
  final bool risky;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final phone = action.phone;
    final url = action.url;
    final color = risky ? BeobaColors.red : BeobaColors.brand;

    return Semantics(
      button: true,
      label: '${action.label} ${phone ?? ''}',
      child: InkWell(
        onTap: () => _open(phone, url),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: BeobaTapTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(phone != null ? Icons.call : Icons.open_in_new,
                  size: 20, color: color),
              const SizedBox(width: 9),
              SafeText(
                action.label,
                where: 'ActionRef.label',
                style: theme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (phone != null) ...[
                const SizedBox(width: 10),
                SafeText(
                  phone,
                  where: 'ActionRef.phone',
                  style: theme.titleMedium?.copyWith(
                    fontSize: 20,
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 걸리지 않아도 화면의 번호는 그대로 남는다. 실패를 사용자에게 떠넘기지 않는다.
  Future<void> _open(String? phone, String? url) async {
    final uri = phone != null
        ? Uri(scheme: 'tel', path: phone.replaceAll('-', ''))
        : url != null
            ? Uri.parse(url)
            : null;
    if (uri == null) return;
    await launchUrl(uri).catchError((_) => false);
  }
}

/// 인터뷰 중에 그 자리에 뜨는 경보. 닫으면 그 화면에서만 물러난다.
class BrokerAlerts extends ConsumerWidget {
  const BrokerAlerts({required this.domainId, super.key});

  final String domainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(openBrokerWarningsProvider(domainId));
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final warning in warnings)
          BrokerAlertCard(
            warning: warning,
            onDismiss: () => ref
                .read(interviewSessionProvider(domainId).notifier)
                .dismissSignal(warning.id),
          ),
      ],
    );
  }
}

/// 결과 화면. **지나오면서 걸린 것을 모아서 다시 보여준다.**
///
/// 접히지 않고 닫히지도 않는다 — 위기 창구와 같은 예외다.
/// 다만 걸린 게 없으면 **자리조차 만들지 않는다.** 「해당 없음」을 보여주면
/// 카드 다섯 장 규칙만 깎아먹는다.
class BrokerAlertSection extends ConsumerWidget {
  const BrokerAlertSection({required this.domainId, super.key});

  final String domainId;

  static const String heading = '이런 말을 들으셨다면';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(allBrokerWarningsProvider(domainId));
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(heading, icon: Icons.shield_outlined),
        for (final warning in warnings) BrokerAlertCard(warning: warning),
      ],
    );
  }
}
