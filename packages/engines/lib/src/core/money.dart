/// 원 단위 정수 금액 연산.
///
/// **`double` 로 곱하지 않는다.** `23000 * 0.9` 는 IEEE 754 에서
/// `20699.999...` 가 되어 내림하면 20,699원이 된다. 실제 인지대는 20,700원이다.
/// 요율을 정수(백만분율)로 바꾼 뒤 정수 곱셈·나눗셈만 한다.
class Money {
  const Money._();

  /// 요율을 정수로 바꿀 때 쓰는 배율. 백만분율(ppm).
  static const int scale = 1000000; // not-a-legal-number: 계산 배율

  /// 오버플로 방지 상한. 이 이상은 법률 계산에서 나올 수 없는 금액이다.
  static const int maxBase = 9000000000000; // not-a-legal-number: 오버플로 한계

  /// 정확히 표현할 수 있는 최대 정수 — **웹 기준**.
  ///
  /// 웹(dart2js)에서 `int` 는 JS 실수라 2^53 까지만 정확하다. 모바일(int64)보다
  /// 훨씬 좁으므로 둘 중 좁은 쪽에 맞춘다. 그래야 같은 입력이 플랫폼마다 다른 답을
  /// 내놓는 일이 없다.
  static const int maxSafeInteger = 9007199254740991; // not-a-legal-number: 2^53-1

  /// 만원 한 장이 몇 원인가.
  static const int manwon = 10000; // not-a-legal-number: 단위 환산

  /// 만원 칸에 넣을 수 있는 최대 수.
  ///
  /// 화면이 만원 단위로 받더라도 **저장은 원 단위 정수 그대로다.** 곱한 뒤에도
  /// [maxBase] 안에 있어야 하므로 입력 자체를 여기서 막는다. 곱하고 나서 터지면
  /// 사용자는 자기가 뭘 잘못했는지 알 수 없다.
  static const int maxManwonInput = maxBase ~/ manwon;

  /// 만원 단위 입력을 원으로 바꾼다.
  ///
  /// 인지대는 구간이 갈리므로 **원 단위 정확도를 하나도 잃으면 안 된다.**
  /// 만원 입력은 화면의 편의일 뿐이고, 여기를 지나는 순간 원이 된다.
  static int fromManwon(int manwonAmount) {
    if (manwonAmount.abs() > maxManwonInput) {
      throw ArgumentError.value(
        manwonAmount,
        'manwonAmount',
        '만원 단위 입력이 계산 가능 범위를 넘습니다',
      );
    }
    return manwonAmount * manwon;
  }

  /// [base] 에 [rate] 를 곱한다. 내림(0 방향 절사).
  ///
  /// 예: `applyRate(50000000, 0.0045) == 225000`
  static int applyRate(int base, double rate) => _multiply(base, rate);

  /// [base] 에 배수 [multiplier] 를 곱한다. 내림.
  ///
  /// 예: `applyMultiplier(23000, 0.9) == 20700`
  static int applyMultiplier(int base, double multiplier) =>
      _multiply(base, multiplier);

  /// [unit] 원 미만 절사. `unit` 이 null 이거나 1 이하면 그대로 둔다.
  ///
  /// 예: `roundDown(16666, 100) == 16600`
  static int roundDown(int amount, int? unit) {
    if (unit == null || unit <= 1) return amount;
    return (amount ~/ unit) * unit;
  }

  /// 단가 × 수량.
  static int perUnit(int unitPrice, int units) => unitPrice * units;

  static int _multiply(int base, double factor) {
    if (base.abs() > maxBase) {
      throw ArgumentError.value(base, 'base', '금액이 계산 가능 범위를 넘습니다');
    }
    final scaledFactor = (factor * scale).round();
    if (scaledFactor == 0) return 0;

    final sign = (base < 0) != (scaledFactor < 0) ? -1 : 1;
    final absBase = base.abs();
    final absFactor = scaledFactor.abs();

    // `(base * scaledFactor) ~/ scale` 을 그대로 하면 중간값이 불필요하게 커진다.
    // 몫과 나머지로 쪼개면 결과는 같으면서 중간값이 scale 배만큼 작아져,
    // 웹의 2^53 안에서도 정확하게 계산된다.
    //   base = whole × scale + fraction
    //   (base × f) ~/ scale = whole × f + (fraction × f) ~/ scale
    final whole = absBase ~/ scale;
    final fraction = absBase % scale;

    // base 만 보면 부족하다. modifier.multiply 는 JSON 에서 오고 1을 넘을 수 있어
    // (할증), 큰 금액 × 큰 배수가 표현 범위를 넘길 수 있다. 중간값을 직접 본다.
    final limit = maxSafeInteger ~/ absFactor;
    if (whole > limit || fraction > limit) {
      throw ArgumentError.value(
        factor,
        'factor',
        '계산 결과가 정확히 표현할 수 있는 범위를 넘습니다 (base: $base)',
      );
    }
    return sign * (whole * absFactor + (fraction * absFactor) ~/ scale);
  }
}
