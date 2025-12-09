import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:meta/meta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

import '../test_runners.dart';

void main() {
  group("SuperTextField", () {
    group("scrolling", () {
      group("without ancestor scrollable", () {
        testWidgetsOnDesktopAndWeb(
          'PAGE DOWN scrolls down by the viewport height',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldTestApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we scrolled down by the viewport height.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.viewportDimension),
            );
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnDesktopAndWeb(
          'PAGE DOWN does not scroll past bottom of the viewport',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldTestApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the bottom but not all the way to avoid explicit
            // checks comparing scroll offset directly against `maxScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
            await tester.pump();

            await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we didn't scroll past the bottom of the viewport.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnDesktopAndWeb(
          'PAGE UP scrolls up by the viewport height',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldTestApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to the bottom of the viewport.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
            await tester.pump();

            await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we scrolled up by the viewport height.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent - scrollState.position.viewportDimension),
            );
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnDesktopAndWeb(
          'PAGE UP does not scroll past top of the viewport',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldTestApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the top but not all the way to avoid explicit
            // checks comparing scroll offset directly against `minScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
            await tester.pump();

            await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we didn't scroll past the top of the viewport.
            expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
          },
          variant: _scrollingVariant,
        );

        group("scrolls to top of viewport", () {
          testWidgetsOnDesktop(
            'using CMD + HOME on mac and CTRL + HOME on other platforms',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to the bottom of the viewport.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
              await tester.pump();

              // Scroll to viewport's top.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdHome(tester);
              } else {
                await tester.pressCtrlHome(tester);
              }

              // Ensure we scrolled to the viewport's top.
              expect(
                scrollState.position.pixels,
                equals(scrollState.position.minScrollExtent),
              );
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using HOME on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to the bottom of the viewport.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
              await tester.pump();

              // Scroll to viewport's top.
              await tester.pressHome();

              // Ensure we scrolled to the viewport's top.
              expect(
                scrollState.position.pixels,
                equals(scrollState.position.minScrollExtent),
              );
            },
            variant: _scrollingVariant,
          );
        });

        group("does not scroll past top of the viewport", () {
          testWidgetsOnDesktop(
            "using CMD + HOME on mac and CTRL + HOME on other platforms ",
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the top but not all the way to avoid explicit
              // checks comparing scroll offset directly against `minScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
              await tester.pump();

              // Scroll to viewport's top.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdHome(tester);
              } else {
                await tester.pressCtrlHome(tester);
              }

              // Ensure we didn't scroll past the viewport's top.
              expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using HOME on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the top but not all the way to avoid explicit
              // checks comparing scroll offset directly against `minScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
              await tester.pump();

              // Scroll to viewport's top.
              await tester.pressHome();

              // Ensure we didn't scroll past the viewport's top.
              expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
            },
            variant: _scrollingVariant,
          );
        });

        group("scrolls to bottom of viewport", () {
          testWidgetsOnDesktop(
            "using CMD + END on mac and CTRL + END on other platforms ",
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to viewport's bottom.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdEnd(tester);
              } else {
                await tester.pressCtrlEnd(tester);
              }

              // Ensure we scrolled to the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using END on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to viewport's bottom.
              await tester.pressEnd();

              // Ensure we scrolled to the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );
        });

        group("does not scroll past bottom of the viewport", () {
          testWidgetsOnDesktop(
            "using CMD + END on mac and CTRL + END on other platforms",
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the bottom but not all the way to avoid explicit
              // checks comparing scroll offset directly against `maxScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
              await tester.pump();

              // Scroll to viewport's bottom.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdEnd(tester);
              } else {
                await tester.pressCtrlEnd(tester);
              }
              // Ensure we didn't scroll past the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using END on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldTestApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the bottom but not all the way to avoid explicit
              // checks comparing scroll offset directly against `maxScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
              await tester.pump();

              // Scroll to viewport's bottom.
              await tester.pressEnd();

              // Ensure we didn't scroll past the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );
        });
      });

      group("inside ancestor scrollable", () {
        testWidgetsOnDesktopAndWeb(
          'PAGE DOWN scrolls down by the viewport height',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we scrolled down by the viewport height.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.viewportDimension),
            );
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnDesktopAndWeb(
          'PAGE DOWN does not scroll past bottom of the viewport',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the bottom but not all the way to avoid explicit
            // checks comparing scroll offset directly against `maxScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
            await tester.pump();

            await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we didn't scroll past the bottom of the viewport.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnDesktopAndWeb(
          'PAGE UP scrolls up by the viewport height',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to the bottom of the viewport.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
            await tester.pump();

            await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we scrolled up by the viewport height.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent - scrollState.position.viewportDimension),
            );
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnDesktopAndWeb(
          'PAGE UP does not scroll past top of the viewport',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue!;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant.textInputSource,
              verticalAlignment: currentVariant.verticalAlignment,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the top but not all the way to avoid explicit
            // checks comparing scroll offset directly against `minScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
            await tester.pump();

            await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

            // Let the scrolling system auto-scroll, as desired.
            await tester.pumpAndSettle();

            // Ensure we didn't scroll past the top of the viewport.
            expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
          },
          variant: _scrollingVariant,
        );

        group("scrolls to top of viewport", () {
          testWidgetsOnDesktop(
            'using CMD + HOME on mac and CTRL + HOME on other platforms',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to the bottom of the viewport.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
              await tester.pump();

              // Scroll to viewport's top.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdHome(tester);
              } else {
                await tester.pressCtrlHome(tester);
              }

              // Ensure we scrolled to the viewport's top.
              expect(
                scrollState.position.pixels,
                equals(scrollState.position.minScrollExtent),
              );
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using HOME on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to the bottom of the viewport.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
              await tester.pump();

              // Scroll to viewport's top.
              await tester.pressHome();

              // Ensure we scrolled to the viewport's top.
              expect(
                scrollState.position.pixels,
                equals(scrollState.position.minScrollExtent),
              );
            },
            variant: _scrollingVariant,
          );
        });

        group("does not scroll past top of the viewport", () {
          testWidgetsOnDesktop(
            "using CMD + HOME on mac and CTRL + HOME on other platforms ",
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the top but not all the way to avoid explicit
              // checks comparing scroll offset directly against `minScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
              await tester.pump();

              // Scroll to viewport's top.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdHome(tester);
              } else {
                await tester.pressCtrlHome(tester);
              }

              // Ensure we didn't scroll past the viewport's top.
              expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using HOME on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the top but not all the way to avoid explicit
              // checks comparing scroll offset directly against `minScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
              await tester.pump();

              // Scroll to viewport's top.
              await tester.pressHome();

              // Ensure we didn't scroll past the viewport's top.
              expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
            },
            variant: _scrollingVariant,
          );
        });

        group("scrolls to bottom of viewport", () {
          testWidgetsOnDesktop(
            "using CMD + END on mac and CTRL + END on other platforms ",
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to viewport's bottom.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdEnd(tester);
              } else {
                await tester.pressCtrlEnd(tester);
              }

              // Ensure we scrolled to the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using END on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll to viewport's bottom.
              await tester.pressEnd();

              // Ensure we scrolled to the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );
        });

        group("does not scroll past bottom of the viewport", () {
          testWidgetsOnDesktop(
            "using CMD + END on mac and CTRL + END on other platforms",
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the bottom but not all the way to avoid explicit
              // checks comparing scroll offset directly against `maxScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
              await tester.pump();

              // Scroll to viewport's bottom.
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await tester.pressCmdEnd(tester);
              } else {
                await tester.pressCtrlEnd(tester);
              }
              // Ensure we didn't scroll past the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );

          _testWidgetsOnMacAndWebDesktop(
            'using END on mac and web desktop',
            (tester) async {
              final currentVariant = _scrollingVariant.currentValue!;

              // Pump the widget tree with a SuperTextField which is four lines tall.
              await _pumpSuperTextFieldScrollSliverApp(
                tester,
                textInputSource: currentVariant.textInputSource,
                verticalAlignment: currentVariant.verticalAlignment,
              );

              // Tap on the text field to focus it.
              await tester.placeCaretInSuperTextField(0);

              // Find text field scrollable.
              final scrollState = tester.state<ScrollableState>(find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ));

              // Scroll very close to the bottom but not all the way to avoid explicit
              // checks comparing scroll offset directly against `maxScrollExtent`
              // and test scrolling behaviour in more realistic manner.
              scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
              await tester.pump();

              // Scroll to viewport's bottom.
              await tester.pressEnd();

              // Ensure we didn't scroll past the viewport's bottom.
              expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
            },
            variant: _scrollingVariant,
          );
        });
      });
    });

    group("scrolling within ancestor scrollable", () {
      group("scrolls from the text field's top to bottom and then towards the page bottom and back to the page top",
          () {
        testWidgetsOnDesktop(
          "using CMD + HOME/END on mac and CTRL + HOME/END on other platforms",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.top,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Find the text field's  ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Scrolls to text field's bottom.

            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }
            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.

            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        _testWidgetsOnMacAndWebDesktop(
          "using HOME and END on mac and web desktop",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.top,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ));

            // Find the text field's  ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Scrolls to text field's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );
      });

      group(
          "when placed at the page bottom, scrolls from the text field's top to the page bottom and back to the page top",
          () {
        testWidgetsOnDesktop(
          "using CMD + HOME/END on mac and CTRL + HOME/END on other platforms",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.bottom,
            );

            // Find the text field's ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            ancestorScrollState.position.jumpTo(ancestorScrollState.position.maxScrollExtent);
            await tester.pump();

            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Find SuperTextField scrollable
            final scrollState = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ),
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Scroll all the way to the text field's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        _testWidgetsOnMacAndWebDesktop(
          "using HOME and END on mac and web desktop",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.bottom,
            );

            // Find the text field's ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            ancestorScrollState.position.jumpTo(ancestorScrollState.position.maxScrollExtent);
            await tester.pump();

            // Ensure we are at the bottom of the page.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Find SuperTextField scrollable
            final scrollState = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ),
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Scroll all the way to the text field's bottom.
            await tester.pressEnd();

            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );
      });

      group(
          "when placed at the page center, scrolls from text field's top to the page bottom, and then back to the page top",
          () {
        testWidgetsOnDesktop(
          "using CMD + HOME/END on mac and CTRL + HOME/END on other platforms",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.center,
            );

            // Find the text field's ancestor scrollable.
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ),
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Ensure we are at the top of the textfiled.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to text field's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        _testWidgetsOnMacAndWebDesktop(
          "using HOME and END on mac and web desktop",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperTextField which is four lines tall.
            await _pumpSuperTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.center,
            );

            // Find the text field's ancestor scrollable.
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(SuperTextField),
                matching: find.byType(Scrollable),
              ),
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperTextField(0);

            // Ensure we are at the top of the textfiled.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to text field's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );
      });
    });
  });
}

/// Variant for an [SuperTextField] experience with/without ancestor scrollable.
final _scrollingVariant = ValueVariant<_SuperTextFieldScrollSetup>({
  const _SuperTextFieldScrollSetup(
    textInputSource: TextInputSource.ime,
    verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.top,
  ),
  const _SuperTextFieldScrollSetup(
    textInputSource: TextInputSource.keyboard,
    verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.top,
  ),
  const _SuperTextFieldScrollSetup(
    textInputSource: TextInputSource.ime,
    verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.center,
  ),
  const _SuperTextFieldScrollSetup(
    textInputSource: TextInputSource.keyboard,
    verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.center,
  ),
  const _SuperTextFieldScrollSetup(
    textInputSource: TextInputSource.ime,
    verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.bottom,
  ),
  const _SuperTextFieldScrollSetup(
    textInputSource: TextInputSource.keyboard,
    verticalAlignment: _TextFieldVerticalAlignmentWithinScrollable.bottom,
  ),
});

/// Variant for [SuperTextField]'s text input source.
final _textFieldInputSourceVariant = ValueVariant<TextInputSource>({
  TextInputSource.keyboard,
  TextInputSource.ime,
});

/// Pumps a [SuperTextField].
Future<void> _pumpSuperTextFieldTestApp(
  WidgetTester tester, {
  TextInputSource textInputSource = TextInputSource.keyboard,
  _TextFieldVerticalAlignmentWithinScrollable verticalAlignment = _TextFieldVerticalAlignmentWithinScrollable.top,
}) async {
  final textController = AttributedTextEditingController(
    text: AttributedText(_textFieldInput),
  );

  return await _pumpTestApp(
    tester,
    textController: textController,
    minLines: 8,
    maxLines: 8,
    textInputSource: textInputSource,
  );
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  double? maxWidth,
  double? maxHeight,
  TextInputSource textInputSource = TextInputSource.keyboard,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: SuperTextField(
            textController: textController,
            configuration: SuperTextFieldPlatformConfiguration.desktop,
            textStyleBuilder: (_) => const TextStyle(fontSize: 20),
            minLines: minLines,
            maxLines: maxLines,
            inputSource: textInputSource,
          ),
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for the final viewport size.
  await tester.pump();
}

/// Pumps a [SuperTextField] wrapped within [Scrollable].
Future<void> _pumpSuperTextFieldScrollSliverApp(
  WidgetTester tester, {
  TextInputSource textInputSource = TextInputSource.keyboard,
  _TextFieldVerticalAlignmentWithinScrollable verticalAlignment = _TextFieldVerticalAlignmentWithinScrollable.top,
}) async {
  final textController = AttributedTextEditingController(
    text: AttributedText(_textFieldInput),
  );

  final slivers = [
    if (verticalAlignment == _TextFieldVerticalAlignmentWithinScrollable.bottom ||
        verticalAlignment == _TextFieldVerticalAlignmentWithinScrollable.center)
      SliverToBoxAdapter(
        child: Builder(builder: (context) {
          return SizedBox(
            // Occupy enough vertical space to push text field slightly across the viewport
            // to introduce scrollable content but small enough to keep it within viewport to be
            // detected in tests.
            height: MediaQuery.of(context).size.height * 0.95,
            width: double.infinity,
            child: const Placeholder(
              child: Center(
                child: Text("Content"),
              ),
            ),
          );
        }),
      ),
    SliverToBoxAdapter(
      child: SuperTextField(
        textController: textController,
        configuration: SuperTextFieldPlatformConfiguration.desktop,
        textStyleBuilder: (_) => const TextStyle(fontSize: 20),
        // Force the text field to be tall enough to easily see content scrolling by,
        // but short enough to ensure that the content is scrollable.
        minLines: 8,
        maxLines: 8,
        inputSource: textInputSource,
      ),
    ),
    if (verticalAlignment == _TextFieldVerticalAlignmentWithinScrollable.top ||
        verticalAlignment == _TextFieldVerticalAlignmentWithinScrollable.center)
      SliverToBoxAdapter(
        child: Builder(builder: (context) {
          return SizedBox(
            height: MediaQuery.of(context).size.height,
            width: double.infinity,
            child: const Placeholder(
              child: Center(
                child: Text("Content"),
              ),
            ),
          );
        }),
      ),
  ];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: slivers,
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for
  // the final viewport size.
  await tester.pump();
}

/// An arbitrary input, long enough to introduce scrollable content
/// within text field.
final String _textFieldInput = List.generate(20, (index) => "Line $index").join("\n");

/// Defines [SuperTextField] test configurations for a test variant.
///
/// Specificed configurations alter the conditions under which we test
/// [SuperTextField] scrolling on scroll actions invoked through shortcuts.
class _SuperTextFieldScrollSetup {
  const _SuperTextFieldScrollSetup({
    required this.textInputSource,
    required this.verticalAlignment,
  });
  final TextInputSource textInputSource;
  final _TextFieldVerticalAlignmentWithinScrollable verticalAlignment;

  @override
  String toString() {
    return 'SuperTextFieldScrollSetup: aligned at ${verticalAlignment.name},  ${textInputSource.toString()}';
  }
}

/// Defines the vertical alignment of [SuperTextField] within ancestor
/// scrollable.
///
/// Testing against different layouts helps verify that the text field's scrolling
/// through scroll shortcuts remains same irrespective of the text field's vertical alignment
/// within ancestor scrollable.
enum _TextFieldVerticalAlignmentWithinScrollable {
  top,
  center,
  bottom;
}

/// Runs the test on mac desktop, and on web across all desktop platforms.
@isTestGroup
void _testWidgetsOnMacAndWebDesktop(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnMac(description, test, skip: skip, variant: variant);

  testWidgetsOnWebDesktop(description, test, skip: skip, variant: variant);
}
