import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:slimsocial_for_facebook/widgets/rating_dialog.dart';

/// Pushes the dialog on a route that can actually be popped.
///
/// The 5-star path calls `Navigator.pop`, and popping the *root* route trips
/// an assertion, so the dialog cannot simply be rendered as a body child.
Future<void> _open(WidgetTester tester, RatingDialog dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => dialog),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The stars are the first step's own widgets, so their absence is what
/// "advanced past the stars" means. Both steps are an [AlertDialog], and
/// `.tr()` yields the raw key here, so neither type nor text can tell them
/// apart.
Finder _star(int stars) => find.byKey(ValueKey('rating_star_$stars'));

void main() {
  group('RatingDialog', () {
    testWidgets(
      'the star that was tapped is what onRated receives (five)',
      (tester) async {
        int? reported;
        await _open(
          tester,
          RatingDialog(onRated: (stars) async => reported = stars),
        );

        await tester.tap(_star(5));
        await tester.pumpAndSettle();

        expect(reported, 5);
      },
    );

    testWidgets(
      'the star that was tapped is what onRated receives (one)',
      (tester) async {
        int? reported;
        await _open(
          tester,
          RatingDialog(onRated: (stars) async => reported = stars),
        );

        await tester.tap(_star(1));
        await tester.pumpAndSettle();

        expect(reported, 1);
      },
    );

    testWidgets(
      'a low rating is reported even though this build can do nothing '
      'further with it',
      (tester) async {
        int? reported;
        await _open(
          tester,
          RatingDialog(onRated: (stars) async => reported = stars),
        );

        await tester.tap(_star(2));
        await tester.pumpAndSettle();

        //the whole point of reporting before branching: with no dsn compiled
        //in, the step this rating leads to collects nothing, and the answer
        //would be lost if it were recorded on the way out instead
        expect(reported, 2);
        expect(Telemetry.canCollectFeedback, isFalse);
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets('a low rating advances past the stars', (tester) async {
      await _open(tester, RatingDialog(onRated: (_) async {}));

      await tester.tap(_star(2));
      await tester.pumpAndSettle();

      expect(_star(2), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
      'a high rating pops the dialog rather than advancing',
      (tester) async {
        await _open(tester, RatingDialog(onRated: (_) async {}));

        await tester.tap(_star(4));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'in a build with no dsn the second step offers no feedback box',
      (tester) async {
        //asserted, not assumed: `canCollectFeedback` is false exactly because
        //the suite is compiled without --dart-define=SENTRY_DSN. This test
        //describes THAT build. A build with a dsn takes the other branch of
        //`_stepFeedback` and does show a TextField, which nothing here covers
        expect(Telemetry.canCollectFeedback, isFalse);

        await _open(tester, RatingDialog(onRated: (_) async {}));

        await tester.tap(_star(3));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(_star(3), findsNothing);
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets('dismissing the stars reports nothing', (tester) async {
      var calls = 0;
      await _open(tester, RatingDialog(onRated: (_) async => calls++));

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
