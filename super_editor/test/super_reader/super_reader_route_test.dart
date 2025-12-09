import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';

import '../../lib/src/test/super_reader_test/reader_test_tools.dart';

void main() {
  group('SuperReader > routes >', () {
    testWidgetsOnAllPlatforms('can be used with a route with a delegated transition on top', (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withCustomWidgetTreeBuilder(
            (superReader) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: superReader,
                    ),
                    Builder(builder: (context) {
                      return ElevatedButton(
                        child: const Text('delegatedTransition'),
                        onPressed: () {
                          Navigator.of(context).push(_TestRoute());
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          )
          .pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Reaching this point means that the reader did not crash when the route with
      // a delegated transition was pushed on top of it.
      // See https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2794 for details.
    });
  });
}

/// A [ModalRoute] that uses a delegated transition.
class _TestRoute extends ModalRoute<void> {
  _TestRoute();

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      };

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return const Center(
      child: Text('Hello'),
    );
  }

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
}
