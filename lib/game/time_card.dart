class TimeCardUseResult {
  const TimeCardUseResult({
    required this.remainingChips,
    required this.bonusSeconds,
    required this.usedThisHand,
    required this.usedThisSession,
  });

  final int remainingChips;
  final int bonusSeconds;
  final int usedThisHand;
  final int usedThisSession;
}

class TimeCardManager {
  TimeCardManager({
    this.price = 100,
    this.bonusSeconds = 30,
    this.handLimit = 2,
    this.sessionLimit = 5,
  }) {
    if (price <= 0) {
      throw ArgumentError('price must be greater than zero');
    }

    if (bonusSeconds <= 0) {
      throw ArgumentError('bonusSeconds must be greater than zero');
    }

    if (handLimit <= 0 || sessionLimit <= 0) {
      throw ArgumentError('limits must be greater than zero');
    }

    if (handLimit > sessionLimit) {
      throw ArgumentError('handLimit cannot exceed sessionLimit');
    }
  }

  final int price;
  final int bonusSeconds;
  final int handLimit;
  final int sessionLimit;

  int usedThisHand = 0;
  int usedThisSession = 0;
  bool _usedThisAction = false;

  int get remainingThisHand => handLimit - usedThisHand;

  int get remainingThisSession => sessionLimit - usedThisSession;

  bool canUse(int chips) {
    return chips >= price &&
        !_usedThisAction &&
        usedThisHand < handLimit &&
        usedThisSession < sessionLimit;
  }

  /// 开始一手新牌，重置本手牌使用数量。
  /// 牌桌会话累计数量不会重置。
  void startHand() {
    usedThisHand = 0;
    _usedThisAction = false;
  }

  /// 开始真人玩家的一次新行动。
  /// 每次行动最多使用一张时间牌。
  void startAction() {
    _usedThisAction = false;
  }

  /// 离开牌桌并创建新牌桌时调用，重置整桌累计数量。
  void startSession() {
    usedThisHand = 0;
    usedThisSession = 0;
    _usedThisAction = false;
  }

  TimeCardUseResult use(int chips) {
    if (chips < 0) {
      throw ArgumentError('chips cannot be negative');
    }

    if (!canUse(chips)) {
      throw StateError('time card cannot be used now');
    }

    _usedThisAction = true;
    usedThisHand++;
    usedThisSession++;

    return TimeCardUseResult(
      remainingChips: chips - price,
      bonusSeconds: bonusSeconds,
      usedThisHand: usedThisHand,
      usedThisSession: usedThisSession,
    );
  }
}
