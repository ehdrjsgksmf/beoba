import 'package:shared_preferences/shared_preferences.dart';

/// 「쉬운 말로 보기」를 골랐는지 — **기기에 남기는 두 번째 값이다**
/// (DECISIONS 289번).
///
/// 껐다 켤 때마다 다시 꺼지면, 어려운 문장이 안 읽히는 분이 매번 스위치부터
/// 찾아야 한다. 그런데 그 스위치도 글자다. 그래서 한 번 고른 것을 기억한다.
///
/// ★ 남기는 것은 켜짐/꺼짐 하나뿐이다. 적으신 내용은 여기에 없다.
/// 개인정보처리방침 1절이 이 사실을 말하고, 검사 (ah) 가 키를 센다.
abstract interface class PlainModeStore {
  /// 아직 한 번도 안 고르셨으면 null.
  Future<bool?> read();

  Future<void> write(bool on);
}

/// 기기에 남긴다.
class PrefsPlainModeStore implements PlainModeStore {
  const PrefsPlainModeStore();

  static const String key = 'plain_mode';

  @override
  Future<bool?> read() async =>
      (await SharedPreferences.getInstance()).getBool(key);

  @override
  Future<void> write(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(key, on);
}

/// 테스트용. 아무것도 남기지 않는다.
class MemoryPlainModeStore implements PlainModeStore {
  MemoryPlainModeStore([this._on]);

  bool? _on;

  @override
  Future<bool?> read() async => _on;

  @override
  Future<void> write(bool on) async => _on = on;
}
