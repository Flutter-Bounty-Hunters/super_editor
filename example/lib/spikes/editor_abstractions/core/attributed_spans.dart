import 'package:flutter/foundation.dart';

/// A set of spans, each with an associated attribution, that take
/// up some amount of space in a discrete range. `AttributedSpans`
/// are useful when implementing attributed text for the purpose
/// of markup and styling.
///
/// You can think of `AttributedSpans` like a set of lanes. Each
/// lane may be occupied by some series of spans for a particular
/// attribute:
///
/// ------------------------------------------------------
/// Bold    :  {xxxx}                      {xxxxx}
/// Italics :             {xxxxxxxx}
/// Link    :                              {xxxxx}
/// ------------------------------------------------------
///
/// Each attributed span is represented by two `SpanMarker`s, one
/// with type `SpanMarkerType.start` and one with type
/// `SpanMarkerType.end`.
///
/// Spans with the same attribution cannot overlap each other, but
/// spans with different attributions can overlap each other.
///
/// When applying `AttributedSpans` to text as styles, you'll
/// eventually want a collapsed series of spans. Use `collapseSpans()`
/// to collapse the different attribution spans into a single
/// series of multi-attribution spans.
class AttributedSpans {
  AttributedSpans({
    int length = 0,
    List<SpanMarker> attributions,
  })  : _length = length,
        attributions = attributions ?? [] {
    _ensureMarkersAreInOrder();
  }

  void _ensureMarkersAreInOrder() {
    int previousOffset = -1;
    for (final attribution in this.attributions) {
      if (attribution.offset < previousOffset) {
        // The attributions are not in order. Print them and throw an exception.
        print('Attributions:');
        for (final attribution in this.attributions) {
          print(' - $attribution');
        }
        throw Exception('The given attributions are not in the correct order.');
      }
      previousOffset = attribution.offset;
    }
  }

  // TODO: length is a concept that came from AttributedText. Do we
  //       even need to enforce a length in AttributedSpans?
  // The length of the range that these spans are
  // allowed to occupy.
  final int _length;

  // TODO: make attributions private, but ensure that tests are effective
  final List<SpanMarker> attributions;

  /// Returns true if this `AttributedSpans` contains at least one
  /// unit of attribution for each of the given `attributions`
  /// within the given range (inclusive).
  bool hasAttributionsWithin({
    @required Set<dynamic> attributions,
    @required int start,
    @required int end,
  }) {
    final attributionsToFind = Set.from(attributions);
    for (int i = start; i <= end; ++i) {
      for (final attribution in attributionsToFind) {
        if (hasAttributionAt(i, attribution: attribution)) {
          attributionsToFind.remove(attribution);
        }

        if (attributionsToFind.isEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns true if a span with the given `attribution` covers the given
  /// `offset`.
  bool hasAttributionAt(
    int offset, {
    dynamic attribution,
  }) {
    SpanMarker markerBefore = _getStartingMarkerAtOrBefore(offset, attribution: attribution);
    if (markerBefore == null) {
      // print(' - there is no start marker for "$attribution" before $offset');
      return false;
    }
    SpanMarker markerAfter =
        markerBefore != null ? _getEndingMarkerAtOrAfter(markerBefore.offset, attribution: attribution) : null;
    if (markerAfter == null) {
      throw Exception('Found an open-ended attribution. It starts with: $markerBefore');
    }

    // print('Looking for "$attribution" at $offset. Before: ${markerBefore.offset}, After: ${markerAfter.offset}');

    return (markerBefore.offset <= offset) && (offset <= markerAfter.offset);
  }

  /// Returns all attributions for spans that cover the given `offset`.
  Set<dynamic> getAllAttributionsAt(int offset) {
    final allAttributions =
        attributions.fold(<dynamic>{}, (allAttributions, marker) => allAttributions..add(marker.attribution));
    final attributionsAtOffset = <dynamic>{};
    for (final attribution in allAttributions) {
      final hasAttribution = hasAttributionAt(offset, attribution: attribution);
      // print(' - has "$attribution" attribution at $offset? ${hasAttribution}');
      if (hasAttribution) {
        attributionsAtOffset.add(attribution);
      }
    }
    return attributionsAtOffset;
  }

  SpanMarker _getStartingMarkerAtOrBefore(int offset, {dynamic attribution}) {
    return attributions //
        .reversed // search from the end so its the nearest start marker
        .where((marker) => attribution == null || marker.attribution == attribution)
        .firstWhere((marker) => marker.isStart && marker.offset <= offset, orElse: () => null);
  }

  SpanMarker _getEndingMarkerAtOrAfter(int offset, {dynamic attribution}) {
    return attributions
        .where((marker) => attribution == null || marker.attribution == attribution)
        .firstWhere((marker) => marker.isEnd && marker.offset >= offset, orElse: () => null);
  }

  /// Adds a span with the given `newAttribution` from `start` to `end`,
  /// inclusive, or expands existing spans to cover at least the range
  /// between `start` and `end`.
  void addAttribution({
    @required dynamic newAttribution,
    @required int start,
    @required int end,
  }) {
    if (start < 0 || start > end) {
      return;
    }
    if (end >= _length) {
      throw Exception(
          'Attribution range exceeds AttributedSpans length. AttributedSpans length: $_length, given range: $start -> $end');
    }

    print('addAttribution(): $start -> $end');
    if (!hasAttributionAt(start, attribution: newAttribution)) {
      print(' - adding start marker at: $start');
      _insertMarker(SpanMarker(
        attribution: newAttribution,
        offset: start,
        markerType: SpanMarkerType.start,
      ));
    }

    // Delete all matching attributions between `range.start`
    // and `range.end`.
    final markersToDelete = attributions
        .where((attribution) => attribution.attribution == newAttribution)
        .where((attribution) => attribution.offset > start)
        .where((attribution) => attribution.offset <= end)
        .toList();
    print(' - removing ${markersToDelete.length} markers between $start and $end');
    // TODO: ideally we'd say "remove all" but that method doesn't
    //       seem to exist?
    attributions.removeWhere((element) => markersToDelete.contains(element));

    final lastDeletedMarker = markersToDelete.isNotEmpty ? markersToDelete.last : null;

    if (lastDeletedMarker == null || lastDeletedMarker.markerType == SpanMarkerType.end) {
      // If we didn't delete any markers, the span that began at
      // `range.start` or before needs to be capped off.
      //
      // If we deleted some markers, but the last marker was an
      // `end` marker, we still have an open-ended span and we
      // need to cap it off.
      print(' - inserting ending marker at: $end');
      _insertMarker(SpanMarker(
        attribution: newAttribution,
        offset: end,
        markerType: SpanMarkerType.end,
      ));
    }
    // Else, `range.end` is in the middle of larger span and
    // doesn't need to be inserted.

    print(' - all attributions after:');
    attributions.where((element) => element.attribution == newAttribution).forEach((element) {
      print(' - $element');
    });
  }

  /// Removes any matching attribution spans between `start` and
  /// `end`, inclusive.
  void removeAttribution({
    @required dynamic attributionToRemove,
    @required int start,
    @required int end,
  }) {
    if (start < 0 || start > end) {
      return;
    }
    if (end >= _length) {
      throw Exception('Attribution range exceeds AttributedSpans length.');
    }

    print('removeAttribution(): $start -> $end');
    if (hasAttributionAt(start, attribution: attributionToRemove)) {
      final markerAtStart = _getMarkerAt(attributionToRemove, start);

      if (markerAtStart == null) {
        print(' - inserting new `end` marker at start of range');
        _insertMarker(SpanMarker(
          attribution: attributionToRemove,
          // Note: if `range.start` is zero, then markerAtStart
          // must not be null, so this condition never triggers.
          offset: start - 1,
          markerType: SpanMarkerType.end,
        ));
      } else if (markerAtStart.isStart) {
        print(' - removing a `start` marker at start of range');
        _removeMarker(markerAtStart);
      } else {
        throw Exception(
            '_hasAttributionAt() said there was an attribution for "$attributionToRemove" at offset "$start", but there is an `end` marker at that position.');
      }
    }

    // Delete all matching attributions between `range.start`
    // and `range.end`.
    final markersToDelete = attributions
        .where((attribution) => attribution.attribution == attributionToRemove)
        .where((attribution) => attribution.offset > start)
        .where((attribution) => attribution.offset <= end)
        .toList();
    print(' - removing ${markersToDelete.length} markers between $start and $end');
    // TODO: ideally we'd say "remove all" but that method doesn't
    //       seem to exist?
    attributions.removeWhere((element) => markersToDelete.contains(element));

    if (end >= _length - 1) {
      // If the range ends at the end of the AttributedSpans, we don't
      // need to insert any `start` markers because there can't be any
      // other `end` markers later in the AttributedSpans.
      print(' - this range goes to the end of the AttributedSpans, so we don\'t need to insert any more markers.');
      print(' - all attributions after:');
      attributions.where((element) => element.attribution == attributionToRemove).forEach((element) {
        print(' - $element');
      });
      return;
    }

    final lastDeletedMarker = markersToDelete.isNotEmpty ? markersToDelete.last : null;

    if (lastDeletedMarker == null || lastDeletedMarker.markerType == SpanMarkerType.start) {
      // The last marker we deleted was a `start` marker.
      // Therefore, an `end` marker appears somewhere down the line.
      // We can't leave it dangling. Add a `start` marker back.
      print(' - inserting a final `start` marker at the end to keep symmetry');
      _insertMarker(SpanMarker(
        attribution: attributionToRemove,
        offset: end + 1,
        markerType: SpanMarkerType.start,
      ));
    }

    print(' - all attributions after:');
    attributions.where((element) => element.attribution == attributionToRemove).forEach((element) {
      print(' - $element');
    });
  }

  /// If ALL of the units in `range` contain the given `attribution`,
  /// that attribution is removed from those units. Otherwise, all of
  /// the units in `range` are assigned the `attribution`.
  void toggleAttribution({
    @required dynamic attribution,
    @required int start,
    @required int end,
  }) {
    if (_isContinuousAttribution(attribution: attribution, start: start, end: end)) {
      removeAttribution(attributionToRemove: attribution, start: start, end: end);
    } else {
      addAttribution(newAttribution: attribution, start: start, end: end);
    }
  }

  bool _isContinuousAttribution({
    @required dynamic attribution,
    @required int start,
    @required int end,
  }) {
    print('_isContinousAttribution(): "$attribution", range: $start -> $end');
    SpanMarker markerBefore = _getNearestMarkerAtOrBefore(start, attribution: attribution);
    print(' - marker before: $markerBefore');

    if (markerBefore == null || markerBefore.isEnd) {
      return false;
    }

    final indexBefore = attributions.indexOf(markerBefore);
    final nextMarker = attributions.sublist(indexBefore).firstWhere(
        (marker) => marker.attribution == attribution && marker.offset > markerBefore.offset,
        orElse: () => null);
    print(' - next marker: $nextMarker');

    if (nextMarker == null) {
      throw Exception('Inconsistent attributions state. Found a `start` marker with no matching `end`.');
    }
    if (nextMarker.isStart) {
      throw Exception('Inconsistent attributions state. Found a `start` marker following a `start` marker.');
    }

    // If there is even one additional marker in the `range`
    // of interest, it means that the given attribution is
    // not applied to the entire range.
    return nextMarker.offset >= end;
  }

  SpanMarker _getNearestMarkerAtOrBefore(
    int offset, {
    dynamic attribution,
  }) {
    SpanMarker markerBefore;
    final markers =
        attribution != null ? attributions.where((marker) => marker.attribution == attribution) : attributions;

    for (final marker in markers) {
      if (marker.offset <= offset) {
        markerBefore = marker;
      }
      if (marker.offset > offset) {
        break;
      }
    }

    return markerBefore;
  }

  SpanMarker _getMarkerAt(dynamic attribution, int offset) {
    return attributions
        .where((marker) => marker.attribution == attribution)
        .firstWhere((marker) => marker.offset == offset, orElse: () => null);
  }

  /// Preconditions:
  ///  - there must not already exist a marker with the same
  ///    attribution at the same offset.
  void _insertMarker(SpanMarker newMarker) {
    SpanMarker markerAfter =
        attributions.firstWhere((existingMarker) => existingMarker.offset >= newMarker.offset, orElse: () => null);

    if (markerAfter != null) {
      final markerAfterIndex = attributions.indexOf(markerAfter);
      attributions.insert(markerAfterIndex, newMarker);
    } else {
      // Insert the new marker at the end.
      attributions.add(newMarker);
    }
  }

  /// Preconditions:
  ///  - `marker` must exist in the `attributions` list.
  void _removeMarker(SpanMarker marker) {
    final index = attributions.indexOf(marker);
    if (index < 0) {
      throw Exception('Tried to remove a marker that isn\'t in attributions list: $marker');
    }
    attributions.removeAt(index);
  }

  /// Pushes back all the spans in `other` by the length of this
  /// `AttributedSpans`, and then appends the `other` spans to this
  /// `AttributedSpans`.
  void addToEnd(AttributedSpans other) {
    print('addToEnd()');
    print(' - our attributions before pushing them:');
    print(toString());

    // Push back all the `other` markers to make room for the
    // spans we're putting in front of them.

    final pushDistance = _length;
    print(' - pushing `other` markers by: $pushDistance');
    print(' - `other` attributions before pushing them:');
    print(other);
    final pushedSpans = other.copy()..pushAttributionsBack(pushDistance);

    // Combine `this` and `other` attributions into one list.
    final List<SpanMarker> combinedAttributions = List.from(attributions)..addAll(pushedSpans.attributions);
    print(' - combined attributions before merge:');
    print(combinedAttributions);

    // Clean up the boundary between the two lists of attributions
    // by merging compatible attributions that meet at teh boundary.
    _mergeBackToBackAttributions(combinedAttributions, _length - 1);

    print(' - combined attributions after merge:');
    for (final marker in combinedAttributions) {
      print('   - $marker');
    }

    attributions
      ..clear()
      ..addAll(combinedAttributions);
  }

  void _mergeBackToBackAttributions(List<SpanMarker> attributions, int mergePoint) {
    print(' - merging attributions at $mergePoint');
    // Look for any compatible attributions at
    // `mergePoint` and `mergePoint+1` and combine them.
    final startEdgeMarkers = attributions.where((marker) => marker.offset == mergePoint).toList();
    final endEdgeMarkers = attributions.where((marker) => marker.offset == mergePoint + 1).toList();
    for (final startEdgeMarker in startEdgeMarkers) {
      print(' - marker on left side: $startEdgeMarker');
      final matchingEndEdgeMarker = endEdgeMarkers.firstWhere(
          (marker) => marker.attribution == startEdgeMarker.attribution && marker.isStart,
          orElse: () => null);
      print(' - matching marker on right side? $matchingEndEdgeMarker');
      if (startEdgeMarker.isEnd && matchingEndEdgeMarker != null) {
        // These two attributions should be combined into one.
        // To do this, delete these two markers from the original
        // attribution list.
        print(' - removing both markers because they offset each other');
        attributions..remove(startEdgeMarker)..remove(matchingEndEdgeMarker);
      }
    }
  }

  /// Returns of a copy of this `AttributedSpans` between `startOffset`
  /// and `endOffset`.
  ///
  /// If no `endOffset` is provided, a copy is made from `startOffset`
  /// to the end of this `AttributedSpans`.
  AttributedSpans copyAttributionRegion(int startOffset, [int endOffset]) {
    endOffset = endOffset ?? _length - 1;
    print('_copyAttributionRegion() - start: $startOffset, end: $endOffset');

    final List<SpanMarker> cutAttributions = [];

    print(' - inspecting existing markers in full AttributedSpans');
    final Map<dynamic, int> foundStartMarkers = {};
    final Map<dynamic, int> foundEndMarkers = {};

    // Analyze all markers that appear before the start of
    // the copy range so that we can insert any appropriate
    // `start` markers at the beginning of the copy range.
    attributions //
        .where((marker) => marker.offset < startOffset) //
        .forEach((marker) {
      print(' - marker before the copy region: $marker');
      // Track any markers that begin before the `startOffset`
      // and continue beyond `startOffset`.
      if (marker.isStart) {
        print(' - remembering this marker to insert in copied region');
        foundStartMarkers.putIfAbsent(marker.attribution, () => 0);
        foundStartMarkers[marker.attribution] += 1;
      } else {
        print(
            ' - this marker counters an earlier one we found. We will not re-insert this marker in the copied region');
        foundStartMarkers.putIfAbsent(marker.attribution, () => 0);
        foundStartMarkers[marker.attribution] -= 1;
      }
    });

    // Insert any `start` markers at the start of the copy region
    // so that we maintain attribution symmetry.
    foundStartMarkers.forEach((markerAttribution, count) {
      if (count == 1) {
        // Found an unmatched `start` marker. Replace it.
        print(' - inserting "$markerAttribution" marker at start of copy region to maintain symmetry.');
        cutAttributions.add(SpanMarker(
          attribution: markerAttribution,
          offset: 0,
          markerType: SpanMarkerType.start,
        ));
      } else if (count < 0 || count > 1) {
        throw Exception(
            'Found an unbalanced number of `start` and `end` markers before offset: $startOffset - $attributions');
      }
    });

    // Directly copy every marker that appears within the cut
    // region.
    attributions //
        .where((marker) => startOffset <= marker.offset && marker.offset <= endOffset) //
        .forEach((marker) {
      print(' - copying "${marker.attribution}" at ${marker.offset} from original AttributionSpans to copy region.');
      cutAttributions.add(marker.copyWith(
        offset: marker.offset - startOffset,
      ));
    });

    // Analyze all markers that appear after the end of
    // the copy range so that we can insert any appropriate
    // `end` markers at the end of the copy range.
    attributions //
        .reversed //
        .where((marker) => marker.offset > endOffset) //
        .forEach((marker) {
      print(' - marker after the copy region: $marker');
      // Track any markers that end after the `endOffset`
      // and start before `endOffset`.
      if (marker.isEnd) {
        print(' - remembering this marker to insert in copied region');
        foundEndMarkers.putIfAbsent(marker.attribution, () => 0);
        foundEndMarkers[marker.attribution] += 1;
      } else {
        print(
            ' - this marker counters an earlier one we found. We will not re-insert this marker in the copied region');
        foundEndMarkers.putIfAbsent(marker.attribution, () => 0);
        foundEndMarkers[marker.attribution] -= 1;
      }
    });

    // Insert any `end` markers at the end of the copy region
    // so that we maintain attribution symmetry.
    foundEndMarkers.forEach((markerAttribution, count) {
      if (count == 1) {
        // Found an unmatched `end` marker. Replace it.
        print(' - inserting "$markerAttribution" marker at end of copy region to maintain symmetry.');
        cutAttributions.add(SpanMarker(
          attribution: markerAttribution,
          offset: endOffset - startOffset,
          markerType: SpanMarkerType.end,
        ));
      } else if (count < 0 || count > 1) {
        throw Exception(
            'Found an unbalanced number of `start` and `end` markers after offset: $endOffset - $attributions');
      }
    });

    print(' - copied attributions:');
    for (final attribution in cutAttributions) {
      print('   - $attribution');
    }

    return AttributedSpans(attributions: cutAttributions);
  }

  /// Changes all spans in this `AttributedSpans` by pushing
  /// them back by `offset` amount.
  void pushAttributionsBack(int offset) {
    final pushedAttributions = attributions.map((marker) => marker.copyWith(offset: marker.offset + offset)).toList();
    attributions
      ..clear()
      ..addAll(pushedAttributions);
  }

  /// Changes spans in this `AttributedSpans` by cutting out the
  /// region from `startOffset` to `startOffset + count`, exclusive.
  void contractAttributions({
    @required int startOffset,
    @required int count,
  }) {
    final contractedAttributions = <SpanMarker>[];

    // Add all the markers that are unchanged.
    contractedAttributions.addAll(attributions.where((marker) => marker.offset < startOffset));

    print(' - removing $count characters starting at $startOffset');
    final needToEndAttributions = <dynamic>{};
    final needToStartAttributions = <dynamic>{};
    attributions
        .where((marker) => (startOffset <= marker.offset) && (marker.offset < startOffset + count))
        .forEach((marker) {
      // Get rid of this marker and keep track of
      // any open-ended attributions that need to
      // be closed.
      print(' - removing ${marker.markerType} at ${marker.offset}');
      if (marker.isStart) {
        if (needToEndAttributions.contains(marker.attribution)) {
          // We've already removed an `end` marker so now
          // we're even.
          needToEndAttributions.remove(marker.attribution);
        } else {
          // We've removed a `start` marker that needs to
          // be replaced down the line.
          needToStartAttributions.add(marker.attribution);
        }
      } else {
        if (needToStartAttributions.contains(marker.attribution)) {
          // We've already removed a `start` marker so now
          // we're even.
          needToStartAttributions.remove(marker.attribution);
        } else {
          // We've removed an `end` marker that needs to
          // be replaced down the line.
          needToEndAttributions.add(marker.attribution);
        }
      }
    });

    // Re-insert any markers that are needed to retain
    // symmetry after the deletions above.
    needToStartAttributions.forEach((attribution) {
      final offset = startOffset > 0 ? startOffset - 1 : 0;
      print(' - adding back a start marker at $offset');
      contractedAttributions.add(SpanMarker(
        attribution: attribution,
        offset: offset,
        markerType: SpanMarkerType.start,
      ));
    });
    needToEndAttributions.forEach((attribution) {
      final offset = startOffset > 0 ? startOffset - 1 : 0;
      print(' - adding back an end marker at $offset');
      contractedAttributions.add(SpanMarker(
        attribution: attribution,
        offset: offset,
        markerType: SpanMarkerType.end,
      ));
    });

    // Add all remaining markers but with an `offset`
    // that is less by `count`.
    contractedAttributions.addAll(
      attributions
          .where((marker) => marker.offset >= startOffset + count)
          .map((marker) => marker.copyWith(offset: marker.offset - count)),
    );

    attributions
      ..clear()
      ..addAll(contractedAttributions);
  }

  /// Returns a copy of this `AttributedSpans`.
  AttributedSpans copy() {
    return AttributedSpans(
      length: _length,
      attributions: List.from(attributions),
    );
  }

  /// Combines all spans of different types into a single
  /// list of spans that contain multiple types per segment.
  ///
  /// The returns spans are ordered.
  List<MultiAttributionSpan> collapseSpans() {
    print('collapseSpans() - content length: $_length');
    print(' - attributions used to compute spans:');
    for (final marker in attributions) {
      print('   - $marker');
    }

    if (_length == 0) {
      // There is no content and therefore no attributions.
      print(' - content is empty. Returning empty span list.');
      return [];
    }

    // Cut up attributions in a series of corresponding "start"
    // and "end" points for every different combination of
    // attributions.
    final startPoints = <int>[0]; // we always start at zero
    final endPoints = <int>[];

    print(' - accumulating start and end points:');
    for (final marker in attributions) {
      print(' - marker at ${marker.offset}');
      print(' - start points before change: $startPoints');
      print(' - end points before change: $endPoints');

      if (marker.isStart) {
        // Add a `start` point.
        if (!startPoints.contains(marker.offset)) {
          print(' - adding start point at ${marker.offset}');
          startPoints.add(marker.offset);
        }

        // If there are no attributions before this `start` point
        // then there won't be an `end` just before this
        // `start` point. Insert one.
        if (marker.offset > 0 && !endPoints.contains(marker.offset - 1)) {
          print(' - going back one and adding end point at: ${marker.offset - 1}');
          endPoints.add(marker.offset - 1);
        }
      }
      if (marker.isEnd) {
        // Add an `end` point.
        if (!endPoints.contains(marker.offset)) {
          print(' - adding an end point at: ${marker.offset}');
          endPoints.add(marker.offset);
        }

        // Automatically start another range if we aren't at
        // the end of the content. We do this because we're not
        // guaranteed to have another `start` marker after this
        // `end` marker.
        if (marker.offset < _length - 1 && !startPoints.contains(marker.offset + 1)) {
          print(' - jumping forward one to add a start point at: ${marker.offset + 1}');
          startPoints.add(marker.offset + 1);
        }
      }

      print(' - start points after change: $startPoints');
      print(' - end points after change: $endPoints');
    }
    if (!endPoints.contains(_length - 1)) {
      // This condition occurs when there are no attributions.
      print(' - adding a final endpoint at end of text');
      endPoints.add(_length - 1);
    }

    if (startPoints.length != endPoints.length) {
      print(' - start points: $startPoints');
      print(' - end points: $endPoints');
      throw Exception(
          ' - mismatch between number of start points and end points. Content length: $_length, Start: ${startPoints.length} -> ${startPoints}, End: ${endPoints.length} -> ${endPoints}, from attributions: ${attributions}');
    }

    // Sort the start and end points so that they can be
    // processed from beginning to end.
    startPoints.sort();
    endPoints.sort();

    // Create the collapsed spans.
    List<MultiAttributionSpan> collapsedSpans = [];
    for (int i = 0; i < startPoints.length; ++i) {
      print(' - building span from ${startPoints[i]} -> ${endPoints[i]}');
      collapsedSpans.add(MultiAttributionSpan(
        start: startPoints[i],
        end: endPoints[i],
        attributions: getAllAttributionsAt(startPoints[i]),
      ));
    }
    return collapsedSpans;
  }

  @override
  String toString() {
    final buffer = StringBuffer('[AttributedSpans] (${(attributions.length / 2).round()} spans):');
    for (final marker in attributions) {
      buffer.write('\n - $marker');
    }
    return buffer.toString();
  }
}

/// Marks the start or end of an attribution span.
///
/// The given `AttributionType` must implement equality for
/// span management to work correctly.
class SpanMarker<AttributionType> implements Comparable<SpanMarker<AttributionType>> {
  const SpanMarker({
    @required this.attribution,
    @required this.offset,
    @required this.markerType,
  });

  final AttributionType attribution;
  final int offset;
  final SpanMarkerType markerType;

  bool get isStart => markerType == SpanMarkerType.start;

  bool get isEnd => markerType == SpanMarkerType.end;

  SpanMarker copyWith({
    AttributionType attribution,
    int offset,
    SpanMarkerType markerType,
  }) =>
      SpanMarker(
        attribution: attribution ?? this.attribution,
        offset: offset ?? this.offset,
        markerType: markerType ?? this.markerType,
      );

  @override
  String toString() => '[SpanMarker] - attribution: $attribution, offset: $offset, type: $markerType';

  @override
  int compareTo(SpanMarker other) {
    return offset - other.offset;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpanMarker &&
          attribution == other.attribution &&
          offset == other.offset &&
          markerType == other.markerType;

  @override
  int get hashCode => attribution.hashCode ^ offset.hashCode ^ markerType.hashCode;
}

enum SpanMarkerType {
  start,
  end,
}

class MultiAttributionSpan {
  const MultiAttributionSpan({
    @required this.start,
    @required this.end,
    @required this.attributions,
  });

  final int start;
  final int end;
  final Set<dynamic> attributions;
}
