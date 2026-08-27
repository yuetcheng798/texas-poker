import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/game/time_card.dart';

void main() {
  test('using a time card immediately deducts chips and adds time', () {
    final manager = TimeCardManager();

    manager.startHand();
    manager.startAction();

    final result = manager.use(500);

    expect(result.remainingChips, 400);
    expect(result.bonusSeconds, 30);
    expect(result.usedThisHand, 1);
    expect(result.usedThisSession, 1);
  });

  test('one action can use at most one time card', () {
    final manager = TimeCardManager();

    manager.startHand();
    manager.startAction();
    manager.use(500);

    expect(() => manager.use(400), throwsStateError);
  });

  test('one hand can use at most two time cards', () {
    final manager = TimeCardManager();

    manager.startHand();

    manager.startAction();
    manager.use(500);

    manager.startAction();
    manager.use(400);

    expect(manager.usedThisHand, 2);
    expect(manager.usedThisSession, 2);

    manager.startAction();

    expect(() => manager.use(300), throwsStateError);
  });

  test('one table session can use at most five time cards', () {
    final manager = TimeCardManager();

    // Hand 1: use two cards.
    manager.startHand();
    manager.startAction();
    manager.use(1000);

    manager.startAction();
    manager.use(900);

    // Hand 2: use two more cards.
    manager.startHand();
    manager.startAction();
    manager.use(800);

    manager.startAction();
    manager.use(700);

    // Hand 3: use the final card.
    manager.startHand();
    manager.startAction();
    manager.use(600);

    expect(manager.usedThisSession, 5);
    expect(manager.remainingThisSession, 0);

    manager.startAction();

    expect(() => manager.use(500), throwsStateError);
  });

  test('new hand resets hand count but keeps session count', () {
    final manager = TimeCardManager();

    manager.startHand();
    manager.startAction();
    manager.use(500);

    manager.startHand();

    expect(manager.usedThisHand, 0);
    expect(manager.usedThisSession, 1);
    expect(manager.canUse(500), isTrue);
  });

  test('new session resets all counts', () {
    final manager = TimeCardManager();

    manager.startHand();
    manager.startAction();
    manager.use(500);

    manager.startSession();

    expect(manager.usedThisHand, 0);
    expect(manager.usedThisSession, 0);
  });

  test('cannot use a card when chips are insufficient', () {
    final manager = TimeCardManager();

    manager.startHand();
    manager.startAction();

    expect(() => manager.use(99), throwsStateError);
  });
}
