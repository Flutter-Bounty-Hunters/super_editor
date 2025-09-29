import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:golden_bricks/golden_bricks.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test/super_editor/supereditor_test_tools.dart';

void main() {
  group('SuperEditor > caret rendering >', () {
    testGoldenSceneOnMac('shows caret at right side of an image', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-image-caret-downstream-mac',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await _pumpCaretTestApp(tester, scaffold, decorator);

              // Tap close to the right edge of the editor to place the caret
              // downstream on the image.
              await tester.tapAt(
                tester.getTopRight(find.byType(SuperEditor)) + const Offset(-20, 20),
              );
              await tester.pump();
            },
          )
          .renderOrCompareGolden();
    });

    testGoldenSceneOnIOS('shows caret at right side of an image', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-image-caret-downstream-ios',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await _pumpCaretTestApp(tester, scaffold, decorator);

              // Tap close to the right edge of the editor to place the caret
              // downstream on the image.
              await tester.tapAt(
                tester.getTopRight(find.byType(SuperEditor)) + const Offset(-20, 20),
              );
              await tester.pump();
            },
          )
          .renderOrCompareGolden();
    });

    testGoldenSceneOnAndroid(
      'shows caret at right side of an image',
      (tester) async {
        await Gallery(
          tester,
          sceneName: 'goldens/super-editor-image-caret-downstream-android',
          layout: SceneLayout.column,
        )
            .itemFromPumper(
              id: "1",
              description: 'SuperEditor',
              pumper: (tester, scaffold, decorator) async {
                await _pumpCaretTestApp(tester, scaffold, decorator);

                // Tap close to the right edge of the editor to place the caret
                // downstream on the image.
                await tester.tapAt(
                  tester.getTopRight(find.byType(SuperEditor)) + const Offset(-20, 20),
                );
                await tester.pump();
              },
            )
            .renderOrCompareGolden();
      },
    );

    testGoldenSceneOnMac('shows caret at left side of an image', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-image-caret-upstream-mac',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await _pumpCaretTestApp(tester, scaffold, decorator);

              // Tap close to the left edge of the editor to place the caret upstream
              // on the image.
              await tester.tapAt(
                tester.getTopLeft(find.byType(SuperEditor)) + const Offset(20, 20),
              );
              await tester.pump();
            },
          )
          .renderOrCompareGolden();
    });

    testGoldenSceneOnIOS('shows caret at left side of an image', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-image-caret-upstream-ios',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await _pumpCaretTestApp(tester, scaffold, decorator);

              // Tap close to the left edge of the editor to place the caret upstream
              // on the image.
              await tester.tapAt(
                tester.getTopLeft(find.byType(SuperEditor)) + const Offset(20, 20),
              );
              await tester.pump();
            },
          )
          .renderOrCompareGolden();
    });

    testGoldenSceneOnAndroid(
      'shows caret at left side of an image',
      (tester) async {
        await Gallery(
          tester,
          sceneName: 'goldens/super-editor-image-caret-upstream-android',
          layout: SceneLayout.column,
        )
            .itemFromPumper(
              id: "1",
              description: 'SuperEditor',
              pumper: (tester, scaffold, decorator) async {
                await _pumpCaretTestApp(tester, scaffold, decorator);

                // Tap close to the left edge of the editor to place the caret upstream
                // on the image.
                await tester.tapAt(
                  tester.getTopLeft(find.byType(SuperEditor)) + const Offset(20, 20),
                );
                await tester.pump();
              },
            )
            .renderOrCompareGolden();
      },
    );

    testGoldenSceneOnIOS('allows customizing the caret width', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-ios-custom-caret-width',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await tester //
                  .createDocument()
                  .withSingleParagraph()
                  .withIosCaretStyle(width: 4.0)
                  .withEditorSize(const Size(600, 600))
                  .withGalleryScaffold(scaffold, decorator)
                  .pump();

              // Place caret at "Lorem ip|sum"
              await tester.placeCaretInParagraph('1', 8);
            },
          )
          .renderOrCompareGolden();
    });

    testGoldenSceneOnIOS('allows customizing the expanded handle width', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-ios-custom-handle-width',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await tester //
                  .createDocument()
                  .withSingleParagraph()
                  .withIosCaretStyle(width: 4.0)
                  .withEditorSize(const Size(600, 600))
                  .withGalleryScaffold(scaffold, decorator)
                  .pump();

              // Double tap to select the word ipsum.
              await tester.doubleTapInParagraph('1', 8);
            },
          )
          .renderOrCompareGolden();
    });

    testGoldenSceneOnIOS('allows customizing the expanded handle ball diameter', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-ios-custom-handle-ball-diameter',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await tester //
                  .createDocument()
                  .withSingleParagraph()
                  .withIosCaretStyle(handleBallDiameter: 16.0)
                  .withEditorSize(const Size(600, 600))
                  .withGalleryScaffold(scaffold, decorator)
                  .pump();

              // Double tap to select the word ipsum.
              await tester.doubleTapInParagraph('1', 8);
            },
          )
          .renderOrCompareGolden();
    });

    testGoldenSceneOnAndroid('allows customizing the caret width', (tester) async {
      await Gallery(
        tester,
        sceneName: 'goldens/super-editor-android-custom-caret-width',
        layout: SceneLayout.column,
      )
          .itemFromPumper(
            id: "1",
            description: 'SuperEditor',
            pumper: (tester, scaffold, decorator) async {
              await tester //
                  .createDocument()
                  .withSingleParagraph()
                  .withAndroidCaretStyle(width: 4)
                  .withEditorSize(const Size(600, 600))
                  .withGalleryScaffold(scaffold, decorator)
                  .pump();

              // Place caret at "Lorem ip|sum"
              await tester.placeCaretInParagraph('1', 8);
            },
          )
          .renderOrCompareGolden();
    });

    group('phone rotation updates caret position', () {
      const screenSizePortrait = Size(400.0, 800.0);
      const screenSizeLandscape = Size(800.0, 400);

      testGoldenSceneOnIOS('from portrait to landscape', (tester) async {
        tester.view
          ..devicePixelRatio = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSize = screenSizePortrait;
        addTearDown(() => tester.platformDispatcher.clearAllTestValues());

        await FilmStrip(tester)
            .setup((tester) async {
              final context = await _pumpTestAppWithGoldenBricksFont(tester);

              // Place caret at "adipiscing elit|.". In portrait mode, this character
              // is displayed on the second line. In landscape mode, it's displayed
              // on the first line.
              await tester.placeCaretInParagraph(context.document.first.id, 54);
            })
            .takePhoto(find.byType(SuperEditor), "portrait")
            .modifyScene((tester, testContext) async {
              // Make the window wider, pushing the caret text position up a line.
              tester.view.physicalSize = screenSizeLandscape;
              await tester.pumpAndSettle();
            })
            .takePhoto(find.byType(SuperEditor), "landscape")
            .renderOrCompareGolden(
              goldenName: "super-editor-caret-rotation-portrait-landscape-ios",
              layout: SceneLayout.column,
            );
      });

      testGoldenSceneOnAndroid('from portrait to landscape', (tester) async {
        tester.view
          ..devicePixelRatio = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSize = screenSizePortrait;
        addTearDown(() => tester.platformDispatcher.clearAllTestValues());

        await FilmStrip(tester)
            .setup((tester) async {
              final context = await _pumpTestAppWithGoldenBricksFont(tester);

              // Place caret at "adipiscing elit|.". In portrait mode, this character
              // is displayed on the second line. In landscape mode, it's displayed
              // on the first line.
              await tester.placeCaretInParagraph(context.document.first.id, 54);
            })
            .takePhoto(find.byType(SuperEditor), "portrait")
            .modifyScene((tester, testContext) async {
              // Make the window wider, pushing the caret text position up a line.
              tester.view.physicalSize = screenSizeLandscape;
              await tester.pumpAndSettle();
            })
            .takePhoto(find.byType(SuperEditor), "landscape")
            .renderOrCompareGolden(
              goldenName: "super-editor-caret-rotation-portrait-landscape-android",
              layout: SceneLayout.column,
            );
      });

      testGoldenSceneOnIOS('from landscape to portrait', (tester) async {
        tester.view
          ..devicePixelRatio = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSize = screenSizeLandscape;
        addTearDown(() => tester.platformDispatcher.clearAllTestValues());

        await FilmStrip(tester)
            .setup((tester) async {
              final context = await _pumpTestAppWithGoldenBricksFont(tester);

              // Place caret at "adipiscing elit|.". In portrait mode, this character
              // is displayed on the second line. In landscape mode, it's displayed
              // on the first line.
              await tester.placeCaretInParagraph(context.document.first.id, 54);
            })
            .takePhoto(find.byType(SuperEditor), "portrait")
            .modifyScene((tester, testContext) async {
              // Make the window thiner, pushing the caret text position down a line.
              tester.view.physicalSize = screenSizePortrait;
              await tester.pumpAndSettle();
            })
            .takePhoto(find.byType(SuperEditor), "landscape")
            .renderOrCompareGolden(
              goldenName: "super-editor-caret-rotation-landscape-portrait-ios",
              layout: SceneLayout.column,
            );
      });

      testGoldenSceneOnAndroid('from landscape to portrait', (tester) async {
        tester.view
          ..devicePixelRatio = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSize = screenSizeLandscape;
        addTearDown(() => tester.platformDispatcher.clearAllTestValues());

        await FilmStrip(tester)
            .setup((tester) async {
              final context = await _pumpTestAppWithGoldenBricksFont(tester);

              // Place caret at "adipiscing elit|.". In portrait mode, this character
              // is displayed on the second line. In landscape mode, it's displayed
              // on the first line.
              await tester.placeCaretInParagraph(context.document.first.id, 54);
            })
            .takePhoto(find.byType(SuperEditor), "portrait")
            .modifyScene((tester, testContext) async {
              // Make the window thiner, pushing the caret text position down a line.
              tester.view.physicalSize = screenSizePortrait;
              await tester.pumpAndSettle();
            })
            .takePhoto(find.byType(SuperEditor), "landscape")
            .renderOrCompareGolden(
              goldenName: "super-editor-caret-rotation-landscape-portrait-android'",
              layout: SceneLayout.column,
            );
      });
    });
  });
}

Future<void> _pumpCaretTestApp(
  WidgetTester tester,
  GalleryItemScaffold scaffold,
  GalleryItemDecorator? decorator,
) {
  return tester //
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ImageNode(
              id: '1',
              imageUrl: 'https://this.is.a.fake.image',
              metadata: const SingleColumnLayoutComponentStyles(
                width: double.infinity,
              ).toMetadata(),
            ),
          ],
        ),
      )
      .withEditorSize(const Size(600, 600))
      .withCaretStyle(
        caretStyle: const CaretStyle(color: Colors.red),
      )
      .useStylesheet(
        defaultStylesheet.copyWith(addRulesAfter: [
          StyleRule(
            BlockSelector.all,
            (doc, docNode) => {
              // Zeroes the padding so the component takes all
              // the editor width.
              Styles.padding: const CascadingPadding.all(0.0),
            },
          )
        ]),
      )
      .withAddedComponents(
        [
          const FakeImageComponentBuilder(
            size: Size(double.infinity, 100),
            fillColor: Colors.yellow,
          ),
        ],
      )
      .withGalleryScaffold(scaffold, decorator)
      .pump();
}

/// Pumps a widget tree with a [SuperEditor] styled with the Golden Bricks font
/// for all kinds of nodes.
Future<TestDocumentContext> _pumpTestAppWithGoldenBricksFont(WidgetTester tester) async {
  return await tester //
      .createDocument()
      .fromMarkdown('Lorem ipsum dolor sit amet, consectetur adipiscing elit.')
      .useStylesheet(
        defaultStylesheet.copyWith(addRulesAfter: [
          StyleRule(
            BlockSelector.all,
            (doc, docNode) => {
              Styles.textStyle: const TextStyle(
                fontFamily: goldenBricks,
              )
            },
          )
        ]),
      )
      .pump();
}
