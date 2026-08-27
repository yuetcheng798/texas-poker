import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/betting_round.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/poker_action.dart';

void main() {
  List<Player> createPlayers() {
    return [
      for (var i = 0; i < 3; i++)
        Player(id: 'p$i', name: 'Player $i', initialChips: 200),
    ];
  }

  void startPlayers(List<Player> players) {
    for (final player in players) {
      player.startHand();
    }
  }

  test('preflop call and check should complete the round', () {
    final players = createPlayers();
    startPlayers(players);

    players[0].commit(10);
    players[1].commit(20);

    final round = BettingRound(
      players: players,
      firstActorSeat: 2,
      bigBlind: 20,
      openingBet: 20,
    );

    expect(round.currentActor!.id, 'p2');
    expect(round.amountToCall, 20);

    round.act(const PlayerAction(type: ActionType.call));
    expect(round.currentActor!.id, 'p0');

    round.act(const PlayerAction(type: ActionType.call));
    expect(round.currentActor!.id, 'p1');

    round.act(const PlayerAction(type: ActionType.check));

    expect(round.isComplete, isTrue);
    expect(round.history.length, 3);
    expect(players[0].streetContribution, 20);
    expect(players[2].streetContribution, 20);
  });

  test('bet and raise should update current bet and minimum raise', () {
    final players = createPlayers();
    startPlayers(players);

    final round = BettingRound(
      players: players,
      firstActorSeat: 0,
      bigBlind: 20,
    );

    round.act(const PlayerAction(type: ActionType.bet, amount: 20));

    expect(round.currentBet, 20);
    expect(round.minRaise, 20);
    expect(round.currentActor!.id, 'p1');

    round.act(const PlayerAction(type: ActionType.raise, amount: 60));

    expect(round.currentBet, 60);
    expect(round.minRaise, 40);
    expect(round.currentActor!.id, 'p2');

    round.act(const PlayerAction(type: ActionType.call));
    round.act(const PlayerAction(type: ActionType.call));

    expect(round.isComplete, isTrue);
    expect(players[0].streetContribution, 60);
    expect(players[1].streetContribution, 60);
    expect(players[2].streetContribution, 60);
  });

  test('raise below minimum should throw unless it is all in', () {
    final players = createPlayers();
    startPlayers(players);

    final round = BettingRound(
      players: players,
      firstActorSeat: 0,
      bigBlind: 20,
    );

    round.act(const PlayerAction(type: ActionType.bet, amount: 20));

    round.act(const PlayerAction(type: ActionType.raise, amount: 60));

    expect(
      () => round.act(const PlayerAction(type: ActionType.raise, amount: 70)),
      throwsStateError,
    );
  });

  test('fold should leave one winner and complete the round', () {
    final players = createPlayers();
    startPlayers(players);

    final round = BettingRound(
      players: players,
      firstActorSeat: 0,
      bigBlind: 20,
    );

    round.act(const PlayerAction(type: ActionType.fold));
    round.act(const PlayerAction(type: ActionType.fold));

    expect(round.isComplete, isTrue);
    expect(round.handWonByFold, isTrue);
    expect(round.currentActor, isNull);
  });
}
