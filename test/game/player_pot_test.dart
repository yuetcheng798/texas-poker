import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/player.dart';
import 'package:texas_poker/game/pot.dart';

void main() {
  group('Player', () {
    test('commit updates chips and contributions', () {
      final player = Player(id: 'p1', name: 'Player 1', initialChips: 100);

      player.startHand();

      final committed = player.commit(30);

      expect(committed, 30);
      expect(player.chips, 70);
      expect(player.handContribution, 30);
      expect(player.streetContribution, 30);
      expect(player.status, PlayerStatus.active);
    });

    test('commit over stack becomes all in', () {
      final player = Player(id: 'p1', name: 'Player 1', initialChips: 100);

      player.startHand();

      final committed = player.commit(150);

      expect(committed, 100);
      expect(player.chips, 0);
      expect(player.handContribution, 100);
      expect(player.status, PlayerStatus.allIn);
    });
  });

  group('PotCalculator', () {
    test('builds main pot and side pot correctly', () {
      final p1 = Player(id: 'p1', name: 'Player 1', initialChips: 200);
      final p2 = Player(id: 'p2', name: 'Player 2', initialChips: 200);
      final p3 = Player(id: 'p3', name: 'Player 3', initialChips: 200);

      p1.startHand();
      p2.startHand();
      p3.startHand();

      p1.handContribution = 100;
      p2.handContribution = 200;
      p3.handContribution = 200;
      p3.status = PlayerStatus.folded;

      final pots = PotCalculator.build([p1, p2, p3]);

      expect(pots.length, 2);

      expect(pots[0].amount, 300);
      expect(pots[0].eligiblePlayerIds, ['p1', 'p2']);

      expect(pots[1].amount, 200);
      expect(pots[1].eligiblePlayerIds, ['p2']);
    });
  });
}
