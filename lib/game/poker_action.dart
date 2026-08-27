enum ActionType { fold, check, call, bet, raise, allIn }

class PlayerAction {
  const PlayerAction({required this.type, this.amount = 0});

  final ActionType type;

  /// bet 和 raise 表示下注后的目标总额，不是本次增加额。
  final int amount;
}

class ActionRecord {
  const ActionRecord({
    required this.playerId,
    required this.action,
    required this.requestedAmount,
    required this.committedAmount,
    required this.streetBet,
  });

  final String playerId;
  final ActionType action;
  final int requestedAmount;
  final int committedAmount;
  final int streetBet;
}
