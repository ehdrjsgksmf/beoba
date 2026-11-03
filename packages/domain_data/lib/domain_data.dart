/// 버바 도메인 데이터 — 모델 · 로더 · 스키마 검증.
///
/// 순수 Dart. Flutter 에 의존하지 않는다.
/// dart:io 가 필요하면 `package:domain_data/io.dart` 를 따로 임포트한다.
library;

export 'src/common/article_ref.dart';
export 'src/common/converters.dart';
export 'src/common/json_map.dart';
export 'src/common/approx_date.dart';
export 'src/common/kst_date.dart';
export 'src/loader/domain_loader.dart';
export 'src/loader/domain_source.dart';
export 'src/loader/load_report.dart';
export 'src/model/amount_variant.dart';
export 'src/model/broker.dart';
export 'src/model/channels.dart';
export 'src/model/cost_formula.dart';
export 'src/model/cost_item.dart';
export 'src/model/deadline.dart';
export 'src/model/document_item.dart';
export 'src/model/domain.dart';
export 'src/model/domain_detect.dart';
export 'src/model/domain_group.dart';
export 'src/model/empty_section.dart';
export 'src/model/enums.dart';
export 'src/model/glossary.dart';
export 'src/model/hard_stop.dart';
export 'src/model/jurisdiction_rule.dart';
export 'src/model/fee_schedule.dart';
export 'src/model/holiday.dart';
export 'src/model/legal_basis.dart';
export 'src/model/limit_formula.dart';
export 'src/model/limit_rule.dart';
export 'src/model/limitation_rule.dart';
export 'src/model/caution.dart';
export 'src/model/jurisdiction_guide.dart';
export 'src/model/exclusive_group.dart';
export 'src/model/missing_guide.dart';
export 'src/model/plain_korean.dart';
export 'src/model/procedure.dart';
export 'src/model/court_term.dart';
export 'src/model/question.dart';
export 'src/model/resource.dart';
export 'src/model/verification.dart';
export 'src/model/welfare.dart';
export 'src/model/welfare_bridge.dart';
export 'src/validate/schema_issue.dart';
export 'src/validate/schema_validator.dart';
