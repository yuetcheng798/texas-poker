import 'card.dart';

enum HandCategory {
  highCard,
  pair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
}

extension HandCategoryInfo on HandCategory {
  String get displayName {
    switch (this) {
      case HandCategory.highCard:
        return '高牌';
      case HandCategory.pair:
        return '一对';
      case HandCategory.twoPair:
        return '两对';
      case HandCategory.threeOfAKind:
        return '三条';
      case HandCategory.straight:
        return '顺子';
      case HandCategory.flush:
        return '同花';
      case HandCategory.fullHouse:
        return '葫芦';
      case HandCategory.fourOfAKind:
        return '四条';
      case HandCategory.straightFlush:
        return '同花顺';
    }
  }
}

class EvaluatedHand implements Comparable<EvaluatedHand> {
  const EvaluatedHand({required this.category, required this.tieBreakers});

  final HandCategory category;
  final List<int> tieBreakers;

  @override
  int compareTo(EvaluatedHand other) {
    final categoryResult = category.index.compareTo(other.category.index);

    if (categoryResult != 0) {
      return categoryResult;
    }

    final length = tieBreakers.length < other.tieBreakers.length
        ? tieBreakers.length
        : other.tieBreakers.length;

    for (var i = 0; i < length; i++) {
      final result = tieBreakers[i].compareTo(other.tieBreakers[i]);

      if (result != 0) {
        return result;
      }
    }

    return tieBreakers.length.compareTo(other.tieBreakers.length);
  }

  bool beats(EvaluatedHand other) => compareTo(other) > 0;

  bool tiesWith(EvaluatedHand other) => compareTo(other) == 0;

  @override
  String toString() {
    return '${category.displayName}: $tieBreakers';
  }
}

class HandEvaluator {
  HandEvaluator._();

  static EvaluatedHand evaluate(List<PlayingCard> cards) {
    if (cards.length < 5 || cards.length > 7) {
      throw ArgumentError('德州扑克需要 5～7 张牌，当前为 ${cards.length} 张');
    }

    EvaluatedHand? best;

    void search(int start, List<PlayingCard> selected) {
      if (selected.length == 5) {
        final current = _evaluateFive(selected);

        if (best == null || current.beats(best!)) {
          best = current;
        }

        return;
      }

      final needed = 5 - selected.length;

      for (var i = start; i <= cards.length - needed; i++) {
        search(i + 1, [...selected, cards[i]]);
      }
    }

    search(0, []);

    return best!;
  }

  static EvaluatedHand _evaluateFive(List<PlayingCard> cards) {
    final values = cards.map((card) => card.value).toList()
      ..sort((a, b) => b.compareTo(a));

    final counts = <int, int>{};

    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }

    final groups = counts.entries.toList()
      ..sort((a, b) {
        final countResult = b.value.compareTo(a.value);

        if (countResult != 0) {
          return countResult;
        }

        return b.key.compareTo(a.key);
      });

    final isFlush = cards.map((card) => card.suit).toSet().length == 1;
    final straightHigh = _straightHigh(values);

    if (isFlush && straightHigh != null) {
      return EvaluatedHand(
        category: HandCategory.straightFlush,
        tieBreakers: [straightHigh],
      );
    }

    if (groups.first.value == 4) {
      final quad = groups.first.key;
      final kicker = values.firstWhere((value) => value != quad);

      return EvaluatedHand(
        category: HandCategory.fourOfAKind,
        tieBreakers: [quad, kicker],
      );
    }

    if (groups.first.value == 3 && groups[1].value == 2) {
      return EvaluatedHand(
        category: HandCategory.fullHouse,
        tieBreakers: [groups.first.key, groups[1].key],
      );
    }

    if (isFlush) {
      return EvaluatedHand(category: HandCategory.flush, tieBreakers: values);
    }

    if (straightHigh != null) {
      return EvaluatedHand(
        category: HandCategory.straight,
        tieBreakers: [straightHigh],
      );
    }

    if (groups.first.value == 3) {
      final triple = groups.first.key;
      final kickers = values.where((value) => value != triple).toList();

      return EvaluatedHand(
        category: HandCategory.threeOfAKind,
        tieBreakers: [triple, ...kickers],
      );
    }

    final pairs = groups
        .where((group) => group.value == 2)
        .map((group) => group.key)
        .toList();

    if (pairs.length == 2) {
      final kicker = values.firstWhere(
        (value) => value != pairs[0] && value != pairs[1],
      );

      return EvaluatedHand(
        category: HandCategory.twoPair,
        tieBreakers: [pairs[0], pairs[1], kicker],
      );
    }

    if (pairs.length == 1) {
      final pair = pairs.first;
      final kickers = values.where((value) => value != pair).toList();

      return EvaluatedHand(
        category: HandCategory.pair,
        tieBreakers: [pair, ...kickers],
      );
    }

    return EvaluatedHand(category: HandCategory.highCard, tieBreakers: values);
  }

  static int? _straightHigh(List<int> values) {
    final uniqueValues = values.toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    if (uniqueValues.length != 5) {
      return null;
    }

    if (uniqueValues.first - uniqueValues.last == 4) {
      return uniqueValues.first;
    }

    // A-2-3-4-5，A 按 1 计算。
    if (uniqueValues.join(',') == '14,5,4,3,2') {
      return 5;
    }

    return null;
  }
}
