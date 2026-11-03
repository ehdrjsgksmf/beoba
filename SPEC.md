# 버바 (Beoba) — 개발 명세서

> **이 문서가 유일한 기준입니다.** 이전 논의 문서(v0.1~v0.3, 프레임워크 v2)와 충돌하는 내용이 있으면 **이 문서를 따르세요.**

**버전** SPEC 1.1 · 2026-08-15
**스택** Flutter — **빌드 타깃: Android + Web** (iOS는 검증 후 추가)
**첫 목표** 사건 저장까지 되는 실제 서비스

---

# 0. 제품 한 줄

> **법률 문제가 생겼을 때, 오늘 뭘 해야 하는지 알려주고 그 절차를 끝까지 따라가는 앱.**

## 0.1 절대 규칙 (위반 시 제품 존립 위험)

```
❌ 법률 판단을 하지 않는다      ("이 사건은 유리합니다")
❌ 승패·결과를 예측하지 않는다   ("승소 가능성 70%")
❌ 문서를 대신 작성하지 않는다   (AI가 내용증명 생성)
❌ 변호사를 알선하고 대가를 받지 않는다
❌ 형사 사건을 다루지 않는다     (마약·불법도박 포함)

⭕ 기한을 계산한다
⭕ 서류를 목록화한다
⭕ 비용을 계산한다
⭕ 관할을 찾는다
⭕ 공적 무료 창구로 연결한다
⭕ 법정 상한과 대조해 경고한다
```

**근거**: 대법원 2025두35483 (2025.2.12) — 템플릿 빈칸 채우기는 적법, 생성형 AI 문서작성·개별 사건 검토는 위반 소지.

---

# 1. 아키텍처 원칙

> **분야는 코드가 아니라 데이터다.**

```
packages/engines/          ← 순수 Dart. Flutter 의존 금지. 분야 무관.
  deadline_engine.dart
  cost_engine.dart
  jurisdiction_engine.dart
  document_engine.dart
  limit_checker.dart
  interview_engine.dart
  safety_filter.dart

packages/domain_data/      ← 모델 + 로더 + 스키마 검증
assets/domains/*.json      ← 분야별 데이터
apps/beoba/             ← Flutter UI
```

분야를 추가할 때 **JSON 파일만 추가**합니다. 엔진 코드는 건드리지 않습니다.

---

# 2. 5층 구조

모든 기능은 이 다섯 층 중 하나에 속합니다.

| 층 | 이름 | 하는 일 | 엔진 |
|---|---|---|---|
| ① | **위기** | 전화번호만 표시. AI 판단 0 | 없음 (정적 데이터) |
| ② | **방어** | 브로커·사기 경보, 법정 상한 대조 | `LimitChecker` |
| ③ | **자원** | 공적 지원제도 안내 | 없음 (조건 필터) |
| ④ | **행동** | 기한·서류·비용·관할 | 4엔진 |
| ⑤ | **기록** | 사건 관리·알림 | 로컬 DB |

---

# 3. 기술 스택 (확정)

## 3.0 빌드 타깃 — Android + Web

| 플랫폼 | 지금 | 용도 |
|---|---|---|
| **Web** | ✅ | 평소 개발 확인 (`flutter run -d chrome`). 아이폰 사파리로 레이아웃 점검 가능 |
| **Android** | ✅ | 실제 기능 검증. apk를 카톡으로 보내 즉시 설치 |
| iOS | ⏸ 나중 | 검증 통과 후. Mac 또는 Codemagic 필요 |
| Desktop | ⏸ 나중 | B2B 버전 낼 때 |

**iOS를 지금 빌드하지 않을 뿐, 영구 배제가 아닙니다.** 나중에 붙일 때 화면 코드를 고치지 않아도 되게 설계하세요.

### 필수 — 알림 추상화

```dart
abstract class NotificationService {
  Future<void> requestPermission();
  Future<void> schedule(DeadlineResult d, List<int> daysBefore);
  Future<void> cancel(String deadlineId);
}

class LocalNotificationService  implements NotificationService { }  // Android/iOS 공통
class FcmNotificationService    implements NotificationService { }  // 서버 발송
class NoopNotificationService   implements NotificationService { }  // Web (지금은 미지원)
```

**화면 코드는 `NotificationService`만 호출합니다.** 플랫폼 분기는 DI 레벨에서 처리하세요.
나중에 iOS나 웹 푸시를 붙일 때 구현체만 추가하면 됩니다.

### 웹 렌더링 주의

Flutter Web은 CanvasKit으로 그려서 모바일 빌드(Impeller/Skia)와 **텍스트 줄바꿈이 미세하게 다를 수 있습니다.**
특히 한글 줄바꿈. 최종 확인은 Android 실기기로 하세요.

## 3.1 라이브러리

| 레이어 | 선택 | 비고 |
|---|---|---|
| 앱 | Flutter 3.x | 모노레포는 melos |
| 상태관리 | Riverpod | 엔진 주입 |
| 로컬 DB | Drift (SQLite) | 사건 데이터는 로컬 우선 |
| 백엔드 | Supabase | Postgres + Auth + RLS + Storage |
| 푸시 | FCM | 기한 알림 |
| 로컬 알림 | flutter_local_notifications | 오프라인 대응 |
| 원격 데이터 | Supabase Storage + 버전 체크 | **필수** (아래 §3.1) |
| 모델 | freezed + json_serializable | |

## 3.2 원격 데이터 교체는 필수입니다

제도가 자주 바뀝니다. **실제로 햇살론이 2026년 1월 4종→2종으로 통합됐고, 소액생계비대출은 2025년 3월 개명됐습니다.**

앱 업데이트 심사를 기다리는 사이 사용자가 틀린 정보를 봅니다.

```
앱 시작
  → 로컬 캐시 domain manifest 버전 확인
  → 서버 manifest 버전 비교
  → 다르면 변경된 JSON만 다운로드 → 캐시 갱신
  → 네트워크 실패 시 번들된 기본값 사용
```

---

# 4. 도메인 JSON 스키마

전체 구조:

```jsonc
{
  "id": "debt_recovery",
  "version": "1.0.0",
  "schemaVersion": 1,
  "name": "떼인 돈 받기",
  "shortName": "돈 받기",
  "icon": "💰",
  "status": "active",              // active | beta | disabled
  "lastVerifiedAt": "2026-08-15",

  "intake":        [ Question ],
  "deadlines":     [ Deadline ],
  "documents":     [ DocumentItem ],
  "costs":         [ CostItem ],
  "jurisdiction":  [ JurisdictionRule ],
  "procedures":    [ Procedure ],
  "resources":     [ Resource ],       // ③ 자원
  "brokerAlerts":  [ BrokerAlert ],    // ② 방어
  "lookupTools":   [ LookupTool ],     // ② 방어
  "limitRules":    [ LimitRule ],      // ② 방어
  "hardStops":     [ HardStop ],
  "publicChannels":[ PublicChannel ]
}
```

## 4.1 Verification — 모든 데이터 항목의 필수 필드

**이게 제품의 안전장치입니다. 예외 없습니다.**

```jsonc
"verification": {
  "status": "verified",     // verified | needs_check | unverified
  "source": "민사소송 등 인지법 제2조 제1항",
  "sourceUrl": "https://www.law.go.kr/...",
  "checkedAt": "2026-08-15",
  "checkedBy": "self",      // self | lawyer | official
  "note": null
}
```

**코드로 강제할 것:**

| status | 동작 |
|---|---|
| `verified` | 정상 표시 + 근거 링크 노출 |
| `needs_check` | 🟡 배지 + "확인이 필요한 정보입니다" + 공식 창구 링크 |
| `unverified` | **로더 단계에서 제거. UI에 도달 금지** |

추가 규칙:
- `severity: "critical"`인 Deadline이 `verified`가 아니면 **빌드 실패**
- `lastVerifiedAt`이 180일 이상 지난 도메인은 앱 시작 시 경고 로그

## 4.2 Question (인터뷰)

```jsonc
{
  "id": "q_claim_type",
  "order": 1,
  "text": "어떤 돈을 받지 못하고 계신가요?",
  "whyAsk": "돈의 성격에 따라 시효와 절차가 달라집니다.",   // 필수
  "type": "single",     // single | multi | number | money | date | text
  "field": "claimType",
  "weight": 2,          // 필수 항목 2, 추가 항목 1
  "required": true,
  "showIf": null,       // JSONLogic
  "options": [
    { "value": "loan", "label": "빌려준 돈" },
    { "value": "wage", "label": "못 받은 임금", "redirect": "wage_theft" }
  ]
}
```

- **`whyAsk`가 비어 있으면 빌드 실패시킬 것.** 이게 제품의 차별점입니다.
- AI는 질문을 **생성하지 않습니다.** 이 목록에서 고를 뿐입니다.
- `redirect`는 다른 분야로 이관합니다.

## 4.3 Deadline

```jsonc
{
  "id": "dl_payment_order_objection",
  "label": "지급명령 이의신청",
  "severity": "critical",        // critical | warning | info
  "basisField": "paymentOrderServedDate",
  "offset": { "value": 2, "unit": "week" },   // day | week | month | year
  "calcRule": "from_basis",
  "showIf": { "==": [{"var":"hasPaymentOrder"}, true] },
  "legalBasis": {
    "law": "민사소송법", "article": "제470조 제1항",
    "text": "지급명령에 대한 이의신청은 송달받은 날부터 2주 이내(불변기간)",
    "url": "..."
  },
  "notify": [30, 7, 3, 1],
  "verification": { ... },
  "tests": [ { "basis": "2026-08-15", "expected": "2026-08-29" } ]   // 필수
}
```

**calcRule 4종**

| 값 | 계산 | 예 |
|---|---|---|
| `from_basis` | 기산일 + offset | 송달일 + 2주 |
| `from_month_end` | 기산일이 속한 달의 말일 + offset | 상속세 (사망일 속한 달 말일 + 6개월) |
| `from_known_date` | 사용자가 입력한 "안 날" + offset | 상속포기 3개월 |
| `fixed_annual` | 매년 고정 월/일 | 국적이탈 3월 31일 |

**하드 규칙**
- `tests` 배열 없으면 빌드 실패
- 모든 날짜 연산은 **KST 자정 기준**. `DateTime.now()` 직접 호출 금지 → `KstClock` 주입
- D-day는 `dueDate.difference(today).inDays`

## 4.4 CostItem

```jsonc
{
  "id": "cost_stamp_fee",
  "label": "인지대",
  "formula": {
    "type": "tiered",          // tiered | fixed | perUnit
    "input": "claimAmount",
    "tiers": [
      { "max": 10000000,   "rate": 0.005,  "add": 0 },
      { "max": 100000000,  "rate": 0.0045, "add": 5000 },
      { "max": 1000000000, "rate": 0.004,  "add": 55000 },
      { "max": null,       "rate": 0.0035, "add": 555000 }
    ],
    "rounding": { "minimum": 1000, "roundDown": 100 }
  },
  "modifiers": [
    { "id": "payment_order", "label": "지급명령", "multiply": 0.1,
      "condition": { "==": [{"var":"procedure"}, "payment_order"] },
      "rounding": { "minimum": 1000, "roundDown": 100 } },
    { "id": "efiling", "label": "전자소송", "multiply": 0.9,
      "condition": { "==": [{"var":"useEfiling"}, true] } }
  ],
  "costScenarios": [
    { "id": "cs_po_paper", "label": "지급명령으로 하면", "option": "종이로 낼 때",
      "facts": { "procedure": "payment_order", "useEfiling": false },
  "showIf": { "in": [{ "var": "knowsDebtorAddress" }, ["yes", "partial"]] }
                               // 아예 못 쓰는 갈래는 금액도 내지 않는다.
                               // facts 는 **가정**, showIf 는 **거르기**다 }
  ],
  "alsoBasis": [ ... ],   // 근거가 둘 이상일 때 (§4.6)
  "verification": { ... },
  "tests": [ ... ]   // 필수
}
```

**⚠️ 경계값**: `max` 비교는 `amount < tier.max` (미만). 소가 정확히 1억원은 **세 번째 구간**입니다.
금액은 전부 `int` (원 단위). `double` 금지.

**`perUnit` 의 회수 — 갈래가 아니라 조건인 것**

```jsonc
"formula": {
  "type": "perUnit", "unitPrice": 5500,
  "unitsFormula": {
    "parties": 2,
    "roundsByProcedure": { "payment_order": 6, "lawsuit": 15 },
    // 절차가 같아도 회수가 갈리는 자리. 먼저 맞는 규칙이 이긴다.
    "roundsWhen": [
      { "label": "소액사건", "rounds": 10,
        "showIf": { "and": [ {"==": [{"var":"procedure"}, "lawsuit"]},
                             {"<=": [{"var":"claimAmount"}, 30000000]} ] } }
    ]
  }
}
```

소액사건은 **사용자가 고르는 갈래가 아니라 소가로 자동 결정된다**(소액사건심판규칙
제1조의2). 인지대 산식은 같고 달라지는 것은 송달료 회차뿐이라 `costScenarios` 를
늘리지 않고 소송 갈래 **안에서** 가른다. 경계는 「초과하지 아니하는」이라 **3,000만원
정각은 소액**이다. `roundsWhen[].showIf` 도 검증기가 `showIf` 와 똑같이 본다.

**`verification.openPart` — 일부만 확인됐을 때**

`status` 는 항목 전체의 **바닥값**이라 조각 하나가 열려 있으면 `needs_check` 다.
`openPart` 에 그 조각의 이름을 적으면 배지가 그것만 가리킨다 —
「확인이 필요한 정보입니다 — 1회 송달료 금액」. 확정된 부분까지 못 믿을 것으로
읽히는 것을 막는다.

## 4.5 LimitRule (② 방어 · 신규)

상대가 요구한 금액이 법정 상한을 넘는지 대조합니다.

```jsonc
{
  "id": "lr_brokerage_fee",
  "label": "부동산 중개보수",
  // 필드명 + 화면에 쓸 한글 라벨. 라벨을 코드에 두면 engines 가 분야 어휘를 알게 된다.
  "inputs": [
    { "field": "transactionAmount", "label": "거래금액" },
    { "field": "dealType",          "label": "거래 유형" },
    { "field": "requestedAmount",   "label": "요구받은 금액" }
  ],
  "formula": {
    "type": "tiered_with_cap",
    "variants": {
      "lease": [
        { "max": 50000000,   "rate": 0.005, "cap": 200000 },
        { "max": 100000000,  "rate": 0.004, "cap": 300000 },
        { "max": 600000000,  "rate": 0.003, "cap": null },
        { "max": 1200000000, "rate": 0.004, "cap": null },
        { "max": 1500000000, "rate": 0.005, "cap": null },
        { "max": null,       "rate": 0.006, "cap": null }
      ]
    }
  },
  "verdicts": {
    "over":  "🔴 법정 상한을 넘습니다",
    "at":    "🟢 법정 상한 이내입니다",
    "zero":  null
  },
  "legalBasis": { "law": "공인중개사법", "article": "제32조·제33조" },
  "verification": { ... }
}
```

**특수 케이스 — `alwaysIllegal`**

```jsonc
{
  "id": "lr_loan_broker_fee",
  "label": "대출 중개수수료",
  "alwaysIllegal": true,
  "message": "대출 중개인이 소비자에게 돈을 요구하는 것은 금액·명칭과 관계없이 불법입니다.",
  "legalBasis": { "law": "대부업법", "article": "제11조의2 제2항 / 제19조 제2항 제6호" }
}
```

## 4.6 BrokerAlert (② 방어 · 신규)

```jsonc
{
  "id": "ba_ccrs_fee",
  "severity": "yellow",        // 법률 위험도. red | orange | yellow | blue
  "display": "inline",         // 화면 무게. stop | inline. 기본 inline
                               //   stop 은 **최대 3건** — 넘으면 빌드 실패
  "phrase": "채무조정 진행해 드릴게요, 수수료는 ○○○만원입니다",
  "truth": "신용회복위원회 채무조정 신청비는 5만원이고 그 외 추가비용은 없습니다.",
  "triggers": ["채무조정 대행", "신복위 대행", "워크아웃 대행"],
  "exceptTriggers": [],          // 히트를 덮는 낱말. 겹칠 때만 무효
  "tests": [                     // 낱말 정답지. 비어 있으면 빌드 실패
    { "text": "채무조정 대행해 준다고 수수료를 달래요", "expected": true },
    { "text": "신용회복위원회에 직접 신청했어요", "expected": false }
  ],
  "action": { "label": "직접 신청하기", "phone": "1600-5500",
              "url": "https://www.ccrs.or.kr" },
  "legalBasis": null,
  "alsoBasis": [],               // 근거가 둘 이상일 때만
  "verification": { ... }
}
```

**`DocumentItem.ifMissing` — 없을 때 할 말** (선택)

```jsonc
"ifMissing": {
  "alternatives": [ { "id", "label", "whatIsThis", "verification" } ],
  "howToGet":     [ { "id", "label", "where", "verification" } ],
  "ifNoneAtAll":  "…",
  "seeProcedure": "proc_notarial_deed",   // 조건은 그 절차가 들고 있다
  "verification": { … }
}
```

**「없다」로 판정된 것에만 펼친다.** 상태가 셋이다 —
`have`(있다고 답함) · `missing`(없다고 답함) · `unknown`(아직 안 답함).
`haveIf` 가 거짓이라는 것만으로 「없다」로 읽으면 **인터뷰를 중간에 그만둔
사람 전원이 「아무것도 없는 사람」**이 된다.

문장의 선: **「자료가 될 수 있어요」 밖으로 나가지 않는다.**
「인정됩니다 · 충분합니다 · 증거가 됩니다」는 법원이 정하는 것이다.

`seeProcedure` 가 가리키는 절차의 **`caution` · `legalBasis` · `fees`** 를 화면이
그대로 데려온다. 조건도 요금표도 **여기서 다시 쓰지 않는다** — 두 벌이 되면
언젠가 한쪽만 고쳐진다.

**없어서 못 하는 것과 아직 안 한 것은 다르다.** 내용증명처럼 지금 만들 수 있는
것은 `showIf` 로 감추지 말고 **누구에게나 목록에 두고** `haveIf` 로 표시만
가른다. 감추면 지금 할 수 있는 일이 화면에서 사라진다.
문구는 **「하세요」가 아니라 「하실 수 있어요」**다.

**일부러 비운 자리에는 `_ifMissingNote` 로 이유를 남긴다.** 대안이 근거 없는
경험칙이거나 경우마다 달라 하나로 못 쓰면 비워 두는 것이 맞다 — 눌렀는데 할
말이 없으면 그게 더 나쁘다. 다만 이유가 없으면 다음 사람이 「빠뜨렸나」 하고
아무 말이나 채운다.

**`DocumentItem.haveIf` — 이미 갖고 있는가** (선택)

`showIf` 와 **다른 축**이다.

```
showIf  이 서류가 **필요한가**
haveIf  사용자가 **이미 갖고 있는가**
```

둘을 안 나누면 이미 있다고 답한 서류를 「준비하세요」로 다시 내민다.
없으면 「모른다」다 — 갖고 있다고 단정하지 않는다.
**화면은 목록에서 지우지 않고 표시만 바꾼다.**

```jsonc
"showIf": null,
"haveIf": { "in": ["contract", { "var": "writtenEvidence" }] }
```

**`Question.flowOnly` — 계산에 안 쓰는 질문이라고 적는 자리**

검증기가 「물어 놓고 아무 데서도 안 읽는 필드」를 **경고**한다(검사 g).
묻는 이유가 계산만은 아니다 — 흐름을 고르거나 사용자가 자기 상황을 정리하도록
묻는 것도 정당하다. **다만 그렇다고 적혀 있어야 한다.**

```jsonc
"field": "demandDate",
"flowOnly": true      // 계산에 안 쓴다. 사용자가 자기 날짜를 인식하게 하는 질문
```

표시가 없는데 안 읽히면 둘 중 하나다 — 읽어야 하는데 안 읽는 것이거나,
물을 이유가 없는 질문이거나. **경고를 0으로 만들려고 표시를 다는 것이 이 검사를
죽이는 길이다.**

**`Caution.question` — 안내는 물음으로 나간다** (필수)

「달라질 수 있는 것」을 넷 다 펼쳐 놓으면 해당 없는 사람도 넷을 다 지나쳐
내려가야 한다. 화면은 물음 버튼만 내고, 눌러야 `condition` + `consequence` +
근거가 펼쳐진다. **`cautions[]` 에서 비어 있으면 빌드가 깨진다.**

```jsonc
"question":    "빌려주는 일을 업으로 하시나요?",     // 버튼에 그대로 나간다
"condition":   "빌려주는 일을 업으로 하고 계시다면",  // 펼친 안쪽
"consequence": "…"
```

`condition` 을 버튼에 그대로 쓰지 않는다. 조각 문장이라 물음이 되지 않고, 화면이
어미를 붙이면 「하셨다면라면」이 다시 나온다 ([DECISIONS 78](DECISIONS.md)).

**물음은 상태를 단정하지 않는다.** 「대부업자이신가요?」 ✘ →
「빌려주는 일을 업으로 하시나요?」 ✔ — 대부업자인지는 판단이다. 위기 문구 규칙과 같다.

`jurisdictionGuide.branches` 도 `Caution` 이지만 물음이 아니라 **갈래**라서
요구하지 않는다. 셋을 나란히 보여주는 것이 그쪽의 규칙이다 (DECISIONS 72).

**`severity` 와 `display` 는 다른 축이다**

```
severity   법률 위험도.  데이터가 정한다. 화면은 **색**으로 쓴다
display    화면 무게.    stop 이면 큰 카드로 멈춰 세운다. 기본은 inline
```

위험도로 무게를 정하면 안 된다 — `red` 가 8건이라 여덟이 큰 카드가 되고,
**기본이 되면 아무것도 못 멈춘다.** `stop` 의 기준은 「사용자 본인이 형사처벌
대상이 되거나, 지금 움직이면 되돌릴 수 있는 것」이고 **상한이 3건**이다.
`inline` 도 조문·창구·`truth` 를 똑같이 단다 — 약해서가 아니라 되돌릴 게 없어서다.

**`triggers` — 이 파일은 모든 분야가 공유한다**

브로커 경보는 `_shared_crisis` 에 모여 있고 전 분야가 같은 목록을 쓴다.
**한 분야에서 자연스러운 말이 다른 분야에서 경보가 된다.**

```
「보증금」    전세·월세 분야의 일상어    → 「보증금을 먼저 입금」 으로 좁혔다
「일당 30」   임금체불 분야의 일상어      → 뺐다
「착수금」    변호사 착수금              → 「착수금을 먼저」 로 좁혔다
「금융거래법」 「전자금융거래법」의 부분문자열 → exceptTriggers 로 덮었다
```

낱말은 **틀릴 수 없는 것만** 담는다. 오탐이 나면 조문과 무관한 자리에
「이건 100% 사기입니다」가 붙어 **틀린 근거를 대게 된다** — 단순한 성가심이 아니다.
`tests[]` 는 `hardStops` · `autoTriggers` 와 같은 정답지이고 **음성 사례가 없으면
빌드가 깨진다.** 항목별 정답지가 못 보는 자리는 `keyword_golden_test.dart` 가
문장 하나를 **경보 전부**에 대어 본다.

**`legalBasis.text` 에는 조문 원문만 둔다**

화면이 `quote` scope 로 그리는 자리다. 요약을 넣으면 **창작이 인용처럼 보인다.**

```
(a) text 가 있으면 law · article 이 반드시 있어야 한다
(b) 「입니다·습니다·해요·예요·드립니다·위반 시」 → 우리 말투. 원문이 아니다
(c) article 에 조문이 여럿이면(·, /) text 를 담을 수 없다 → alsoBasis 로 나눈다
```

셋 다 `verify_domains` 가 막는다. 원문을 못 받았으면 **`text` 를 비우고**
`article` 만 남긴다 — 조문 이름은 화면에 나가고 매니페스트에도 잡힌다.
생략한 자리는 `…` 로 드러낸다.

**`alsoBasis` — 근거가 하나로 안 끝날 때** (`BrokerAlert` · `Caution`)

숫자가 든 조문과 효과가 든 조문은 대개 다른 법령에 있다. 연 60% 는 대부업법
시행령에, 「그래서 계약이 무효」는 대부업법 본문에 있다. **하나만 달면 나머지는
법령 매니페스트에서 사라져 개정이 나도 아무도 모른다.** 순서는 사람이 읽을
순서이고, 매니페스트 수집기는 `law` · `article` 을 가진 맵을 위치와 무관하게
줍기 때문에 생성기를 고칠 필요가 없다.

```jsonc
"legalBasis": { "law": "대부업법", "article": "제8조의2 제1항", "text": "…" },
"alsoBasis": [
  { "law": "대부업 등의 등록 및 금융이용자 보호에 관한 법률 시행령",
    "article": "제5조의2 제1항", "text": "…연 100분의 60을 말한다." }
]
```

**severity 의미**
| 값 | 뜻 |
|---|---|
| `red` | 들으면 100% 불법 |
| `orange` | 응하면 본인도 처벌 |
| `yellow` | 법정 기준 초과 — 계산해 보세요 |
| `blue` | 애초에 불가능한 약속 |

## 4.7 Resource (③ 자원 · 신규)

```jsonc
{
  "id": "res_ccrs_quick",
  "tier": 4,                     // 사다리 단계 0~8
  "name": "신속채무조정",
  "org": "신용회복위원회",
  "phone": "1600-5500",
  "url": "https://www.ccrs.or.kr",
  "cost": 50000,                 // 원 단위. 0 = 무료
  "eligibility": [
    { "label": "연체 30일 이하", "condition": {...} },
    { "label": "총채무 15억원 이하", "condition": {...} }
  ],
  "benefit": "이자율 30~50% 인하 · 최장 3년 유예 · 최장 10년 분할",
  "verification": { ... }
}
```

## 4.8 나머지 타입

```jsonc
// DocumentItem
{ "id":"doc_transfer_record", "label":"계좌이체 내역", "importance":"high",
  "issuedBy":"거래 은행", "onlineAvailable":true, "showIf":null, "verification":{...} }

// JurisdictionRule
{ "id":"jr_debtor_address", "label":"채무자 주소지 관할 법원",
  "inputField":"debtorAddress", "lookupTable":"court_by_district", "verification":{...} }

// Procedure
{ "id":"proc_payment_order", "step":4, "name":"지급명령 (독촉절차)",
  "summary":"...", "costRefs":[...], "deadlineRefs":[...], "documentRefs":[...],
  "officialLinks":[...], "legalBasis":{...}, "verification":{...} }

// HardStop
{ "id":"hs_criminal", "trigger":{"type":"keyword",
  "patterns":["고소","형사","사기죄","경찰서","검찰","구속","송치","마약","도박장"]},
  "screen":"hardstop_criminal", "channels":["klac_132","helplaw24"] }

// LookupTool
{ "id":"lt_lender", "label":"등록 대부업체 조회",
  "url":"https://fines.fss.or.kr/fines/plis/moneyLenderSearch/MoneyLenderSearch.getMoneyLenderList.do",
  "hint":"받은 전화번호로 역조회하세요", "verification":{...} }

// PublicChannel
{ "id":"klac_132", "label":"대한법률구조공단", "phone":"132",
  "note":"무료 법률상담", "url":"https://klac.or.kr", "verification":{...} }
```

---

# 5. 엔진 명세

## 5.1 공통

```dart
// 모든 엔진은 순수 함수. 네트워크·LLM 호출 없음.
abstract class Engine<TOut> {
  TOut compute(Domain domain, CaseFacts facts);
}

class CaseFacts {
  final Map<String, dynamic> values;   // field → value
  T? get<T>(String field);
}
```

## 5.2 DeadlineEngine

```dart
class DeadlineResult {
  final String id, label;
  final DateTime dueDate;
  final int daysRemaining;      // 음수 = 경과
  final Severity severity;
  final LegalBasis basis;
}

List<DeadlineResult> compute(Domain d, CaseFacts f);
```

- `showIf` 미충족 항목은 제외
- `basisField` 값이 없으면 제외 (에러 아님)
- 정렬: severity DESC → daysRemaining ASC

## 5.3 CostEngine

```dart
class CostLine {
  final String id, label;
  final int amount;         // 조문대로. 정답지가 보는 값
  final int guidedAmount;   // 화면에 낼 값 (안전 여유가 더해진 값)
  final List<String> appliedModifiers;
}
class CostResult {
  final List<CostLine> lines;
  final int total;          // amount 의 합
  int get guidedTotal;      // guidedAmount 의 합
}
```

modifier 적용 순서: **정의된 배열 순서대로 곱셈**. `rounding` 은 계산식 직후 1회, 그리고
**준용 규정이 있는 modifier 뒤에만** 한 번 더. `{minimum, roundDown}` 은 택일이다
(인지법 제2조②). 갈래가 여럿이면 `costScenarios` 로 한 벌씩 계산해 나란히 낸다.

**`amount` 와 `guidedAmount` 는 다른 층이다.** 인지법 제16조 뒤에는 끝수 준용이 없어
문언대로면 900원이 나오는 조합이 있다. 그대로 안내했다가 법원이 1,000원을 요구하면
보정 명령이 오고, 1,000원으로 안내했다가 실제가 900원이면 100원을 더 낼 뿐이다.
화면은 `guidedAmount`/`guidedTotal` 을, **정답지는 `amount`** 를 본다. 최저액은 코드가
아니라 데이터(`rounding.minimum`)에서 온다. 둘이 갈리면 펼침 내역이 두 값을 나란히
보여준다 — 왜 올라갔는지 안 보이면 그건 그냥 틀린 숫자다.

## 5.4 LimitChecker (신규)

```dart
enum LimitVerdict { over, within, alwaysIllegal, unknown }

class LimitResult {
  final LimitVerdict verdict;
  final int? legalMax;
  final int? requested;
  final int? excess;
  final String message;
  final LegalBasis basis;
}

LimitResult check(LimitRule rule, Map<String, num> inputs);
```

`alwaysIllegal: true`면 입력과 무관하게 `LimitVerdict.alwaysIllegal` 반환.

## 5.5 SafetyFilter

```dart
class SafetyFilter {
  static const patterns = [
    r'승소', r'이길 수 있', r'유리합니다', r'가능성이 높습니다',
    r'100%', r'확실히', r'무조건', r'반드시 받',
    r'주장하세요', r'걱정하지', r'제 생각에',
  ];
  static bool isSafe(String text);
  static void assertSafe(String text);   // 위반 시 throw (debug) / 차단 + 로깅 (release)
}
```

**정적 문구도 예외 없이 통과해야 합니다.** 위젯 빌드 시점에 검사하세요.

## 5.6 InterviewEngine

```dart
Question? next(Domain d, CaseFacts f);   // null = 완료
int score(Domain d, CaseFacts f);        // 판단가능성
Readiness readiness(Domain d, CaseFacts f);  // green | yellow | red
```

**판정**
```
필수 항목 전부 확보 && 점수 ≥ 임계값        → green
필수 항목 70% 이상 && 점수 ≥ 임계값의 60%   → yellow
그 외                                      → red (결과 화면 대신 되돌아가기)
```

**M1에서는 LLM 없이 만듭니다.** 선택지 기반만으로 동작해야 합니다.

---

# 6. 전화번호 역조회 (② 방어)

**단계적으로 구현합니다. M4에는 Level 1만.**

| Lv | 방식 | 난이도 | 시점 |
|---|---|---|---|
| **1** | 형식 판별 + 공식 조회처 딥링크 | **0.5일** | **M4** |
| 2 | 자체 등록업체 DB | 어려움 (공개 API 없음) | 보류 |
| 3 | 더치트 API 연동 | 유료 파트너십 | 사용자 확보 후 |

## Level 1 명세 (M4 구현 대상)

```dart
class PhoneRiskResult {
  final List<PhoneFlag> flags;
  final List<LookupTool> lookupTools;
}

enum PhoneFlag {
  internetPhone,      // 070, 050x
  international,      // +82 외 국제번호
  personalMobile,     // 010 — 금융회사는 대표번호 사용
  unknownFormat,
}
```

**규칙 (API 불필요, 순수 로직)**

| 조건 | 경고 |
|---|---|
| `070`, `050` 시작 | 인터넷전화입니다. 금융회사 사칭이 많습니다 |
| 국제번호 (한국 외) | 국내 금융회사가 국제번호로 전화하지 않습니다 |
| `010` 개인번호로 대출·채무조정 상담 | 정식 금융회사·공공기관은 대표번호를 씁니다 |

**그리고 공식 조회처로 보냅니다**
```
[ 금감원 등록 대부업체 조회 ]  ← 받은 번호로 역조회
[ 경찰청 사이버사기 피해신고 이력조회 ]
[ 더치트 조회 ]
```

> **핵심 UX 포인트**: 역조회의 가치는 "조회 결과"가 아니라 **"조회할 수 있다는 사실을 알려주는 것"**입니다.
> 대부분의 사람은 이런 조회처가 있다는 걸 모릅니다. Level 1만으로 가치의 대부분이 나옵니다.

---

# 7. 로컬 DB (Drift)

```
cases          id, domainId, title, createdAt, updatedAt, status, progressPct
case_facts     caseId, field, value(json), source, confidence, updatedAt
case_deadlines caseId, deadlineId, dueDate, severity, notifiedAt, dismissed
case_todos     caseId, todoId, label, done, doneAt, order
case_documents caseId, docId, fileName, localPath, remotePath, importance, uploadedAt
case_events    caseId, eventDate, label, note, createdAt
```

**Supabase 동기화**
- `cases` / `case_facts` — 클라이언트 암호화 후 업로드 (선택 기능, 기본 OFF)
- `anon_events` — 개인정보 제거 후 통계용

```sql
anon_events(id, domain_id, stage, event_type,
            amount_bucket,   -- 정확 금액 금지. 구간만
            region_code,     -- 시도 단위만
            days_from_start, occurred_month)
```

---

# 8. 화면 구조

```
[탭 1] 📁 내 사건       ⑤   ← 앱 기본 진입
[탭 2] 📖 알아보기      ③④  ← 분야별 정보 · 계산기 단독 사용
[탭 3] 🛡️ 지켜보기      ②   ← 브로커 경보 · 조회 도구 · 상한 계산
[탭 4] 🆘 도움받기      ①③  ← 위기 연결 · 무료 창구
[탭 5] 내 정보

[모달] 사건 만들기
  분야 선택 → 인터뷰 → 사건 정리 카드 → 결과(기한·비용·절차) → 저장
```

## 8.1 결과 화면 3층 표시 규칙

법률 정보 블록은 반드시 세 층으로 분리하고 **시각적으로 섞지 않습니다.**

| 층 | 조건 | 필수 요소 | 문장 형식 |
|---|---|---|---|
| 🟢 **법에 있는 내용** | 조문 원문 확보 + 검증 통과 | 조문 원문 + 링크 | 평서 인용 |
| 🟡 **적용될 가능성** | 🟢 근거 존재 + 필수 사실 충족 | 연결된 🟢 블록 ID | **조건절 필수** ("~라면") |
| 🔴 **확인 안 된 것** | 필수 사실 미확보 | 되돌아갈 질문 링크 | "확인하지 못했습니다" |

**코드 강제**
- 🟡 블록은 🟢 블록 참조 없이 생성 불가 → 렌더링 차단
- 🟡 문장에 조건절 정규식 미매칭 시 차단

## 8.2 용어 풀이 — **검색하지 않고 표시한다**

밑줄을 그을 문장은 **우리가 쓴 문장**이다. 훑을 이유가 없다.

```
✘ 용어집 키로 화면 문자열을 검색해서 자동으로 밑줄을 붙인다
⭕ 문장 안에 토큰을 박는다 →  「법원이 [[지급명령]]을 합니다」
```

`주소가` ⊃ `소가` · `생각하다` ⊃ `각하` · `확정신고` ⊃ `확정` 문제가
**설계 단계에서 사라진다.** 파서는 `engines` 에 있고 검증기와 화면이
같은 것을 본다. 모든 검사는 `stripTerms` 로 대괄호를 뗀 뒤에 돈다.

**`assets/glossary/terms.json`** — 분야를 가로지르므로 도메인 밖에 산다.

```jsonc
{ "term": "지급명령", "kind": "statute" | "our_words",
  "oneLiner": "…",              // 40자 이내. 넘으면 빌드가 선다
  "lawRef": { … }, "alsoBasis": [ … ], "effective": "2025-07-12",
  "verification": { … } }
```

| 갈래 | 뜻 | 시트 |
|---|---|---|
| 🟢 `statute` | 법에 뜻이나 효력이 적혀 있다 | 조문 원문 + 출처 |
| 🟡 `our_words` | 법이 쓰지만 뜻을 정해 두지 않았다 | **근거 배지 금지** + 우리 말 고지 |
| ✘ | 화면에서 쓰지 않을 말 | 용어집에 넣지 않고 문장에서 뺀다 |

**조문이 있다고 다 정의는 아니다.** 인지법 제1조는 「붙여야 한다」는 의무이고
송달료규칙 제2조는 「누가 내는가」다. 한 줄 풀이는 우리 말로 쓰고, 조문은
**그 조문이 실제로 정하는 것**의 근거로만 싣는다.

시트 순서는 고정이다 — ① 말 ② 🟡 고지 ③ 한 줄 풀이 ④ 조문 원문 ⑤ 출처
⑥ 닫기. **④를 접지 않는다.** 접으면 아무도 안 연다.

한 줄 풀이도 토큰을 쓸 수 있다 — 40자 안에서는 괄호로 풀 자리가 없고
**밑줄이 곧 그 자리를 여는 문**이다. 풀이끼리 돌고 돌면(자기 참조 포함)
빌드가 막는다.

**토큰은 낱말을 통째로 감싼다.** 「확정[[판결]]」은 화면에서 뒤 두 글자에만
점선이 그어져 두 낱말로 읽힌다. 토큰 앞에 한글이 붙으면 실패다.

**시트는 한 겹까지 열린다.** 둘째 겹부터는 토큰을 평문으로 그려 더 들어갈
문을 없앤다 — 못 열게 막으면 고장으로 읽히고, 세 겹 쌓이면 사람이 자기가
어디 있었는지 잊는다.

**근거 원문 안에는 아무것도 넣지 않는다.** 토큰도, 밑줄도, 병기도.
`legalBasis.text`·`alsoBasis[].text` 안의 `[[` 는 **실패**다. 손대는 순간
원문이 아니게 되고, 인용은 3층 🟢 의 전제다.

화면 규칙 — **점선 밑줄이고 파란 링크가 아니다**(다른 데로 간다는 뜻으로
읽힌다). 상한은 **이어지는 문장 300자당 셋**이다. 카드가 길면 카드 하나가
화면 세 개 분량이라 카드당 셋은 화면당 하나가 되고, 짧으면 셋이 밑줄 밭이
된다. 기준은 손가락으로 한 번에 보이는 만큼이지 데이터 구조가 아니다.
같은 말은 그 카드에서 첫 번째만.

**붙이는 자리는 하나뿐이다** — 그 말을 모르면 그 문장의 **결론이 안 읽히는**
자리. 나열된 낱개에는 붙이지 않고 그것들을 **묶는 말**에만 붙인다
(「판결·확정된 지급명령」은 셋 다 집행권원의 예시다). 「판결」·「확정」은
몰라도 문장이 읽히므로 붙이지 않고, 카드가 자기 이름으로 쓰는 말도
`whatIsThis` 가 이미 설명하므로 붙이지 않는다.

**빌드가 막는 것** — 용어집에 없는 토큰 · 화면에 남은 대괄호 · 40자 초과 ·
🟢 의 원문 누락 · 🟡 에 붙은 조문 · 매니페스트와 다른 시행일 · 밑줄 상한
초과 · 낱말 중간을 자른 토큰 · 풀이의 순환 · 「인용」·「채무명의」가 화면
문장에 등장 · **저장소 어디에든 매니페스트에 없는 「제○조」**.

마지막 것은 파일을 나열하지 않는다. 나열하면 새 파일에서 또 뚫린다 —
실제로 용어집이 그렇게 판본 추적 밖에 있었다. 넘기는 자리는 그 **개수를
갈래별로 검증기가 매번 찍는다.**

**가르는 기준은 이름이 아니라 관계다.** 조문 원문인가는 「`law` 가 형제로
있는가」로, 검수 메모인가는 「`verification` 아래인가」로 본다. 이름으로
가르면 같은 이름이 다른 뜻으로 쓰이는 자리에서 샌다 — `verification.note`
(안 나감)와 `PublicChannel.note`(화면에 나감)가 그랬다.

문서(`.md`)도 훑되 **경고로만** 낸다. 다음 사람이 읽고 그걸 근거로 코드를
짜는 문서라서 넣고, 문서 고치다 빌드가 서면 안 되니 실패로 하지 않는다.
인용 블록 안은 넘기고, 사람이 판단해 단 표시도 넘긴다 —
`(불채택)` 안 쓰기로 했다 · `(조건부)` 아직 조건이 안 왔다.
**표시를 지우면 경고가 되살아난다.**

**경고만 하는 것** — 아직 안 쓰는 용어집 항목. 그리고 「✏️ 밑줄 후보」 —
용어집 키가 토큰 밖에 쓰인 자리. **자동으로 붙이지 않는다.** 붙이는 순간
그게 곧 검색 방식이고 이 규칙 전체가 무너진다.

---

# 9. 마일스톤

| M | 내용 | 기간 |
|---|---|---|
| **M0** | 프로젝트 셋업 + 엔진 5종 + 테스트 | 2주 |
| **M1** | 도메인 로더 + 인터뷰 + 결과 화면 (로컬만) | 3주 |
| **M2** | 인증 + 사건 저장 + 대시보드 | 2주 |
| **M3** | 기한 알림 — `NotificationService` 추상화 + Android 로컬/FCM | 2주 |
| **M4** | 위기 연결 + 브로커 경보 + LimitChecker + 번호 역조회 Lv1 | 2주 |
| **M5** | 원격 데이터 교체 + Android 빌드 + 웹 배포 | 2주 |
| | **합계** | **13주** |
| M6+ | 분야 추가 (JSON만) | 분야당 2~3주 |

## 9.1 M2 완료 기준

M1 이 저장을 갖지 않아 미뤄 둔 것들이다. **셋은 같은 작업 묶음이고 하나만 먼저
들어가면 안 된다** — 저장을 시작하는 순간 M1 의 "저장하지 않습니다" 고지가 거짓이 된다.

- [ ] **인터뷰 도중 새로고침하거나 앱을 종료해도 답한 내용이 남아 이어서 진행된다**
      (DECISIONS 33번 — M1 에서는 홈으로 롤백되는 것이 올바른 동작이었다)
- [ ] 홈 자유 입력에 개인정보 마스킹이 적용된다 (DECISIONS 31번)
- [ ] 저장을 시작하면 홈·인터뷰의 "저장되지 않습니다" 고지를 사실에 맞게 고친다

---

# 10. M0 작업 지시

```
T1  모노레포 셋업 (melos)
    packages/engines        ← 순수 Dart, flutter 의존 금지
    packages/domain_data
    apps/beoba

T2  도메인 모델 정의 (freezed + json_serializable)
    - 모든 타입에 verification 필수
    - 스키마 검증기: 필수 필드 누락 · whyAsk 공백 · tests 누락 → 예외

T3  KstClock + DeadlineEngine
    - calcRule 4종
    - 윤년 · 월말 경계 · 30/31일 처리
    - JSON의 tests[] 를 읽어 자동 테스트 생성

T4  CostEngine
    - tiered / fixed / perUnit
    - modifier 체인 (배열 순서 곱셈)
    - roundDown, int 연산
    - 경계값 테스트 (1천만 / 1억 / 10억)

T5  JurisdictionEngine + DocumentEngine

T6  LimitChecker
    - tiered_with_cap
    - alwaysIllegal 분기

T7  SafetyFilter + 스키마 검증기
    - CI에서 assets/domains/*.json 전수 검증
    - 실패 시 빌드 중단

T8  통합 확인
    debt_recovery.json 로드 → 5개 엔진 통과 → 콘솔 출력
    (화면 없음)
```

**T3~T6은 병렬 가능.** 인터페이스만 먼저 확정하세요.

---

# 11. 코딩 규칙

```
1. packages/engines 는 Flutter에 의존하지 않는다 (순수 Dart)
2. DateTime.now() 직접 호출 금지 → KstClock 주입
3. 모든 날짜 연산은 KST 자정 기준. UTC 금지
4. 금액은 int (원). double 금지
5. 사용자에게 보이는 모든 문자열은 SafetyFilter 통과
6. 법률 정보 위젯은 legalBasis 없이 생성 불가 (required)
7. verification.status == unverified 데이터는 로더에서 제거
8. JSON의 tests[] 는 CI에서 반드시 실행
9. 하드코딩된 법률 수치 금지 — 전부 JSON에서 읽는다
```

**9번이 특히 중요합니다.** 제도가 자주 바뀝니다. 코드에 숫자를 박으면 앱 업데이트 없이 못 고칩니다.

---

# 12. 검증 상태 (2026-08-15 기준)

`debt_recovery.json`의 각 항목 `verification.status`를 따르되, 요약하면:

## ✅ verified — 즉시 사용
```
인지대 산식 4단계 · 지급명령 인지 1/10 · 송달료 5,500원 · 소액사건 3,000만원
답변서 30일 · 지급명령 이의신청 2주
공인중개사법 중개보수 상한 요율표
대부업법 최고금리 연 20% / 60% 초과 시 전부 무효
대부업법 제11조의2 소비자 부담 중개수수료 금지
전자금융거래법 통장 대여 처벌
신용회복위원회 채무조정 3종 (요건·감면·비용 5만원)
새도약기금 (요건·한도·1660-0705)
채무자대리인 무료지원
위기 상담 번호 전체 (1336 / 1342 / 109 / 132 / 1332 / 1397 / 1600-5500)
```

## 🟡 needs_check — 화면에 배지 표시
```
전자소송 인지 10분의 9 (인지법 제16조 조문번호)
2026년 송달료 단가 (5,640원 인상설)
```

## 🔴 unverified — JSON에 넣되 status를 unverified로. 화면 미노출
```
소멸시효 (일반 10년 / 상사 5년 / 단기시효)
관할 규칙 상세
임금채권 시효 3년 / 퇴직금 14일
부당해고 구제신청 3개월
청약철회 기간
햇살론 2026 개편 내용 (☎1397 유선 확인 필요)
불법사금융예방대출 2026 금리·한도 (☎1397)
대부중개수수료 상한 (2025.12 재조정 논의)
```

---

# 13. 첨부 파일

| 파일 | 내용 |
|---|---|
| `domains/debt_recovery.json` | 분야 1 실제 데이터 |
| `domains/_shared_crisis.json` | ① 위기 연결 (전 분야 공통) |

---

*법률 수치는 전부 JSON의 `verification`을 따릅니다. 코드에 하드코딩하지 마세요.*
