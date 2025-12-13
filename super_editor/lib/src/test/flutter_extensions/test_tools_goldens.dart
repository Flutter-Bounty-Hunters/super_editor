import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Runs one golden test for every platform, e.g., Android, iOS, Web, Mac, Windows, Linux.
///
/// It's the job of the test implementation to include the platform name in the golden
/// file name - if this is not done, all tests will overwrite the same golden file(s).
@isTest
void testGoldensOnAllPlatforms(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  Size? windowSize,
}) {
  testGoldensOnAndroid(description, test, windowSize: windowSize, skip: skip);
  testGoldensOniOS(description, test, windowSize: windowSize, skip: skip);
  testGoldensOnMac(description, test, windowSize: windowSize, skip: skip);
  testGoldensOnWindows(description, test, windowSize: windowSize, skip: skip);
  testGoldensOnLinux(description, test, windowSize: windowSize, skip: skip);
}

/// Runs one golden test for Android and iOS.
///
/// It's the job of the test implementation to include the platform name in the golden
/// file name - if this is not done, all tests will overwrite the same golden file(s).
@isTest
void testGoldensOnMobile(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  Size? windowSize,
}) {
  testGoldensOnAndroid(description, test, windowSize: windowSize, skip: skip);
  testGoldensOniOS(description, test, windowSize: windowSize, skip: skip);
}

/// A golden test that configures itself as a Android platform before executing the
/// given [test], and nullifies the Android configuration when the test is done.
@isTest
void testGoldensOnAndroid(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  Size? windowSize,
}) {
  testGoldens('$description (on Android)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    // Adjust the size of the golden window/image as desired.
    tester.viewSize = windowSize;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a iOS platform before executing the
/// given [test], and nullifies the iOS configuration when the test is done.
@isTest
void testGoldensOniOS(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  Size? windowSize,
}) {
  testGoldens('$description (on iOS)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    // Adjust the size of the golden window/image as desired.
    tester.viewSize = windowSize;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a Mac platform before executing the
/// given [test], and nullifies the Mac configuration when the test is done.
@isTest
void testGoldensOnMac(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  Size? windowSize,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    // Adjust the size of the golden window/image as desired.
    tester.viewSize = windowSize;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a Windows platform before executing the
/// given [test], and nullifies the Windows configuration when the test is done.
@isTest
void testGoldensOnWindows(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  Size? windowSize,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    // Adjust the size of the golden window/image as desired.
    tester.viewSize = windowSize;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a Linux platform before executing the
/// given [test], and nullifies the Linux configuration when the test is done.
@isTest
void testGoldensOnLinux(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  Size? windowSize,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    // Adjust the size of the golden window/image as desired.
    tester.viewSize = windowSize;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

extension TesterWindowSize on WidgetTester {
  set viewSize(Size? desiredSize) {
    if (desiredSize == null) {
      return;
    }

    view.physicalSize = desiredSize;
    addTearDown(() => view.resetPhysicalSize());
  }
}

const goldenSizeXLarge = Size(2400, 1600);
const goldenSizeLarge = Size(1200, 800);
const goldenSizeLongStrip = Size(1000, 300);
const goldenSizeMedium = Size(800, 600);
const goldenSizeSmall = Size(600, 400);

/// A matcher that expects given content to match the golden file referenced
/// by [key], allowing up to [maxPixelMismatchCount] different pixels before
/// considering the test to be a failure.
///
/// Typically, the [key] is expected to be a relative file path from the given
/// test file, to the golden file, e.g., "goldens/my-golden-name.png".
///
/// This matcher can be used by calling it in `expectLater()`, e.g.,
///
///     await expectLater(
///       find.byType(MaterialApp),
///       matchesGoldenFileWithPixelAllowance("goldens/my-golden-name.png", 20),
///     );
///
/// Typically, Flutter's golden system describes mismatches in terms of percentages.
/// But percentages are difficult to depend upon. Sometimes a relatively large percentage
/// doesn't matter, and sometimes a tiny percentage is critical. When it comes to ignoring
/// irrelevant mismatches, it's often more convenient to work in terms of pixels. This
/// matcher lets developers specify a maximum pixel mismatch count, instead of relying on
/// percentage differences across the entire golden image.
MatchesGoldenFile matchesGoldenFileWithPixelAllowance(Object key, int maxPixelMismatchCount, {int? version}) {
  if (key is Uri) {
    return MatchesGoldenFileWithPixelAllowance(key, maxPixelMismatchCount, version);
  } else if (key is String) {
    return MatchesGoldenFileWithPixelAllowance.forStringPath(key, maxPixelMismatchCount, version);
  }
  throw ArgumentError('Unexpected type for golden file: ${key.runtimeType}');
}

/// A special version of [MatchesGoldenFile] that allows a specified number of
/// pixels to be different between golden files before considering the test to
/// be a failure.
///
/// Typically, this matcher is expected to be created by calling
/// [matchesGoldenFileWithPixelAllowance].
class MatchesGoldenFileWithPixelAllowance extends MatchesGoldenFile {
  /// Creates a [MatchesGoldenFileWithPixelAllowance] that looks for a golden
  /// file at the relative path within the [key] URI.
  ///
  /// The [key] URI should be a relative path from the executing test's
  /// directory to the golden file, e.g., "goldens/my-golden-name.png".
  MatchesGoldenFileWithPixelAllowance(super.key, this._maxPixelMismatchCount, [super.version]);

  /// Creates a [MatchesGoldenFileWithPixelAllowance] that looks for a golden
  /// file at the relative [path].
  ///
  /// The [path] should be relative to the executing test's directory, e.g.,
  /// "goldens/my-golden-name.png".
  MatchesGoldenFileWithPixelAllowance.forStringPath(String path, this._maxPixelMismatchCount, [int? version])
      : super.forStringPath(path, version);

  final int _maxPixelMismatchCount;

  @override
  Future<String?> matchAsync(dynamic item) async {
    // Cache the current goldenFileComparator so we can restore
    // it after the test.
    final originalComparator = goldenFileComparator;

    try {
      goldenFileComparator = PixelDiffGoldenComparator(
        (goldenFileComparator as LocalFileComparator).basedir.path,
        pixelCount: _maxPixelMismatchCount,
      );

      return await super.matchAsync(item);
    } finally {
      goldenFileComparator = originalComparator;
    }
  }
}

/// A golden file comparator that allows a specified number of pixels
/// to be different between the golden image file and the test image file, and
/// still pass.
class PixelDiffGoldenComparator extends LocalFileComparator {
  PixelDiffGoldenComparator(
    String testBaseDirectory, {
    required int pixelCount,
  })  : _testBaseDirectory = testBaseDirectory,
        _maxPixelMismatchCount = pixelCount,
        super(Uri.parse(testBaseDirectory));

  @override
  Uri get basedir => Uri.parse(_testBaseDirectory);

  /// The file system path to the directory that holds the currently executing
  /// Dart test file.
  final String _testBaseDirectory;

  /// The maximum number of mismatched pixels for which this pixel test
  /// is considered a success/pass.
  final int _maxPixelMismatchCount;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    // Note: the incoming `golden` Uri is a partial path from the currently
    // executing test directory to the golden file, e.g., "goldens/my-test.png".
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed) {
      return true;
    }

    final diffImage = result.diffs!.entries.first.value;
    final pixelCount = diffImage.width * diffImage.height;
    final pixelMismatchCount = pixelCount * result.diffPercent;

    if (pixelMismatchCount <= _maxPixelMismatchCount) {
      return true;
    }

    // Paint the golden diffs and images to failure files.
    await generateFailureOutput(result, golden, basedir);
    throw FlutterError(
        "Pixel test failed. ${result.diffPercent.toStringAsFixed(2)}% diff, $pixelMismatchCount pixel count diff (max allowed pixel mismatch count is $_maxPixelMismatchCount)");
  }

  @override
  @protected
  Future<List<int>> getGoldenBytes(Uri golden) async {
    final File goldenFile = _getGoldenFile(golden);
    if (!goldenFile.existsSync()) {
      fail('Could not be compared against non-existent file: "$golden"');
    }
    final List<int> goldenBytes = await goldenFile.readAsBytes();
    return goldenBytes;
  }

  File _getGoldenFile(Uri golden) => File(path.join(_testBaseDirectory, path.fromUri(golden.path)));
}
