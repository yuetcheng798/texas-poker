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
      throw ArgumentError('initialChips cannot be negative');
    }
  }

  final String id;
  final String name;
  final bool isHuman;

  int chips;
  PlayerStatus status = PlayerStatus.active;

  final List<PlayingCard> holeCards = [];

  /// Total amount committed during the current hand.
  int handContribution = 0;

  /// Amount committed during the current betting street.
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
      throw StateError('a player can only receive two hole cards');
    }

    holeCards.add(card);
  }

  /// Commits chips to the pot and returns the actual amount committed.
  int commit(int amount) {
    if (amount < 0) {
      throw ArgumentError('commit amount cannot be negative');
    }

    if (!canAct) {
      throw StateError('player cannot act');
    }

    final actualAmount = amount > chips ? chips : amount;

    chips -= actualAmount;
    handContribution += actualAmount;
    streetContribution += actualAmount;

    if (chips == 0) {
      status = PlayerStatus.allIn;
    }

    return actualAmount;
  }

  /// Spends chips outside the pot, such as buying a time card.
  void spendChips(int amount) {
    if (amount <= 0) {
      throw ArgumentError('spend amount must be greater than zero');
    }

    if (amount > chips) {
      throw StateError('not enough chips');
    }

    chips -= amount;
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
