import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/card.dart';
import 'package:texas_poker/game/deck.dart';
import 'package:texas_poker/game/hand_evaluator.dart';

void main() {
  group('Deck', () {
    test('应该包含 52 张不重复的牌', () {
      final deck = Deck();

      expect(deck.cards.length, 52);
      expect(deck.cards.toSet().length, 52);
    });

    test('抽牌后牌堆数量应该减少', () {
      final deck = Deck();

      final card = deck.draw();

      expect(card, isA<PlayingCard>());
      expect(deck.remaining, 51);
    });
  });

  group('HandEvaluator', () {
    test('应该识别同花顺', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: Rank.ten),
        const PlayingCard(suit: Suit.hearts, rank: Rank.jack),
        const PlayingCard(suit: Suit.hearts, rank: Rank.queen),
        const PlayingCard(suit: Suit.hearts, rank: Rank.king),
        const PlayingCard(suit: Suit.hearts, rank: Rank.ace),
      ];

      final result = HandEvaluator.evaluate(cards);

      expect(result.category, HandCategory.straightFlush);
      expect(result.tieBreakers, [14]);
    });

    test('7 张牌应该选择最好的 5 张牌', () {
      final cards = [
        const PlayingCard(suit: Suit.spades, rank: Rank.ace),
        const PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        const PlayingCard(suit: Suit.clubs, rank: Rank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: Rank.ace),
        const PlayingCard(suit: Suit.spades, rank: Rank.king),
        const PlayingCard(suit: Suit.hearts, rank: Rank.two),
        const PlayingCard(suit: Suit.clubs, rank: Rank.three),
      ];

      final result = HandEvaluator.evaluate(cards);

      expect(result.category, HandCategory.fourOfAKind);
      expect(result.tieBreakers, [14, 13]);
    });

    test('应该正确识别 A-2-3-4-5 顺子', () {
      final cards = [
        const PlayingCard(suit: Suit.spades, rank: Rank.ace),
        const PlayingCard(suit: Suit.hearts, rank: Rank.two),
        const PlayingCard(suit: Suit.clubs, rank: Rank.three),
        const PlayingCard(suit: Suit.diamonds, rank: Rank.four),
        const PlayingCard(suit: Suit.spades, rank: Rank.five),
      ];

      final result = HandEvaluator.evaluate(cards);

      expect(result.category, HandCategory.straight);
      expect(result.tieBreakers, [5]);
    });
  });
}
