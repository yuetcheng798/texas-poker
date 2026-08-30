import 'player.dart';
import 'poker_action.dart';

class BettingRound {
  BettingRound({
    required this.players,
    required this.firstActorSeat,
    required this.bigBlind,
    this.openingBet = 0,
    int? minimumRaise,
  }) : currentBet = openingBet,
       minRaise = minimumRaise ?? bigBlind {
    if (players.length < 2 || players.length > 8) {
      throw ArgumentError('players must contain 2 to 8 players');
    }

    if (firstActorSeat < 0 || firstActorSeat >= players.length) {
      throw ArgumentError('firstActorSeat is invalid');
    }

    if (bigBlind <= 0) {
      throw ArgumentError('bigBlind must be greater than zero');
    }

    if (openingBet < 0) {
      throw ArgumentError('openingBet cannot be negative');
    }

    if (minRaise <= 0) {
      throw ArgumentError('minimum raise must be greater than zero');
    }

    for (final player in players) {
      if (player.status == PlayerStatus.active && player.chips > 0) {
        _pendingPlayerIds.add(player.id);
      }
    }

    _currentActorSeat = _findFirstPendingSeat(firstActorSeat);
    _updateCompletion();
  }

  final List<Player> players;
  final int firstActorSeat;
  final int bigBlind;
  final int openingBet;

  int currentBet;
  int minRaise;

  int? _currentActorSeat;
  bool _isComplete = false;
  bool _handWonByFold = false;

  final Set<String> _pendingPlayerIds = <String>{};
  final List<ActionRecord> _history = <ActionRecord>[];

  List<ActionRecord> get history => List.unmodifiable(_history);

  Player? get currentActor {
    final seat = _currentActorSeat;
    return seat == null ? null : players[seat];
  }

  int? get currentActorSeat => _currentActorSeat;

  bool get isComplete => _isComplete;

  bool get handWonByFold => _handWonByFold;

  int get amountToCall {
    final actor = currentActor;

    if (actor == null) {
      return 0;
    }

    final amount = currentBet - actor.streetContribution;
    return amount > 0 ? amount : 0;
  }

  int get minimumRaiseTo {
    if (currentBet == 0) {
      return bigBlind;
    }

    return currentBet + minRaise;
  }

  int get maximumRaiseTo {
    final actor = currentActor;

    if (actor == null) {
      return 0;
    }

    return actor.streetContribution + actor.chips;
  }

  List<ActionType> get legalActions {
    final actor = currentActor;

    if (actor == null || _isComplete) {
      return const [];
    }

    final actions = <ActionType>[ActionType.fold];

    if (amountToCall == 0) {
      actions.add(ActionType.check);
    } else {
      actions.add(ActionType.call);
    }

    if (currentBet == 0) {
      actions.add(ActionType.bet);
    } else {
      actions.add(ActionType.raise);
    }

    if (actor.chips > 0) {
      actions.add(ActionType.allIn);
    }

    return List.unmodifiable(actions);
  }

  /// Executes one action for the current player.
  void act(PlayerAction action) {
    if (_isComplete) {
      throw StateError('betting round is already complete');
    }

    final actor = currentActor;

    if (actor == null) {
      throw StateError('there is no current actor');
    }

    if (actor.status != PlayerStatus.active || actor.chips <= 0) {
      throw StateError('current player cannot act');
    }

    final actorSeatBeforeAction = actorSeat;
    final playerId = actor.id;
    var committedAmount = 0;

    switch (action.type) {
      case ActionType.fold:
        actor.fold();
        _pendingPlayerIds.remove(playerId);

      case ActionType.check:
        if (amountToCall != 0) {
          throw StateError('cannot check when facing a bet');
        }

        _pendingPlayerIds.remove(playerId);

      case ActionType.call:
        if (amountToCall == 0) {
          throw StateError('cannot call when there is nothing to call');
        }

        committedAmount = actor.commit(amountToCall);
        _pendingPlayerIds.remove(playerId);

      case ActionType.bet:
        if (currentBet != 0) {
          throw StateError('cannot bet when a bet already exists');
        }

        _validateTarget(actor, action.amount);

        final target = action.amount;
        final maximumTarget = actor.streetContribution + actor.chips;
        final isShortAllIn = target == maximumTarget && target < bigBlind;

        if (target < bigBlind && !isShortAllIn) {
          throw StateError('minimum opening bet is $bigBlind');
        }

        committedAmount = _commitToTarget(actor, target);
        currentBet = target;

        if (!isShortAllIn) {
          minRaise = target;
          _resetPendingAfterFullRaise(playerId);
        } else {
          _pendingPlayerIds.remove(playerId);
        }

      case ActionType.raise:
        if (currentBet == 0) {
          throw StateError('use bet when there is no current bet');
        }

        _validateTarget(actor, action.amount);

        final target = action.amount;
        final raiseBy = target - currentBet;
        final maximumTarget = actor.streetContribution + actor.chips;
        final isAllIn = target == maximumTarget;

        if (raiseBy < minRaise && !isAllIn) {
          throw StateError(
            'minimum raise is $minRaise; minimum target is $minimumRaiseTo',
          );
        }

        committedAmount = _commitToTarget(actor, target);

        if (raiseBy >= minRaise) {
          currentBet = target;
          minRaise = raiseBy;
          _resetPendingAfterFullRaise(playerId);
        } else {
          // A short all-in increases the call amount but does not reopen
          // raising for players who have already acted.
          currentBet = target;
          _pendingPlayerIds.remove(playerId);
        }

      case ActionType.allIn:
        final target = actor.streetContribution + actor.chips;

        if (target <= currentBet) {
          committedAmount = _commitToTarget(actor, target);
          _pendingPlayerIds.remove(playerId);
        } else {
          final raiseBy = target - currentBet;
          committedAmount = _commitToTarget(actor, target);

          if (raiseBy >= minRaise) {
            currentBet = target;
            minRaise = raiseBy;
            _resetPendingAfterFullRaise(playerId);
          } else {
            currentBet = target;
            _pendingPlayerIds.remove(playerId);
          }
        }
    }

    _history.add(
      ActionRecord(
        playerId: playerId,
        action: action.type,
        requestedAmount: action.amount,
        committedAmount: committedAmount,
        streetBet: actor.streetContribution,
      ),
    );

    _updateCompletion();

    if (!_isComplete) {
      _currentActorSeat = _findNextPendingSeat(actorSeatBeforeAction);
      _updateCompletion();
    }
  }

  int get actorSeat {
    final seat = _currentActorSeat;

    if (seat == null) {
      throw StateError('there is no current actor');
    }

    return seat;
  }

  void _validateTarget(Player actor, int target) {
    final maximumTarget = actor.streetContribution + actor.chips;

    if (target <= currentBet) {
      throw StateError('target must be greater than current bet');
    }

    if (target <= actor.streetContribution) {
      throw StateError('target must be greater than current street bet');
    }

    if (target > maximumTarget) {
      throw StateError('target cannot exceed player stack');
    }
  }

  int _commitToTarget(Player actor, int target) {
    final amount = target - actor.streetContribution;

    if (amount <= 0) {
      throw StateError('commit amount must be greater than zero');
    }

    return actor.commit(amount);
  }

  void _resetPendingAfterFullRaise(String actorId) {
    _pendingPlayerIds
      ..clear()
      ..addAll(
        players
            .where(
              (player) =>
                  player.id != actorId &&
                  player.status == PlayerStatus.active &&
                  player.chips > 0,
            )
            .map((player) => player.id),
      );
  }

  int? _findFirstPendingSeat(int fromSeat) {
    for (var offset = 0; offset < players.length; offset++) {
      final seat = (fromSeat + offset) % players.length;
      final player = players[seat];

      if (_pendingPlayerIds.contains(player.id) &&
          player.status == PlayerStatus.active &&
          player.chips > 0) {
        return seat;
      }
    }

    return null;
  }

  int? _findNextPendingSeat(int fromSeat) {
    for (var offset = 1; offset <= players.length; offset++) {
      final seat = (fromSeat + offset) % players.length;
      final player = players[seat];

      if (_pendingPlayerIds.contains(player.id) &&
          player.status == PlayerStatus.active &&
          player.chips > 0) {
        return seat;
      }
    }

    return null;
  }

  void _updateCompletion() {
    final remainingPlayers = players
        .where(
          (player) =>
              player.status != PlayerStatus.folded &&
              player.status != PlayerStatus.away,
        )
        .toList();

    if (remainingPlayers.length <= 1) {
      _isComplete = true;
      _handWonByFold = true;
      _currentActorSeat = null;
      return;
    }

    if (_pendingPlayerIds.isEmpty) {
      _isComplete = true;
      _currentActorSeat = null;
    }
  }
}
