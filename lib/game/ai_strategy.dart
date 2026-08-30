import 'betting_round.dart';
import 'card.dart';
import 'hand_evaluator.dart';
import 'player.dart';
import 'poker_action.dart';

enum AiStyle { balanced, aggressive, tight }

class AiDecision {
  const AiDecision({
    required this.action,
    required this.strength,
    required this.reason,
  });

  final PlayerAction action;
  final double strength;
  final String reason;
}

class DifficultAiStrategy {
  DifficultAiStrategy({this.style = AiStyle.balanced});

  final AiStyle style;

  AiDecision decide({
    required Player player,
    required List<PlayingCard> communityCards,
    required BettingRound round,
    int activePlayers = 2,
  }) {
    final strength = _estimateStrength(
      player.holeCards,
      communityCards,
      activePlayers,
    );

    final facing = round.amountToCall;
    final canRaise = _canRaise(round);
    final canCheck = round.legalActions.contains(ActionType.check);
    final canCall = round.legalActions.contains(ActionType.call);
    final canFold = round.legalActions.contains(ActionType.fold);

    // A call that consumes the whole remaining stack is an all-in call.
    // Evaluate it separately from an ordinary call.
    if (facing > 0 && facing >= player.chips) {
      if (canCall &&
          _shouldCallAllIn(
            player: player,
            round: round,
            strength: strength,
            activePlayers: activePlayers,
          )) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.call),
          strength: strength,
          reason: 'Strong enough to call the all-in.',
        );
      }

      if (canFold) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.fold),
          strength: strength,
          reason: 'The all-in price is too high for this hand.',
        );
      }
    }

    if (strength >= 0.76) {
      if (canRaise) {
        return AiDecision(
          action: _raiseAction(round),
          strength: strength,
          reason: 'Strong hand: make a value bet or raise.',
        );
      }

      if (round.legalActions.contains(ActionType.allIn) &&
          round.maximumRaiseTo > round.currentBet) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.allIn),
          strength: strength,
          reason: 'Strong hand with a short effective stack: go all in.',
        );
      }

      if (canCall && facing > 0) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.call),
          strength: strength,
          reason: 'Strong hand: call the current bet.',
        );
      }

      if (canCheck) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.check),
          strength: strength,
          reason: 'Strong hand: check to control the action.',
        );
      }
    }

    if (strength >= 0.52) {
      if (canRaise && style == AiStyle.aggressive && facing == 0) {
        return AiDecision(
          action: _raiseAction(round),
          strength: strength,
          reason: 'Medium-strong hand: apply pressure when checked to.',
        );
      }

      if (canCall && facing <= _affordableCall(player, strength)) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.call),
          strength: strength,
          reason: 'Medium hand: call within the stack pressure limit.',
        );
      }

      if (canCheck) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.check),
          strength: strength,
          reason: 'Medium hand: check and control the pot.',
        );
      }

      if (canFold) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.fold),
          strength: strength,
          reason: 'The bet is too large for a medium-strength hand.',
        );
      }
    }

    if (strength >= 0.34 && canCall) {
      final cheapCall = facing <= _affordableCall(player, strength);

      if (cheapCall) {
        return AiDecision(
          action: const PlayerAction(type: ActionType.call),
          strength: strength,
          reason: 'Marginal hand with a cheap price: call one street.',
        );
      }
    }

    if (canCheck) {
      return AiDecision(
        action: const PlayerAction(type: ActionType.check),
        strength: strength,
        reason: 'No bet to face: take the free check.',
      );
    }

    return AiDecision(
      action: const PlayerAction(type: ActionType.fold),
      strength: strength,
      reason: 'Insufficient hand strength: fold.',
    );
  }

  double _estimateStrength(
    List<PlayingCard> holeCards,
    List<PlayingCard> board,
    int activePlayers,
  ) {
    if (holeCards.length != 2) {
      return 0;
    }

    double strength;

    if (board.length < 3) {
      strength = _preflopStrength(holeCards);
    } else {
      final evaluated = HandEvaluator.evaluate([...holeCards, ...board]);

      strength = _madeHandStrength(evaluated);

      if (_hasFlushDraw(holeCards, board)) {
        strength += 0.08;
      }

      if (_hasStraightDraw(holeCards, board)) {
        strength += 0.07;
      }
    }

    final extraPlayers = activePlayers > 2 ? activePlayers - 2 : 0;
    strength -= extraPlayers.clamp(0, 6).toDouble() * 0.0125;

    if (style == AiStyle.aggressive) {
      strength += 0.035;
    } else if (style == AiStyle.tight) {
      strength -= 0.035;
    }

    return strength.clamp(0.0, 1.0).toDouble();
  }

  double _preflopStrength(List<PlayingCard> cards) {
    final first = cards[0].value;
    final second = cards[1].value;
    final high = first > second ? first : second;
    final low = first > second ? second : first;

    if (first == second) {
      return (0.56 + (high - 2) * 0.025).clamp(0.0, 0.90).toDouble();
    }

    var strength = 0.27 + (high - 2) * 0.018;

    if (cards[0].suit == cards[1].suit) {
      strength += 0.06;
    }

    if ((high - low).abs() <= 2) {
      strength += 0.045;
    }

    if (high >= 13 && low >= 10) {
      strength += 0.09;
    }

    if (high == 14) {
      strength += 0.04;
    }

    return strength.clamp(0.0, 0.82).toDouble();
  }

  double _madeHandStrength(EvaluatedHand hand) {
    switch (hand.category) {
      case HandCategory.highCard:
        return 0.24 + hand.tieBreakers.first / 100;
      case HandCategory.pair:
        return 0.43 + hand.tieBreakers.first / 100;
      case HandCategory.twoPair:
        return 0.58;
      case HandCategory.threeOfAKind:
        return 0.72;
      case HandCategory.straight:
        return 0.82;
      case HandCategory.flush:
        return 0.87;
      case HandCategory.fullHouse:
        return 0.94;
      case HandCategory.fourOfAKind:
        return 0.985;
      case HandCategory.straightFlush:
        return 1.0;
    }
  }

  bool _shouldCallAllIn({
    required Player player,
    required BettingRound round,
    required double strength,
    required int activePlayers,
  }) {
    final callAmount = round.amountToCall;

    if (callAmount <= 0 || callAmount > player.chips) {
      return false;
    }

    final pot = round.players.fold<int>(
      0,
      (total, current) => total + current.handContribution,
    );
    final potAfterCall = pot + callAmount;

    if (potAfterCall <= 0) {
      return false;
    }

    final potOdds = callAmount / potAfterCall;

    final minimumStrength = activePlayers >= 5
        ? 0.76
        : activePlayers >= 3
        ? 0.70
        : 0.62;

    final safetyMargin = activePlayers >= 5 ? 0.08 : 0.05;

    return strength >= minimumStrength && strength >= potOdds + safetyMargin;
  }

  bool _canRaise(BettingRound round) {
    final hasRaise = round.legalActions.contains(ActionType.raise);
    final hasBet = round.legalActions.contains(ActionType.bet);

    return (hasRaise || hasBet) && round.maximumRaiseTo >= round.minimumRaiseTo;
  }

  PlayerAction _raiseAction(BettingRound round) {
    final target = round.currentBet == 0
        ? round.bigBlind * 3
        : round.currentBet + round.minRaise;

    final safeTarget = target > round.maximumRaiseTo
        ? round.maximumRaiseTo
        : target;

    if (round.currentBet == 0) {
      return PlayerAction(type: ActionType.bet, amount: safeTarget);
    }

    return PlayerAction(type: ActionType.raise, amount: safeTarget);
  }

  int _affordableCall(Player player, double strength) {
    final ratio = strength >= 0.60 ? 0.25 : 0.12;
    final amount = (player.chips * ratio).floor();

    return amount < 1 ? 1 : amount;
  }

  bool _hasFlushDraw(List<PlayingCard> holeCards, List<PlayingCard> board) {
    final counts = <Suit, int>{};

    for (final card in [...holeCards, ...board]) {
      counts[card.suit] = (counts[card.suit] ?? 0) + 1;
    }

    return counts.values.any((count) => count == 4);
  }

  bool _hasStraightDraw(List<PlayingCard> holeCards, List<PlayingCard> board) {
    final values = {
      for (final card in [...holeCards, ...board]) card.value,
    };

    if (values.contains(14)) {
      values.add(1);
    }

    for (var start = 1; start <= 10; start++) {
      final count = [
        for (var value = start; value < start + 5; value++)
          if (values.contains(value)) value,
      ].length;

      if (count >= 4) {
        return true;
      }
    }

    return false;
  }
}
