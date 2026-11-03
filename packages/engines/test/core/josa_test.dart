import 'package:engines/engines.dart';
import 'package:test/test.dart';

void main() {
  /// 골든셋 — 이 앱의 화면에 실제로 나오는 낱말들.
  ///
  /// 낱말이 늘 때마다 여기에 한 줄을 더한다. 조사를 이어 붙이는 코드는
  /// **낱말이 늘어날 때마다 다시 틀리기 때문**에 목록으로 잠가 둔다.
  const words = <String, ({String topic, String by})>{
    '인지대': (topic: '인지대는', by: '인지대로'),
    '송달료': (topic: '송달료는', by: '송달료로'),
    '지급명령': (topic: '지급명령은', by: '지급명령으로'),
    '소장': (topic: '소장은', by: '소장으로'),
    '답변서': (topic: '답변서는', by: '답변서로'),
    '이의신청': (topic: '이의신청은', by: '이의신청으로'),
    '내용증명': (topic: '내용증명은', by: '내용증명으로'),
    '차용증': (topic: '차용증은', by: '차용증으로'),
    '계좌이체 내역': (topic: '계좌이체 내역은', by: '계좌이체 내역으로'),
    '판결': (topic: '판결은', by: '판결로'),
    '공정증서': (topic: '공정증서는', by: '공정증서로'),
    '관할': (topic: '관할은', by: '관할로'),
    '채권자': (topic: '채권자는', by: '채권자로'),
    '채무자': (topic: '채무자는', by: '채무자로'),
    '소액사건': (topic: '소액사건은', by: '소액사건으로'),
    '전자소송': (topic: '전자소송은', by: '전자소송으로'),
  };

  group('Josa — 골든셋', () {
    test('은/는', () {
      for (final entry in words.entries) {
        expect(
          withJosa(entry.key, Josa.topic),
          entry.value.topic,
          reason: entry.key,
        );
      }
    });

    test('으로/로 — 받침 ㄹ 은 받침 없는 쪽이다', () {
      for (final entry in words.entries) {
        expect(
          withJosa(entry.key, Josa.by),
          entry.value.by,
          reason: entry.key,
        );
      }
    });

    test('골든셋이 줄어들지 않는다', () {
      // 낱말을 지우면 그 낱말의 조사가 다시 틀려도 아무도 모른다.
      expect(words, hasLength(16));
    });
  });

  group('Josa — 나머지 짝', () {
    test('이/가 · 을/를 · 과/와 · 이라/라', () {
      expect(withJosa('판결', Josa.subject), '판결이');
      expect(withJosa('인지대', Josa.subject), '인지대가');
      expect(withJosa('소장', Josa.object), '소장을');
      expect(withJosa('송달료', Josa.object), '송달료를');
      expect(withJosa('소장', Josa.with_), '소장과');
      expect(withJosa('송달료', Josa.with_), '송달료와');
      expect(withJosa('소액사건', Josa.called), '소액사건이라');
      expect(withJosa('채무자', Josa.called), '채무자라');
    });

    test('ㄹ 이 갈리는 것은 으로/로 하나뿐이다', () {
      // 서울로 · 서울은. ㄹ 을 통째로 받침 없는 것으로 다루면 「서울는」이 된다.
      expect(withJosa('서울', Josa.by), '서울로');
      expect(withJosa('서울', Josa.topic), '서울은');
      expect(withJosa('판결', Josa.subject), '판결이');
    });
  });

  group('Josa — 한글로 끝나지 않는 말', () {
    test('숫자는 읽는 소리로 판정한다', () {
      // 「기산일이 2026년 8월 15일」처럼 숫자로 끝나는 자리가 실제로 있다.
      expect(withJosa('15', Josa.called), '15라'); // 십오
      expect(withJosa('13', Josa.called), '13이라'); // 십삼
      expect(withJosa('16', Josa.topic), '16은'); // 십육
      expect(withJosa('11', Josa.by), '11로'); // 십일 — ㄹ
      expect(withJosa('10', Josa.by), '10으로'); // 영(ㅇ) — 십(ㅂ)으로 읽어도 답은 같다
    });

    test('괄호·따옴표는 건너뛰고 그 앞을 본다', () {
      expect(withJosa('「소장」', Josa.topic), '「소장」은');
      expect(withJosa('(인지대)', Josa.topic), '(인지대)는');
    });

    test('한글도 숫자도 아니면 받침이 있는 쪽으로 둔다', () {
      // 「lease라면」보다 「lease이라면」이 덜 틀린다.
      expect(withJosa('lease', Josa.called), 'lease이라');
    });
  });
}
