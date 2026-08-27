enum Suit { clubs, diamonds, hearts, spades }

extension SuitInfo on Suit {
  String get symbol {
    switch (this) {
      case Suit.clubs:
        return '♣';
      case Suit.diamonds:
        return '♦';
      case Suit.hearts:
        return '♥';
      case Suit.spades:
        return '♠';
    }
  }

  bool get isRed => this == Suit.diamonds || this == Suit.hearts;
}

enum Rank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
}

extension RankInfo on Rank {
  int get value => index + 2;

  String get label {
    switch (this) {
      case Rank.two:
        return '2';
      case Rank.three:
        return '3';
      case Rank.four:
        return '4';
      case Rank.five:
        return '5';
      case Rank.six:
        return '6';
      case Rank.seven:
        return '7';
      case Rank.eight:
        return '8';
      case Rank.nine:
        return '9';
      case Rank.ten:
        return 'T';
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
      case Rank.ace:
        return 'A';
    }
  }
}

class PlayingCard {
  const PlayingCard({required this.suit, required this.rank});

  final Suit suit;
  final Rank rank;

  int get value => rank.value;

  String get text => '${rank.label}${suit.symbol}';

  @override
  String toString() => text;

  @override
  bool operator ==(Object other) {
    return other is PlayingCard && other.suit == suit && other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(suit, rank);
}
