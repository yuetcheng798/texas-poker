import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/ai_strategy.dart';
import 'package:texas_poker/game/betting_round.dart';
import 'package:texas_poker/game/card.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/poker_action.dart';

void main() {
  BettingRound createRound(List<Player> players) {
    for (final player in players) {
      player.startHand();
    }

    return BettingRound(players: players, firstActorSeat: 0, bigBlind: 20);
  }

  test('strong pocket aces should make an aggressive decision', () {
    final player = Player(id: 'p0', name: 'AI', initialChips: 2000);

    final opponent = Player(id: 'p1', name: 'Opponent', initialChips: 2000);

    final round = createRound([player, opponent]);

    // startHand clears hole cards, so deal them after creating the round.
    player
      ..receiveCard(const PlayingCard(suit: Suit.spades, rank: Rank.ace))
      ..receiveCard(const PlayingCard(suit: Suit.hearts, rank: Rank.ace));

    final decision = DifficultAiStrategy().decide(
      player: player,
      communityCards: const [],
      round: round,
    );

    expect(decision.action.type, anyOf(ActionType.bet, ActionType.allIn));
    expect(decision.strength, greaterThan(0.7));
  });

  test('weak hand facing a large bet should fold', () {
    final player = Player(id: 'p0', name: 'AI', initialChips: 200);
    final opponent = Player(id: 'p1', name: 'Opponent', initialChips: 200);

    createRound([player, opponent]);

    opponent.commit(80);

    final bettingRound = BettingRound(
      players: [player, opponent],
      firstActorSeat: 0,
      bigBlind: 20,
      openingBet: 80,
    );

    player
      ..receiveCard(const PlayingCard(suit: Suit.spades, rank: Rank.two))
      ..receiveCard(const PlayingCard(suit: Suit.hearts, rank: Rank.seven));

    final decision = DifficultAiStrategy().decide(
      player: player,
      communityCards: const [],
      round: bettingRound,
    );

    expect(decision.action.type, ActionType.fold);
  });
}
