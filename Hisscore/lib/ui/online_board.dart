import 'package:flutter/material.dart';

import '../game/online_scores.dart';
import 'theme.dart';

/// The top of one global board, loaded when shown. The player's own row is
/// highlighted.
class OnlineBoardView extends StatefulWidget {
  const OnlineBoardView({super.key, required this.scores, required this.board});

  final OnlineScoreBoard scores;
  final BoardId board;

  @override
  State<OnlineBoardView> createState() => _OnlineBoardViewState();
}

class _OnlineBoardViewState extends State<OnlineBoardView> {
  static const _rows = 10;

  late Future<List<BoardEntry>> _future = _load();

  Future<List<BoardEntry>> _load() =>
      widget.scores.top(widget.board, limit: _rows);

  @override
  void didUpdateWidget(OnlineBoardView old) {
    super.didUpdateWidget(old);
    if (old.board != widget.board || old.scores != widget.scores) {
      _future = _load();
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BoardEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _note('LOADING...');
        }
        if (snapshot.hasError) {
          return GestureDetector(
            onTap: _retry,
            child: _note('COULD NOT LOAD - TAP TO RETRY'),
          );
        }
        final entries = snapshot.data ?? const [];
        if (entries.isEmpty) return _note('NO SCORES YET');
        final me = widget.scores.playerId;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++)
              _Row(
                rank: i + 1,
                entry: entries[i],
                mine: entries[i].playerId == me,
              ),
          ],
        );
      },
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: RetroText.pixel(size: 8, color: RetroColors.metal),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.mine});

  final int rank;
  final BoardEntry entry;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = mine
        ? RetroColors.amber
        : (rank == 1 ? RetroColors.phosphorHot : RetroColors.phosphorDim);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank.',
              style: RetroText.pixel(size: 7, color: color),
            ),
          ),
          SizedBox(
            width: 116,
            child: Text(
              entry.name,
              overflow: TextOverflow.ellipsis,
              style: RetroText.pixel(size: 7, color: color),
            ),
          ),
          Text(
            entry.score.toString().padLeft(5, '0'),
            style: RetroText.pixel(size: 8, color: color),
          ),
        ],
      ),
    );
  }
}

/// Asks for the player's public handle. Pops with a cleaned, valid name, or
/// null if cancelled. Owns its own controller (see `EnterCodeDialog`).
class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key, required this.current});

  final String current;

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final _controller = TextEditingController(text: widget.current);
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = PlayerName.clean(_controller.text);
    if (!PlayerName.isValid(name)) {
      setState(() => _invalid = true);
    } else {
      Navigator.of(context).pop(name);
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
        'YOUR NAME',
        style: RetroText.pixel(size: 12, color: RetroColors.amber),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PlayerName.maxLength,
        textCapitalization: TextCapitalization.characters,
        style: RetroText.pixel(size: 14, color: RetroColors.phosphor),
        decoration: InputDecoration(
          counterStyle: RetroText.pixel(size: 7, color: RetroColors.metal),
          errorText: _invalid
              ? '${PlayerName.minLength}-${PlayerName.maxLength} LETTERS OR DIGITS'
              : null,
          errorStyle: RetroText.pixel(size: 7, color: RetroColors.food),
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
            'SAVE',
            style: RetroText.pixel(size: 9, color: RetroColors.amber),
          ),
        ),
      ],
    );
  }
}
