import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/blocks/indentation.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../core/document.dart';
import 'layout_single_column/layout_single_column.dart';
import 'paragraph.dart';
import 'text.dart';
import 'text_tools.dart';

// ignore: unused_element
final _log = Logger(scope: 'blockquote.dart');

class BlockquoteComponentBuilder implements ComponentBuilder {
  const BlockquoteComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
      PresenterContext context, Document document, DocumentNode node) {
    if (node is! ParagraphNode) {
      return null;
    }
    if (node.getMetadataValue('blockType') != blockquoteAttribution) {
      return null;
    }

    final textDirection = getParagraphDirection(node.text.toPlainText());

    TextAlign textAlign = (textDirection == TextDirection.ltr) ? TextAlign.left : TextAlign.right;
    final textAlignName = node.getMetadataValue('textAlign');
    switch (textAlignName) {
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }

    return BlockquoteComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata["createdAt"],
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      indent: node.indent,
      backgroundColor: const Color(0x00000000),
      borderRadius: BorderRadius.zero,
      textDirection: textDirection,
      textAlignment: textAlign,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! BlockquoteComponentViewModel) {
      return null;
    }

    return BlockquoteComponent(
      textKey: componentContext.componentKey,
      text: componentViewModel.text,
      styleBuilder: componentViewModel.textStyleBuilder,
      indent: componentViewModel.indent,
      indentCalculator: componentViewModel.indentCalculator,
      backgroundColor: componentViewModel.backgroundColor,
      borderRadius: componentViewModel.borderRadius,
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
      underlines: componentViewModel.createUnderlines(),
    );
  }
}

class BlockquoteComponentViewModel extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  BlockquoteComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required this.text,
    required this.textStyleBuilder,
    this.inlineWidgetBuilders = const [],
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.indent = 0,
    this.indentCalculator = defaultParagraphIndentCalculator,
    required this.backgroundColor,
    required this.borderRadius,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
    TextRange? composingRegion,
    bool showComposingRegionUnderline = false,
    UnderlineStyle spellingErrorUnderlineStyle = const SquiggleUnderlineStyle(color: Color(0xFFFF0000)),
    List<TextRange> spellingErrors = const <TextRange>[],
    UnderlineStyle grammarErrorUnderlineStyle = const SquiggleUnderlineStyle(color: Colors.blue),
    List<TextRange> grammarErrors = const <TextRange>[],
  }) {
    this.composingRegion = composingRegion;
    this.showComposingRegionUnderline = showComposingRegionUnderline;

    this.spellingErrorUnderlineStyle = spellingErrorUnderlineStyle;
    this.spellingErrors = spellingErrors;

    this.grammarErrorUnderlineStyle = grammarErrorUnderlineStyle;
    this.grammarErrors = grammarErrors;
  }

  @override
  AttributedText text;
  @override
  AttributionStyleBuilder textStyleBuilder;
  @override
  InlineWidgetBuilderChain inlineWidgetBuilders;
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment;

  int indent;
  TextBlockIndentCalculator indentCalculator;

  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty;

  Color backgroundColor;
  BorderRadius borderRadius;

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);
    backgroundColor = styles[Styles.backgroundColor] ?? Colors.transparent;
    borderRadius = styles[Styles.borderRadius] ?? BorderRadius.zero;
  }

  @override
  BlockquoteComponentViewModel copy() {
    return internalCopy(
      BlockquoteComponentViewModel(
        nodeId: nodeId,
        createdAt: createdAt,
        text: text.copy(),
        textStyleBuilder: textStyleBuilder,
        opacity: opacity,
        selectionColor: selectionColor,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
      ),
    );
  }

  @override
  BlockquoteComponentViewModel internalCopy(BlockquoteComponentViewModel viewModel) {
    final copy = super.internalCopy(viewModel) as BlockquoteComponentViewModel;

    copy
      ..indent = indent
      ..indentCalculator = indentCalculator
      ..backgroundColor = backgroundColor
      ..borderRadius = borderRadius;

    return copy;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is BlockquoteComponentViewModel &&
          runtimeType == other.runtimeType &&
          textViewModelEquals(other) &&
          indent == other.indent &&
          backgroundColor == other.backgroundColor &&
          borderRadius == other.borderRadius;

  @override
  int get hashCode =>
      super.hashCode ^ textViewModelHashCode ^ indent.hashCode ^ backgroundColor.hashCode ^ borderRadius.hashCode;
}

/// Displays a blockquote in a document.
class BlockquoteComponent extends StatelessWidget {
  const BlockquoteComponent({
    Key? key,
    required this.textKey,
    required this.text,
    required this.styleBuilder,
    this.inlineWidgetBuilders = const [],
    this.textSelection,
    this.indent = 0,
    this.indentCalculator = defaultParagraphIndentCalculator,
    this.selectionColor = Colors.lightBlueAccent,
    required this.backgroundColor,
    required this.borderRadius,
    this.highlightWhenEmpty = false,
    this.underlines = const [],
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final InlineWidgetBuilderChain inlineWidgetBuilders;
  final TextSelection? textSelection;
  final int indent;
  final TextBlockIndentCalculator indentCalculator;
  final Color selectionColor;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final bool highlightWhenEmpty;
  final List<Underlines> underlines;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: backgroundColor,
        ),
        child: Row(
          children: [
            // Indent spacing on left.
            SizedBox(
              width: indentCalculator(
                styleBuilder({}),
                indent,
              ),
            ),
            // The actual paragraph UI.
            Expanded(
              child: TextComponent(
                key: textKey,
                text: text,
                textStyleBuilder: styleBuilder,
                inlineWidgetBuilders: inlineWidgetBuilders,
                textSelection: textSelection,
                selectionColor: selectionColor,
                highlightWhenEmpty: highlightWhenEmpty,
                underlines: underlines,
                showDebugPaint: showDebugPaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
