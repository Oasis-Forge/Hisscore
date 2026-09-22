import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's own pixel face into the test binding.
///
/// A golden that contains text is only worth having if the text is the
/// text a player would see. Without this the engine falls back to the
/// test font, which draws every glyph as an identical box — so `50` and
/// `150` differ only in how many boxes there are, and the face the whole
/// look of the game rests on is not in the picture at all.
///
/// Read from disk rather than through `rootBundle`, which in a test
/// serves the asset manifest of the test binary, not the app's.
Future<void> loadPixelFont() async {
  final bytes = await File(
    'assets/fonts/PressStart2P-Regular.ttf',
  ).readAsBytes();
  final loader = FontLoader('PressStart2P')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
