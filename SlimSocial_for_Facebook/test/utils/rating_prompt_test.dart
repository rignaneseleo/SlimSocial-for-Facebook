import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/rating_prompt.dart';

/// The state of someone who has just reached a trigger open having used the
/// app normally, i.e. every gate open. Each test below closes exactly one.
///
/// [opens] is required because which open a case runs at is the substance of
/// nearly every test below, and [loadsThisSession] defaults past the largest
/// threshold so the engagement gate is never the accidental reason a case
/// fails.
bool _ask({
  required int opens,
  int asks = 0,
  bool answered = false,
  int lastAskedOpen = 0,
  int loadsThisSession = RatingPrompt.kFirstAskInteractions + 1,
}) =>
    RatingPrompt.shouldAsk(
      opens: opens,
      asks: asks,
      answered: answered,
      lastAskedOpen: lastAskedOpen,
      loadsThisSession: loadsThisSession,
    );

void main() {
  group('trigger opens', () {
    test('asks on each scheduled open', () {
      for (final open in RatingPrompt.kAskOnOpens) {
        expect(_ask(opens: open), isTrue, reason: 'open $open');
      }
    });

    test('stays quiet on every open either side of a scheduled one', () {
      for (final open in <int>[2, 4, 9, 11]) {
        expect(_ask(opens: open), isFalse, reason: 'open $open');
      }
    });

    test('stays quiet before the first scheduled open', () {
      expect(_ask(opens: 0), isFalse);
    });
  });

  group('the engagement gate', () {
    test('the first ask needs a used session, not just a launch', () {
      expect(
        _ask(opens: 1, loadsThisSession: RatingPrompt.kFirstAskInteractions - 1),
        isFalse,
      );
      expect(
        _ask(opens: 1, loadsThisSession: RatingPrompt.kFirstAskInteractions),
        isTrue,
      );
    });

    test('later asks need only a feed that loaded at all', () {
      //asking over a blank screen buys a one-star rating and teaches nothing
      expect(_ask(opens: 3, loadsThisSession: 0), isFalse);
      expect(_ask(opens: 3, loadsThisSession: 1), isTrue);
      expect(_ask(opens: 10, loadsThisSession: 0), isFalse);
      expect(_ask(opens: 10, loadsThisSession: 1), isTrue);
    });
  });

  group('stopping conditions', () {
    test('never asks again once a rating was given', () {
      expect(_ask(opens: 3, answered: true), isFalse);
    });

    test('stops at the ceiling even on a scheduled open', () {
      expect(_ask(opens: 3, asks: RatingPrompt.kMaxAsks), isFalse);
    });

    test('the ceiling holds independently of the schedule', () {
      //the backstop has to survive someone lengthening kAskOnOpens
      expect(RatingPrompt.kMaxAsks, lessThanOrEqualTo(RatingPrompt.kAskOnOpens.length));
    });

    test('asks at most once per launch', () {
      expect(_ask(opens: 3, lastAskedOpen: 3), isFalse);
      expect(_ask(opens: 3, lastAskedOpen: 1), isTrue);
    });
  });
}
