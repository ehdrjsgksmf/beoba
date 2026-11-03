import 'package:test/test.dart';

import '../tool/law_file_name.dart';

/// 법령 매니페스트는 **파일명을 판본으로 믿는다.** 그 믿음이 성립하는 조건을
/// 여기서 잠근다.
///
/// PDF 원본은 저장소에 없어서 CI 가 파일을 볼 수 없다. 파일명 규칙만은 파일 없이
/// 검사할 수 있고, 이 규칙이 어긋나면 매니페스트가 **조용히** 틀린다.
void main() {
  group('별표 표시가 맨 뒤 괄호에 붙어 오는 꼴', () {
    test('붙여 쓴 것도 띄어 쓴 것도 읽는다', () {
      // 이 셋이 「이름을 못 읽음」으로 쌓여 있었다. 못 읽은 것을 세어 두어서
      // 눈에 띄었다(DECISIONS 118번).
      expect(
        parseAnnexFileName(
          '근로기준법 시행령(대통령령)(제35436호)(20251023)(별표1).pdf',
        ),
        '근로기준법 시행령 [별표 1]',
      );
      expect(
        parseAnnexFileName(
          '근로기준법 시행령(대통령령)(제35436호)(20251023) (별표 3).pdf',
        ),
        '근로기준법 시행령 [별표 3]',
      );
      expect(
        parseAnnexFileName(
          '노동위원회법 시행령(대통령령)(제36423호)(20260701)(별표1).pdf',
        ),
        '노동위원회법 시행령 [별표 1]',
      );
    });

    test('별표 표시가 없으면 별표가 아니다', () {
      expect(
        parseAnnexFileName('민법(법률)(제21454호)(20260317).pdf'),
        isNull,
      );
    });
  });

  group('파일명에서 판본을 읽는다', () {
    test('법률', () {
      final parsed = parseLawFileName('민법(법률)(제21454호)(20260317).pdf')!;
      expect(parsed.name, '민법');
      expect(parsed.kind, '법률');
      expect(parsed.number, '제21454호');
      expect(parsed.effective, '2026-03-17');
    });

    test('시행령은 본법과 다른 법령이다', () {
      // 이름 부분이 비탐욕이라 `… 법률 시행령` 이 통째로 이름이 된다.
      // 여기서 잘리면 시행령의 판본이 본법 것으로 붙는다.
      final parsed = parseLawFileName(
        '대부업 등의 등록 및 금융이용자 보호에 관한 법률 시행령(대통령령)(제36313호)(20260506).pdf',
      )!;
      expect(parsed.name, '대부업 등의 등록 및 금융이용자 보호에 관한 법률 시행령');
      expect(parsed.kind, '대통령령');
    });

    test('규칙이 다른 파일은 읽지 않는다', () {
      // 예규는 파일명에 호수·시행일이 이 꼴로 들어 있지 않다. 억지로 읽어
      // 그럴듯한 판본을 만들지 않고 못 읽었다고 답한다.
      expect(
        parseLawFileName(
          '송달료규칙의 시행에 따른 업무처리요령(재일 87-4) 개정 2026.02.26 '
          '[재판예규 제1950호, 시행 2026.03.01].pdf',
        ),
        isNull,
      );
      expect(parseLawFileName('README.md'), isNull);
    });
  });

  group('같은 법령명이 둘이면 판본이 섞인다', () {
    test('둘 다 있으면 잡는다', () {
      // 실제로 겪을 뻔한 자리다. 소액사건심판법은 파일명이 제19281호(2023-03-28)
      // 인데 한동안 헤더가 제21458호(2028-03-01)인 판본으로 적혀 있었다.
      // 그때 두 판본이 같이 있었다면 overrides 의 헤더 값이 **양쪽 모두에** 붙고,
      // 인용은 정렬 순서로 먼저 온 쪽에 붙는다.
      final files = [
        parseLawFileName('소액사건심판법(법률)(제19281호)(20230328).pdf')!,
        parseLawFileName('소액사건심판법(법률)(제21458호)(20280301).pdf')!,
      ];

      final duplicates = duplicateLawNames(files);
      expect(duplicates.keys, ['소액사건심판법']);
      expect(duplicates['소액사건심판법'], hasLength(2));
    });

    test('본법과 시행령은 겹치는 것이 아니다', () {
      final files = [
        parseLawFileName('법률구조법(법률)(제18755호)(20230112).pdf')!,
        parseLawFileName('법률구조법 시행령(대통령령)(제32635호)(20220818).pdf')!,
      ];

      expect(duplicateLawNames(files), isEmpty);
    });
  });
}
