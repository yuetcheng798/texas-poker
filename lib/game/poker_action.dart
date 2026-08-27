enum ActionType { fold, check, call, bet, raise, allIn }

class PlayerAction {
  const PlayerAction({required this.type, this.amount = 0});

  final ActionType type;

  /// 对于 bet、raise、allIn，表示本次总投入或目标投入金额。
  final int amount;
}
