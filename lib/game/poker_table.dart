import 'dart:math';
import 'card.dart';
import 'deck.dart';
import 'betting_round.dart';
import 'player.dart';
import 'poker_action.dart';

enum TableStreet { waiting, preFlop, flop, turn, river, showdown, complete }

class PokerTable {
  PokerTable({
    required List<Player> players,
    this.smallBlind = 10,
    this.bigBlind = 20,
    int dealerSeat = 0,
    Random? random,
  }) : players = List.unmodifiable(players),
       _dealerSeat = dealerSeat,
       _deck = Deck(random: random) {
    if (players.length < 2 || players.length > 8) {
      throw ArgumentError('table must contain 2 to 8 players');
    }

    if (smallBlind <= 0 || bigBlind <= smallBlind) {
      throw ArgumentError('blind configuration is invalid');
    }

    if (dealerSeat < 0 || dealerSeat >= players.length) {
      throw ArgumentError('dealer seat is invalid');
    }
  }

  final List<Player> players;
  final int smallBlind;
  final int bigBlind;
  final Deck _deck;

  final List<PlayingCard> communityCards = [];
  final List<PlayingCard> burnedCards = [];
  final List<ActionRecord> _completedActionHistory = [];

  int _dealerSeat;
  int? _smallBlindSeat;
  int? _bigBlindSeat;

  BettingRound? _bettingRound;

  int handNumber = 0;
  TableStreet street = TableStreet.waiting;

  Player get dealer => players[_dealerSeat];

  Player? get smallBlindPlayer {
    final seat = _smallBlindSeat;
    return seat == null ? null : players[seat];
  }

  Player? get bigBlindPlayer {
    final seat = _bigBlindSeat;
    return seat == null ? null : players[seat];
  }

  BettingRound? get bettingRound => _bettingRound;

  Player? get currentActor => _bettingRound?.currentActor;

  int? get currentActorSeat => _bettingRound?.currentActorSeat;

  int get currentBet => _bettingRound?.currentBet ?? 0;

  int get amountToCall => _bettingRound?.amountToCall ?? 0;

  List<ActionType> get legalActions {
    return _bettingRound?.legalActions ?? const [];
  }

  int get potAmount {
    return players.fold(0, (total, player) => total + player.handContribution);
  }

  List<ActionRecord> get actionHistory {
    final currentHistory = _bettingRound?.history ?? const <ActionRecord>[];

    return List.unmodifiable([..._completedActionHistory, ...currentHistory]);
  }

  List<Player> get playersInHand {
    return players
        .where(
          (player) =>
              player.status == PlayerStatus.active ||
              player.status == PlayerStatus.folded ||
              player.status == PlayerStatus.allIn,
        )
        .toList(growable: false);
  }

  List<Player> get playersAbleToAct {
    return players
        .where(
          (player) => player.status == PlayerStatus.active && player.chips > 0,
        )
        .toList(growable: false);
  }

  /// Starts a new hand, moves the dealer button, posts blinds,
  /// and deals two hole cards to every participating player.
  void beginHand() {
    if (street != TableStreet.waiting && street != TableStreet.complete) {
      throw StateError('the current hand has not ended');
    }

    final availableSeats = _availableSeats;

    if (availableSeats.length < 2) {
      throw StateError('at least two players with chips are required');
    }

    for (final player in players) {
      if (player.status != PlayerStatus.away) {
        player.startHand();
      }
    }

    final activeSeats = _activeSeats;

    if (activeSeats.length < 2) {
      throw StateError('at least two active players are required');
    }

    _dealerSeat = _seatAtOrAfter(_dealerSeat, activeSeats);

    final headsUp = activeSeats.length == 2;

    if (headsUp) {
      _smallBlindSeat = _dealerSeat;
      _bigBlindSeat = _nextSeat(_dealerSeat, activeSeats);
    } else {
      _smallBlindSeat = _nextSeat(_dealerSeat, activeSeats);
      _bigBlindSeat = _nextSeat(_smallBlindSeat!, activeSeats);
    }

    _deck
      ..reset()
      ..shuffle();

    communityCards.clear();
    burnedCards.clear();
    _completedActionHistory.clear();

    _dealHoleCards(activeSeats);

    players[_smallBlindSeat!].commit(smallBlind);
    players[_bigBlindSeat!].commit(bigBlind);

    final firstActor = headsUp
        ? _dealerSeat
        : _nextSeat(_bigBlindSeat!, activeSeats);

    handNumber++;
    street = TableStreet.preFlop;

    _bettingRound = BettingRound(
      players: players,
      firstActorSeat: firstActor,
      bigBlind: bigBlind,
      openingBet: bigBlind,
    );

    _autoAdvanceIfAllIn();
  }

  /// Applies one action and advances the table when the betting round ends.
  void act(PlayerAction action) {
    final round = _bettingRound;

    if (round == null) {
      throw StateError('there is no active betting round');
    }

    round.act(action);

    if (round.isComplete) {
      _advanceAfterBettingRound();
    }
  }

  /// Ends the current hand and prepares the table for the next hand.
  ///
  /// Winner settlement will be added in the next stage.
  void completeHand() {
    if (street == TableStreet.waiting || street == TableStreet.complete) {
      throw StateError('there is no active hand');
    }

    final round = _bettingRound;
    if (round != null) {
      _completedActionHistory.addAll(round.history);
    }

    _bettingRound = null;
    _smallBlindSeat = null;
    _bigBlindSeat = null;
    street = TableStreet.complete;

    final seatsForNextHand = players
        .where(
          (player) => player.status != PlayerStatus.away && player.chips > 0,
        )
        .map(players.indexOf)
        .toList();

    if (seatsForNextHand.length >= 2) {
      _dealerSeat = _nextSeat(_dealerSeat, seatsForNextHand);
    }
  }

  void _advanceAfterBettingRound() {
    final round = _bettingRound;

    if (round == null || !round.isComplete) {
      return;
    }

    _completedActionHistory.addAll(round.history);
    _bettingRound = null;

    if (round.handWonByFold) {
      street = TableStreet.showdown;
      return;
    }

    switch (street) {
      case TableStreet.preFlop:
        _startStreet(TableStreet.flop, 3);
      case TableStreet.flop:
        _startStreet(TableStreet.turn, 1);
      case TableStreet.turn:
        _startStreet(TableStreet.river, 1);
      case TableStreet.river:
        street = TableStreet.showdown;
      case TableStreet.waiting:
      case TableStreet.showdown:
      case TableStreet.complete:
        throw StateError('cannot advance from street $street');
    }

    _autoAdvanceIfAllIn();
  }

  void _autoAdvanceIfAllIn() {
    final round = _bettingRound;

    if (round != null && round.isComplete) {
      _advanceAfterBettingRound();
    }
  }

  void _startStreet(TableStreet nextStreet, int boardCardCount) {
    for (final player in players) {
      if (player.status != PlayerStatus.away) {
        player.startStreet();
      }
    }

    burnedCards.add(_deck.draw());
    communityCards.addAll(_deck.drawMany(boardCardCount));
    street = nextStreet;

    final firstActor = _firstActingSeatAfterDealer();

    _bettingRound = BettingRound(
      players: players,
      firstActorSeat: firstActor,
      bigBlind: bigBlind,
    );
  }

  void _dealHoleCards(List<int> activeSeats) {
    for (var round = 0; round < 2; round++) {
      for (var offset = 1; offset <= activeSeats.length; offset++) {
        final seat = _seatAfterOffset(_dealerSeat, offset, activeSeats);
        players[seat].receiveCard(_deck.draw());
      }
    }
  }

  int _firstActingSeatAfterDealer() {
    for (var offset = 1; offset <= players.length; offset++) {
      final seat = (_dealerSeat + offset) % players.length;
      final player = players[seat];

      if (player.status == PlayerStatus.active && player.chips > 0) {
        return seat;
      }
    }

    // All remaining players are all-in. The seat is only used as a
    // placeholder because BettingRound will complete immediately.
    return _dealerSeat;
  }

  List<int> get _availableSeats {
    return [
      for (var i = 0; i < players.length; i++)
        if (players[i].status != PlayerStatus.away && players[i].chips > 0) i,
    ];
  }

  List<int> get _activeSeats {
    return [
      for (var i = 0; i < players.length; i++)
        if (players[i].status == PlayerStatus.active) i,
    ];
  }

  int _seatAtOrAfter(int seat, List<int> seats) {
    for (final candidate in seats) {
      if (candidate >= seat) {
        return candidate;
      }
    }

    return seats.first;
  }

  int _nextSeat(int seat, List<int> seats) {
    for (final candidate in seats) {
      if (candidate > seat) {
        return candidate;
      }
    }

    return seats.first;
  }

  int _seatAfterOffset(int seat, int offset, List<int> seats) {
    final currentIndex = seats.indexOf(seat);
    final startIndex = currentIndex < 0 ? 0 : currentIndex;

    return seats[(startIndex + offset) % seats.length];
  }
}
