import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'hard_stop.dart';
import 'verification.dart';
import 'welfare.dart';

part 'channels.freezed.dart';
part 'channels.g.dart';

/// ① 위기 — 공적 창구. 전화번호만 표시한다. **AI 판단 0.**
@freezed
abstract class PublicChannel with _$PublicChannel implements Verifiable {
  const factory PublicChannel({
    required String id,

    /// true 면 다른 모든 화면을 덮고 최우선 표시.
    @Default(false) bool priority,
    @Default('') String label,
    String? org,
    String? phone,
    String? url,
    String? note,
    /// **기관이 알려 준 것이면 딱지를 단다** — 네 번째 층([AgencyNotice]).
    ///
    /// 조문이 아닌 금액·절차가 여기 있을 수 있다. 신용회복위원회 채무조정
    /// 신청비가 그렇다 — 법령이 아니라 기관 공지다. 그 사실 자체가 이 항목의
    /// 정보이므로 숨기지 않고 **어디서 왔는지 적는다.**
    ///
    /// 검사 (aa)가 이 딱지를 본다 — 딱지가 있으면 그 금액을 조문 인용 대신
    /// 「기관 이름 + 확인한 날」로 견준다.
    AgencyNotice? notice,
    required Verification verification,
  }) = _PublicChannel;

  factory PublicChannel.fromJson(JsonMap json) => _$PublicChannelFromJson(json);
}

/// 도메인의 `publicChannels` 항목.
///
/// 분야 JSON 은 id 문자열만 적고(`"klac_132"`), `_shared_crisis.json` 은
/// 전체 객체를 담는다. 둘 다 받는다.
sealed class PublicChannelEntry {
  const PublicChannelEntry();

  factory PublicChannelEntry.fromJson(Object? json) {
    if (json is String) return PublicChannelRef(json);
    if (json is Map) {
      return PublicChannelFull(
        PublicChannel.fromJson(Map<String, dynamic>.from(json)),
      );
    }
    throw FormatException('publicChannels 항목은 문자열 id 또는 객체여야 합니다', json);
  }

  /// 참조든 전체 객체든 id 는 항상 있다.
  String get id;

  Object toJson();
}

class PublicChannelRef extends PublicChannelEntry {
  const PublicChannelRef(this.id);

  @override
  final String id;

  @override
  Object toJson() => id;

  @override
  bool operator ==(Object other) => other is PublicChannelRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PublicChannelRef($id)';
}

class PublicChannelFull extends PublicChannelEntry {
  const PublicChannelFull(this.channel);

  final PublicChannel channel;

  @override
  String get id => channel.id;

  @override
  Object toJson() => channel.toJson();

  @override
  bool operator ==(Object other) =>
      other is PublicChannelFull && other.channel == channel;

  @override
  int get hashCode => channel.hashCode;

  @override
  String toString() => 'PublicChannelFull(${channel.id})';
}

class PublicChannelEntryConverter
    implements JsonConverter<PublicChannelEntry, Object?> {
  const PublicChannelEntryConverter();

  @override
  PublicChannelEntry fromJson(Object? json) => PublicChannelEntry.fromJson(json);

  @override
  Object toJson(PublicChannelEntry object) => object.toJson();
}

/// ② 방어 — 사용자가 직접 조회해 볼 수 있는 공식 사이트.
@freezed
abstract class LookupTool with _$LookupTool implements Verifiable {
  const factory LookupTool({
    required String id,
    required String label,
    String? org,
    required String url,
    String? hint,
    required Verification verification,
  }) = _LookupTool;

  factory LookupTool.fromJson(JsonMap json) => _$LookupToolFromJson(json);
}

/// 특정 표현이 나오면 자동으로 창구를 띄운다. **앱은 해석하지 않고 낱말만 본다.**
@freezed
abstract class AutoTrigger with _$AutoTrigger {
  const factory AutoTrigger({
    required String id,
    @Default(false) bool priority,
    @Default(<String>[]) List<String> patterns,

    /// 이 낱말이 히트를 **덮고 있으면** 그 히트만 무효.
    ///
    /// 패턴을 좁혀도 남는 것이 있다 — `자살하` 로 좁혀도 `자살하는 사람을 돕는`
    /// 같은 문장은 걸린다. 다른 패턴의 히트는 살아 있어야 한다.
    @Default(<String>[]) List<String> exceptPatterns,

    /// 띄울 `PublicChannel` id 목록.
    @Default(<String>[]) List<String> show,

    /// 낱말 검사의 **정답지. 비어 있으면 빌드 실패.**
    @Default(<KeywordTest>[]) List<KeywordTest> tests,
    String? note,
  }) = _AutoTrigger;

  factory AutoTrigger.fromJson(JsonMap json) => _$AutoTriggerFromJson(json);
}

/// 전화번호 형태만으로 붙일 수 있는 경고. 역조회 Level 1.
@freezed
abstract class PhoneRiskRule with _$PhoneRiskRule {
  const factory PhoneRiskRule({
    required String id,

    /// 정규식.
    required String match,
    required String flag,
    @Default('') String message,

    /// 이 맥락에서만 적용한다. 비어 있으면 항상.
    @Default(<String>[]) List<String> context,
  }) = _PhoneRiskRule;

  factory PhoneRiskRule.fromJson(JsonMap json) => _$PhoneRiskRuleFromJson(json);
}
