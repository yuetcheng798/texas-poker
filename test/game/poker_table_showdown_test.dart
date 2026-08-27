import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/poker_action.dart';
import 'package:texas_poker/game/poker_table.dart';

void main() {
  test('river completion should settle the pot automatically', () {
    final players = [
      Player(id: 'p0', name: 'Player 0', initialChips: 2000),
      Player(id: 'p1', name: 'Player 1', initialChips: 2000),
    ];

    final table = PokerTable(players: players, dealerSeat: 0);

    table.beginHand();

    // Heads-up preflop:
    // dealer/small blind calls, big blind checks.
    table.act(const PlayerAction(type: ActionType.call));
    table.act(const PlayerAction(type: ActionType.check));

    expect(table.street, TableStreet.flop);
    expect(table.communityCards.length, 3);

    // Flop.
    table.act(const PlayerAction(type: ActionType.check));
    table.act(const PlayerAction(type: ActionType.check));

    expect(table.street, TableStreet.turn);
    expect(table.communityCards.length, 4);

    // Turn.
    table.act(const PlayerAction(type: ActionType.check));
    table.act(const PlayerAction(type: ActionType.check));

    expect(table.street, TableStreet.river);
    expect(table.communityCards.length, 5);

    // River.
    table.act(const PlayerAction(type: ActionType.check));
    table.act(const PlayerAction(type: ActionType.check));

    expect(table.street, TableStreet.showdown);
    expect(table.showdownResult, isNotNull);
    expect(table.showdownResult!.totalPaid, 40);

    // The total amount of chips at the table must not change.
    expect(players[0].chips + players[1].chips, 4000);
  });

  test('fold should settle the pot without community cards', () {
    final players = [
      Player(id: 'p0', name: 'Player 0', initialChips: 2000),
      Player(id: 'p1', name: 'Player 1', initialChips: 2000),
    ];

    final table = PokerTable(players: players, dealerSeat: 0);

    table.beginHand();

    // Small blind folds. Big blind wins the 30-chip pot.
    table.act(const PlayerAction(type: ActionType.fold));

    expect(table.street, TableStreet.showdown);
    expect(table.showdownResult, isNotNull);
    expect(table.payouts['p1'], 30);
    expect(players[0].chips, 1990);
    expect(players[1].chips, 2010);
  });
}
