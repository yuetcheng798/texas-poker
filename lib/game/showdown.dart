import 'hand_evaluator.dart';
import 'player.dart';
import 'pot.dart';
import 'card.dart';

class PotAward {
  const PotAward({
    required this.potAmount,
    required this.winnerIds,
    required this.shares,
  });

  final int potAmount;
  final List<String> winnerIds;
  final Map<String, int> shares;
}

class ShowdownResult {
  const ShowdownResult({required this.awards, required this.payouts});

  final List<PotAward> awards;
  final Map<String, int> payouts;

  int get totalPaid {
    return payouts.values.fold(0, (sum, amount) => sum + amount);
  }
}

class ShowdownEngine {
  ShowdownEngine._();

  static ShowdownResult settle({
    required List<Player> players,
    required List<PlayingCard> communityCards,
    int dealerSeat = 0,
  }) {
    if (players.length < 2) {
      throw ArgumentError('at least two players are required');
    }

    if (dealerSeat < 0 || dealerSeat >= players.length) {
      throw ArgumentError('dealerSeat is invalid');
    }

    final pots = PotCalculator.build(players);
    final playerById = {for (final player in players) player.id: player};

    final evaluatedHands = <String, EvaluatedHand>{};

    if (communityCards.length == 5) {
      for (final player in players) {
        if (player.status == PlayerStatus.folded ||
            player.status == PlayerStatus.away ||
            player.holeCards.length != 2) {
          continue;
        }

        evaluatedHands[player.id] = HandEvaluator.evaluate([
          ...player.holeCards,
          ...communityCards,
        ]);
      }
    }

    final awards = <PotAward>[];
    final payouts = <String, int>{};

    for (final pot in pots) {
      final eligiblePlayers = pot.eligiblePlayerIds
          .map((id) => playerById[id])
          .whereType<Player>()
          .toList();

      if (eligiblePlayers.isEmpty) {
        throw StateError('pot has no eligible players');
      }

      List<Player> winners;

      if (eligiblePlayers.length == 1) {
        // Everyone else folded.
        winners = eligiblePlayers;
      } else {
        if (communityCards.length != 5) {
          throw StateError('showdown requires five community cards');
        }

        final ranked = eligiblePlayers
            .where((player) => evaluatedHands.containsKey(player.id))
            .toList();

        if (ranked.isEmpty) {
          throw StateError('no eligible player can be evaluated');
        }

        var bestHand = evaluatedHands[ranked.first.id]!;
        winners = [ranked.first];

        for (final player in ranked.skip(1)) {
          final hand = evaluatedHands[player.id]!;

          if (hand.beats(bestHand)) {
            bestHand = hand;
            winners = [player];
          } else if (hand.tiesWith(bestHand)) {
            winners.add(player);
          }
        }
      }

      final baseShare = pot.amount ~/ winners.length;
      final remainder = pot.amount % winners.length;
      final orderedWinners = _orderClockwise(winners, players, dealerSeat);

      final shares = <String, int>{};

      for (var i = 0; i < orderedWinners.length; i++) {
        final player = orderedWinners[i];
        final amount = baseShare + (i < remainder ? 1 : 0);

        shares[player.id] = amount;
        payouts[player.id] = (payouts[player.id] ?? 0) + amount;
      }

      awards.add(
        PotAward(
          potAmount: pot.amount,
          winnerIds: orderedWinners.map((player) => player.id).toList(),
          shares: Map.unmodifiable(shares),
        ),
      );
    }

    for (final player in players) {
      final amount = payouts[player.id] ?? 0;
      player.chips += amount;
    }

    return ShowdownResult(
      awards: List.unmodifiable(awards),
      payouts: Map.unmodifiable(payouts),
    );
  }

  /// Odd chips are awarded clockwise from the seat left of the dealer.
  static List<Player> _orderClockwise(
    List<Player> winners,
    List<Player> players,
    int dealerSeat,
  ) {
    final winnerIds = winners.map((player) => player.id).toSet();
    final ordered = <Player>[];

    for (var offset = 1; offset <= players.length; offset++) {
      final seat = (dealerSeat + offset) % players.length;
      final player = players[seat];

      if (winnerIds.contains(player.id)) {
        ordered.add(player);
      }
    }

    return ordered;
  }
}
