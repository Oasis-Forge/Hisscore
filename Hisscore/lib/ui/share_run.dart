import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../game/challenge_code.dart';
import '../game/challenge_link.dart';
import '../game/daily_challenge.dart';
import '../game/high_score_store.dart';
import '../game/snake_engine.dart';
import 'share_card.dart';

/// Pushes a finished run out through the platform share sheet.
///
/// The image is the point and the text is the caption, but rendering the
/// card can fail (a canvas is not guaranteed on every platform), so a
/// failed render degrades to sharing the text alone rather than sharing
/// nothing. A failed share is swallowed for the same reason: the player
/// dismissing the sheet must not look like a crash.
Future<void> shareRun({
  required SnakeEngine engine,
  required bool isDailyRun,
  required int dailyDayNumber,
  required DailyState dailyState,
  ChallengeCode? challenge,
}) async {
  final text = _shareText(
    engine: engine,
    isDailyRun: isDailyRun,
    dailyDayNumber: dailyDayNumber,
    dailyState: dailyState,
    challenge: challenge,
  );
  final subtitle = _subtitle(
    engine: engine,
    isDailyRun: isDailyRun,
    dailyDayNumber: dailyDayNumber,
    dailyState: dailyState,
    challenge: challenge,
  );
  try {
    List<XFile>? files;
    try {
      final png = await renderShareCard(engine: engine, subtitle: subtitle);
      files = [XFile.fromData(png, mimeType: 'image/png')];
    } catch (e) {
      debugPrint('Share card failed, sharing text only: $e');
    }
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: files,
        fileNameOverrides: files == null ? null : ['hisscore.png'],
      ),
    );
  } catch (e) {
    debugPrint('Share failed: $e');
  }
}

String _shareText({
  required SnakeEngine engine,
  required bool isDailyRun,
  required int dailyDayNumber,
  required DailyState dailyState,
  ChallengeCode? challenge,
}) {
  if (isDailyRun) {
    return DailyChallenge.resultText(
      dayNumber: dailyDayNumber,
      score: engine.score,
      apples: engine.totalApplesEaten,
      bestCombo: engine.bestCombo,
      streak: dailyState.currentStreak,
      modifier: engine.modifier,
    );
  }
  if (challenge != null) {
    // The link, not just the code. A code has to be read, remembered
    // and typed into a dialog the reader has to find first; a link is
    // one tap. The code stays in the line above it for anyone whose
    // messaging app strips links, or who is reading this aloud.
    return 'HISCORE challenge ${challenge.text} — ${engine.mode.label}'
        ' — Score ${engine.score} 🐍\n'
        'Beat it: ${ChallengeLink.web(challenge)}';
  }
  final level = engine.mode == GameMode.adventure
      ? ' (Level ${engine.level})'
      : '';
  return 'HISSCORE — ${engine.mode.label} — Score ${engine.score}$level 🐍\n'
      'Can you beat it?';
}

/// The line under the score on the card itself.
String _subtitle({
  required SnakeEngine engine,
  required bool isDailyRun,
  required int dailyDayNumber,
  required DailyState dailyState,
  ChallengeCode? challenge,
}) {
  if (isDailyRun) {
    final rule = engine.modifier == null
        ? ''
        : '  ·  ${engine.modifier!.label}';
    return 'DAILY #$dailyDayNumber  ·  '
        'STREAK ${dailyState.currentStreak}$rule';
  }
  if (challenge != null) return '${engine.mode.label}  ·  ${challenge.text}';
  // A run that was brought back says so, next to the score it kept.
  return engine.revived
      ? '${engine.mode.label}  ·  REVIVED'
      : engine.mode.label;
}
