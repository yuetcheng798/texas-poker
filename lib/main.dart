import 'dart:async';

import 'package:flutter/material.dart';

import 'game/ai_strategy.dart';
import 'game/card.dart';
import 'game/player.dart';
import 'game/poker_action.dart';
import 'game/poker_table.dart';
import 'game/time_card.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Texas Poker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PokerPage(),
    );
  }
}

class PokerPage extends StatefulWidget {
  const PokerPage({super.key});

  @override
  State<PokerPage> createState() => _PokerPageState();
}

class _PokerPageState extends State<PokerPage> {
  static const humanId = 'p0';

  late final PokerTable table;
  late final DifficultAiStrategy aiStrategy;
  late final TimeCardManager timeCards;

  Timer? aiTimer;
  Timer? turnTimer;

  int secondsLeft = 30;
  int turnVersion = 0;

  @override
  void initState() {
    super.initState();
    aiStrategy = DifficultAiStrategy();

    timeCards = TimeCardManager()
      ..startSession()
      ..startHand();

    table = PokerTable(
      players: [
        for (var i = 0; i < 8; i++)
          Player(
            id: 'p$i',
            name: i == 0 ? 'You' : 'AI $i',
            initialChips: 2000,
            isHuman: i == 0,
          ),
      ],
      dealerSeat: 0,
    );

    table.beginHand();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _afterStateChanged();
    });
  }

  @override
  void dispose() {
    aiTimer?.cancel();
    turnTimer?.cancel();
    super.dispose();
  }

  Player? get humanPlayer {
    for (final player in table.players) {
      if (player.id == humanId) {
        return player;
      }
    }

    return null;
  }

  bool get isHumanTurn => table.currentActor?.id == humanId;

  void _afterStateChanged() {
    aiTimer?.cancel();
    turnTimer?.cancel();
    turnVersion++;

    if (!mounted || table.street == TableStreet.showdown) {
      return;
    }

    final actor = table.currentActor;

    if (actor == null) {
      return;
    }

    if (actor.id == humanId) {
      _startTurnTimer(actor.id);
    } else {
      _scheduleAi(actor.id);
    }
  }

  void _startTurnTimer(String actorId) {
    final version = ++turnVersion;

    setState(() {
      secondsLeft = 30;
    });

    turnTimer?.cancel();
    turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || version != turnVersion) {
        timer.cancel();
        return;
      }

      if (table.currentActor?.id != actorId) {
        timer.cancel();
        return;
      }

      if (secondsLeft <= 1) {
        timer.cancel();
        _performAction(const PlayerAction(type: ActionType.fold));
        return;
      }

      setState(() {
        secondsLeft--;
      });
    });
  }

  void _scheduleAi(String actorId) {
    turnTimer?.cancel();

    aiTimer?.cancel();
    aiTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted || table.currentActor?.id != actorId) {
        return;
      }

      final actor = table.currentActor;
      final round = table.bettingRound;

      if (actor == null || round == null) {
        return;
      }

      final activePlayers = table.playersInHand
          .where(
            (player) =>
                player.status != PlayerStatus.folded &&
                player.status != PlayerStatus.away,
          )
          .length;

      final decision = aiStrategy.decide(
        player: actor,
        communityCards: table.communityCards,
        round: round,
        activePlayers: activePlayers,
      );

      debugPrint(
        'AI ${actor.name}: '
        'action=${decision.action.type}, '
        'strength=${decision.strength.toStringAsFixed(3)}, '
        'facing=${round.amountToCall}, '
        'allIn=${round.isFacingAllIn}, '
        'activePlayers=$activePlayers',
      );

      _performAction(decision.action);
    });
  }

  void _performAction(PlayerAction action) {
    if (!mounted) {
      return;
    }

    try {
      table.act(action);
      setState(() {});
      _afterStateChanged();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _useTimeCard() {
    if (!isHumanTurn) {
      return;
    }

    final human = humanPlayer;

    if (human == null || !timeCards.canUse(human.chips)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Time card is unavailable')));
      return;
    }

    final result = timeCards.use(human.chips);
    human.spendChips(100);

    setState(() {
      secondsLeft += result.bonusSeconds;
    });
  }

  Future<void> _showRaiseDialog() async {
    if (!isHumanTurn) {
      return;
    }

    final round = table.bettingRound;
    if (round == null) {
      return;
    }

    final minimumTarget = round.minimumRaiseTo;
    final maximumTarget = round.maximumRaiseTo;

    if (maximumTarget < minimumTarget) {
      _performAction(const PlayerAction(type: ActionType.allIn));
      return;
    }

    final controller = TextEditingController(text: '$minimumTarget');

    final target = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Raise to'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '$minimumTarget - $maximumTarget',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);

                if (value == null ||
                    value < minimumTarget ||
                    value > maximumTarget) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (target != null && mounted) {
      final type = table.currentBet == 0 ? ActionType.bet : ActionType.raise;

      _performAction(PlayerAction(type: type, amount: target));
    }
  }

  void _startNextHand() {
    try {
      if (table.street == TableStreet.showdown) {
        table.completeHand();
      }

      table.beginHand();
      setState(() {});
      _afterStateChanged();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _streetName(TableStreet street) {
    switch (street) {
      case TableStreet.waiting:
        return 'Waiting';
      case TableStreet.preFlop:
        return 'Pre-Flop';
      case TableStreet.flop:
        return 'Flop';
      case TableStreet.turn:
        return 'Turn';
      case TableStreet.river:
        return 'River';
      case TableStreet.showdown:
        return 'Showdown';
      case TableStreet.complete:
        return 'Complete';
    }
  }

  String _playerStatus(Player player) {
    switch (player.status) {
      case PlayerStatus.active:
        return player.id == table.currentActor?.id ? 'ACTING' : 'IN HAND';
      case PlayerStatus.folded:
        return 'FOLDED';
      case PlayerStatus.allIn:
        return 'ALL-IN';
      case PlayerStatus.away:
        return 'AWAY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final human = humanPlayer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Texas Poker'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text('Street: ${_streetName(table.street)}')),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTopInfo(human),
                    const SizedBox(height: 16),
                    _buildPlayers(),
                    const SizedBox(height: 20),
                    _buildBoard(),
                    const SizedBox(height: 16),
                    _buildActionArea(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopInfo(Player? human) {
    final actorName = table.currentActor?.name ?? '-';

    return Row(
      children: [
        Expanded(child: _infoCard('Pot', '${table.potAmount}')),
        const SizedBox(width: 8),
        Expanded(child: _infoCard('Current actor', actorName)),
        const SizedBox(width: 8),
        Expanded(child: _infoCard('Your chips', '${human?.chips ?? 0}')),
        const SizedBox(width: 8),
        Expanded(child: _infoCard('Actions', '${table.actionHistory.length}')),
      ],
    );
  }

  Widget _infoCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayers() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: table.players.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 150,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        return _buildPlayerCard(table.players[index]);
      },
    );
  }

  Widget _buildPlayerCard(Player player) {
    final isActing = player.id == table.currentActor?.id;

    return Card(
      color: isActing ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    player.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${player.chips}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(_playerStatus(player)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 2; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _playingCard(
                      player.holeCards.length > i ? player.holeCards[i] : null,
                      hidden:
                          !player.isHuman &&
                          table.street != TableStreet.showdown,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Community cards',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Time cards: hand ${timeCards.usedThisHand}/${timeCards.handLimit} '
              'session ${timeCards.usedThisSession}/${timeCards.sessionLimit}',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: timeCards.canUse(humanPlayer?.chips ?? 0)
                  ? _useTimeCard
                  : null,
              icon: const Icon(Icons.hourglass_top),
              label: const Text('Use time card +30s'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < 5; i++)
                  _playingCard(
                    table.communityCards.length > i
                        ? table.communityCards[i]
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _playingCard(PlayingCard? card, {bool hidden = false}) {
    final text = card == null
        ? ''
        : hidden
        ? '?'
        : card.text;

    final isRed = card?.suit.isRed ?? false;

    return Container(
      width: 48,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hidden ? Colors.blueGrey.shade700 : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.black26),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: hidden
              ? Colors.white
              : isRed
              ? Colors.red
              : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    if (table.street == TableStreet.showdown) {
      return _buildShowdown();
    }

    if (!isHumanTurn) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('AI is thinking...'),
        ),
      );
    }

    final legal = table.legalActions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Your turn: $secondsLeft seconds',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Time cards: hand ${timeCards.usedThisHand}/${timeCards.handLimit} '
              'session ${timeCards.usedThisSession}/${timeCards.sessionLimit}',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: timeCards.canUse(humanPlayer?.chips ?? 0)
                  ? _useTimeCard
                  : null,
              icon: const Icon(Icons.hourglass_top),
              label: const Text('Use time card +30s'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (legal.contains(ActionType.fold))
                  FilledButton.tonal(
                    onPressed: () => _performAction(
                      const PlayerAction(type: ActionType.fold),
                    ),
                    child: const Text('Fold'),
                  ),
                if (legal.contains(ActionType.check))
                  FilledButton(
                    onPressed: () => _performAction(
                      const PlayerAction(type: ActionType.check),
                    ),
                    child: const Text('Check'),
                  ),
                if (legal.contains(ActionType.call))
                  FilledButton(
                    onPressed: () => _performAction(
                      const PlayerAction(type: ActionType.call),
                    ),
                    child: Text('Call ${table.amountToCall}'),
                  ),
                if (legal.contains(ActionType.bet) ||
                    legal.contains(ActionType.raise))
                  FilledButton(
                    onPressed: _showRaiseDialog,
                    child: Text(table.currentBet == 0 ? 'Bet' : 'Raise'),
                  ),
                if (legal.contains(ActionType.allIn))
                  FilledButton(
                    onPressed: () => _performAction(
                      const PlayerAction(type: ActionType.allIn),
                    ),
                    child: const Text('All-in'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowdown() {
    final result = table.showdownResult;
    final payouts = result?.payouts ?? const <String, int>{};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Hand complete',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (payouts.isEmpty)
              const Text('No payout result')
            else
              for (final entry in payouts.entries)
                Text('${entry.key} won ${entry.value} chips'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _startNextHand,
              child: const Text('Next hand'),
            ),
          ],
        ),
      ),
    );
  }
}
