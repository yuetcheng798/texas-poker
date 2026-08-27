import 'dart:math';

import 'card.dart';
import 'deck.dart';
import 'player.dart';

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
      throw ArgumentError('牌桌玩家数量必须在 2～8 人之间');
    }

    if (smallBlind <= 0 || bigBlind <= smallBlind) {
      throw ArgumentError('盲注设置不合法');
    }

    if (dealerSeat < 0 || dealerSeat >= players.length) {
      throw ArgumentError('庄家座位不合法');
    }
  }

  final List<Player> players;
  final int smallBlind;
  final int bigBlind;
  final Deck _deck;

  int _dealerSeat;
  int? _smallBlindSeat;
  int? _bigBlindSeat;
  int? _currentActorSeat;

  int handNumber = 0;
  TableStreet street = TableStreet.waiting;

  final List<PlayingCard> communityCards = [];

  Player get dealer => players[_dealerSeat];

  Player? get smallBlindPlayer {
    final seat = _smallBlindSeat;
    return seat == null ? null : players[seat];
  }

  Player? get bigBlindPlayer {
    final seat = _bigBlindSeat;
    return seat == null ? null : players[seat];
  }

  Player? get currentActor {
    final seat = _currentActorSeat;
    return seat == null ? null : players[seat];
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
        .where((player) => player.status == PlayerStatus.active)
        .toList(growable: false);
  }

  /// 开始一手新牌：移动按钮、收取盲注、发两张底牌。
  void beginHand() {
    if (street != TableStreet.waiting && street != TableStreet.complete) {
      throw StateError('当前牌局尚未结束');
    }

    final availableSeats = _availableSeats;

    if (availableSeats.length < 2) {
      throw StateError('至少需要两名有筹码的玩家才能开始牌局');
    }

    // 只重置仍在牌桌上的玩家；away 玩家不会自动回来。
    for (final player in players) {
      if (player.status != PlayerStatus.away) {
        player.startHand();
      }
    }

    final activeSeats = _activeSeats;

    if (activeSeats.length < 2) {
      throw StateError('至少需要两名有效玩家才能开始牌局');
    }

    _dealerSeat = _seatAtOrAfter(_dealerSeat, activeSeats);

    final isHeadsUp = activeSeats.length == 2;

    if (isHeadsUp) {
      // 单挑时：庄家同时是小盲，另一名玩家是大盲。
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

    _dealHoleCards(activeSeats);

    players[_smallBlindSeat!].commit(smallBlind);
    players[_bigBlindSeat!].commit(bigBlind);

    // 翻牌前：多人桌从大盲左侧开始；单挑由庄家先行动。
    _currentActorSeat = isHeadsUp
        ? _dealerSeat
        : _nextSeat(_bigBlindSeat!, activeSeats);

    handNumber++;
    street = TableStreet.preFlop;
  }

  /// 本手牌结束后移动庄家按钮。
  void completeHand() {
    if (street == TableStreet.waiting || street == TableStreet.complete) {
      throw StateError('没有正在进行的牌局');
    }

    final seatsForNextHand = players
        .where(
          (player) => player.status != PlayerStatus.away && player.chips > 0,
        )
        .map((player) => players.indexOf(player))
        .toList();

    if (seatsForNextHand.length >= 2) {
      _dealerSeat = _nextSeat(_dealerSeat, seatsForNextHand);
    }

    _smallBlindSeat = null;
    _bigBlindSeat = null;
    _currentActorSeat = null;
    street = TableStreet.complete;
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

  void _dealHoleCards(List<int> activeSeats) {
    for (var round = 0; round < 2; round++) {
      for (var offset = 1; offset <= activeSeats.length; offset++) {
        final seat = _seatAfterOffset(_dealerSeat, offset, activeSeats);
        players[seat].receiveCard(_deck.draw());
      }
    }
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
