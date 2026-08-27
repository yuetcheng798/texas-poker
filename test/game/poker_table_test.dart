import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/poker_table.dart';

void main() {
  List<Player> createPlayers() {
    return [
      for (var i = 0; i < 8; i++)
        Player(id: 'p$i', name: 'Player $i', initialChips: 2000),
    ];
  }

  test('eight-player table assigns button and blinds correctly', () {
    final players = createPlayers();
    final table = PokerTable(players: players, dealerSeat: 0);

    table.beginHand();

    expect(table.street, TableStreet.preFlop);
    expect(table.handNumber, 1);
    expect(table.dealer.id, 'p0');
    expect(table.smallBlindPlayer!.id, 'p1');
    expect(table.bigBlindPlayer!.id, 'p2');
    expect(table.currentActor!.id, 'p3');

    expect(players[1].handContribution, 10);
    expect(players[2].handContribution, 20);

    for (final player in players) {
      expect(player.holeCards.length, 2);
    }

    expect(table.communityCards, isEmpty);
  });

  test('heads-up table uses dealer as small blind and first actor', () {
    final players = [
      Player(id: 'p0', name: 'Player 0', initialChips: 2000),
      Player(id: 'p1', name: 'Player 1', initialChips: 2000),
    ];

    final table = PokerTable(players: players, dealerSeat: 0);

    table.beginHand();

    expect(table.dealer.id, 'p0');
    expect(table.smallBlindPlayer!.id, 'p0');
    expect(table.bigBlindPlayer!.id, 'p1');
    expect(table.currentActor!.id, 'p0');

    expect(players[0].handContribution, 10);
    expect(players[1].handContribution, 20);
  });

  test('dealer button moves clockwise after hand completion', () {
    final players = createPlayers();
    final table = PokerTable(players: players, dealerSeat: 0);

    table.beginHand();
    expect(table.dealer.id, 'p0');

    table.completeHand();
    table.beginHand();

    expect(table.dealer.id, 'p1');
    expect(table.smallBlindPlayer!.id, 'p2');
    expect(table.bigBlindPlayer!.id, 'p3');
  });
}
