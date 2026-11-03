import 'package:domain_data/domain_data.dart';

import 'case_facts.dart';

/// 모든 엔진은 순수 함수다. 네트워크·LLM 호출이 없다.
///
/// 엔진은 어떤 분야인지 알지 못한다. [Domain] 에 실린 데이터만 읽는다.
abstract interface class Engine<TOut> {
  TOut compute(Domain domain, CaseFacts facts);
}
