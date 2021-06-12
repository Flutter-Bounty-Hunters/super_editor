import 'package:example/spikes/editor_abstractions/core/attributed_spans.dart';
import 'package:example/spikes/editor_abstractions/core/attributed_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Attributed Text', () {
    test('no styles', () {
      final text = AttributedText(
        text: 'abcdefghij',
      );
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, 'abcdefghij');
      expect(textSpan.children, null);
    });

    test('full-span style', () {
      final text = AttributedText(text: 'abcdefghij', attributions: const [
        SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
        SpanMarker(attribution: 'bold', offset: 9, markerType: SpanMarkerType.end),
      ]);
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, 'abcdefghij');
      expect(textSpan.style!.fontWeight, FontWeight.bold);
      expect(textSpan.children, null);
    });

    test('single character style', () {
      final text = AttributedText(text: 'abcdefghij', attributions: const [
        SpanMarker(attribution: 'bold', offset: 1, markerType: SpanMarkerType.start),
        SpanMarker(attribution: 'bold', offset: 1, markerType: SpanMarkerType.end),
      ]);
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, null);
      expect(textSpan.children!.length, 3);
      expect(textSpan.children![0].toPlainText(), 'a');
      expect(textSpan.children![1].toPlainText(), 'b');
      expect(textSpan.children![1].style!.fontWeight, FontWeight.bold);
      expect(textSpan.children![2].toPlainText(), 'cdefghij');
      expect(textSpan.children![2].style!.fontWeight, null);
    });

    test('single character style - reverse order', () {
      final text = AttributedText(text: 'abcdefghij', attributions: const [
        // Notice that the markers are provided in reverse order:
        // end then start. Order shouldn't matter within a single
        // position index. This test ensures that.
        SpanMarker(attribution: 'bold', offset: 1, markerType: SpanMarkerType.end),
        SpanMarker(attribution: 'bold', offset: 1, markerType: SpanMarkerType.start),
      ]);
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, null);
      expect(textSpan.children!.length, 3);
      expect(textSpan.children![0].toPlainText(), 'a');
      expect(textSpan.children![1].toPlainText(), 'b');
      expect(textSpan.children![1].style!.fontWeight, FontWeight.bold);
      expect(textSpan.children![2].toPlainText(), 'cdefghij');
      expect(textSpan.children![2].style!.fontWeight, null);
    });

    test('add single character style', () {
      final text = AttributedText(text: 'abcdefghij');
      text.addAttribution('bold', const TextRange(start: 1, end: 1));
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, null);
      expect(textSpan.children!.length, 3);
      expect(textSpan.children![0].toPlainText(), 'a');
      expect(textSpan.children![1].toPlainText(), 'b');
      expect(textSpan.children![1].style!.fontWeight, FontWeight.bold);
      expect(textSpan.children![2].toPlainText(), 'cdefghij');
      expect(textSpan.children![2].style!.fontWeight, null);
    });

    test('partial style', () {
      final text = AttributedText(text: 'abcdefghij', attributions: const [
        SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start),
        SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end),
      ]);
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, null);
      expect(textSpan.children!.length, 3);
      expect(textSpan.children![0].toPlainText(), 'ab');
      expect(textSpan.children![1].toPlainText(), 'cdefgh');
      expect(textSpan.children![1].style!.fontWeight, FontWeight.bold);
      expect(textSpan.children![2].toPlainText(), 'ij');
    });

    test('non-mingled varying styles', () {
      final text = AttributedText(text: 'abcdefghij', attributions: const [
        SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
        SpanMarker(attribution: 'bold', offset: 4, markerType: SpanMarkerType.end),
        SpanMarker(attribution: 'italics', offset: 5, markerType: SpanMarkerType.start),
        SpanMarker(attribution: 'italics', offset: 9, markerType: SpanMarkerType.end),
      ]);
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, null);
      expect(textSpan.children!.length, 2);
      expect(textSpan.children![0].toPlainText(), 'abcde');
      expect(textSpan.children![0].style!.fontWeight, FontWeight.bold);
      expect(textSpan.children![0].style!.fontStyle, null);
      expect(textSpan.children![1].toPlainText(), 'fghij');
      expect(textSpan.children![1].style!.fontWeight, null);
      expect(textSpan.children![1].style!.fontStyle, FontStyle.italic);
    });

    test('intermingled varying styles', () {
      final text = AttributedText(text: 'abcdefghij', attributions: const [
        SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start),
        SpanMarker(attribution: 'italics', offset: 4, markerType: SpanMarkerType.start),
        SpanMarker(attribution: 'bold', offset: 5, markerType: SpanMarkerType.end),
        SpanMarker(attribution: 'italics', offset: 7, markerType: SpanMarkerType.end),
      ]);
      final textSpan = text.computeTextSpan(_styleBuilder);

      expect(textSpan.text, null);
      expect(textSpan.children!.length, 5);
      expect(textSpan.children![0].toPlainText(), 'ab');
      expect(textSpan.children![0].style!.fontWeight, null);
      expect(textSpan.children![0].style!.fontStyle, null);

      expect(textSpan.children![1].toPlainText(), 'cd');
      expect(textSpan.children![1].style!.fontWeight, FontWeight.bold);
      expect(textSpan.children![1].style!.fontStyle, null);

      expect(textSpan.children![2].toPlainText(), 'ef');
      expect(textSpan.children![2].style!.fontWeight, FontWeight.bold);
      expect(textSpan.children![2].style!.fontStyle, FontStyle.italic);

      expect(textSpan.children![3].toPlainText(), 'gh');
      expect(textSpan.children![3].style!.fontWeight, null);
      expect(textSpan.children![3].style!.fontStyle, FontStyle.italic);

      expect(textSpan.children![4].toPlainText(), 'ij');
      expect(textSpan.children![4].style!.fontWeight, null);
      expect(textSpan.children![4].style!.fontStyle, null);
    });
  });
}

/// Creates styles based on the given `attributions`.
TextStyle _styleBuilder(Set<dynamic> attributions) {
  TextStyle newStyle = const TextStyle();
  for (final attribution in attributions) {
    if (attribution is! String) {
      continue;
    }

    switch (attribution) {
      case 'bold':
        newStyle = newStyle.copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      case 'italics':
        newStyle = newStyle.copyWith(
          fontStyle: FontStyle.italic,
        );
        break;
      case 'strikethrough':
        newStyle = newStyle.copyWith(
          decoration: TextDecoration.lineThrough,
        );
        break;
    }
  }
  return newStyle;
}
