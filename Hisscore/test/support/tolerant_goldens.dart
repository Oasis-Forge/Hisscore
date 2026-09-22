import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Marks the box a golden is captured from.
///
/// `find.byType(RepaintBoundary).first` finds the framework's own
/// boundary around the whole 800x600 test view, so every golden came
/// out that size however big the widget under it said it was — which
/// left a 34px timer ring as 0.2% of the image, comfortably inside the
/// comparator's tolerance and therefore unguarded. Capturing a boundary
/// of our own, under a [Center] so it can take its own size, makes the
/// size in the test the size in the file.
const goldenBoundary = ValueKey<String>('golden-boundary');

/// Goldens are rendered on a developer's machine and checked on CI's, so
/// allow a hair of anti-aliasing drift between platforms while still
/// catching a malformed shape (three painter bugs have been caught by
/// eye: the lightning bolt, the star, and the ghost drawn a cell ahead
/// of the snake it was racing).
class TolerantComparator extends LocalFileComparator {
  TolerantComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

/// Installs [TolerantComparator] for the calling test file. Call from a
/// `setUp`, passing the file's own name — the comparator resolves
/// golden paths relative to it.
void useTolerantGoldens(String testFileName, {double tolerance = 0.005}) {
  final base = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = TolerantComparator(
    Uri.parse('${base.basedir}$testFileName'),
    tolerance: tolerance,
  );
}
