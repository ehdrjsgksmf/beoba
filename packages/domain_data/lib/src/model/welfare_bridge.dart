import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'welfare_bridge.freezed.dart';
part 'welfare_bridge.g.dart';

/// **법률과 복지가 만나는 자리.**
///
/// 복지로는 사용자가 왜 왔는지 모른다. 우리는 안다 — 임금이 밀렸다는 것을
/// 이미 알고 있으니 그 사람에게 걸리는 제도를 바로 놓을 수 있다.
/// **이 앱만 할 수 있는 자리**이고, 그래서 조심해서 놓아야 한다.
///
/// ## 짐작으로 잇지 않는다
///
/// 잇는 기준은 하나뿐이다 — **제도 쪽 근거법령(`baslawList`)의 이름이 여기
/// 적은 이름과 맞는가.** 주제가 비슷해 보인다는 이유로는 안 잇는다.
///
/// ```
/// ⭕ 임금채권보장법이 이 분야의 근거이고, 대지급금의 근거법령도 그 법이다
/// ✘ 보증금을 못 받았으니 「내집마련 디딤돌 대출」도 주거니까 걸어 두자
/// ```
///
/// 뒤엣것을 하면 그 순간 **우리가 만든 안내**가 된다. 그리고 틀렸을 때
/// 어디서 틀렸는지 되짚을 수가 없다.
///
/// ## 조건 없는 약속을 하지 않는다
///
/// 여기 걸린 제도는 「해당된다」가 아니라 「이런 것들이 있다」까지다.
/// 해당하는지는 그쪽에서 본다. [why] 도 그렇게 적는다.
@freezed
abstract class WelfareBridge with _$WelfareBridge {
  const factory WelfareBridge({
    /// **왜 이 법령들이 이 분야와 이어지는가.** 비어 있으면 빌드가 깨진다.
    ///
    /// 목록만 남기면 다음 사람이 「비슷하니까 하나 더 넣자」를 한다.
    required String why,

    /// 이어 볼 근거법령 이름. **매니페스트에 있는 이름이어야 한다.**
    @Default(<String>[]) List<String> laws,
  }) = _WelfareBridge;

  factory WelfareBridge.fromJson(JsonMap json) => _$WelfareBridgeFromJson(json);
}
