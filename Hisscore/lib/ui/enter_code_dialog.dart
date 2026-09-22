import 'package:flutter/material.dart';

import '../game/challenge_code.dart';
import '../game/challenge_link.dart';
import 'theme.dart';

/// Asks for a friend's challenge code. Pops with the parsed
/// [ChallengeCode], or null if cancelled.
///
/// Takes a link as readily as a code, and a whole forwarded message as
/// readily as either — see [ChallengeLink.parse]. What arrives in a
/// player's clipboard is whatever their friend sent them, and asking
/// them to pick eight characters out of it is asking them to do the
/// computer's job.
///
/// The text controller lives in this dialog's own [State], so it is
/// disposed only once the dialog is really gone. Disposing it from the
/// caller right after the route pops leaves the text field still on
/// screen for the closing animation, using a dead controller.
class EnterCodeDialog extends StatefulWidget {
  const EnterCodeDialog({super.key});

  @override
  State<EnterCodeDialog> createState() => _EnterCodeDialogState();
}

class _EnterCodeDialogState extends State<EnterCodeDialog> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = ChallengeLink.read(_controller.text);
    if (parsed == null) {
      setState(() => _invalid = true);
    } else {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RetroColors.screen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: RetroColors.phosphorDim, width: 1.5),
      ),
      title: Text(
        'ENTER CODE',
        style: RetroText.pixel(size: 12, color: RetroColors.amber),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        style: RetroText.pixel(size: 14, color: RetroColors.phosphor),
        decoration: InputDecoration(
          hintText: 'XXXX-XXXX',
          hintStyle: RetroText.pixel(size: 14, color: RetroColors.phosphorDim),
          helperText: 'CODE OR LINK',
          helperStyle: RetroText.pixel(size: 8, color: RetroColors.phosphorDim),
          errorText: _invalid ? 'INVALID CODE' : null,
          errorStyle: RetroText.pixel(size: 8, color: RetroColors.food),
        ),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'CANCEL',
            style: RetroText.pixel(size: 9, color: RetroColors.phosphorDim),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            'START',
            style: RetroText.pixel(size: 9, color: RetroColors.amber),
          ),
        ),
      ],
    );
  }
}

/// Asked when a challenge link arrives while a run is still going.
///
/// A link is somebody else's idea of when to play. Acting on it without
/// asking would throw away a run in progress — the player tapped a
/// message, not a restart button — so the run in progress wins unless
/// they say otherwise. Pops true to play the challenge.
class ChallengeArrivedDialog extends StatelessWidget {
  const ChallengeArrivedDialog({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final code = challenge.code;
    final rival = challenge.rival;
    // Who sent it and what they scored, when the link said. That is the
    // difference between "a board" and "a race", and it is the thing
    // most likely to decide the answer.
    final from = rival == null
        ? ''
        : '\n${rival.name.isEmpty ? 'THEY' : rival.name} SCORED ${rival.score}';
    return AlertDialog(
      backgroundColor: RetroColors.screen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: RetroColors.phosphorDim, width: 1.5),
      ),
      title: Text(
        'CHALLENGE',
        style: RetroText.pixel(size: 12, color: RetroColors.amber),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code.text,
            style: RetroText.pixel(size: 14, color: RetroColors.phosphor),
          ),
          const SizedBox(height: 10),
          Text(
            '${code.mode.label}$from\nTHIS ENDS YOUR RUN',
            style: RetroText.pixel(size: 8, color: RetroColors.phosphorDim),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'NOT NOW',
            style: RetroText.pixel(size: 9, color: RetroColors.phosphorDim),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'PLAY IT',
            style: RetroText.pixel(size: 9, color: RetroColors.amber),
          ),
        ),
      ],
    );
  }
}
