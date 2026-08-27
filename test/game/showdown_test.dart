import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/card.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/showdown.dart';

void main() {
  test('stronger hand should win the pot', () {
    final p1 = Player(id: 'p1', name: 'Player 1', initialChips: 100);
    final p2 = Player(id: 'p2', name: 'Player 2', initialChips: 100);

    p1.startHand();
    p2.startHand();

    p1.commit(50);
    p2.commit(50);

    p1
      ..receiveCard(const PlayingCard(suit: Suit.spades, rank: Rank.ace))
      ..receiveCard(const PlayingCard(suit: Suit.hearts, rank: Rank.ace));

    p2
      ..receiveCard(const PlayingCard(suit: Suit.spades, rank: Rank.king))
      ..receiveCard(const PlayingCard(suit: Suit.hearts, rank: Rank.king));

    final board = [
      const PlayingCard(suit: Suit.clubs, rank: Rank.two),
      const PlayingCard(suit: Suit.diamonds, rank: Rank.seven),
      const PlayingCard(suit: Suit.hearts, rank: Rank.nine),
      const PlayingCard(suit: Suit.spades, rank: Rank.jack),
      const PlayingCard(suit: Suit.clubs, rank: Rank.three),
    ];

    final result = ShowdownEngine.settle(
      players: [p1, p2],
      communityCards: board,
      dealerSeat: 0,
    );

    expect(result.totalPaid, 100);
    expect(result.payouts['p1'], 100);
    expect(result.payouts.containsKey('p2'), isFalse);

    expect(p1.chips, 150);
    expect(p2.chips, 50);
  });

  test('tied players should split the pot', () {
    final p1 = Player(id: 'p1', name: 'Player 1', initialChips: 100);
    final p2 = Player(id: 'p2', name: 'Player 2', initialChips: 100);

    p1.startHand();
    p2.startHand();

    p1.commit(50);
    p2.commit(50);

    p1
      ..receiveCard(const PlayingCard(suit: Suit.spades, rank: Rank.ace))
      ..receiveCard(const PlayingCard(suit: Suit.hearts, rank: Rank.king));

    p2
      ..receiveCard(const PlayingCard(suit: Suit.clubs, rank: Rank.ace))
      ..receiveCard(const PlayingCard(suit: Suit.diamonds, rank: Rank.king));

    final board = [
      const PlayingCard(suit: Suit.clubs, rank: Rank.two),
      const PlayingCard(suit: Suit.diamonds, rank: Rank.three),
      const PlayingCard(suit: Suit.hearts, rank: Rank.four),
      const PlayingCard(suit: Suit.spades, rank: Rank.five),
      const PlayingCard(suit: Suit.clubs, rank: Rank.nine),
    ];

    final result = ShowdownEngine.settle(
      players: [p1, p2],
      communityCards: board,
      dealerSeat: 0,
    );

    expect(result.payouts['p1'], 50);
    expect(result.payouts['p2'], 50);
    expect(p1.chips, 100);
    expect(p2.chips, 100);
  });

  test('folded player cannot win the pot', () {
    final p1 = Player(id: 'p1', name: 'Player 1', initialChips: 100);
    final p2 = Player(id: 'p2', name: 'Player 2', initialChips: 100);

    p1.startHand();
    p2.startHand();

    p1.commit(40);
    p2.commit(40);
    p2.fold();

    final result = ShowdownEngine.settle(
      players: [p1, p2],
      communityCards: const [],
      dealerSeat: 0,
    );

    expect(result.payouts['p1'], 80);
    expect(result.payouts.containsKey('p2'), isFalse);
    expect(p1.chips, 140);
    expect(p2.chips, 60);
  });
}
