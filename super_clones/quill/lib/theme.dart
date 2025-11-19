import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

/// The background color of the window panes, such as the background of the
/// app header/ribbon.
const windowBackgroundColor = Color(0xFFf9fbfd);

/// The color of the icons that appear next to the document title.
const titleActionIconColor = Color(0xFF444746);

/// The horizontal padding of the primary app menu buttons, e.g., "File", "Edit".
const menuButtonHorizontalPadding = 8.0;

/// The background color of the app toolbar, i.e., the toolbar with options for font
/// family, font size, text alignment.
const toolbarBackgroundColor = Color(0xFFedf2fa);

/// The background color of a selected button on the toolbar, i.e., the color of a
/// bold button when the selection is bold.
const toolbarButtonSelectedColor = Color(0xFFd3e3fd);

/// The background color of a hovered button on the toolbar.
const toolbarButtonHoveredColor = Color(0xFFE1E6ED);

/// The background color of a pressed button on the toolbar.
const toolbarButtonPressedColor = Color(0xFFDAE0E6);

/// The color of the vertical divider of the toolbar.
const toolbarDividerColor = Color(0xFFC7C7C7);

/// Computes the background color for toolbar buttons.
Color? getButtonColor(Set<WidgetState> states) {
  if (states.contains(WidgetState.pressed)) {
    return toolbarButtonPressedColor;
  }

  if (states.contains(WidgetState.selected)) {
    return toolbarButtonSelectedColor;
  }

  if (states.contains(WidgetState.hovered)) {
    return toolbarButtonHoveredColor;
  }

  return Colors.transparent;
}

const themeFontSizeByName = <String?, double>{
  "Huge": 32,
  "Large": 19,
  "Normal": 13,
  "Small": 10,
};

const themeHeaderFontSizeByName = <String?, double>{
  "Heading 1": 26,
  "Heading 2": 19,
  "Heading 3": 15,
  "Heading 4": 13,
  "Heading 5": 11,
  "Heading 6": 9,
  null: 13, // Paragraph text size
};

final defaultToolbarButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(getButtonColor),
  overlayColor: WidgetStateProperty.all(Colors.transparent),
  foregroundColor: WidgetStateProperty.all(Colors.black),
  fixedSize: WidgetStateProperty.all(const Size(30, 30)),
  minimumSize: WidgetStateProperty.all(const Size(30, 30)),
  maximumSize: WidgetStateProperty.all(const Size(30, 30)),
  iconSize: WidgetStateProperty.all(18),
  padding: WidgetStateProperty.all(EdgeInsets.zero),
  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4.0),
    ),
  ),
  shadowColor: WidgetStateProperty.all(Colors.transparent),
);

final featherStylesheet = defaultStylesheet.copyWith(
    addRulesAfter: featherStyles,
    inlineTextStyler: (Set<Attribution> attributions, TextStyle existingStyle) {
      var newStyle = defaultInlineTextStyler(attributions, existingStyle);

      if (attributions.contains(const NamedFontSizeAttribution("Huge"))) {
        newStyle = newStyle.copyWith(
          fontSize: 32,
        );
      }
      if (attributions.contains(const NamedFontSizeAttribution("Large"))) {
        newStyle = newStyle.copyWith(
          fontSize: 19,
        );
      }
      if (attributions.contains(const NamedFontSizeAttribution("Small"))) {
        newStyle = newStyle.copyWith(
          fontSize: 10,
        );
      }

      return newStyle;
    });

final featherStyles = [
  StyleRule(
    BlockSelector.all,
    (doc, docNode) {
      return {
        Styles.padding: const CascadingPadding.all(0),
        Styles.textStyle: const TextStyle(
          fontFamily: "Sans Serif",
          fontSize: 13,
          height: 1.4,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header1"),
    (doc, docNode) {
      return {
        Styles.padding: const CascadingPadding.only(top: 16),
        Styles.textStyle: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header2"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header3"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header4"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header5"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header6"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("blockquote"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("code"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Colors.white,
          fontFamily: "Monospace",
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
      };
    },
  ),
];

FollowerAlignment popoverAligner(Rect globalLeaderRect, Size followerSize, Size screenSize, GlobalKey? boundaryKey) {
  return const FollowerAlignment(
    leaderAnchor: Alignment.bottomLeft,
    followerAnchor: Alignment.topLeft,
    followerOffset: Offset(0, 1),
  );
}
