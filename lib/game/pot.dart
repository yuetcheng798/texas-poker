import 'player.dart';

class Pot {
  const Pot({required this.amount, required this.eligiblePlayerIds});

  final int amount;
  final List<String> eligiblePlayerIds;

  @override
  String toString() {
    return 'Pot(amount: $amount, eligible: $eligiblePlayerIds)';
  }
}

class PotCalculator {
  PotCalculator._();

  /// 根据每名玩家本手牌的累计投入，计算主池和边池。
  ///
  /// 已弃牌玩家仍然需要参与金额计算，但不能成为底池赢家。
  static List<Pot> build(List<Player> players) {
    final levels =
        players
            .map((player) => player.handContribution)
            .where((amount) => amount > 0)
            .toSet()
            .toList()
          ..sort();

    final pots = <Pot>[];
    var previousLevel = 0;

    for (final level in levels) {
      final contributors = players
          .where((player) => player.handContribution >= level)
          .length;

      final amount = (level - previousLevel) * contributors;

      final eligiblePlayerIds = players
          .where(
            (player) =>
                player.handContribution >= level &&
                player.status != PlayerStatus.folded &&
                player.status != PlayerStatus.away,
          )
          .map((player) => player.id)
          .toList(growable: false);

      if (amount > 0) {
        pots.add(Pot(amount: amount, eligiblePlayerIds: eligiblePlayerIds));
      }

      previousLevel = level;
    }

    return pots;
  }
}
