import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/crisis_providers.dart';
import '../providers/domain_providers.dart';
import '../providers/interview_providers.dart';
import '../screens/crisis/crisis_screen.dart';
import '../screens/detected/detected_screen.dart';
import '../screens/domain_select/domain_select_screen.dart';
import '../screens/domain_select/upcoming_screen.dart';
import '../screens/hardstop/hardstop_confirm_screen.dart';
import '../screens/hardstop/hardstop_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/interview/interview_screen.dart';
import '../screens/privacy/privacy_screen.dart';
import '../screens/result/result_detail_screen.dart';
import '../screens/result/result_screen.dart';
import '../screens/result/take_away_screen.dart';
import '../screens/summary/summary_screen.dart';
import '../screens/welfare/welfare_ask_screen.dart';
import '../screens/welfare/welfare_list_screen.dart';

/// 라우트 이름.
///
/// **주소에 무엇을 남기는지가 설계다.** 이 앱 사용자는 가족 공용 PC 나 PC방에서
/// 열 가능성이 높고, 홈에서 "저장되지 않습니다" 라고 약속했다. 주소창과 브라우저
/// 히스토리는 그 약속 밖에 있는 저장소다.
///
/// 그래서 **질문 id 도, 하드스톱 id 도, 트리거 id 도 URL 에 넣지 않는다.**
/// `hs_criminal` 이 남으면 형사 사건이었다는 사실이, `trg_mental` 이 남으면
/// 자살 관련 화면을 봤다는 사실이 기록으로 남는다.
/// 무엇을 보여줄지는 전부 상태에서 읽는다 — 어차피 화면이 provider 로 다시 계산한다.
abstract final class Routes {
  static const String home = '/';
  static const String domains = '/domains';

  /// 개인정보처리방침 전문. **사람의 사정이 하나도 안 실리는 주소다.**
  ///
  /// 그래서 세그먼트가 하나뿐이고, 새로고침해도 잃을 상태가 없다.
  static const String privacy = '/privacy';

  /// 묶음 하나를 연 화면. **묶음 id 는 공개 정보다** — 어느 묶음을 눌렀는지는
  /// 그 사람의 사정이 아니라 우리 목록의 구조다.
  static String domainGroup(String groupId) => '/domains/g/$groupId';

  /// 두 번째 문 — 복지. **답은 주소에 안 싣는다.**
  ///
  /// 태어난 해와 가구상황이 주소에 남으면 가족 공용 PC 의 히스토리에
  /// 그 사람의 나이와 형편이 그대로 남는다. 분야 흐름과 같은 규칙이다.
  static String welfare([String? fromDomainId]) => fromDomainId == null
      ? '/welfare'
      : '/welfare?$kFromDomain=$fromDomainId';
  static String welfareList([String? fromDomainId]) => fromDomainId == null
      ? '/welfare/list'
      : '/welfare/list?$kFromDomain=$fromDomainId';

  /// 질문은 **순번**으로만 가리킨다. 순번은 리플레이로 흔들리지만 가드가 교정한다.
  static String interview(String domainId, [int? step]) =>
      step == null ? '/interview/$domainId' : '/interview/$domainId/$step';

  static String summary(String domainId) => '/summary/$domainId';
  static String result(String domainId) => '/result/$domainId';

  /// 상세. 요약에서 눌러서 들어간다.
  static String resultDetail(String domainId) => '/result/$domainId/detail';

  /// 정리해서 가져가는 글 한 장.
  static String takeAway(String domainId) => '/result/$domainId/sheet';

  /// 「이렇게 이해했어요」. 자유 입력에서 분야 하나만 걸렸을 때 거친다.
  static String detected(String domainId) => '/detected/$domainId';

  /// 준비 중 분야 안내. 분야 id 는 공개 정보라 주소에 남아도 된다.
  static String upcoming(String domainId) => '/upcoming/$domainId';

  static String hardStopConfirm(String domainId) => '/hardstop/$domainId/confirm';
  static String hardStop(String domainId) => '/hardstop/$domainId';
  static String crisis(String domainId) => '/crisis/$domainId';

  /// 경로에서 domainId 를 꺼낸다. 없으면 null.
  static String? domainIdOf(String location) {
    final segments = Uri.parse(location).pathSegments;
    return segments.length >= 2 ? segments[1] : null;
  }
}

/// 정리 카드에서 "고치기" 로 왔다는 표시.
///
/// **`extra` 로 나르지 않는다.** 웹에서 `extra` 는 브라우저 히스토리 state 로
/// 들어간다 — 주소창에 안 보일 뿐이다(DECISIONS 101번). 예전 주석은
/// 「주소창에도 히스토리에도 남지 않는다」고 적고 있었는데 틀린 말이었고,
/// 그 오해가 홈의 자유 입력까지 같은 길로 보냈다.
///
/// 이건 사용자가 적은 글이 아니라 켜짐/꺼짐 하나다. 질의 문자열에 둔다 —
/// 새로고침에도 살아남아 오히려 맞게 동작한다.
const String kFromSummary = 'fix';

/// 좁힌 분야 목록을 무시하고 전부 본다는 표시.
///
/// `kFromSummary` 와 같은 이유로 질의 문자열이다 — 사용자가 적은 글이 아니라
/// 켜짐/꺼짐 하나이고, 새로고침에도 살아남아야 맞다.
const String kShowAllDomains = 'all';

/// 어느 분야에서 복지 쪽으로 건너왔는지. **분야 id 는 공개 정보다.**
///
/// 답한 내용이 아니라 「어느 문으로 들어왔나」 하나뿐이라 주소에 남아도 된다.
/// 새로고침해도 좁혀 둔 상태가 살아 있어야 맞다.
const String kFromDomain = 'from';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) => _guard(ref, state),
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.domains,
        builder: (context, state) => DomainSelectScreen(
          showAllDomains: state.uri.queryParameters[kShowAllDomains] != null,
        ),
        routes: [
          GoRoute(
            path: 'g/:groupId',
            builder: (context, state) => DomainSelectScreen(
              groupId: state.pathParameters['groupId'],
            ),
          ),
        ],
      ),
      // 두 번째 문. 사건이 아니라 형편으로 들어오는 자리라 분야 id 가 없다.
      //
      // **다만 분야에서 건너올 수 있다.** 그때만 `from` 이 붙는다 —
      // 분야 id 는 공개 정보라 주소에 남아도 되고(위 참조), 새로고침해도
      // 좁혀 둔 상태가 살아 있어야 맞다.
      GoRoute(
        path: '/welfare',
        builder: (context, state) => WelfareAskScreen(
          fromDomainId: state.uri.queryParameters[kFromDomain],
        ),
        routes: [
          GoRoute(
            path: 'list',
            builder: (context, state) => WelfareListScreen(
              fromDomainId: state.uri.queryParameters[kFromDomain],
            ),
          ),
        ],
      ),
      // 방침. 분야도 사건도 없는 자리라 가드 밖이다.
      GoRoute(
        path: Routes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/detected/:domainId',
        builder: (context, state) =>
            DetectedScreen(domainId: state.pathParameters['domainId']!),
      ),
      GoRoute(
        path: '/interview/:domainId',
        builder: (context, state) => InterviewScreen(
          domainId: state.pathParameters['domainId']!,
          step: 1,
        ),
        routes: [
          GoRoute(
            path: ':step',
            builder: (context, state) => InterviewScreen(
              domainId: state.pathParameters['domainId']!,
              step: int.tryParse(state.pathParameters['step'] ?? '') ?? 1,
              fromSummary:
                  state.uri.queryParameters[kFromSummary] != null,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/summary/:domainId',
        builder: (context, state) =>
            SummaryScreen(domainId: state.pathParameters['domainId']!),
      ),
      GoRoute(
        path: '/result/:domainId',
        builder: (context, state) =>
            ResultScreen(domainId: state.pathParameters['domainId']!),
      ),
      GoRoute(
        path: '/result/:domainId/detail',
        builder: (context, state) =>
            ResultDetailScreen(domainId: state.pathParameters['domainId']!),
      ),
      GoRoute(
        path: '/result/:domainId/sheet',
        builder: (context, state) =>
            TakeAwayScreen(domainId: state.pathParameters['domainId']!),
      ),
      GoRoute(
        path: '/upcoming/:domainId',
        builder: (context, state) =>
            UpcomingScreen(domainId: state.pathParameters['domainId']!),
      ),
      // 위기 안내. 차단이 아니다 — 닫으면 하던 일로 돌아간다.
      GoRoute(
        path: '/crisis/:domainId',
        builder: (context, state) =>
            CrisisScreen(domainId: state.pathParameters['domainId']!),
      ),
      // 확인 화면은 되물을 뿐이다. 뒤로 나갈 수 있다.
      GoRoute(
        path: '/hardstop/:domainId/confirm',
        builder: (context, state) =>
            HardStopConfirmScreen(domainId: state.pathParameters['domainId']!),
      ),
      // 차단. 흐름의 끝이다.
      GoRoute(
        path: '/hardstop/:domainId',
        builder: (context, state) =>
            HardStopScreen(domainId: state.pathParameters['domainId']!),
      ),
    ],
    errorBuilder: (context, state) => const _RouteNotFound(),
  );
});

/// 화면 하나하나가 아니라 **여기 한 곳**에서 막는다.
///
/// 화면마다 검사를 부르면 새 화면을 만들 때 빠뜨린다. 딥링크·새로고침으로 들어오는
/// 경로도 여기를 지난다.
String? _guard(Ref ref, GoRouterState state) {
  final location = state.uri.path;

  // 도메인이 아직 안 읽혔으면 BootstrapGate 가 처리한다.
  if (!ref.read(domainBundleProvider).hasValue) return null;

  final domainId = Routes.domainIdOf(location);
  if (domainId == null) return null;
  if (!requireBundle(ref).domains.containsKey(domainId)) return null;

  // 1. 최우선 위기 신호는 다른 무엇보다 먼저 덮는다. 하드스톱보다도 먼저다 —
  //    죽고 싶다는 사람에게 "형사 사건은 다루지 않습니다" 를 보여줄 수는 없다.
  if (ref.read(priorityCrisisSignalProvider(domainId)) != null &&
      !location.startsWith('/crisis/')) {
    return Routes.crisis(domainId);
  }

  // 2. **하드스톱은 문이 아니라 그물이다.**
  //
  //    문을 하나로 모아도(`startDomain`) 주소를 직접 치거나 브라우저
  //    뒤로·앞으로 가면 그 문을 안 지난다. 새 문이 생길 때마다 거기에
  //    검사를 붙이는 방식은 언젠가 하나를 빠뜨린다 — 실제로 홈에 감지를
  //    붙이자마자 형사 하드스톱을 건너뛰었다(DECISIONS 132번).
  //
  //    되묻는 하드스톱(키워드)은 여기서 안 본다. 그건 확인 화면이
  //    「아니요」를 받아야 하는 것이라 가드가 덮으면 되묻지 못하고 돈다.
  //    키워드는 자유 입력이 있어야 걸리고, 자유 입력은 문을 지나야 들어온다.
  if (_isSessionRoute(location)) {
    final blocking = ref
        .read(hardStopsProvider(domainId))
        .where((stop) => !stop.needsConfirmation);
    if (blocking.isNotEmpty) return Routes.hardStop(domainId);
  }

  // 3. 인터뷰 순번 교정. 답을 고쳐 가지가 닫히면 옛 순번이 유효하지 않게 되는데,
  //    히스토리를 잘라내는 대신 **도착지를 항상 유효하게** 만든다.
  if (location.startsWith('/interview/')) {
    return _interviewRedirect(ref, domainId, location);
  }

  return null;
}

/// 사건 세션을 들고 있는 화면들. **어느 문으로 들어왔든 여기를 지난다.**
bool _isSessionRoute(String location) =>
    location.startsWith('/interview/') ||
    location.startsWith('/detected/') ||
    location.startsWith('/summary/') ||
    location.startsWith('/result/');

String? _interviewRedirect(Ref ref, String domainId, String location) {
  final current = ref.read(currentStepProvider(domainId));
  final total = ref.read(applicableQuestionsProvider(domainId)).length;

  final segments = Uri.parse(location).pathSegments;
  final requested = segments.length >= 3 ? int.tryParse(segments[2]) : null;

  // 순번 없이 `/interview/:domainId` 로 들어왔다.
  if (requested == null) {
    // 물어볼 것이 더 없으면 정리 카드로. 중간에 안내 화면을 두지 않는다.
    return current == null
        ? Routes.summary(domainId)
        : Routes.interview(domainId, current);
  }

  // 있지도 않은 자리.
  if (requested < 1 || requested > total) {
    return current == null
        ? Routes.summary(domainId)
        : Routes.interview(domainId, current);
  }

  // **다 답한 뒤에는 어느 질문으로든 갈 수 있다.** 정리 카드의 "고치기" 와
  // 차단 화면의 "그 질문으로 돌아가기" 가 이 경로다. 여기서 막으면 고칠 방법이 없다.
  if (current == null) return null;

  // 아직 답하는 중이라면 답하지 않은 곳을 건너뛸 수 없다. 뒤로는 얼마든지 간다.
  if (requested > current) return Routes.interview(domainId, current);

  return null;
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: IconButton(
          iconSize: 40,
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go(Routes.home),
        ),
      ),
    );
  }
}
