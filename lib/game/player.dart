import 'card.dart';

enum PlayerStatus { active, folded, allIn, away }

class Player {
  Player({
    required this.id,
    required this.name,
    required int initialChips,
    this.isHuman = false,
  }) : chips = initialChips {
    if (initialChips < 0) {
      throw ArgumentError('初始筹码不能为负数');
    }
  }

  final String id;
  final String name;
  final bool isHuman;

  int chips;
  PlayerStatus status = PlayerStatus.active;

  final List<PlayingCard> holeCards = [];

  /// 本手牌累计投入的筹码，用于主池和边池计算。
  int handContribution = 0;

  /// 当前下注街投入的筹码。
  int streetContribution = 0;

  bool get canAct => status == PlayerStatus.active && chips > 0;

  bool get isInHand =>
      status == PlayerStatus.active ||
      status == PlayerStatus.folded ||
      status == PlayerStatus.allIn;

  void startHand() {
    holeCards.clear();
    handContribution = 0;
    streetContribution = 0;
    status = chips > 0 ? PlayerStatus.active : PlayerStatus.away;
  }

  void startStreet() {
    streetContribution = 0;
  }

  void receiveCard(PlayingCard card) {
    if (holeCards.length >= 2) {
      throw StateError('每名玩家最多只能有两张底牌');
    }

    holeCards.add(card);
  }

  /// 投入筹码，返回实际投入的数量。
  int commit(int amount) {
    if (amount < 0) {
      throw ArgumentError('投入筹码不能为负数');
    }

    if (!canAct) {
      throw StateError('当前玩家不能下注');
    }

    final actual = amount > chips ? chips : amount;

    chips -= actual;
    handContribution += actual;
    streetContribution += actual;

    if (chips == 0) {
      status = PlayerStatus.allIn;
    }

    return actual;
  }

  void fold() {
    if (status == PlayerStatus.active) {
      status = PlayerStatus.folded;
    }
  }

  void leaveTable() {
    status = PlayerStatus.away;
    holeCards.clear();
  }
}
