import 'package:flutter/material.dart';

/// 색 토큰.
///
/// **색은 여기에만 있다.** 위젯에서 `Color(0x...)` 를 쓰지 않는다.
///
/// 이름 규칙 — `x` 는 글자·강조, `xSoft` 는 배경, `xLine` 은 예전 테두리 자리.
///
/// ## 2026-09-16 — 테두리를 버렸다 (DECISIONS 286번)
///
/// 테두리로 칸을 나누는 것은 서식의 문법이다. 이제 **여백과 글자 크기와 면의
/// 밝기로만** 나눈다. `xLine` 토큰은 이름을 남겨 두되 면과 같은 값이다 — 새로
/// 테두리를 그리지 않는다.
///
/// ★ **대비를 쟀다.** 받은 색표 중 네 가지가 뜻을 나르는 글자에 필요한 4.5:1 을
/// 못 넘었다. 같은 색상에서 밝기만 내려 넘겼다(옆 주석에 받은 값을 남긴다).
/// 우리 사용자는 어르신과 눈이 침침한 분이다.
abstract final class BeobaColors {
  // 글자
  /// 제목 · 이름. 흰 16.6 · 카드 15.6
  static const Color ink = Color(0xFF191F28);

  /// 본문. 흰 7.1 · 카드 6.7 · 강조 면 6.4
  static const Color ink2 = Color(0xFF4E5968);

  /// 보조 설명. **받은 값 #6B7684 는 카드(#F7F8FA) 위에서 4.34** 라 올렸다.
  /// 어느 면 위에서도(흰 · 카드 · 진한 면 · 강조 · 초록 · 노랑 · 위험 면) 4.5 를 넘는다.
  static const Color ink3 = Color(0xFF656F7D);

  /// 흐림. **4.5 를 안 넘는다(흰 2.0).** 없어도 되는 글자에만 쓴다 — 뜻을 나르는
  /// 글자에 쓰면 안 된다.
  static const Color ink4 = Color(0xFFB0B8C1);

  // 면·선
  static const Color bg = Color(0xFFFFFFFF);

  /// 카드 바탕. 테두리 없이 흰 화면에서 면으로 갈린다.
  static const Color card = Color(0xFFF7F8FA);
  static const Color surfaceSoft = Color(0xFFF7F8FA);

  /// 면 진함 — 둘째 버튼 · 꺼진 칩 · **카드 안의 안내 상자**. 카드 바탕과 같은
  /// 색이면 테두리가 없어진 뒤 상자가 안 보인다.
  static const Color surfaceStrong = Color(0xFFF2F4F6);

  /// 선. **거의 안 쓴다.** 행 사이 구분선 같은 자리에만 남았다.
  static const Color line = Color(0xFFE5E8EB);
  static const Color line2 = Color(0xFFE5E8EB);

  /// 선택되지 않은 라디오·체크박스 테두리. **조작 요소라 3:1 을 넘겨야 한다** —
  /// 카드(#F7F8FA) 위 3.3.
  static const Color control = Color(0xFF7F8994);

  /// 진행바·게이지의 빈 구간.
  static const Color track = Color(0xFFE5E8EB);

  // 강조
  /// 누름 · 링크 · 주요 버튼. **받은 값 #3182F6 은 흰 바탕 3.71, 흰 글자 3.71** 이라
  /// 올렸다. 흰 5.0 · 카드 4.7 · 강조 면 4.5 · 흰 글자 5.0
  static const Color brand = Color(0xFF0A67ED);

  /// 링크색. 이제 강조와 같다.
  static const Color brand2 = Color(0xFF0A67ED);

  /// 강조 옅은 면 — 「지금 하실 일」 블록 · 아이콘 타일.
  static const Color brandSoft = Color(0xFFEDF4FE);
  static const Color brandLine = Color(0xFFEDF4FE);

  /// 강조 면 위의 본문. 6.4
  static const Color brandInk = Color(0xFF4E5968);

  // 의미색
  /// 법 초록. **받은 값 #0F8A5F 는 배지 면 위 3.90** 이라 올렸다. 배지 면 4.54 · 흰 5.1
  static const Color green = Color(0xFF0E7E57);
  static const Color greenSoft = Color(0xFFE6F6EF);
  static const Color greenLine = Color(0xFFE6F6EF);

  /// 적용 노랑. **받은 값 #C08A16 은 배지 면 위 2.84** 라 올렸다. 어느 면 위에서도 4.5 를 넘는다.
  static const Color amber = Color(0xFF906811);
  static const Color amberSoft = Color(0xFFFFF6E5);
  static const Color amberLine = Color(0xFFFFF6E5);

  /// 위험 글자. 흰 5.3 · 위험 면 4.9
  static const Color red = Color(0xFFC9303A);

  /// 위험 표지(점 · 선 · 아이콘). **글자에 쓰지 않는다** — 흰 3.7.
  static const Color redMark = Color(0xFFF04452);
  static const Color redSoft = Color(0xFFFEF3F2);

  /// 「적용될 가능성」 배지의 실선. **면(#FFF6E5) 대비 3.04** — 조작 요소와 같은 3:1.
  static const Color badgeLine = Color(0xFFB7861F);

  /// 「확인 안 된 것」 배지의 점선. **받은 값 #C4CBD3 은 흰 면 대비 1.6** 이라 흑백에서
  /// 안 보였다. 올린 값은 흰 3.21 · 카드 3.02.
  static const Color badgeDash = Color(0xFF8391A2);
  static const Color redLine = Color(0xFFFEF3F2);

  // ── 별칭 ────────────────────────────────────────────────────────
  // 아래 둘은 지금 같은 색이지만 **뜻이 다르다.** 하나로 합치지 않는다.
  // 뜻이 갈리는 날 색을 나눌 수 있어야 한다 (DECISIONS.md).

  /// 🟡 인식의 불확실 — "적용될 가능성" · "확인이 필요한 정보".
  static const Color legalMaybe = amber;

  /// 🟠 시간의 급박 — 기한 severity `warning`.
  static const Color severityWarning = amber;
}

/// 여백·모서리 값.
abstract final class BeobaSpace {
  static const double cardPadding = 16;
  static const double tierPaddingV = 15;
  static const double tierPaddingH = 16;
  static const double blockGap = 12;
  static const double tierGap = 11;

  /// 화면 좌우 여백. 본문 폭은 [maxContentWidth] 로 묶는다.
  static const double pageH = 16;
  static const double pageTop = 18;
  static const double pageBottom = 30;

  /// 넓은 화면(웹)에서 한 줄이 지나치게 길어지지 않게 한다.
  static const double maxContentWidth = 560;

  /// 카드.
  static const double radius = 16;

  /// 큰 블록 — 「지금 하실 일」.
  static const double radiusBlock = 18;
  static const double radiusButton = 14;

  /// 아이콘 타일.
  static const double radiusIcon = 13;

  /// 세 층 배지.
  static const double radiusBadge = 7;

  /// 카드보다 한 단계 작다 — 「왜 묻나요?」 · 안내 상자.
  static const double radiusInner = 12;
}

/// 탭 타깃 최소 높이.
///
/// 접근성 기준은 48 이고 프로토타입은 그보다 넉넉하다. 넉넉한 쪽을 쓴다.
abstract final class BeobaTapTarget {
  static const double minimum = 48;
  static const double button = 52;
  static const double choice = 56;
  static const double linkRow = 50;
}

/// 「왜 묻나요?」 의 위계.
///
/// **질문보다 확실히 뒤로 물러난다.** 사용자가 답할 대상은 질문이고 whyAsk 는 그
/// 이유다. 둘이 비슷한 무게로 보이면 무엇에 답해야 하는지가 흐려진다.
///
/// **글씨 크기만으로는 안 된다.** 처음에는 크기와 글자색만 낮췄는데, 질문은 맨
/// 텍스트인 반면 이쪽은 색면 + 테두리 + 아이콘을 두르고 있어서 여전히 이겼다.
/// **색면과 테두리와 아이콘은 글자 크기를 이긴다.**
///
/// 그래서 **브랜드 색을 뺐다.** 브랜드 색은 "여기가 중요합니다" 신호인데 그걸
/// 부연 설명이 쓰고 있었다. 남긴 것은 왼쪽 얇은 선 하나 — 본문에 섞이지 않을
/// 만큼만 구분하고 그 이상 주장하지 않는다.
abstract final class BeobaWhyAsk {
  /// 배경 없음. 왼쪽 선 하나로만 구분한다.
  static const Color accent = BeobaColors.line;
  static const double accentWidth = 3;

  static const double bodySize = 13.5;
  static const Color bodyColor = BeobaColors.ink2;
  static const double bodyHeight = 1.6;

  /// 제목("왜 묻나요?"). 라벨이지 제목이 아니다.
  static const double titleSize = 12.5;
  static const Color titleColor = BeobaColors.ink3;
}

/// 숫자가 자리를 지키도록. 진행 `n/m` · 날짜 · 금액에 쓴다.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

ThemeData buildBeobaTheme() {
  // 자간 — 제목 -0.9 · 본문 -0.35 (DECISIONS 286번).
  const base = TextStyle(color: BeobaColors.ink, height: 1.62, letterSpacing: -0.35);

  final textTheme = TextTheme(
    // 화면 제목
    headlineSmall: base.copyWith(
      fontSize: 25,
      fontWeight: FontWeight.w700,
      height: 1.36,
      letterSpacing: -0.9,
    ),
    // 구역 제목
    titleMedium: base.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.9,
    ),
    titleSmall: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    // 본문
    bodyLarge: base.copyWith(fontSize: 15, color: BeobaColors.ink2),
    bodyMedium: base.copyWith(fontSize: 15),
    bodySmall: base.copyWith(fontSize: 15, color: BeobaColors.ink2, height: 1.66),
    // 보조 문구
    labelLarge: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: base.copyWith(fontSize: 13, color: BeobaColors.ink3, height: 1.65),
    labelSmall: base.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
      color: BeobaColors.ink3,
      height: 1.2,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: BeobaColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BeobaColors.brand,
      primary: BeobaColors.brand,
      surface: BeobaColors.bg,
      error: BeobaColors.red,
    ),
    textTheme: textTheme,
    // 탭 타깃을 기본으로 넓힌다. 타깃 사용자가 소외계층이다.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // 그림자도 테두리도 없다. 면의 밝기와 여백으로 나눈다(DECISIONS 286번).
    cardTheme: const CardThemeData(
      elevation: 0,
      color: BeobaColors.card,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: BeobaColors.line2,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BeobaColors.bg,
      foregroundColor: BeobaColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BeobaColors.brand,
        foregroundColor: BeobaColors.bg,
        disabledBackgroundColor: BeobaColors.track,
        disabledForegroundColor: BeobaColors.ink3,
        elevation: 0,
        minimumSize: const Size.fromHeight(BeobaTapTarget.button),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BeobaSpace.radiusButton)),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        // 둘째 버튼 — 면 진함 · 글자 보통. 테두리 없음.
        foregroundColor: BeobaColors.ink2,
        backgroundColor: BeobaColors.surfaceStrong,
        minimumSize: const Size.fromHeight(BeobaTapTarget.button),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BeobaSpace.radiusButton)),
        ),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BeobaColors.brand2,
        minimumSize: const Size(0, BeobaTapTarget.minimum),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: BeobaColors.card,
      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      // 테두리 없이 면으로. **다만 누른 자리(포커스)는 2px 선을 남긴다** — 지금
      // 어디에 쓰고 있는지가 눈에 보여야 한다.
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(BeobaSpace.radiusInner)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(BeobaSpace.radiusInner)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(BeobaSpace.radiusInner)),
        borderSide: BorderSide(color: BeobaColors.brand, width: 2),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BeobaColors.brand,
      linearTrackColor: BeobaColors.track,
      linearMinHeight: 6,
    ),
  );
}
