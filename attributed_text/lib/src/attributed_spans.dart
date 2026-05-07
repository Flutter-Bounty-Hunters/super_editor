import 'dart:math';

import 'package:collection/collection.dart';

import 'attribution.dart';
import 'logging.dart';
import 'span_range.dart';

final _log = attributionsLog;

/// A set of spans, each with an associated [Attribution], that take
/// up some amount of space in a discrete range.
///
/// [AttributedSpans] are useful when implementing attributed text
/// for the purpose of markup and styling.
///
/// You can think of [AttributedSpans] like a set of lanes. Each
/// lane may be occupied by some series of spans for a particular
/// attribute:
///
/// ------------------------------------------------------
/// Bold    :  {xxxx}                      {xxxxx}
/// Italics :             {xxxxxxxx}
/// Link    :                              {xxxxx}
/// ------------------------------------------------------
///
/// An attribution can be any subclass of [Attribution]. Based
/// on the type of [Attribution] that is used, two [Attribution]s
/// might occupy the same lane or different lanes. For example,
/// any two [NamedAttribution]s occupy the same lane if-and-only-if
/// the two [Attribution]s have the same name, like "bold".
///
/// Each attributed span is represented by two [SpanMarker]s, one
/// with type [SpanMarkerType.start] and one with type
/// [SpanMarkerType.end].
///
/// Spans with equivalent [Attribution]s **cannot** overlap each other, but
/// spans with different [Attribution]s **can** overlap each other.
class AttributedSpans {
  /// Constructs an [AttributedSpans] with the given [attributions].
  ///
  /// [attributions] may be omitted to create an [AttributedSpans]
  /// with no spans.
  AttributedSpans({
    List<SpanMarker>? attributions,
  }) : _markers = [...?attributions] {
    _sortAttributions();
  }

  // markers must always be in order from lowest marker offset to highest marker offset.
  Iterable<SpanMarker> get markers => _markers;
  final List<SpanMarker> _markers;

  void _sortAttributions() {
    _markers.sort();
  }

  /// Returns `true` if this [AttributedSpans] contains at least one
  /// unit of attribution for each of the given [attributions]
  /// within the given range (inclusive).
  bool hasAttributionsWithin({
    required Set<Attribution> attributions,
    required int start,
    required int end,
  }) {
    final attributionsToFind = Set.from(attributions);
    for (int i = start; i <= end; ++i) {
      final foundAttributions = <Attribution>{};
      for (final attribution in attributionsToFind) {
        if (hasAttributionAt(i, attribution: attribution)) {
          // Store the attributions we found so far to remove them
          // from attributionsToFind after the loop.
          //
          // Removing from the set while iterating throws an exception.
          foundAttributions.add(attribution);
        }
      }
      attributionsToFind.removeAll(foundAttributions);
      if (attributionsToFind.isEmpty) {
        // We found all attributions.
        return true;
      }
    }
    return false;
  }

  /// Finds and returns all [Attribution]s in this [AttributedSpans] that
  /// match any of the given [attributions].
  ///
  /// Two [Attribution]s are said to "match" if their `id`s are equal.
  Set<Attribution> getMatchingAttributionsWithin({
    required Set<Attribution> attributions,
    required int start,
    required int end,
  }) {
    if (attributions.isEmpty) {
      return {};
    }

    final desiredIds = {
      for (final a in attributions) //
        a.id
    };
    final matchingAttributions = <Attribution>{};
    final Map<String, int> openSpans = {};

    for (final marker in _markers) {
      if (marker.isStart) {
        if (desiredIds.contains(marker.attribution.id)) {
          // We found the start of an attribution span we're interested in.
          openSpans[marker.attribution.id] ??= marker.offset;
        }
      } else {
        final spanStart = openSpans.remove(marker.attribution.id);
        if (spanStart == null) {
          // We haven't found a corresponding start to this attribution range that
          // we care about. This means that this is not one of the `attributions`
          // we're looking for. Skip it.
          continue;
        }

        if (spanStart <= end && marker.offset >= start) {
          // We found the end of an attribution span we're interested in. Also,
          // that span starts and ends within the range of interest. Add this
          // attribution to the set we return.
          matchingAttributions.add(marker.attribution);
        }
      }
    }

    return matchingAttributions;
  }

  /// Returns `true` if the given [offset] has the given [attribution].
  ///
  /// If the given [attribution] is `null`, returns `true` if any attribution
  /// exists at the given [offset].
  bool hasAttributionAt(
    int offset, {
    Attribution? attribution,
  }) {
    SpanMarker? markerBefore = _getStartingMarkerAtOrBefore(offset, attribution: attribution);
    if (markerBefore == null) {
      return false;
    }
    SpanMarker? markerAfter = _getEndingMarkerAtOrAfter(markerBefore.offset, attribution: attribution);
    if (markerAfter == null) {
      throw Exception('Found an open-ended attribution. It starts with: $markerBefore');
    }

    return (markerBefore.offset <= offset) && (offset <= markerAfter.offset);
  }

  /// Calculates and returns the full [AttributionSpan], which contains the
  /// given [attribution] at the given [offset].
  ///
  /// For example, imagine spans applied to text like this: "Hello, |world!|".
  /// The text between the bars has a "bold" attribution. Invoking this method
  /// with the "bold" attribution and an offset of `10` would return an
  /// `AttributionSpan` of "bold" from `7` to `14`.
  AttributionSpan expandAttributionToSpan({
    required Attribution attribution,
    required int offset,
  }) {
    if (!hasAttributionAt(offset, attribution: attribution)) {
      throw Exception(
          'Tried to expand attribution ($attribution) at offset "$offset" but the given attribution does not exist at that offset.');
    }

    // The following methods should be guaranteed to produce non-null
    // values because we already verified that the given attribution
    // exists at the given offset.
    SpanMarker markerBefore = _getStartingMarkerAtOrBefore(offset, attribution: attribution)!;
    SpanMarker markerAfter = _getEndingMarkerAtOrAfter(markerBefore.offset, attribution: attribution)!;

    return AttributionSpan(
      attribution: attribution,
      start: markerBefore.offset,
      end: markerAfter.offset,
    );
  }

  /// Returns all attributions for spans that cover the given [offset].
  Set<Attribution> getAllAttributionsAt(int offset) {
    final allAttributions = <Attribution>{};
    for (final marker in _markers) {
      allAttributions.add(marker.attribution);
    }

    final attributionsAtOffset = <Attribution>{};
    for (final attribution in allAttributions) {
      final hasAttribution = hasAttributionAt(offset, attribution: attribution);
      if (hasAttribution) {
        attributionsAtOffset.add(attribution);
      }
    }

    return attributionsAtOffset;
  }

  /// Returns spans for each attribution that (at least partially) appear
  /// between [start] and [end], inclusive, as selected by [attributionFilter].
  ///
  /// By default, the returned spans represent the full, contiguous span
  /// of each attribution. This means that if a portion of an attribution
  /// appears between [start] and [end], the entire attribution span is
  /// returned, including the area that sits before [start], or after [end].
  ///
  /// To obtain attribution spans that are cut down and limited to the
  /// given [start]/[end] range, pass [true] for [resizeSpansToFitInRange].
  /// This setting only effects the returned spans, it does not alter the
  /// attributions within this [AttributedSpans].
  Set<AttributionSpan> getAttributionSpansInRange({
    required AttributionFilter attributionFilter,
    required int start,
    required int end,
    bool resizeSpansToFitInRange = false,
  }) {
    final matchingAttributionSpans = <AttributionSpan>{};
    final Map<String, int> openSpans = {};

    for (final marker in _markers) {
      if (marker.isStart) {
        if (attributionFilter(marker.attribution)) {
          openSpans[marker.attribution.id] ??= marker.offset;
        }
      } else {
        // Is there a start marker matching this end marker?
        final spanStart = openSpans.remove(marker.attribution.id);
        if (spanStart == null) {
          // We don't have a start marker for this end marker. This is
          // because this attribution failed the `attributionFilter`. We
          // don't care about it.
          continue;
        }

        final spanEnd = marker.offset;

        // Does span overlap requested range?
        if (spanStart <= end && spanEnd >= start) {
          // Add the span to the set. Duplicate are automatically ignored.
          matchingAttributionSpans.add(AttributionSpan(
            attribution: marker.attribution,
            start: resizeSpansToFitInRange ? max(spanStart, start) : spanStart,
            end: resizeSpansToFitInRange ? min(spanEnd, end) : spanEnd,
          ));
        }
      }
    }

    return matchingAttributionSpans;
  }

  /// Returns the range about [offset], which is attributed with all given [attributions].
  ///
  /// [attributions] must not be empty.
  SpanRange getAttributedRange(Set<Attribution> attributions, int offset) {
    if (attributions.isEmpty) {
      throw Exception('getAttributedRange requires a non empty set of attributions');
    }

    int? maxStartMarkerOffset;
    int? minEndMarkerOffset;

    for (final attribution in attributions) {
      if (!hasAttributionAt(offset, attribution: attribution)) {
        throw Exception(
            'Tried to get the attributed range of ($attribution) at offset "$offset" but the given attribution does not exist at that offset.');
      }

      int startMarkerOffset = _getStartingMarkerAtOrBefore(offset, attribution: attribution)!.offset;
      int endMarkerOffset = _getEndingMarkerAtOrAfter(offset, attribution: attribution)!.offset;

      if (maxStartMarkerOffset == null || startMarkerOffset > maxStartMarkerOffset) {
        maxStartMarkerOffset = startMarkerOffset;
      }

      if (minEndMarkerOffset == null || endMarkerOffset < minEndMarkerOffset) {
        minEndMarkerOffset = endMarkerOffset;
      }
    }

    // Note: maxStartMarkerOffset and minEndMarkerOffset are non-null because we verified
    // that all desired attributions are present at the given offset.
    return SpanRange(
      maxStartMarkerOffset!,
      minEndMarkerOffset!,
    );
  }

  /// Finds and returns the nearest [start] marker that appears at or before the
  /// given [offset], optionally looking specifically for a marker with
  /// the given [attribution].
  SpanMarker? _getStartingMarkerAtOrBefore(int offset, {Attribution? attribution}) {
    return _markers //
        .reversed // search from the end so its the nearest start marker
        .where((marker) {
      return attribution == null || (marker.attribution == attribution);
    }).firstWhereOrNull((marker) => marker.isStart && marker.offset <= offset);
  }

  /// Finds and returns the nearest [end] marker that appears at or after the
  /// given [offset], optionally looking specifically for a marker with
  /// the given [attribution].
  SpanMarker? _getEndingMarkerAtOrAfter(int offset, {Attribution? attribution}) {
    return _markers
        .where((marker) => attribution == null || (marker.attribution.id == attribution.id))
        .firstWhereOrNull((marker) => marker.isEnd && marker.offset >= offset);
  }

  /// Applies the [newAttribution] from [start] to [end], inclusive.
  ///
  /// If [start] is less than `0`, nothing happens.
  ///
  /// [AttributedSpans] doesn't have any knowledge about content length, so [end] can
  /// take any value that's desired. However, users of [AttributedSpans] should take
  /// care to avoid values for [end] that exceed the content length.
  ///
  /// The effect of adding an attribution is straight forward when the text doesn't
  /// contain any other attributions with the same ID. However, there are various
  /// situations where [newAttribution] can't necessarily co-exist with other
  /// attribution spans that already exist in the text.
  ///
  /// Attribution overlaps can take one of two forms: mergeable or conflicting.
  ///
  /// ## Mergeable Attribution Spans
  /// An example of a mergeable overlap is where two bold spans overlap each
  /// other. All bold attributions are interchangeable, so when two bold spans
  /// overlap, those spans can be merged together into a single span.
  ///
  /// However, mergeable overlapping spans are not automatically merged. Instead,
  /// this decision is left to the user of this class. If you want [AttributedSpans] to
  /// merge overlapping mergeable spans, pass `true` for [autoMerge]. Otherwise,
  /// if [autoMerge] is `false`, an exception is thrown when two mergeable spans
  /// overlap each other.
  ///
  ///
  /// ## Conflicting Attribution Spans
  /// An example of a conflicting overlap is where a black text color overlaps a red
  /// text color. Text is either black, OR red, but never both. Therefore, the black
  /// attribution cannot co-exist with the red attribution. Something must be done
  /// to resolve this.
  ///
  /// There are two possible ways to handle conflicting overlaps. The new attribution
  /// can overwrite the existing attribution where they overlap. Or, an exception can be
  /// thrown. To overwrite the existing attribution with the new attribution, pass `true`
  /// for [overwriteConflictingSpans]. Otherwise, if [overwriteConflictingSpans]
  /// is `false`, an exception is thrown.
  void addAttribution({
    required Attribution newAttribution,
    required int start,
    required int end,
    bool autoMerge = true,
    bool overwriteConflictingSpans = true,
  }) {
    if (start < 0 || start > end) {
      _log.warning("Tried to add an attribution ($newAttribution) at an invalid start/end: $start -> $end");
      return;
    }

    _log.info("Adding attribution ($newAttribution) from $start to $end");
    _log.finer("Has ${_markers.length} markers before addition");

    final conflicts = <_AttributionConflict>[];

    // Check if conflicting attributions overlap the new attribution.
    final matchingAttributions = getMatchingAttributionsWithin(attributions: {newAttribution}, start: start, end: end);
    if (matchingAttributions.isNotEmpty) {
      for (final matchingAttribution in matchingAttributions) {
        bool areAttributionsMergeable = newAttribution.canMergeWith(matchingAttribution);
        if (!areAttributionsMergeable || !autoMerge) {
          int? conflictStart;
          int? conflictEnd;

          for (int i = start; i <= end; ++i) {
            if (hasAttributionAt(i, attribution: matchingAttribution)) {
              conflictStart ??= i;
              conflictEnd = i;

              if (areAttributionsMergeable) {
                // Both attributions are mergeable, but the caller doesn't want to merge them.
                throw IncompatibleOverlappingAttributionsException(
                  existingAttribution: matchingAttribution,
                  newAttribution: newAttribution,
                  conflictStart: conflictStart,
                );
              }
            } else if (conflictStart != null) {
              // We found the end of the conflict.
              conflicts.add(_AttributionConflict(
                newAttribution: newAttribution,
                existingAttribution: matchingAttribution,
                conflictStart: conflictStart,
                conflictEnd: conflictEnd!,
              ));

              // Reset so we can find the next conflict.
              conflictStart = null;
              conflictEnd = null;
            }
          }

          if (conflictStart != null && conflictEnd != null) {
            // We found a conflict that extends to the end of the range.
            conflicts.add(_AttributionConflict(
              newAttribution: newAttribution,
              existingAttribution: matchingAttribution,
              conflictStart: conflictStart,
              conflictEnd: conflictEnd,
            ));
          }
        }
      }

      if (conflicts.isNotEmpty && !overwriteConflictingSpans) {
        // We found conflicting attributions and we are configured not to overwrite them.
        // For example, the user tried to apply a blue color attribution to a range of text
        // that already has another color attribution.
        throw IncompatibleOverlappingAttributionsException(
          existingAttribution: conflicts.first.existingAttribution,
          newAttribution: newAttribution,
          conflictStart: conflicts.first.conflictStart,
        );
      }
    }

    // Removes any conflicting attributions. For example, consider the following text,
    // with a blue color attribution that spans the entire text:
    //
    //    one two three
    //   |bbbbbbbbbbbbb|
    //
    // We can't apply a green color attribution to the word "two", because it's already
    // attributed with blue. So, we need to remove the blue attribution from the word "two",
    // which results in the following text:
    //
    //    one two three
    //   |bbbb---bbbbbb|
    //
    // After that, we can apply the desired attribution, because there isn't a conflicting attribution
    // in this range anymore.
    for (final conflict in conflicts) {
      removeAttribution(
        attributionToRemove: conflict.existingAttribution,
        start: conflict.conflictStart,
        end: conflict.conflictEnd,
      );
    }

    if (!autoMerge) {
      // We don't want to merge this new attribution with any other nearby attribution.
      // Therefore, we can blindly create the new attribution range without any
      // further adjustments, and then be done.
      _insertMarker(SpanMarker(
        attribution: newAttribution,
        offset: start,
        markerType: SpanMarkerType.start,
      ));
      _insertMarker(SpanMarker(
        attribution: newAttribution,
        offset: end,
        markerType: SpanMarkerType.end,
      ));

      return;
    }

    // Start the new span, either by expanding an existing span, or by
    // inserting a new start marker for the new span.
    final endMarkerJustBefore =
        SpanMarker(attribution: newAttribution, offset: start - 1, markerType: SpanMarkerType.end);
    final endMarkerAtNewStart = SpanMarker(attribution: newAttribution, offset: start, markerType: SpanMarkerType.end);
    if (_markers.contains(endMarkerJustBefore)) {
      // A compatible span ends immediately before this new span begins.
      // Remove the end marker so that the existing span flows into the new span.
      _log.fine('A compatible span already exists immediately before the new span range. Combining the spans.');
      _markers.remove(endMarkerJustBefore);
    } else if (!hasAttributionAt(start, attribution: newAttribution)) {
      // The desired attribution does not yet exist at `start`, and no compatible
      // span sits immediately upstream. Therefore, we need to start a new span
      // for the given `newAttribution`.
      _log.fine('Adding start marker for new span at: $start');
      _insertMarker(SpanMarker(
        attribution: newAttribution,
        offset: start,
        markerType: SpanMarkerType.start,
      ));
    } else if (_markers.contains(endMarkerAtNewStart)) {
      // There's an end marker for this span at the same place where
      // the new span wants to begin. Remove the end marker so that the
      // existing span flows into the new span.
      _log.fine('Removing existing end marker at $start because the new span should merge with an existing span');
      _markers.remove(endMarkerAtNewStart);
    }

    // Delete all markers of the same type between `range.start`
    // and `range.end`.
    final markersToDelete = _markers
        .where((attribution) => attribution.attribution == newAttribution)
        .where((attribution) => attribution.offset > start)
        .where((attribution) => attribution.offset <= end)
        .toList();
    _log.fine('Removing ${markersToDelete.length} markers between $start and $end');
    _markers.removeWhere((element) => markersToDelete.contains(element));

    final lastDeletedMarker = markersToDelete.isNotEmpty ? markersToDelete.last : null;

    if (lastDeletedMarker == null || lastDeletedMarker.markerType == SpanMarkerType.end) {
      // If we didn't delete any markers, the span that began at
      // `range.start` or before needs to be capped off.
      //
      // If we deleted some markers, but the last marker was an
      // `end` marker, we still have an open-ended span and we
      // need to cap it off.
      _log.fine('Inserting ending marker at: $end');
      _insertMarker(SpanMarker(
        attribution: newAttribution,
        offset: end,
        markerType: SpanMarkerType.end,
      ));
    }
    // Else, `range.end` is in the middle of larger span and
    // doesn't need to be inserted.

    assert(() {
      // Only run this loop in debug mode to avoid unnecessary iteration
      // in a release build (when logging should be turned off, anyway).
      _log.fine('All attributions after:');
      _markers.where((element) => element.attribution == newAttribution).forEach((element) {
        _log.fine('$element');
      });
      return true;
    }());
  }

  /// Removes [attributionToRemove] between [start] and [end], inclusive.
  void removeAttribution({
    required Attribution attributionToRemove,
    required int start,
    required int end,
  }) {
    _log.info('Removing attribution $attributionToRemove from $start to $end');
    if (start < 0 || start > end) {
      throw Exception('removeAttribution() did not satisfy start < 0 and start > end, start: $start, end: $end');
    }

    if (!hasAttributionsWithin(attributions: {attributionToRemove}, start: start, end: end)) {
      _log.fine('No such attribution exists in the given span range');
      return;
    }

    // It's possible that a span we want to remove was started before the
    // removal region and/or ended after the removal region. Therefore,
    // the first thing we do is cut off those outer spans one unit before
    // and/or after the removal region.
    //
    // Example:
    //    Starting spans + removal region:
    //    ---[xxxxx]---[yyyyyy]----
    //          |-remove-|
    //
    //    Spans after end cap adjustment:
    //    ---[xx]|xxx]---[yy|[yyy]----
    //
    //    Notice that the above marker structure is illegal.
    //    That's OK because the illegal configuration is only
    //    temporary. By the end of this method it will look
    //    like the following:
    //
    //    Spans after all inner markers are removed:
    //    ---[xx]--------[yyy]----
    final endCapMarkersToInsert = <SpanMarker>{};

    // Determine if we need to insert a new end-cap before
    // the removal region.
    if (hasAttributionAt(start - 1, attribution: attributionToRemove)) {
      final markersAtStart = _getMarkerAt(attributionToRemove, start - 1, SpanMarkerType.end);
      if (markersAtStart.isEmpty) {
        _log.finer('Creating a new "end" marker to appear before the removal range at ${start - 1}');
        endCapMarkersToInsert.add(SpanMarker(
          attribution: attributionToRemove,
          offset: start - 1,
          markerType: SpanMarkerType.end,
        ));
      }
    }

    // Determine if we need to insert a new end-cap after the
    // removal region.
    if (hasAttributionAt(end + 1, attribution: attributionToRemove)) {
      final markersAtEnd = _getMarkerAt(attributionToRemove, end + 1, SpanMarkerType.start);
      if (markersAtEnd.isEmpty) {
        _log.finer('Creating a new "start" marker to appear after the removal range at ${end + 1}');
        endCapMarkersToInsert.add(SpanMarker(
          attribution: attributionToRemove,
          offset: end + 1,
          markerType: SpanMarkerType.start,
        ));
      }
    }

    // Insert new span end-caps immediately before and after
    // the removal region, if needed.
    for (final endCapMarker in endCapMarkersToInsert) {
      _log.finer('Inserting new cap marker: $endCapMarker');
      _insertMarker(endCapMarker);
    }

    // Now that the end caps have been handled, remove all
    // relevant attribution markers between [start, end].
    final markersToDelete = _markers
        .where((attribution) => attribution.attribution == attributionToRemove)
        .where((attribution) => attribution.offset >= start)
        .where((attribution) => attribution.offset <= end)
        .toList();
    _log.finer('removing ${markersToDelete.length} markers between $start and $end');
    _markers.removeWhere((element) => markersToDelete.contains(element));

    _log.finer('all attributions after:');
    _markers.where((element) => element.attribution == attributionToRemove).forEach((element) {
      _log.finer(' - $element');
    });
  }

  /// If ALL of the units between [start] and [end], inclusive, contain the
  /// given [attribution], that attribution is removed from those units.
  /// Otherwise, all of the units between [start] and [end], inclusive,
  /// are assigned the [attribution].
  void toggleAttribution({
    required dynamic attribution,
    required int start,
    required int end,
  }) {
    _log.info('Toggling attribution $attribution from $start to $end');
    if (_isContinuousAttribution(attribution: attribution, start: start, end: end)) {
      removeAttribution(attributionToRemove: attribution, start: start, end: end);
    } else {
      addAttribution(newAttribution: attribution, start: start, end: end);
    }
  }

  /// Returns [true] if the given [attribution] exists from [start] to
  /// [end], inclusive, without any breaks in between. Otherwise, returns
  /// [false].
  bool _isContinuousAttribution({
    required Attribution attribution,
    required int start,
    required int end,
  }) {
    _log.fine('attribution: "$attribution", range: $start -> $end');
    SpanMarker? markerBefore = _getNearestMarkerAtOrBefore(start, attribution: attribution, type: SpanMarkerType.start);
    _log.fine('marker before: $markerBefore');

    if (markerBefore == null) {
      return false;
    }

    final indexBefore = _markers.indexOf(markerBefore);
    final nextMarker = _markers.sublist(indexBefore).firstWhereOrNull((marker) {
      _log.finest('Comparing start marker $markerBefore to another marker $marker');
      return marker.attribution == attribution && marker.offset >= markerBefore.offset && marker != markerBefore;
    });
    _log.fine('next marker: $nextMarker');

    if (nextMarker == null) {
      _log.warning('Inconsistent attribution markers. Found a `start` marker with no matching `end`.');
      _log.warning(this);
      throw Exception('Inconsistent attributions state. Found a `start` marker with no matching `end`.');
    }
    if (nextMarker.isStart) {
      _log.warning('Inconsistent attributions state. Found a `start` marker following a `start` marker.');
      _log.warning(this);
      throw Exception('Inconsistent attributions state. Found a `start` marker following a `start` marker.');
    }

    // If there is even one additional marker in the `range`
    // of interest, it means that the given attribution is
    // not applied to the entire range.
    return nextMarker.offset >= end;
  }

  /// Finds and returns the nearest marker that appears at or before the
  /// given [offset], optionally looking specifically for a marker with
  /// the given [attribution] and given [type].
  SpanMarker? _getNearestMarkerAtOrBefore(
    int offset, {
    Attribution? attribution,
    SpanMarkerType? type,
  }) {
    SpanMarker? markerBefore;
    final markerCandidates = _markers
        .where((marker) => attribution == null || marker.attribution == attribution)
        .where((marker) => type == null || marker.markerType == type);

    for (final marker in markerCandidates) {
      if (marker.offset <= offset) {
        markerBefore = marker;
      }
      if (marker.offset > offset) {
        break;
      }
    }

    return markerBefore;
  }

  /// Returns the markers at the given [offset] with the given [attribution]..
  Set<SpanMarker> _getMarkerAt(Attribution attribution, int offset, [SpanMarkerType? type]) {
    return _markers
        .where((marker) => marker.attribution == attribution)
        .where((marker) => marker.offset == offset)
        .where((marker) => type == null || marker.markerType == type)
        .toSet();
  }

  /// Inserts the [newMarker] into this [AttributedSpans].
  ///
  /// Precondition: There must not already exist a marker with
  /// the same attribution at the same offset.
  void _insertMarker(SpanMarker newMarker) {
    int indexOfFirstMarkerAfterInsertionPoint =
        _markers.indexWhere((existingMarker) => existingMarker.compareTo(newMarker) > 0);
    // [indexWhere] returns -1 if no matching element is found.
    final foundMarkerToInsertBefore = indexOfFirstMarkerAfterInsertionPoint >= 0;

    if (foundMarkerToInsertBefore) {
      _markers.insert(indexOfFirstMarkerAfterInsertionPoint, newMarker);
    } else {
      // Insert the new marker at the end.
      _markers.add(newMarker);
    }
  }

  /// Pushes back all the spans in [other] to [index], and then appends
  /// the [other] spans to this [AttributedSpans].
  ///
  /// The [index] must be greater than the offset of the final marker
  /// within this [AttributedSpans].
  void addAt({
    required AttributedSpans other,
    required int index,
  }) {
    if (_markers.isNotEmpty && _markers.last.offset >= index) {
      throw Exception(
          'Another AttributedSpans can only be appended after the final marker in this AttributedSpans. Final marker: ${_markers.last}');
    }

    _log.fine('attributions before pushing them:');
    _log.fine(toString());

    // Push back all the `other` markers to make room for the
    // spans we're putting in front of them.

    final pushDistance = index;
    _log.fine('pushing `other` markers by: $pushDistance');
    _log.fine('`other` attributions before pushing them:');
    _log.fine(other.toString());
    final pushedSpans = other.copy()..pushAttributionsBack(pushDistance);

    // Combine `this` and `other` attributions into one list.
    final List<SpanMarker> combinedAttributions = List.from(_markers)..addAll(pushedSpans._markers);
    _log.fine('combined attributions before merge:');
    for (final marker in combinedAttributions) {
      _log.fine('   - $marker');
    }

    // Clean up the boundary between the two lists of attributions
    // by merging compatible attributions that meet at the boundary.
    _mergeBackToBackAttributions(combinedAttributions, index);

    _log.fine('combined attributions after merge:');
    for (final marker in combinedAttributions) {
      _log.fine('   - $marker');
    }

    _markers
      ..clear()
      ..addAll(combinedAttributions);
  }

  /// Given a list of [attributions], which includes two different lists of
  /// attributions concatenated together at [mergePoint], merges any
  /// attribution spans that exist back-to-back at the [mergePoint].
  void _mergeBackToBackAttributions(List<SpanMarker> attributions, int mergePoint) {
    _log.fine('merging attributions at $mergePoint');
    // Look for any compatible attributions at
    // `mergePoint - 1` and `mergePoint` and combine them.
    final endAtMergePointMarkers =
        attributions.where((marker) => marker.isEnd && marker.offset == mergePoint - 1).toList();
    final startAtMergePointMarkers =
        attributions.where((marker) => marker.isStart && marker.offset == mergePoint).toList();
    for (final startMarker in startAtMergePointMarkers) {
      _log.fine('marker on right side: $startMarker');
      final endMarker = endAtMergePointMarkers.firstWhereOrNull(
        (marker) => marker.attribution == startMarker.attribution,
      );
      _log.fine('matching marker on left side? $endMarker');
      if (endMarker != null) {
        // These two attributions should be combined into one.
        // To do this, delete these two markers from the original
        // attribution list.
        _log.fine('combining left/right spans at edge at index $mergePoint');
        _log.fine('Removing markers:');
        _log.fine(' - $startMarker');
        _log.fine(' - $endMarker');
        attributions
          ..remove(startMarker)
          ..remove(endMarker);
      }
    }
  }

  /// Returns of a copy of this [AttributedSpans] between [startOffset]
  /// and [endOffset].
  ///
  /// If no [endOffset] is provided, a copy is made from [startOffset]
  /// to the [offset] of the last marker in this [AttributedSpans].
  AttributedSpans copyAttributionRegion(int startOffset, [int? endOffset]) {
    endOffset = endOffset ?? _markers.lastOrNull?.offset ?? 0;
    _log.fine('start: $startOffset, end: $endOffset');

    final List<SpanMarker> cutAttributions = [];

    _log.fine('inspecting existing markers in full AttributedSpans');
    final Map<Attribution, int> foundStartMarkers = {};
    final Map<Attribution, int> foundEndMarkers = {};

    // Analyze all markers that appear before the start of
    // the copy range so that we can insert any appropriate
    // `start` markers at the beginning of the copy range.
    _markers //
        .where((marker) => marker.offset < startOffset) //
        .forEach((marker) {
      _log.fine('marker before the copy region: $marker');
      // Track any markers that begin before the `startOffset`
      // and continue beyond `startOffset`.
      if (marker.isStart) {
        _log.fine('remembering this marker to insert in copied region');
        foundStartMarkers.putIfAbsent(marker.attribution, () => 0);
        foundStartMarkers[marker.attribution] = foundStartMarkers[marker.attribution]! + 1;
      } else {
        _log.fine(
            'this marker counters an earlier one we found. We will not re-insert this marker in the copied region');
        foundStartMarkers.putIfAbsent(marker.attribution, () => 0);
        foundStartMarkers[marker.attribution] = foundStartMarkers[marker.attribution]! - 1;
      }
    });

    // Insert any `start` markers at the start of the copy region
    // so that we maintain attribution symmetry.
    foundStartMarkers.forEach((markerAttribution, count) {
      if (count == 1) {
        // Found an unmatched `start` marker. Replace it.
        _log.fine('inserting "$markerAttribution" marker at start of copy region to maintain symmetry.');
        cutAttributions.add(SpanMarker(
          attribution: markerAttribution,
          offset: 0,
          markerType: SpanMarkerType.start,
        ));
      } else if (count < 0 || count > 1) {
        throw Exception(
            'Found an unbalanced number of `start` and `end` markers before offset: $startOffset - $_markers');
      }
    });

    // Directly copy every marker that appears within the cut
    // region.
    _markers //
        .where((marker) => startOffset <= marker.offset && marker.offset <= endOffset!) //
        .forEach((marker) {
      _log.fine('copying "${marker.attribution}" at ${marker.offset} from original AttributionSpans to copy region.');
      cutAttributions.add(marker.copyWith(
        offset: marker.offset - startOffset,
      ));
    });

    // Analyze all markers that appear after the end of
    // the copy range so that we can insert any appropriate
    // `end` markers at the end of the copy range.
    _markers //
        .reversed //
        .where((marker) => marker.offset > endOffset!) //
        .forEach((marker) {
      _log.fine('marker after the copy region: $marker');
      // Track any markers that end after the `endOffset`
      // and start before `endOffset`.
      if (marker.isEnd) {
        _log.fine('remembering this marker to insert in copied region');
        foundEndMarkers.putIfAbsent(marker.attribution, () => 0);
        foundEndMarkers[marker.attribution] = foundEndMarkers[marker.attribution]! + 1;
      } else {
        _log.fine(
            'this marker counters an earlier one we found. We will not re-insert this marker in the copied region');
        foundEndMarkers.putIfAbsent(marker.attribution, () => 0);
        foundEndMarkers[marker.attribution] = foundEndMarkers[marker.attribution]! - 1;
      }
    });

    // Insert any `end` markers at the end of the copy region
    // so that we maintain attribution symmetry.
    foundEndMarkers.forEach((markerAttribution, count) {
      if (count == 1) {
        // Found an unmatched `end` marker. Replace it.
        _log.fine('inserting "$markerAttribution" marker at end of copy region to maintain symmetry.');
        cutAttributions.add(SpanMarker(
          attribution: markerAttribution,
          offset: endOffset! - startOffset,
          markerType: SpanMarkerType.end,
        ));
      } else if (count < 0 || count > 1) {
        throw Exception('Found an unbalanced number of `start` and `end` markers after offset: $endOffset - $_markers');
      }
    });

    _log.fine('copied attributions:');
    for (final attribution in cutAttributions) {
      _log.fine('   - $attribution');
    }

    return AttributedSpans(attributions: cutAttributions);
  }

  /// Changes all spans in this [AttributedSpans] by pushing
  /// them back by [offset] amount.
  void pushAttributionsBack(int offset) {
    final pushedAttributions = _markers.map((marker) => marker.copyWith(offset: marker.offset + offset)).toList();
    _markers
      ..clear()
      ..addAll(pushedAttributions);
  }

  /// Changes spans in this [AttributedSpans] by cutting out the
  /// region from [startOffset] to [startOffset + count], exclusive.
  void contractAttributions({
    required int startOffset,
    required int count,
  }) {
    final contractedAttributions = <SpanMarker>[];

    // Add all the markers that are unchanged.
    contractedAttributions.addAll(_markers.where((marker) => marker.offset < startOffset));

    _log.fine('removing $count characters starting at $startOffset');
    final needToEndAttributions = <dynamic>{};
    final needToStartAttributions = <dynamic>{};
    _markers
        .where((marker) => (startOffset <= marker.offset) && (marker.offset < startOffset + count))
        .forEach((marker) {
      // Get rid of this marker and keep track of
      // any open-ended attributions that need to
      // be closed.
      _log.fine('removing ${marker.markerType} at ${marker.offset}');
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
    for (final attribution in needToStartAttributions) {
      final offset = startOffset;
      _log.fine('adding back a start marker at $offset');
      contractedAttributions.add(SpanMarker(
        attribution: attribution,
        offset: offset,
        markerType: SpanMarkerType.start,
      ));
    }
    for (final attribution in needToEndAttributions) {
      final offset = startOffset > 0 ? startOffset - 1 : 0;
      _log.fine('adding back an end marker at $offset');
      contractedAttributions.add(SpanMarker(
        attribution: attribution,
        offset: offset,
        markerType: SpanMarkerType.end,
      ));
    }

    // Add all remaining markers but with an `offset`
    // that is less by `count`.
    contractedAttributions.addAll(
      _markers
          .where((marker) => marker.offset >= startOffset + count)
          .map((marker) => marker.copyWith(offset: marker.offset - count)),
    );

    _markers
      ..clear()
      ..addAll(contractedAttributions);
  }

  /// Returns a copy of this [AttributedSpans].
  AttributedSpans copy() {
    return AttributedSpans(
      attributions: List.from(_markers),
    );
  }

  /// Combines all spans of different types into a single
  /// list of spans that contain multiple types per segment.
  ///
  /// The returned spans are ordered from beginning to end.
  List<MultiAttributionSpan> collapseSpans({
    required int contentLength,
  }) {
    _log.fine('content length: $contentLength');
    _log.fine('attributions used to compute spans:');
    for (final marker in _markers) {
      _log.fine('   - $marker');
    }

    if (contentLength == 0) {
      // There is no content and therefore no attributions.
      _log.fine('content is empty. Returning empty span list.');
      return [];
    }

    if (_markers.isEmpty || _markers.first.offset > contentLength - 1) {
      // There is content but no attributions that apply to it.
      return [MultiAttributionSpan(attributions: {}, start: 0, end: contentLength - 1)];
    }

    final collapsedSpans = <MultiAttributionSpan>[];
    var currentSpan = MultiAttributionSpan(attributions: {}, start: 0, end: contentLength - 1);

    _log.fine('walking list of markers to determine collapsed spans.');
    for (final marker in _markers) {
      if (marker.offset > contentLength - 1) {
        // There are markers to process but we ran off the end of the requested content. Break early and handle
        // committing the last span if necessary below.
        _log.fine('ran out of markers within the requested contentLength, breaking early.');
        break;
      }

      if ((marker.isStart && marker.offset > currentSpan.start) ||
          (marker.isEnd && marker.offset >= currentSpan.start)) {
        // We reached the boundary between the current span and the next.  Finalize the current span, commit it, and
        // prepare the next one.
        _log.fine(
            'encountered a span boundary with ${marker.isStart ? "a start" : "an end"} marker at offset ${marker.offset}.');

        // Calculate the end of the current span.
        //
        // If the current marker is an end marker, then the current span at that marker. Otherwise, if the
        // marker is an start marker, the current span ends 1 unit before the marker.
        final currentEnd = marker.isEnd ? marker.offset : marker.offset - 1;

        // Commit the completed span.
        collapsedSpans.add(currentSpan.copyWith(end: currentEnd));
        _log.fine('committed span ${collapsedSpans.last}');

        // Calculate the start of the next span.
        //
        // If the current marker is a start marker, then the next span begins at that marker. Otherwise, if the
        // marker is an end marker, the next span begins 1 unit after the marker.
        final nextStart = marker.isStart ? marker.offset : marker.offset + 1;

        // Create the next span and continue consumeing markers
        currentSpan = currentSpan.copyWith(start: nextStart);
        _log.fine('new current span is $currentSpan');
      }

      // By the time we get here, we are guaranteed that the current marker should modify the current span. Apply
      // changes based on the type of the marker.
      if (marker.isStart) {
        // Add the new attribution to the current span.
        currentSpan.attributions.add(marker.attribution);
        _log.fine('merging ${marker.attribution}, current span is now $currentSpan.');
      } else if (marker.isEnd) {
        // Remove the ending attribution from the current span.
        currentSpan.attributions.remove(marker.attribution);
        _log.fine('removing attribution ${marker.attribution}, current span is now $currentSpan.');
      }
    }

    if (collapsedSpans.isNotEmpty && collapsedSpans.last.end < contentLength - 1) {
      // The last span committed during the loop does not reach the end of the requested content range. We either ran
      // out of markers or the remaining markers are outside the content range. In both cases the value in currentSpan
      // should already have the correct start, end, and attributions values to cover the remaining content.
      collapsedSpans.add(currentSpan);
      _log.fine('committing last span to cover requested content length of $contentLength: ${collapsedSpans.last}');
    }

    _log.fine('returning collapsed spans: $collapsedSpans');
    return collapsedSpans;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttributedSpans &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality.unordered().equals(_markers, other._markers);

  @override
  int get hashCode => _markers.hashCode;

  @override
  String toString() {
    final buffer = StringBuffer('[AttributedSpans] (${(_markers.length / 2).round()} spans):');
    for (final marker in _markers) {
      buffer.write('\n - $marker');
    }
    return buffer.toString();
  }
}

/// Marks the start or end of an attribution span.
///
/// The given [AttributionType] must implement equality for
/// span management to work correctly.
class SpanMarker implements Comparable<SpanMarker> {
  /// Constructs a [SpanMarker] with the given [attribution], [offset] within
  /// some discrete content, and [markerType] of [start] or [end].
  const SpanMarker({
    required this.attribution,
    required this.offset,
    required this.markerType,
  });

  /// The attribution that exists between this [SpanMarker] and its
  /// other endpoint.
  final Attribution attribution;

  /// The position of this [SpanMarker] within some discrete content.
  final int offset;

  /// The type of [SpanMarker], either [start] or [end].
  final SpanMarkerType markerType;

  /// Returns true if this marker is a [SpanMarkerType.start] marker.
  bool get isStart => markerType == SpanMarkerType.start;

  /// Returns true if this marker is a [SpanMarkerType.end] marker.
  bool get isEnd => markerType == SpanMarkerType.end;

  /// Returns a copy of this [SpanMarker] with optional new values
  /// for [attribution], [offset], and [markerType].
  SpanMarker copyWith({
    Attribution? attribution,
    int? offset,
    SpanMarkerType? markerType,
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
    final offsetDiff = offset - other.offset;
    if (offsetDiff != 0) {
      return offsetDiff;
    }
    if (markerType != other.markerType) {
      // Enforce that start markers come before end, even within the same index. This makes it much easier to process
      // the spans linearly, such as in [collapseSpans].
      return isStart ? -1 : 1;
    }
    return 0;
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

/// The type of a marker within a span, either [start] or [end].
enum SpanMarkerType {
  start,
  end,
}

/// An [Attribution] span from [start] to [end], inclusive.
class AttributionSpan {
  const AttributionSpan({
    required this.attribution,
    required this.start,
    required this.end,
  });

  final Attribution attribution;
  final int start;
  final int end;

  /// Returns a [SpanRange] from [start] to [end].
  SpanRange get range => SpanRange(start, end);

  /// Create a returns a copy of this [AttributionSpan], which is constrained
  /// by the given [start] and [end], i.e., the returned value's `start` is
  /// >= [start], and its `end` is <= [end].
  AttributionSpan constrain({
    required int start,
    required int end,
  }) {
    return copyWith(
      start: max(this.start, start),
      end: min(this.end, end),
    );
  }

  AttributionSpan copyWith({
    Attribution? attribution,
    int? start,
    int? end,
  }) {
    return AttributionSpan(
      attribution: attribution ?? this.attribution,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  String toString() {
    return '[AttributionSpan] - $attribution, $start -> $end';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttributionSpan &&
          runtimeType == other.runtimeType &&
          attribution == other.attribution &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => attribution.hashCode ^ start.hashCode ^ end.hashCode;
}

/// A span that contains zero or more attributions.
///
/// An [AttributedSpans] can be collapsed to a single list
/// of [MultiAttributionSpan]s with [AttributedSpans.collapseSpans].
class MultiAttributionSpan {
  const MultiAttributionSpan({
    required this.attributions,
    required this.start,
    required this.end,
  });

  final Set<Attribution> attributions;
  final int start;
  final int end;

  MultiAttributionSpan copyWith({
    Set<Attribution>? attributions,
    int? start,
    int? end,
  }) =>
      MultiAttributionSpan(
        attributions: attributions ?? {...this.attributions},
        start: start ?? this.start,
        end: end ?? this.end,
      );

  @override
  String toString() => '[MultiAttributionSpan] - attributions: $attributions, start: $start, end: $end';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiAttributionSpan &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          const DeepCollectionEquality().equals(attributions, other.attributions);

  @override
  int get hashCode => attributions.hashCode ^ start.hashCode ^ end.hashCode;
}

/// Returns `true` when the given [candidate] [Attribution] matches the desired condition.
typedef AttributionFilter = bool Function(Attribution candidate);

class IncompatibleOverlappingAttributionsException implements Exception {
  IncompatibleOverlappingAttributionsException({
    required this.existingAttribution,
    required this.newAttribution,
    required this.conflictStart,
  });

  final Attribution existingAttribution;
  final Attribution newAttribution;
  final int conflictStart;

  @override
  String toString() {
    return 'Tried to insert attribution ($newAttribution) over a conflicting existing attribution ($existingAttribution). The overlap began at index $conflictStart';
  }
}

/// A conflict between the [newAttribution] and [existingAttribution] between [conflictStart] and [conflictEnd] (inclusive).
///
/// This means [newAttribution] and [existingAttribution] have the same id, but they can't be merged.
class _AttributionConflict {
  _AttributionConflict({
    required this.newAttribution,
    required this.existingAttribution,
    required this.conflictStart,
    required this.conflictEnd,
  });

  /// The new attribution that conflicts with the existing attribution.
  final Attribution newAttribution;

  /// The conflicting attribution.
  final Attribution existingAttribution;

  /// The first conflicting index.
  final int conflictStart;

  /// The last conflicting index (inclusive).
  final int conflictEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AttributionConflict &&
          runtimeType == other.runtimeType &&
          newAttribution == other.newAttribution &&
          existingAttribution == other.existingAttribution &&
          conflictStart == other.conflictStart &&
          conflictEnd == other.conflictEnd;

  @override
  int get hashCode =>
      newAttribution.hashCode ^ existingAttribution.hashCode ^ conflictStart.hashCode ^ conflictEnd.hashCode;

  @override
  String toString() =>
      '[AttributionConflict] - newAttribution: $newAttribution existingAttribution: $existingAttribution, conflictStart: $conflictStart, conflictEnd: $conflictEnd';
}
