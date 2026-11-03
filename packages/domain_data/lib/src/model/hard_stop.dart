import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'hard_stop.freezed.dart';
part 'hard_stop.g.dart';

/// 무엇이 하드스톱을 발동시키는지.
sealed class HardStopTrigger {
  const HardStopTrigger();

  factory HardStopTrigger.fromJson(JsonMap json) {
    final type = json['type'];
    return switch (type) {
      'keyword' => KeywordHardStopTrigger.fromJson(json),
      'field' => FieldHardStopTrigger.fromJson(json),
      _ => throw FormatException('알 수 없는 하드스톱 trigger type: $type'),
    };
  }

  String get type;

  JsonMap toJson();
}

/// 사용자가 쓴 표현에 이 단어가 있으면 발동.
class KeywordHardStopTrigger extends HardStopTrigger {
  const KeywordHardStopTrigger({
    this.patterns = const [],
    this.exceptPatterns = const [],
  });

  factory KeywordHardStopTrigger.fromJson(JsonMap json) =>
      KeywordHardStopTrigger(
        patterns: _strings(json['patterns']),
        exceptPatterns: _strings(json['exceptPatterns']),
      );

  static List<String> _strings(Object? raw) => List<String>.unmodifiable(
        (raw as List<dynamic>? ?? const []).map((p) => p as String),
      );

  final List<String> patterns;

  /// 이 낱말이 히트를 **덮고 있으면** 그 히트만 무효.
  ///
  /// 좁혀도 남는 것이 있다 — `자살` 을 `자살하` 로 좁혀도 `자살예방` 은 걸린다.
  /// 다른 패턴의 히트는 살아 있어야 한다.
  final List<String> exceptPatterns;

  @override
  String get type => 'keyword';

  @override
  JsonMap toJson() => {
        'type': type,
        'patterns': patterns,
        if (exceptPatterns.isNotEmpty) 'exceptPatterns': exceptPatterns,
      };
}

/// 특정 필드가 특정 값이면 발동. 예: `hasCourtDocument == true`
class FieldHardStopTrigger extends HardStopTrigger {
  const FieldHardStopTrigger({required this.field, this.equalsValue});

  factory FieldHardStopTrigger.fromJson(JsonMap json) => FieldHardStopTrigger(
        field: json['field'] as String,
        equalsValue: json['equals'],
      );

  final String field;
  final Object? equalsValue;

  @override
  String get type => 'field';

  @override
  JsonMap toJson() => {'type': type, 'field': field, 'equals': equalsValue};
}

class HardStopTriggerConverter
    implements JsonConverter<HardStopTrigger, JsonMap> {
  const HardStopTriggerConverter();

  @override
  HardStopTrigger fromJson(JsonMap json) => HardStopTrigger.fromJson(json);

  @override
  JsonMap toJson(HardStopTrigger object) => object.toJson();
}

/// 여기서 멈춘다. 형사 사건 등 다루지 않는 영역.
///
/// 검증 필드가 없다 — 판단을 담지 않고 **공적 창구로 넘기기만** 하기 때문이다.
@freezed
abstract class HardStop with _$HardStop {
  const factory HardStop({
    required String id,
    @HardStopTriggerConverter() required HardStopTrigger trigger,
    required String screen,
    String? title,
    String? message,
    @Default(<String>[]) List<String> checklist,

    /// 연결할 `PublicChannel` id 목록.
    @Default(<String>[]) List<String> channels,

    /// 낱말 검사의 **정답지**. 키워드 트리거면 비어 있을 수 없다.
    @Default(<KeywordTest>[]) List<KeywordTest> tests,
  }) = _HardStop;

  factory HardStop.fromJson(JsonMap json) => _$HardStopFromJson(json);
}

/// 낱말 검사 정답지 한 줄.
///
/// **음성 사례가 양성보다 많아야 정상이다.** 문자열 매칭은 놓치는 것보다 잘못 잡는
/// 것이 더 나쁘고, 잘못 잡는 것은 사람이 문장을 써 보기 전에는 드러나지 않는다.
@freezed
abstract class KeywordTest with _$KeywordTest {
  const factory KeywordTest({
    /// 사용자가 썼다고 가정하는 문장.
    required String text,

    /// 이 문장에서 걸려야 하는가.
    required bool expected,
  }) = _KeywordTest;

  factory KeywordTest.fromJson(JsonMap json) => _$KeywordTestFromJson(json);
}
