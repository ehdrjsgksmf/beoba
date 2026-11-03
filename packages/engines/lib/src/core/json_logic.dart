import 'package:domain_data/domain_data.dart';

/// 지원하지 않는 연산자를 만났을 때. **조용히 무시하지 않는다.**
class JsonLogicException implements Exception {
  const JsonLogicException(this.message);

  final String message;

  @override
  String toString() => 'JsonLogicException: $message';
}

/// 도메인 JSON 의 `showIf` · `condition` 평가기.
///
/// JSONLogic 의 부분집합만 구현한다. 지원하지 않는 연산자는 **예외를 던진다** —
/// 조건을 잘못 읽어 항목을 잘못 보여주는 것보다 빌드를 깨는 편이 안전하다.
class JsonLogic {
  const JsonLogic._();

  static const Set<String> supportedOperators = {
    'var',
    '==',
    '===',
    '!=',
    '!==',
    '<',
    '<=',
    '>',
    '>=',
    'in',
    'and',
    'or',
    '!',
    '!!',
    'missing',
  };

  /// 조건이 없으면(null) 항상 참. 결과는 truthy 규칙으로 bool 로 만든다.
  static bool test(JsonMap? rule, Map<String, dynamic> data) {
    if (rule == null || rule.isEmpty) return true;
    return truthy(evaluate(rule, data));
  }

  static Object? evaluate(Object? rule, Map<String, dynamic> data) {
    if (rule is! Map) return rule;
    if (rule.length != 1) {
      throw JsonLogicException('연산자는 하나여야 합니다: ${rule.keys.join(', ')}');
    }

    final operator = rule.keys.first as String;
    final rawArgs = rule.values.first;
    final args = rawArgs is List ? rawArgs : [rawArgs];

    if (!supportedOperators.contains(operator)) {
      throw JsonLogicException('지원하지 않는 연산자: $operator');
    }

    switch (operator) {
      case 'var':
        return _resolveVar(args, data);
      case '==':
      case '===':
        return _equals(_eval(args, 0, data), _eval(args, 1, data));
      case '!=':
      case '!==':
        return !_equals(_eval(args, 0, data), _eval(args, 1, data));
      // 아직 모르는 값과는 크기를 견줄 수 없다. 그때는 **참이 아니다.**
      case '<':
        return (_compare(args, data) ?? 1) < 0;
      case '<=':
        return (_compare(args, data) ?? 1) <= 0;
      case '>':
        return (_compare(args, data) ?? -1) > 0;
      case '>=':
        return (_compare(args, data) ?? -1) >= 0;
      case 'in':
        return _contains(_eval(args, 0, data), _eval(args, 1, data));
      case 'and':
        for (final arg in args) {
          if (!truthy(evaluate(arg, data))) return false;
        }
        return true;
      case 'or':
        for (final arg in args) {
          if (truthy(evaluate(arg, data))) return true;
        }
        return false;
      case '!':
        return !truthy(_eval(args, 0, data));
      case '!!':
        return truthy(_eval(args, 0, data));
      case 'missing':
        return args
            .map((a) => evaluate(a, data))
            .whereType<String>()
            .where((key) => data[key] == null)
            .toList();
    }
    throw JsonLogicException('처리하지 못한 연산자: $operator');
  }

  /// JSONLogic 의 truthy 규칙. null·false·0·빈 문자열·빈 배열이 거짓.
  static bool truthy(Object? value) => switch (value) {
        null => false,
        final bool b => b,
        final num n => n != 0,
        final String s => s.isNotEmpty,
        final Iterable<Object?> list => list.isNotEmpty,
        final Map<Object?, Object?> map => map.isNotEmpty,
        _ => true,
      };

  static Object? _eval(List<Object?> args, int index, Map<String, dynamic> data) =>
      index < args.length ? evaluate(args[index], data) : null;

  static Object? _resolveVar(List<Object?> args, Map<String, dynamic> data) {
    final rawPath = args.isEmpty ? null : evaluate(args.first, data);
    if (rawPath == null || rawPath == '') return data;
    final fallback = args.length > 1 ? evaluate(args[1], data) : null;

    Object? current = data;
    for (final segment in rawPath.toString().split('.')) {
      if (current is Map) {
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        current = (index != null && index >= 0 && index < current.length)
            ? current[index]
            : null;
      } else {
        current = null;
      }
      if (current == null) return fallback;
    }
    return current;
  }

  static bool _equals(Object? left, Object? right) {
    if (left is num && right is num) return left == right;
    if (left == null || right == null) return left == right;
    if (left.runtimeType != right.runtimeType) {
      // "3" 과 3 처럼 타입만 다른 경우를 맞춰 준다 (JSONLogic 느슨한 비교).
      return left.toString() == right.toString();
    }
    return left == right;
  }

  /// 크기 비교. **아직 안 채워진 값이면 null** — 견줄 수 없다는 뜻이다.
  ///
  /// 사용자가 아직 답하지 않은 필드를 보는 조건은 흔하다. 그걸 예외로 터뜨리면
  /// 화면 하나가 통째로 죽는다. 반대로 값이 **있는데** 숫자가 아니면 그건
  /// 데이터가 틀린 것이라 그대로 던진다 — 조용히 false 로 넘기면 조건이 왜
  /// 안 맞는지 아무도 모른다.
  static int? _compare(List<Object?> args, Map<String, dynamic> data) {
    final left = _eval(args, 0, data);
    final right = _eval(args, 1, data);
    if (left == null || right == null) return null;
    final leftNum = _asNum(left);
    final rightNum = _asNum(right);
    if (leftNum == null || rightNum == null) {
      throw JsonLogicException('비교할 수 없는 값입니다: $left, $right');
    }
    return leftNum.compareTo(rightNum);
  }

  static num? _asNum(Object? value) => switch (value) {
        final num n => n,
        final String s => num.tryParse(s),
        _ => null,
      };

  static bool _contains(Object? needle, Object? haystack) => switch (haystack) {
        final Iterable<Object?> list => list.any((item) => _equals(item, needle)),
        final String text => needle != null && text.contains(needle.toString()),
        _ => false,
      };
}
