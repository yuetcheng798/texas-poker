import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/poker_action.dart';
import 'package:texas_poker/game/poker_table.dart';

void main() {
  List<Player> createPlayers() {
    return [
      for (var i = 0; i < 3; i++)
        Player(id: 'p$i', name: 'Player $i', initialChips: 2000),
    ];
  }

  void check(PokerTable table) {
    table.act(const PlayerAction(type: ActionType.check));
  }

  test('table should move from preflop to flop, turn and river', () {
    final table = PokerTable(players: createPlayers(), dealerSeat: 0);

    table.beginHand();

    expect(table.street, TableStreet.preFlop);
    expect(table.currentActor!.id, 'p0');

    // Preflop: p0 calls, p1 calls, p2 checks.
    table.act(const PlayerAction(type: ActionType.call));
    table.act(const PlayerAction(type: ActionType.call));
    table.act(const PlayerAction(type: ActionType.check));

    expect(table.street, TableStreet.flop);
    expect(table.communityCards.length, 3);
    expect(table.burnedCards.length, 1);

    // Flop: p1, p2, p0 check.
    check(table);
    check(table);
    check(table);

    expect(table.street, TableStreet.turn);
    expect(table.communityCards.length, 4);
    expect(table.burnedCards.length, 2);

    // Turn.
    check(table);
    check(table);
    check(table);

    expect(table.street, TableStreet.river);
    expect(table.communityCards.length, 5);
    expect(table.burnedCards.length, 3);

    // River.
    check(table);
    check(table);
    check(table);

    expect(table.street, TableStreet.showdown);
    expect(table.currentActor, isNull);
    expect(table.actionHistory.length, 12);
  });

  test('dealer button should move after completing a hand', () {
    final table = PokerTable(players: createPlayers(), dealerSeat: 0);

    table.beginHand();
    expect(table.dealer.id, 'p0');

    table.completeHand();
    table.beginHand();

    expect(table.dealer.id, 'p1');
  });
}
