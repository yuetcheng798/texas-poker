import 'dart:math';

import 'card.dart';

class Deck {
  Deck({Random? random}) : _random = random {
    reset();
  }

  final Random? _random;
  final List<PlayingCard> _cards = [];

  List<PlayingCard> get cards => List.unmodifiable(_cards);

  int get remaining => _cards.length;

  void reset() {
    _cards
      ..clear()
      ..addAll([
        for (final suit in Suit.values)
          for (final rank in Rank.values) PlayingCard(suit: suit, rank: rank),
      ]);
  }

  void shuffle() {
    _cards.shuffle(_random);
  }

  PlayingCard draw() {
    if (_cards.isEmpty) {
      throw StateError('牌堆已经没有牌了');
    }

    return _cards.removeLast();
  }

  List<PlayingCard> drawMany(int count) {
    if (count < 0 || count > _cards.length) {
      throw ArgumentError('抽取数量不合法: $count');
    }

    return [for (var i = 0; i < count; i++) draw()];
  }
}
