import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:matcher/matcher.dart';
import 'package:text_table/text_table.dart';

/// Creates a [Matcher] that compares an actual Quill [Delta] document
/// to the given [expectedDocument].
Matcher quillDocumentEquivalentTo(Delta expectedDocument) => EquivalentQuillDocumentMatcher(expectedDocument);

class EquivalentQuillDocumentMatcher extends Matcher {
  const EquivalentQuillDocumentMatcher(this._expectedDocument);

  final Delta _expectedDocument;

  @override
  Description describe(Description description) {
    return description.add("a Quill document that looks like:\n$_expectedDocument");
  }

  @override
  bool matches(covariant Object item, Map<dynamic, dynamic> matchState) {
    return _calculateMismatchReason(item, matchState) == null;
  }

  @override
  Description describeMismatch(
    covariant Object item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final mismatchReason = _calculateMismatchReason(item, matchState);
    if (mismatchReason != null) {
      mismatchDescription.add(mismatchReason);
    }
    return mismatchDescription;
  }

  String? _calculateMismatchReason(
    Object target,
    Map<dynamic, dynamic> matchState,
  ) {
    if (target is! Delta) {
      return "the given document isn't a Delta document: $target";
    }
    final actualDocument = target;

    final messages = <String>[];
    bool nodeCountMismatch = false;
    bool nodeTypeOrContentMismatch = false;

    if (_expectedDocument.operations.length != actualDocument.operations.length) {
      messages.add(
          "expected ${_expectedDocument.operations.length} document operations but found ${actualDocument.operations.length}");
      nodeCountMismatch = true;
    } else {
      messages.add("documents have the same number of operations");
    }

    final maxOpCount = max(_expectedDocument.operations.length, actualDocument.operations.length);
    final opComparisons = List.generate(maxOpCount, (index) => ["", "", " "]);
    for (int i = 0; i < maxOpCount; i += 1) {
      if (i < _expectedDocument.operations.length && i < actualDocument.operations.length) {
        opComparisons[i][0] = _expectedDocument.operations[i].describe();
        opComparisons[i][1] = actualDocument.operations[i].describe();

        if (_expectedDocument.operations[i].runtimeType != actualDocument.operations[i].runtimeType) {
          opComparisons[i][2] = "Wrong Type";
          nodeTypeOrContentMismatch = true;
        } else if (_expectedDocument.operations[i] != actualDocument.operations[i]) {
          if (_expectedDocument.operations[i].value != actualDocument.operations[i].value) {
            opComparisons[i][2] = "Different value";
          } else {
            opComparisons[i][2] =
                "Different attributes - Expected: ${_expectedDocument.operations[i].attributes}, Actual: ${actualDocument.operations[i].value}";
          }
          nodeTypeOrContentMismatch = true;
        } else if (!const DeepCollectionEquality()
            .equals(_expectedDocument.operations[i].attributes, actualDocument.operations[i].attributes)) {
          opComparisons[i][2] = "Different attributes";
          nodeTypeOrContentMismatch = true;
        }
      } else if (i < _expectedDocument.operations.length) {
        opComparisons[i][0] = _expectedDocument.operations[i].describe();
        opComparisons[i][1] = "NA";
        opComparisons[i][2] = "Missing Node";
      } else if (i < actualDocument.operations.length) {
        opComparisons[i][0] = "NA";
        opComparisons[i][1] = actualDocument.operations[i].describe();
        opComparisons[i][2] = "Missing Node";
      }
    }

    if (nodeCountMismatch || nodeTypeOrContentMismatch) {
      String messagesList = messages.join(", ");
      messagesList += "\n";
      messagesList += const TableRenderer().render(opComparisons, columns: ["Expected", "Actual", "Difference"]);
      return messagesList;
    }

    return null;
  }
}

extension on Operation {
  String describe() {
    final writtenValue =
        "${value.toString().replaceAll("\n", "⏎")}, Atts: ${attributes?.entries.map((entry) => "${entry.key}: ${entry.value}").join(", ") ?? "None"}";
    if (isInsert) {
      return "Insert: $writtenValue";
    } else if (isRetain) {
      return "Retain: $writtenValue";
    } else if (isDelete) {
      return "Delete: $writtenValue";
    }

    throw Exception("Unknown operation type: $this");
  }
}
