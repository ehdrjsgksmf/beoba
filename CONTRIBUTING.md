# 버바 (Beoba) — 개발 규칙

법률 문제가 생겼을 때 오늘 뭘 해야 하는지 알려주고 그 절차를 끝까지 따라가는 앱.

**타깃 플랫폼: Android + Web.** iOS는 검증 후 추가한다 (아래 참조).

상세 명세는 `SPEC.md`.

우회책이나 비자명한 결정을 내리면 `DECISIONS.md`에 기록한다 (무엇을 · 왜 · 되돌릴 조건).
"왜 이렇게 돼 있지?" 싶은 코드를 만나면 거기부터 본다.

---

## 절대 규칙 (위반 시 제품 존립 위험)

이 앱은 **법률 판단을 하지 않는다.** 코드와 문구 모두에 적용된다.

```
❌ 법률 판단        "이 사건은 유리합니다"
❌ 승패 예측        "승소 가능성 70%"
❌ 문서 대필        AI가 내용증명 생성
❌ 변호사 알선 수수료
❌ 형사 사건        마약·불법도박 포함

⭕ 기한 계산 · 서류 목록 · 비용 계산 · 관할 찾기
⭕ 공적 무료 창구 연결 · 법정 상한 대조 경고
```

근거: 대법원 2025두35483 — 템플릿 빈칸 채우기는 적법, 생성형 AI 문서작성·개별 사건 검토는 위반 소지.

---

## 아키텍처 원칙

> **분야는 코드가 아니라 데이터다.**

```
packages/engines/       순수 Dart. Flutter 의존 금지. 분야 무관.
packages/domain_data/   모델 + 로더 + 스키마 검증
assets/domains/*.json   분야별 데이터
apps/beoba/          Flutter UI
```

분야를 추가할 때 **JSON 파일만 추가**한다. 엔진 코드는 건드리지 않는다.

---

## 플랫폼 정책

**지금 빌드하는 것: Android, Web.**
iOS는 지금 빌드하지 않지만 **나중에 붙일 수 있게 코드를 유지한다.**

```
✅ 해도 되는 것
   dart:io 사용 (Android는 지원)
   플랫폼 분기 (kIsWeb, Platform.isAndroid)

❌ 하지 말 것
   iOS를 영구 배제하는 전제로 설계
   플랫폼 코드를 UI에 직접 박기
```

**알림은 반드시 추상화한다.** `NotificationService` 인터페이스 하나 뒤에
로컬 알림 / FCM / (나중에) 웹 푸시를 구현체로 둔다.
이렇게 해야 iOS를 붙일 때 화면 코드를 하나도 안 고친다.

Flutter Web은 렌더링 엔진이 달라(CanvasKit) 모바일 빌드와 텍스트 줄바꿈이
미세하게 다를 수 있다. 한글 줄바꿈은 Android 실기기로 확인한다.

---

## 코딩 규칙

1. `packages/engines`는 Flutter에 의존하지 않는다 (순수 Dart)
2. `DateTime.now()` 직접 호출 금지 → `KstClock` 주입
3. 모든 날짜 연산은 **KST 자정 기준**. UTC 금지
4. 금액은 `int` (원 단위). `double` 금지
5. 사용자에게 보이는 모든 문자열은 `SafetyFilter` 통과
6. 법률 정보 위젯은 `legalBasis` 없이 생성 불가 (required)
7. `verification.status == "unverified"` 데이터는 로더에서 제거
8. 도메인 JSON의 `tests[]`는 CI에서 반드시 실행
9. **법률 수치를 코드에 하드코딩하지 않는다. 전부 JSON에서 읽는다**
10. 알림은 `NotificationService` 를 통해서만 호출한다

9번이 특히 중요하다. 제도가 자주 바뀐다(햇살론이 2026.1에 4종→2종 통합됨).
코드에 숫자를 박으면 앱 심사 없이 못 고친다.

---

## 명령

```bash
melos bootstrap                    # 의존성 설치
melos run test                     # 전체 테스트
melos run analyze                  # 정적 분석
melos run gen                      # build_runner (freezed/json_serializable)

flutter run -d chrome              # 웹으로 빠르게 확인 (평소 개발)
flutter run -d <device>            # Android 실기기
flutter build apk --release        # 실기기 배포용 apk
flutter build appbundle --release  # 스토어에 낼 것. 새 앱은 AAB 로만 냅니다 (260)
flutter build web --release --no-web-resources-cdn   # 웹 배포용
```

pubspec.yaml 변경 후에는 반드시 `melos bootstrap`.

---

## 받아 오는 데이터

```
law/*.pdf                     법령 원문. 저장소에 없다
law/특일정보_공휴일_*.xml      쉬는 날 원문. 저장소에 없다
tool/build_law_manifest.dart  → assets/laws/manifest.json    커밋
tool/build_holidays.dart      → assets/holidays/YYYY.json    커밋
welfare/*.csv                 복지 자료 원문. 저장소에 없다
welfare/raw/central/*.xml.gz  복지 API 응답 원문. 저장소에 없다
tool/fetch_welfare_central.dart  API → welfare/raw/       (.env 키 필요)
tool/build_welfare.dart       → assets/welfare/*.json        커밋
```

**앱이 API 를 직접 부르지 않는다.** 키가 브라우저 번들에 그대로 들어가고
웹에서는 CORS 로 막힌다. **받기와 굽기도 나눈다** — 굽는 쪽이 네트워크를
부르면 `--check` 가 뜻을 잃는다 (DECISIONS 202).


## 웹 배포

```
flutter build web --release --no-web-resources-cdn
```

**플래그를 빼지 않는다.** 빼면 CanvasKit(1.5MB)과 엔진 폰트를 gstatic 에서
받는다. 바깥 의존이 생기고, 우리가 켠 압축이 거기엔 안 걸린다.
그리고 **개인정보처리방침 3·5절이 그 자리에서 거짓이 된다** (검사 ah).

### 어디에 올리나 — Cloudflare Pages

```
빌드 명령    위 한 줄 (working-directory: apps/beoba)
출력 폴더    apps/beoba/build/web
되돌림       apps/beoba/web/_redirects  →  /*  /index.html  200
```

**Cloudflare 쪽에서 빌드하지 않는다.** 그 빌드 환경에는 Flutter 가 없어서
매번 SDK 를 받아야 하는데, CI 가 이미 같은 명령으로 굽고 있다. CI 가 구운 것을
`wrangler pages deploy` 로 올린다. **산출물은 저장소에 안 넣는다** — `build/web`
은 45MB 이고 커밋하면 이력에서 못 지운다.

★ **`_redirects` 가 없으면 `/privacy` 를 새로고침한 사람이 404 를 본다.**
Flutter 라우트는 서버에 파일이 없다. 실제 파일은 이 규칙보다 먼저 나가므로
`privacy-policy.html` 과 `main.dart.js` 는 영향을 안 받는다.

★ **정적 방침을 `privacy.html` 로 부르지 않는다.** Pages 는 `/privacy` 요청에
`privacy.html` 을 먼저 내주므로 앱의 `/privacy` 라우트를 서버가 가로챈다.
이름을 `privacy-policy.html` 로 갈라 뒀다 (DECISIONS 257번).

★ **배포 직전 게이트는 `melos run verify_release` 다.** 평소에 경고인 것이
거기서 실패가 된다 — 지금은 방침 9절의 연락처가 비어 있는 것이 그것이다.

★ **다만 배포 서버에 brotli 를 켜야 한다.** gstatic 은 brotli 로 주고
있었다 — CDN 만 끊고 gzip 이면 **오히려 느려진다**(3,174KB / 63초 대
2,637KB / 53초). brotli 를 켜면 2,402KB / 48초로 이긴다 (DECISIONS 220).
`.wasm` 과 `.js` 를 압축 대상에서 빼는 서버가 있으니 확인한다.

---

**앱은 네트워크를 부르지 않는다.** 커밋된 JSON 이 진짜 데이터다.
원문이 없는 곳(CI)에서는 생성기가 아무것도 쓰지 않고 멈춘다.

**과거 데이터를 현재 규칙으로 검산하지 않는다.** 법이 바뀌면 그 시점의 판본이
있어야 한다. 없으면 검사 범위를 자르고 어디서 잘랐는지 코드에 적는다
(DECISIONS 88).

---

## 생성 파일

`*.g.dart`, `*.freezed.dart`는 **직접 수정하지 않는다.** `melos run gen`으로 재생성한다.
`.gitignore`에 있으므로 저장소에 올라가지 않는다.

---

## 도메인 JSON 규칙

모든 데이터 항목에 `verification` 필드가 **필수**다.

| status | 동작 |
|---|---|
| `verified` | 정상 표시 + 근거 링크 |
| `needs_check` | 🟡 배지 + "확인이 필요한 정보입니다" |
| `unverified` | **로더에서 제거. UI 도달 금지** |

추가 강제 사항:
- `Question.whyAsk`가 비어 있으면 **빌드 실패**
- `Deadline`에 `tests[]`가 없으면 **빌드 실패**
- `severity: "critical"`인 Deadline이 `verified`가 아니면 **빌드 실패**

JSON에 `unverified` 항목이 일부러 들어 있다. **버그가 아니라 로더 필터링 테스트 케이스다.**

---

## 계산 주의사항

**인지대 tier 경계** — `max` 비교는 `amount < tier.max` (미만).
소가 정확히 1억원은 **세 번째 구간**이다. 두 번째가 아니다.

```
청구액 5,000만원 → 230,000원   (전자소송 207,000원)
청구액 1억원     → 455,000원   (전자소송 409,500원)
지급명령         → 소장 인지액의 1/10
```

**modifier 적용 순서** — 배열에 정의된 순서대로 곱셈.

**끝수 처리(`rounding`)는 조문이 준용하라고 적어 둔 자리에서만 한다.**
`{ "minimum": 1000, "roundDown": 100 }` 은 **택일**이다 — 1천원 미만이면 올리고,
아니면 100원 미만을 버린다 (인지법 제2조②). 버림만 두면 소액에서 1천원 아래로 내려간다.
제7조④가 제2조②을 준용하므로 지급명령 1/10 **뒤에** 다시 처리하고,
제16조에는 그런 규정이 없어 전자소송 10분의 9 뒤에는 처리하지 않는다.

**민사조정은 다르다.** 조정규칙 제3조②이 「본문 **또는 단서**」라고 명시해서
전자 감액 뒤에도 100원을 버린다. 500만원 전자에서 조정 2,200원 · 지급명령
2,250원이다. **셋을 같은 코드로 처리하면 조정 값이 틀린다.**

**사용자가 아직 안 정한 갈래는 묻지 말고 `costScenarios` 로 나란히 낸다.**
지급명령이냐 소송이냐를 물으면 답을 모르는 사람에게 답을 요구하게 된다.
한쪽으로만 계산하면 다른 쪽 사람에게 11배 틀린 금액이 간다.

**갈래와 조건은 다르다.** 소액사건은 사용자가 고르는 것이 아니라 소가로 정해진다
(소액사건심판규칙 제1조의2, 3,000만원 **정각은 소액**). 인지대는 같고 송달료 회차만
갈리므로 `costScenarios` 가 아니라 `unitsFormula.roundsWhen` 으로 가른다.

**조문 해석과 안전 여유는 다른 층이다. 섞지 않는다.**
`CostLine.amount` 는 조문대로의 값이고 정답지가 보는 값이다.
`guidedAmount` 는 화면에 낼 값이다 (법정 최저액 아래로 안 내려간다).
합계도 `total` / `guidedTotal` 로 갈라져 있다. 섞으면 나중에 어느 쪽이 조문이었는지
알 수 없게 된다.

---

## 작업 방식

- 큰 작업은 먼저 설계를 적고, 우회책·비자명한 결정은 `DECISIONS.md` 에 남긴 뒤 구현
- 테스트를 먼저 쓰고 구현한다. 도메인 JSON의 `tests[]`가 정답지다

---

## 하지 말 것

- 법률 수치를 코드에 하드코딩
- 생성 파일(`*.g.dart`) 직접 수정
- `DateTime.now()` 직접 호출
- 금액을 `double`로 처리
- 알림 API를 화면 코드에서 직접 호출
- iOS를 영구 배제하는 전제로 설계
