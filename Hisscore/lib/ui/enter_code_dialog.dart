import 'package:flutter/material.dart';

import '../game/challenge_code.dart';
import 'theme.dart';

/// Asks for a friend's challenge code. Pops with the parsed
/// [ChallengeCode], or null if cancelled.
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
    final parsed = ChallengeCode.parse(_controller.text);
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
