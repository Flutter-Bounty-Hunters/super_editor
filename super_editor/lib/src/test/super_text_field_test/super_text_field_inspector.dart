import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Inspects that state of a [SuperTextField] in a test.
class SuperTextFieldInspector {
  /// Finds and returns the [ProseTextLayout] within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static ProseTextLayout findProseTextLayout([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final element = finder.evaluate().single as StatefulElement;
    return (element.state as SuperTextFieldState).textLayout;
  }

  /// Finds and returns the [AttributedText] within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static AttributedText findText([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final element = finder.evaluate().single as StatefulElement;
    final state = element.state as SuperTextFieldState;
    return state.controller.text;
  }

  /// Finds and returns the [RichText] within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static InlineSpan findRichText([Finder? superTextFieldFinder]) {
    final resolvedSuperTextFieldFinder = superTextFieldFinder ?? find.byType(SuperTextField);

    // Try to find a SuperTextField that contains a SuperText. It's possible
    // that a SuperTextField uses a SuperTextWithSelection instead of a SuperText,
    // that condition is handled later.
    final superTextFinder = find.descendant(of: resolvedSuperTextFieldFinder, matching: find.byType(SuperText));
    final superTextElements = superTextFinder.evaluate();

    if (superTextElements.length > 1) {
      throw Exception("Found more than 1 super text field match with finder: $resolvedSuperTextFieldFinder");
    }

    if (superTextElements.length == 1) {
      final element = superTextFinder.evaluate().single as StatefulElement;
      final state = element.state as SuperTextState;
      return state.widget.richText;
    }

    // We didn't find a SuperTextField with a SuperText. Now we'll search for a
    // SuperTextField with a selection.
    final superTextWithSelectionFinder =
        find.descendant(of: resolvedSuperTextFieldFinder, matching: find.byType(SuperTextWithSelection));
    final superTextWithSelectionElements = superTextWithSelectionFinder.evaluate();

    if (superTextWithSelectionElements.length > 1) {
      throw Exception("Found more than 1 super text field match with finder: $resolvedSuperTextFieldFinder");
    }

    if (superTextWithSelectionElements.length == 1) {
      final element = superTextWithSelectionFinder.evaluate().single as StatefulElement;
      final state = element.state as SuperTextState;
      return state.widget.richText;
    }

    throw Exception("Couldn't find a super text field variant with the given finder: $resolvedSuperTextFieldFinder");
  }

  /// Finds and returns the [TextSelection] within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static TextSelection? findSelection([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final element = finder.evaluate().single as StatefulElement;
    final state = element.state as SuperTextFieldState;
    return state.controller.selection;
  }

  /// Returns `true` if the [SuperTextField] currently has focus.
  ///
  /// {@macro supertextfield_finder}
  static bool hasFocus([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final element = finder.evaluate().single as StatefulElement;
    final state = element.state as SuperTextFieldState;
    return state.hasFocus;
  }

  /// Returns `true` if the given [SuperTextField] is a single-line text field.
  ///
  /// {@macro supertextfield_finder}
  static bool isSingleLine([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);

    final fieldFinder = findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;

    switch (match.runtimeType) {
      case SuperDesktopTextField:
        return (match as SuperDesktopTextField).maxLines == 1;
      case SuperAndroidTextField:
        return (match as SuperAndroidTextField).maxLines == 1;
      case SuperIOSTextField:
        return (match as SuperIOSTextField).maxLines == 1;
      default:
        throw Exception("Found unknown SuperTextField platform widget: $match");
    }
  }

  /// Returns `true` if the given [SuperTextField] is a multi-line text field.
  ///
  /// {@macro supertextfield_finder}
  static bool isMultiLine([Finder? superTextFieldFinder]) {
    return !isSingleLine(superTextFieldFinder);
  }

  /// Returns `true` if the given [SuperTextField] is scrollable, i.e., the content
  /// exceeds the viewport size.
  static bool hasScrollableExtent([Finder? superTextFieldFinder]) {
    final desktopScrollController = findDesktopScrollController(superTextFieldFinder);
    if (desktopScrollController != null) {
      return desktopScrollController.position.maxScrollExtent > 0;
    }

    final mobileScrollController = findMobileScrollController(superTextFieldFinder);
    if (mobileScrollController != null) {
      return mobileScrollController.endScrollOffset > 0;
    }

    throw Exception("Couldn't find a SuperTextField to check the scrollable extent. Finder: $superTextFieldFinder");
  }

  /// Returns `true` if the given [SuperTextField] has a scroll offset of zero, i.e.,
  /// is scrolled to the beginning of the viewport.
  ///
  /// This inspection applies to both horizontal and vertical scrolling text fields.
  ///
  /// {@macro supertextfield_finder}
  static bool isScrolledToBeginning([Finder? superTextFieldFinder]) {
    return findScrollOffset(superTextFieldFinder) == 0.0;
  }

  /// Returns `true` if the given [SuperTextField] is scrolled all the away to the
  /// end of the viewport.
  ///
  /// This inspection applies to both horizontal and vertical scrolling text fields.
  ///
  /// {@macro supertextfield_finder}
  static bool isScrolledToEnd([Finder? superTextFieldFinder]) {
    final maxScrollOffset = findDesktopScrollController(superTextFieldFinder)?.position.maxScrollExtent ??
        findMobileScrollController(superTextFieldFinder)?.endScrollOffset;
    assert(maxScrollOffset != null,
        "Couldn't check if SuperTextField is scrolled to the end because no SuperTextField was found.");
    return findScrollOffset(superTextFieldFinder) == maxScrollOffset;
  }

  /// Finds and returns the scroll offset, in the direction of scrolling,
  /// within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static double? findScrollOffset([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);

    final fieldFinder = findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperDesktopTextField) {
      final textScrollViewElement = find
          .descendant(
            of: finder,
            matching: find.byType(SuperTextFieldScrollview),
          )
          .evaluate()
          .single as StatefulElement;
      final textScrollView = textScrollViewElement.widget as SuperTextFieldScrollview;

      return textScrollView.scrollController.offset;
    }

    // Both mobile textfields use TextScrollView.
    final textScrollViewElement = find
        .descendant(
          of: finder,
          matching: find.byType(TextScrollView),
        )
        .evaluate()
        .single as StatefulElement;
    final textScrollView = textScrollViewElement.widget as TextScrollView;

    return textScrollView.textScrollController.scrollOffset;
  }

  static double? findMaxScrollOffset([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);

    final fieldFinder = findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperDesktopTextField) {
      final textScrollViewElement = find
          .descendant(
            of: finder,
            matching: find.byType(SuperTextFieldScrollview),
          )
          .evaluate()
          .single as StatefulElement;
      final textScrollView = textScrollViewElement.widget as SuperTextFieldScrollview;

      return textScrollView.scrollController.position.maxScrollExtent;
    }

    // Both mobile textfields use TextScrollView.
    final textScrollViewElement = find
        .descendant(
          of: finder,
          matching: find.byType(TextScrollView),
        )
        .evaluate()
        .single as StatefulElement;
    final textScrollView = textScrollViewElement.widget as TextScrollView;

    return textScrollView.textScrollController.endScrollOffset;
  }

  static ScrollController? findDesktopScrollController([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);

    final fieldFinder = findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;
    if (match is! SuperDesktopTextField) {
      return null;
    }

    final textScrollViewElement = find
        .descendant(
          of: finder,
          matching: find.byType(SuperTextFieldScrollview),
        )
        .evaluate()
        .single as StatefulElement;
    final textScrollView = textScrollViewElement.widget as SuperTextFieldScrollview;

    return textScrollView.scrollController;
  }

  static TextScrollController? findMobileScrollController([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);

    final fieldFinder = findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;
    if (match is! SuperAndroidTextField && match is! SuperIOSTextField) {
      return null;
    }

    // Both mobile textfields use TextScrollView.
    final textScrollViewElement = find
        .descendant(
          of: finder,
          matching: find.byType(TextScrollView),
        )
        .evaluate()
        .single as StatefulElement;
    final textScrollView = textScrollViewElement.widget as TextScrollView;

    return textScrollView.textScrollController;
  }

  /// Finds and returns the bounding rectangle for the caret in the given [SuperTextField],
  /// represented as coordinates that are local to the viewport.
  ///
  /// The viewport is the rectangle within which (possibly) scrollable text is displayed.
  ///
  /// {@macro supertextfield_finder}
  static Rect? findCaretRectInViewport([Finder? superTextFieldFinder]) {
    final rootFieldFinder = superTextFieldFinder ?? find.byType(SuperTextField);

    final desktopTextField = find.descendant(of: rootFieldFinder, matching: find.byType(SuperDesktopTextField));
    if (desktopTextField.evaluate().isNotEmpty) {
      return _findCaretRectInViewportOnDesktop(desktopTextField);
    }

    final iOSTextField = find.descendant(of: rootFieldFinder, matching: find.byType(SuperIOSTextField));
    if (iOSTextField.evaluate().isNotEmpty) {
      return _findCaretRectInViewportOnMobile(iOSTextField);
    }

    final androidTextField = find.descendant(of: rootFieldFinder, matching: find.byType(SuperAndroidTextField));
    if (androidTextField.evaluate().isNotEmpty) {
      return _findCaretRectInViewportOnMobile(androidTextField);
    }

    throw Exception(
        "Couldn't find the caret rectangle because we couldn't find a SuperTextField. Finder: $superTextFieldFinder");
  }

  static Rect? _findCaretRectInViewportOnDesktop(Finder desktopTextField) {
    final viewport = find
        .descendant(of: desktopTextField, matching: find.byType(SuperTextFieldScrollview))
        .evaluate()
        .single
        .renderObject as RenderBox;

    final caretDisplayElement = find
        .descendant(of: desktopTextField, matching: find.byType(TextLayoutCaret))
        .evaluate()
        .single as StatefulElement;
    final caretDisplay = caretDisplayElement.state as TextLayoutCaretState;
    final caretGlobalRect = caretDisplay.globalCaretGeometry!;

    final viewportOffset = viewport.localToGlobal(Offset.zero);
    return caretGlobalRect.translate(-viewportOffset.dx, -viewportOffset.dy);
  }

  static Rect? _findCaretRectInViewportOnMobile(Finder mobileFieldFinder) {
    final viewport = find
        .descendant(of: mobileFieldFinder, matching: find.byType(TextScrollView))
        .evaluate()
        .single
        .renderObject as RenderBox;

    final caretDisplayElement = find
        .descendant(of: mobileFieldFinder, matching: find.byType(TextLayoutCaret))
        .evaluate()
        .single as StatefulElement;
    final caretDisplay = caretDisplayElement.state as TextLayoutCaretState;
    final caretGlobalRect = caretDisplay.globalCaretGeometry!;

    final viewportOffset = viewport.localToGlobal(Offset.zero);
    return caretGlobalRect.translate(-viewportOffset.dx, -viewportOffset.dy);
  }

  static bool isAndroidCollapsedHandleVisible([Finder? superTextFieldFinder]) {
    final fieldFinder =
        SuperTextFieldInspector.findInnerPlatformTextField(superTextFieldFinder ?? find.byType(SuperTextField));
    final match = (fieldFinder.evaluate().single as StatefulElement).state as SuperAndroidTextFieldState;

    return match.isCollapsedHandleVisible;
  }

  /// Finds and returns the platform textfield within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static Finder findInnerPlatformTextField([Finder? superTextFieldFinder]) {
    final rootFieldFinder = superTextFieldFinder ?? find.byType(SuperTextField);

    final rootMatches = rootFieldFinder.evaluate();
    if (rootMatches.isEmpty) {
      throw Exception("Couldn't find a super text field variant with the given finder: $rootFieldFinder");
    }
    if (rootMatches.length > 1) {
      throw Exception("Found more than 1 super text field match with finder: $rootFieldFinder");
    }

    final rootMatch = rootMatches.single.widget;
    if (rootMatch is! SuperTextField) {
      // The match isn't a generic SuperTextField. Assume that it's a platform
      // specific super text field, which is what we're looking for. Return it.
      return rootFieldFinder;
    }

    final desktopFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperDesktopTextField)).evaluate();
    if (desktopFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperDesktopTextField));
    }

    final androidFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperAndroidTextField)).evaluate();
    if (androidFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperAndroidTextField));
    }

    final iosFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperIOSTextField)).evaluate();
    if (iosFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperIOSTextField));
    }

    throw Exception(
        "Couldn't find the platform-specific super text field within the root SuperTextField. Root finder: $rootFieldFinder");
  }

  SuperTextFieldInspector._();
}
