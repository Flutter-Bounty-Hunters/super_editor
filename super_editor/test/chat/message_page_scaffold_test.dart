import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../infrastructure/keyboard_panel_scaffold_test.dart';

void main() {
  group('Message page scaffold >', () {
    testWidgets('can add and remove ancestor inherited widgets', (tester) async {
      double? mostRecentTextSize;

      final messagePageScaffold = MessagePageScaffold(
        contentBuilder: (context, __) {
          mostRecentTextSize = DefaultTextStyle.of(context).style.fontSize;
          return const SizedBox();
        },
        bottomSheetBuilder: (context) {
          return const SizedBox();
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: messagePageScaffold,
          ),
        ),
      );
      expect(mostRecentTextSize, 14);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 28,
              ),
              child: messagePageScaffold,
            ),
          ),
        ),
      );
      expect(mostRecentTextSize, 28);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: messagePageScaffold,
          ),
        ),
      );
      expect(mostRecentTextSize, 14);
    });

    testWidgets('re-runs child builder functions when inherited widget changes', (tester) async {
      final textDirection = ValueNotifier(TextDirection.ltr);
      TextDirection? mostRecentContentTextDirection;
      TextDirection? mostRecentBottomSheetTextDirection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TextDirectionChanger(
              textDirection: textDirection,
              child: MessagePageScaffold(
                contentBuilder: (context, __) {
                  mostRecentContentTextDirection = Directionality.of(context);
                  return const SizedBox();
                },
                bottomSheetBuilder: (context) {
                  mostRecentBottomSheetTextDirection = Directionality.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(mostRecentContentTextDirection, TextDirection.ltr);
      expect(mostRecentBottomSheetTextDirection, TextDirection.ltr);

      textDirection.value = TextDirection.rtl;
      await tester.pump();
      expect(mostRecentContentTextDirection, TextDirection.rtl);
      expect(mostRecentBottomSheetTextDirection, TextDirection.rtl);

      textDirection.value = TextDirection.ltr;
      await tester.pump();
      expect(mostRecentContentTextDirection, TextDirection.ltr);
      expect(mostRecentBottomSheetTextDirection, TextDirection.ltr);
    });

    testWidgets('rebuilds stateful child widgets when inherited widget changes', (tester) async {
      final textDirection = ValueNotifier(TextDirection.ltr);
      TextDirection? mostRecentContentTextDirection;
      TextDirection? mostRecentBottomSheetTextDirection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TextDirectionChanger(
              textDirection: textDirection,
              child: MessagePageScaffold(
                contentBuilder: (context, __) {
                  return _StatefulWidgetThatUsesInheritedWidget(
                    onBuildWithTextDirection: (newDirection) => mostRecentContentTextDirection = newDirection,
                    child: const SizedBox(),
                  );
                },
                bottomSheetBuilder: (context) {
                  return _StatefulWidgetThatUsesInheritedWidget(
                    onBuildWithTextDirection: (newDirection) => mostRecentBottomSheetTextDirection = newDirection,
                    child: const SizedBox(),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(mostRecentContentTextDirection, TextDirection.ltr);
      expect(mostRecentBottomSheetTextDirection, TextDirection.ltr);

      textDirection.value = TextDirection.rtl;
      await tester.pump();
      expect(mostRecentContentTextDirection, TextDirection.rtl);
      expect(mostRecentBottomSheetTextDirection, TextDirection.rtl);

      textDirection.value = TextDirection.ltr;
      await tester.pump();
      expect(mostRecentContentTextDirection, TextDirection.ltr);
      expect(mostRecentBottomSheetTextDirection, TextDirection.ltr);
    });

    testWidgets('can navigate to and from', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          routes: {
            '/': (context) {
              return const Scaffold(
                body: Center(
                  child: Text('Home'),
                ),
              );
            },
            'message-scaffold': (context) {
              return Scaffold(
                body: MessagePageScaffold(
                  contentBuilder: (_, __) => const SizedBox(),
                  bottomSheetBuilder: (_) => const SizedBox(),
                ),
              );
            },
          },
        ),
      );
      expect(find.text('Home'), findsOne);

      navigatorKey.currentState!.pushNamed('message-scaffold');
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOne);
    });

    testWidgetsOnMobilePhone('works when bottom sheet animates from below the screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Launch Bottom Sheet"),
                  ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 24,
                        clipBehavior: Clip.antiAlias,
                        scrollControlDisabledMaxHeightRatio: 0.93,
                        builder: (context) {
                          return MessagePageScaffold(
                            contentBuilder: (context, bottomSheetHeight) {
                              return const Placeholder();
                            },
                            bottomSheetBuilder: (context) {
                              return KeyboardScaffoldSafeArea(
                                // ^ This widget is really what we're testing here. It used to
                                //   throw a layout area when its content was below the bottom of
                                //   the screen.
                                child: Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: Colors.red,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    child: const Text("Open Sheet"),
                  ),
                ],
              ),
            );
          }),
        ),
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Ensure the bottom sheet was actually launched.
      expect(find.byType(MessagePageScaffold), findsOne);

      // If there's no error during opening animation, things should be fine.
      // Before this test and related modifications, we were getting layout errors
      // as the bottom sheet tried to animate up from below the bottom of the screen.
    });
  });
}

class _TextDirectionChanger extends StatefulWidget {
  const _TextDirectionChanger({
    required this.textDirection,
    required this.child,
  });

  final ValueNotifier<TextDirection> textDirection;
  final Widget child;

  @override
  State<_TextDirectionChanger> createState() => _TextDirectionChangerState();
}

class _TextDirectionChangerState extends State<_TextDirectionChanger> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.textDirection,
      builder: (context, value, child) {
        return Directionality(
          textDirection: widget.textDirection.value,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

class _StatefulWidgetThatUsesInheritedWidget extends StatefulWidget {
  const _StatefulWidgetThatUsesInheritedWidget({
    required this.onBuildWithTextDirection,
    required this.child,
  });

  final void Function(TextDirection) onBuildWithTextDirection;
  final Widget child;

  @override
  State<_StatefulWidgetThatUsesInheritedWidget> createState() => _StatefulWidgetThatUsesInheritedWidgetState();
}

class _StatefulWidgetThatUsesInheritedWidgetState extends State<_StatefulWidgetThatUsesInheritedWidget> {
  @override
  Widget build(BuildContext context) {
    widget.onBuildWithTextDirection(Directionality.of(context));
    return widget.child;
  }
}
