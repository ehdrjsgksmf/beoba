import 'package:engines/engines.dart' show SessionTally;
import 'package:shared_preferences/shared_preferences.dart';

/// 집계를 보내는 자리. **구현체를 갈아 끼울 수 있게 인터페이스 하나 뒤에 둔다.**
///
/// `NotificationService` 를 추상화한 것과 같은 이유다 — 지금은 아무 데도
/// 안 보내고, 받는 곳이 정해지면 여기만 바꾼다.
///
/// **분석 SDK 를 붙이지 않는다.** Google Analytics 같은 것을 넣는 순간 우리가
/// 통제하지 못하는 값이 같이 나간다. 보내는 것은 [SessionTally] 의 다섯 칸뿐이고
/// 그건 우리가 직접 만든다(DECISIONS 136번).
abstract interface class TallySink {
  /// 실패하면 **조용히 넘어간다.** 세는 것 때문에 화면이 멈추면 안 된다.
  Future<void> send(SessionTally tally);
}

/// 받는 곳이 아직 없다. **아무 데도 안 보낸다.**
///
/// 엔드포인트가 정해지면 이 자리에 HTTP 구현체가 들어온다. 그때까지 앱은
/// 네트워크를 부르지 않는다.
class NoopTallySink implements TallySink {
  const NoopTallySink();

  @override
  Future<void> send(SessionTally tally) async {}
}

/// 「세도 되는지」 답 하나. **기기에 남기는 것은 이것과 쉬운 말 켜짐 하나뿐이다**
/// (`PlainModeStore`, DECISIONS 289번).
///
/// 매번 물으면 성가시다. 그래서 이 한 칸만 남기고, 그 사실도 「자세히」
/// 시트에 적는다 — 남기는 것이 있으면 말한다.
abstract interface class ConsentStore {
  /// 아직 안 물어봤으면 null.
  Future<bool?> read();

  Future<void> write(bool allowed);
}

/// 기기에 남긴다. 이 저장소의 값은 하나뿐이다.
class PrefsConsentStore implements ConsentStore {
  const PrefsConsentStore();

  static const String key = 'tally_consent';

  @override
  Future<bool?> read() async =>
      (await SharedPreferences.getInstance()).getBool(key);

  @override
  Future<void> write(bool allowed) async =>
      (await SharedPreferences.getInstance()).setBool(key, allowed);
}

/// 테스트와 첫 실행용. 아무것도 남기지 않는다.
class MemoryConsentStore implements ConsentStore {
  MemoryConsentStore([this._allowed]);

  bool? _allowed;

  @override
  Future<bool?> read() async => _allowed;

  @override
  Future<void> write(bool allowed) async => _allowed = allowed;
}
