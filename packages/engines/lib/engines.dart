/// 버바 계산 엔진.
///
/// 순수 Dart. **Flutter 에 의존하지 않는다.** 분야를 알지 못한다.
/// 법률 수치는 하나도 들어 있지 않다 — 전부 도메인 JSON 에서 읽는다.
library;

// 엔진 결과를 읽으려면 이 타입들이 필요하다. 함께 내보낸다.
export 'package:domain_data/domain_data.dart'
    show Domain, Importance, KstDate, LegalBasis, Severity, VerificationStatus;

export 'src/core/case_facts.dart';
export 'src/core/engine.dart';
export 'src/core/json_logic.dart';
export 'src/core/korean_amount.dart';
export 'src/core/kst_clock.dart';
export 'src/core/josa.dart';
export 'src/core/term_markup.dart';
export 'src/core/keyword_match.dart';
export 'src/core/money.dart';
export 'src/core/user_text.dart';
export 'src/cost/cost_engine.dart';
export 'src/cost/cost_result.dart';
export 'src/deadline/civil_period.dart';
export 'src/deadline/deadline_engine.dart';
export 'src/deadline/holiday_table.dart';
export 'src/deadline/deadline_result.dart';
export 'src/document/document_engine.dart';
export 'src/interview/domain_detect_engine.dart';
export 'src/interview/interview_engine.dart';
export 'src/tally/session_tally.dart';
export 'src/jurisdiction/court_lookup_table.dart';
export 'src/jurisdiction/jurisdiction_engine.dart';
export 'src/limit/limit_checker.dart';
export 'src/limit/limit_result.dart';
export 'src/procedure/near_miss.dart';
export 'src/report/engine_report.dart';
export 'src/safety/safety_field_scopes.dart';
export 'src/safety/safety_filter.dart';
export 'src/validate/content_validator.dart';
export 'src/validate/citation_audit.dart';
export 'src/validate/plain_korean_check.dart';
export 'src/validate/legal_jargon.dart';
export 'src/validate/object_honorific.dart';
