import 'package:beoba/src/layers/legal_layer.dart';
import 'package:beoba/src/widgets/layer_block.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// SPEC §8.1 — 🟡 는 🟢 참조 없이 만들 수 없고, 단정하지 말고 조건부로 말해야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const basis = LegalBasis(
    law: '민사소송법',
    article: '제256조 제1항',
    text: '피고는 소장의 부본을 송달받은 날부터 30일 이내에 답변서를 제출하여야 한다.',
  );

  const green = GreenBlock(
    id: 'dl_answer',
    title: '민사소송법 제256조 제1항',
    basis: basis,
    quotedText: '피고는 소장의 부본을 송달받은 날부터 30일 이내에 답변서를 제출하여야 한다.',
  );

  const yellow = YellowBlock(
    greenRefId: 'dl_answer',
    condition: '「답변서 제출」의 기산일이 2026년 8월 15일이라면',
    consequence: '기한은 2026년 9월 14일 (D-30) 입니다',
  );

  group('🟡 는 🟢 없이 존재할 수 없다', () {
    test('참조가 살아 있으면 그린다', () {
      const blocks = LayerBlocks(green: [green], yellow: [yellow]);
      expect(blocks.renderableYellow, hasLength(1));
    });

    test('참조가 죽으면 렌더링 목록에서 빠진다', () {
      const orphan = YellowBlock(
        greenRefId: 'dl_없는것',
        condition: '무언가',
        consequence: '어떻게 됩니다',
      );
      const blocks = LayerBlocks(green: [green], yellow: [orphan]);

      expect(blocks.renderableYellow, isEmpty);
    });

    testWidgets('🟢 가 하나도 없으면 🟡 도 화면에 나오지 않는다', (tester) async {
      const blocks = LayerBlocks(yellow: [yellow]);

      await pumpWidgetOnly(
        tester,
        LayerSection(blocks: blocks, onFix: (_) {}),
      );

      expect(find.byType(YellowBlockView), findsNothing);
    });
  });

  group('🟡 문장은 잇기만 한다', () {
    test('조건과 결과를 쉼표로 잇는다', () {
      expect(
        renderYellow(yellow),
        '「답변서 제출」의 기산일이 2026년 8월 15일이라면, 기한은 2026년 9월 14일 (D-30) 입니다',
      );
    });

    test('어미를 덧붙이지 않는다', () {
      // 데이터의 조건절은 이미 `~다면` 으로 끝난다. 화면이 `라면` 을 또 붙여
      // 「이자를받기로하셨다면라면」이 나갔다. 말은 데이터에서 온다.
      const block = YellowBlock(
        greenRefId: 'x',
        condition: '상대가 개인 사업자라면',
        consequence: '절차가 달라집니다',
      );
      expect(renderYellow(block), '상대가 개인 사업자라면, 절차가 달라집니다');
    });

    test('자유 문장을 받는 생성자가 없다', () {
      // 조건과 결과를 따로 받는 것이 유일한 경로다. 완성된 문장을 넣을 수 없으므로
      // "지금 신청하면 됩니다" 같은 지시문이 🟡 로 새어 나갈 길이 없다.
      const block = YellowBlock(
        greenRefId: 'x',
        condition: '조건',
        consequence: '결과',
      );
      expect(block.condition, '조건');
      expect(block.consequence, '결과');
    });

    testWidgets('화면에 조건절 문장과 근거 칩이 함께 나온다', (tester) async {
      const blocks = LayerBlocks(green: [green], yellow: [yellow]);

      await pumpWidgetOnly(
        tester,
        LayerSection(blocks: blocks, onFix: (_) {}),
      );

      expect(find.text(renderYellow(yellow)), findsOneWidget);
      // 근거 칩이 "🟡 는 🟢 없이 존재할 수 없다" 를 화면에 드러낸다.
      expect(find.text('근거'), findsOneWidget);
      expect(find.text('민사소송법 제256조 제1항'), findsNWidgets(2));
    });
  });

  group('🔴 는 막다른 골목이 아니다', () {
    testWidgets('되돌아갈 질문 링크로 끝난다', (tester) async {
      const red = RedBlock(
        label: '돈을 갚기로 한 날은 언제인가요?',
        questionId: 'q_due_date',
      );
      var fixed = '';

      await pumpWidgetOnly(
        tester,
        LayerSection(
          blocks: const LayerBlocks(red: [red]),
          onFix: (id) => fixed = id,
        ),
      );

      expect(find.text(red.label), findsOneWidget);
      await tester.tap(find.text(RedBlockView.action));
      expect(fixed, 'q_due_date');
    });
  });
}
