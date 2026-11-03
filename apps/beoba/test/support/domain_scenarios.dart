import 'package:beoba/src/providers/domain_providers.dart';
import 'package:engines/engines.dart' show KstDate;

import 'test_app.dart';

/// **화면 검사가 도는 갈래 표. 한 곳에만 둔다.**
///
/// 밀도(`result_density_test`) · 가로 넘침(`result_scale_test`) · 쉬운 말
/// (`plain_density_test`)이 각자 자기 표를 들고 있었다. 그래서 분야가 늘 때
/// **어느 한 곳만 고쳐지고 나머지는 조용히 뒤처졌다** — 산재가 가로 넘침에서,
/// 양육비가 셋 중 둘에서 빠져 있었다.
///
/// 표는 여기 하나뿐이고, `domain_coverage.dart` 가 이 표가 열셋을 다 덮는지
/// 본다. 새 분야를 지으면 **여기 한 줄을 더하는 것으로 셋이 같이 늘어난다.**
///
/// 답은 갈래마다 다르다 — 「잘 모르겠어요」로만 채우면 가장 무거운 갈래를
/// 아무도 안 본다. 그래서 분야에 따라 두 줄씩 있는 것이 있다.
const screenScenarios = <String, (String, Map<String, Object?>)>{
  '떼인 돈 · 받을 쪽': (kDebtRecoveryDomainId, completeAnswers),
  '떼인 돈 · 갚을 쪽': (
    kDebtRecoveryDomainId,
    {
      'q_role': 'debtor',
      'q_debtor_situation': 'seizure',
      'q_seizure_when': 'after',
      // 2026-09-04 부터 갚는 쪽에게도 「법원 서류를 받았나」를 묻는다.
      // 안 받았다고 답한 갈래다.
      'q_court_document': 'none',
    }
  ),
  // ★ **같은 사람이 서류를 받았다고 답한 갈래.** 이쪽이 급하다 — 2주를
  // 놓치면 그대로 확정된다. 예전에는 이 물음이 압류 갈래에 안 나가서
  // 여기에 닿을 길이 없었다(DECISIONS 253번).
  '떼인 돈 · 갚을 쪽 · 지급명령': (
    kDebtRecoveryDomainId,
    {
      'q_role': 'debtor',
      'q_debtor_situation': 'seizure',
      'q_seizure_when': 'after',
      'q_court_document': 'payment_order',
      'q_payment_order_served_date': KstDate(2026, 8, 10),
    }
  ),
  '상속': (
    'inheritance',
    {
      'q_known_date': KstDate(2026, 7, 1),
      'q_estate_known': 'unknown',
      'q_filer_count': 1,
      'q_deceased_address': '서울특별시 종로구',
      'q_was_minor': 'no',
    }
  ),
  '못 받은 임금': (
    'wage_theft',
    {
      'q_work_status': 'left',
      'q_last_work_date': KstDate(2026, 8, 1),
      'q_pay_due_date': KstDate(2026, 7, 25),
      'q_subcontract': 'no',
    }
  ),
  '전세·월세 보증금': (
    'deposit_return',
    {
      'q_still_living': 'yes',
      'q_move_in_reported': KstDate(2024, 3, 11),
      'q_fixed_date': 'same_day',
      'q_lease_ended': KstDate(2026, 6, 30),
    }
  ),
  '빚 갚기가 어려울 때': ('debt_relief', {'q_creditor_count': 5}),
  '계좌로 돈이 빠져나갔을 때': (
    'voice_phishing',
    {
      'q_role': 'victim',
      'q_money_path': 'transfer',
      'q_stop_notice_date': KstDate(2026, 8, 10),
      'q_notice_date': KstDate(2026, 8, 12),
    }
  ),
  '계좌가 막힌 쪽': (
    'voice_phishing',
    {
      'q_role': 'account_holder',
      'q_frozen_date': KstDate(2026, 8, 1),
      'q_notice_date': KstDate(2026, 8, 5),
    }
  ),
  '산 물건 무르기': (
    'consumer_withdrawal',
    {
      'q_purchase_channel': 'online',
      'q_reason': 'changed_mind',
      'q_delivery_date': KstDate(2026, 8, 10),
      'q_payment': 'card',
    }
  ),
  '산 물건 무르기 · 찾아온 판매': (
    'consumer_withdrawal',
    {
      'q_purchase_channel': 'doorstep',
      'q_contract_date': KstDate(2026, 8, 10),
      'q_reason': 'changed_mind',
      'q_payment': 'card',
    }
  ),
  '나눠서 산 물건': (
    'installment_purchase',
    {
      'q_installment_shape': 'three_plus',
      'q_installment_payee': 'lender',
      'q_installment_contract_date': KstDate(2026, 8, 10),
      'q_installment_left': 'yes',
    }
  ),
  '중고거래 · 앱 거쳐 계좌송금': (
    'secondhand_fraud',
    {
      'q_seller_type': 'individual',
      'q_via_platform': 'platform',
      'q_payment': 'bank',
      'q_know_seller': 'no',
      'q_paid_date': KstDate(2026, 8, 1),
    }
  ),
  '중고거래 · 잘 모르겠어요': (
    'secondhand_fraud',
    {
      'q_seller_type': 'unknown',
      'q_via_platform': 'unknown',
      'q_payment': 'unknown',
      'q_know_seller': 'no',
      'q_paid_date': KstDate(2026, 8, 1),
    }
  ),
  '일하다 다쳤을 때': (
    'work_injury',
    {
      'q_injury_date': KstDate(2026, 8, 1),
      'q_injury_kind': 'work',
      'q_treated_days': 'longer',
    }
  ),
  '일하다 다쳤을 때 · 잘 모르겠어요': (
    'work_injury',
    {
      'q_injury_date': KstDate(2026, 8, 1),
      'q_injury_kind': 'unknown',
      'q_treated_days': 'unknown',
    }
  ),
  '일이 끊겼을 때': (
    'unemployment_benefit',
    {
      'q_last_work_date': KstDate(2026, 8, 1),
      'q_reported': 'not_yet',
      'q_insured_months': 'under_six',
    }
  ),
  '갑자기 나가라고 했을 때': (
    'unfair_dismissal',
    {
      'q_dismissal_date': KstDate(2026, 8, 15),
      'q_workplace_size': 'five_or_more',
      'q_written_notice': 'no',
      'q_want_return': 'no',
    }
  ),
  '양육비 · 집행권원이 있을 때': (
    'child_support',
    {
      'q_order_kind': 'judgment',
      'q_talk': 'no',
      'q_where_known': 'no',
      'q_income_kind': 'salary',
      'q_court_order': 'enforce',
    }
  ),
  '양육비 · 잘 모르겠어요': (
    'child_support',
    {
      'q_order_kind': 'unknown',
      'q_talk': 'no',
      'q_where_known': 'no',
      'q_income_kind': 'unknown',
      'q_court_order': 'unknown',
    }
  ),
  '상속재산 나누기 · 이야기가 안 될 때': (
    'estate_division',
    {
      'q_stage': 'stuck',
      'q_heir_count': 3,
      'q_opponent_address': '서울특별시 종로구',
      'q_will_direction': 'none',
      'q_share_transferred': 'no',
      'q_late_heir': 'no',
    }
  ),
  '상속재산 나누기 · 잘 모르겠어요': (
    'estate_division',
    {
      'q_stage': 'unknown',
      'q_heir_count': 2,
      'q_opponent_address': '서울특별시 종로구',
      'q_will_direction': 'unknown',
      'q_share_transferred': 'unknown',
      'q_late_heir': 'unknown',
    }
  ),
  '전세사기 · 이후 계약 · 결정문 받음 · 경매 중': (
    'jeonse_fraud',
    {
      'q_first_contract': 'after',
      'q_apply_stage': 'decided',
      'q_auction': 'yes',
    }
  ),
  '전세사기 · 잘 모르겠어요': (
    'jeonse_fraud',
    {
      'q_first_contract': 'unknown',
      'q_apply_stage': 'unknown',
      'q_auction': 'unknown',
    }
  ),
  '전세사기 · 이전 계약 · 신청 전': (
    'jeonse_fraud',
    {
      'q_first_contract': 'before',
      'q_apply_stage': 'not_yet',
      'q_auction': 'no',
    }
  ),
};
