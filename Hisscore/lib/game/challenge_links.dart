import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'challenge_link.dart';

/// Where challenge links come in from.
///
/// The same interface/implementation seam as [CrashReporter] and
/// [HighScoreStore]: a real one that talks to the platform, and a quiet
/// one for tests and for anywhere that has no such thing.
abstract class ChallengeLinks {
  /// The link the app was opened with, if it was opened with one.
  /// Answered once — a second call gets null, because the challenge has
  /// already been started by then.
  Future<Challenge?> initial();

  /// Links that arrive while the app is already running.
  Stream<Challenge> get incoming;

  void dispose();
}

/// Never delivers anything. The default, so a test or a platform
/// without links behaves as if none ever arrive rather than throwing.
class NoChallengeLinks implements ChallengeLinks {
  const NoChallengeLinks();

  @override
  Future<Challenge?> initial() async => null;

  @override
  Stream<Challenge> get incoming => const Stream.empty();

  @override
  void dispose() {}
}

/// Reads links off the Android side.
///
/// Flutter's own deep linking is not used: switching it on turns an
/// incoming link into a *route*, and this app has no router — one
/// `MaterialApp(home:)` and no named routes — so the framework would be
/// asked to navigate somewhere that does not exist. A channel that
/// hands over a string leaves the question of what to do about it where
/// it belongs, which is in the game.
class PlatformChallengeLinks implements ChallengeLinks {
  PlatformChallengeLinks({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'com.oasisforge.hisscore/links';

  final MethodChannel _channel;
  final _controller = StreamController<Challenge>.broadcast();

  @override
  Stream<Challenge> get incoming => _controller.stream;

  @override
  Future<Challenge?> initial() async {
    try {
      final link = await _channel.invokeMethod<String>('initialLink');
      return link == null ? null : ChallengeLink.read(link);
    } catch (e) {
      // A missing channel is the normal case off Android, and a link
      // that never arrives is not worth a crash on any platform.
      debugPrint('Initial link unavailable: $e');
      return null;
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'link') return;
    final read = ChallengeLink.read(call.arguments as String? ?? '');
    // A link that is not a challenge is dropped rather than surfaced:
    // the player tapped something, and being told it was the wrong
    // something helps nobody.
    if (read != null && !_controller.isClosed) _controller.add(read);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _controller.close();
  }
}
