import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/ai_strategy.dart';
import 'package:texas_poker/game/betting_round.dart';
import 'package:texas_poker/game/card.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/poker_action.dart';

void main() {
  test('weak hand should fold against an all-in', () {
    final ai = Player(id: 'ai', name: 'AI', initialChips: 200);
    final opponent = Player(
      id: 'opponent',
      name: 'Opponent',
      initialChips: 200,
    );

    ai.startHand();
    opponent.startHand();
    opponent.commit(200);

    ai
      ..receiveCard(const PlayingCard(suit: Suit.clubs, rank: Rank.two))
      ..receiveCard(const PlayingCard(suit: Suit.hearts, rank: Rank.seven));

    final round = BettingRound(
      players: [ai, opponent],
      firstActorSeat: 0,
      bigBlind: 20,
      openingBet: 200,
    );

    final decision = DifficultAiStrategy().decide(
      player: ai,
      communityCards: const [],
      round: round,
      activePlayers: 2,
    );

    expect(decision.action.type, ActionType.fold);
  });

  test('pocket aces should call a heads-up all-in', () {
    final ai = Player(id: 'ai', name: 'AI', initialChips: 2000);
    final opponent = Player(
      id: 'opponent',
      name: 'Opponent',
      initialChips: 2000,
    );

    ai.startHand();
    opponent.startHand();
    opponent.commit(2000);

    ai
      ..receiveCard(const PlayingCard(suit: Suit.clubs, rank: Rank.ace))
      ..receiveCard(const PlayingCard(suit: Suit.hearts, rank: Rank.ace));

    final round = BettingRound(
      players: [ai, opponent],
      firstActorSeat: 0,
      bigBlind: 20,
      openingBet: 2000,
    );

    final decision = DifficultAiStrategy().decide(
      player: ai,
      communityCards: const [],
      round: round,
      activePlayers: 2,
    );

    expect(decision.action.type, ActionType.call);
  });
}
