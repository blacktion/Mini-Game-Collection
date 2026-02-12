import 'package:flutter/material.dart';
import 'gobang_board_painter.dart';

class BoardWidget extends StatelessWidget {
  final List<List<int>> board;
  final Function(int, int)? onTap;
  final int? previewRow;
  final int? previewCol;
  final int? previewPlayer;
  final int? lastMoveRow;
  final int? lastMoveCol;

  const BoardWidget({
    super.key,
    required this.board,
    this.onTap,
    this.previewRow,
    this.previewCol,
    this.previewPlayer,
    this.lastMoveRow,
    this.lastMoveCol,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: GestureDetector(
        onTapDown: (details) {
          if (onTap == null) return;
          
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = details.localPosition;
          final size = box.size;
          
          final cellSize = size.width / 14;
          
          final col = (localPosition.dx / cellSize).round().clamp(0, 14);
          final row = (localPosition.dy / cellSize).round().clamp(0, 14);
          
          if (board[row][col] == 0) {
            onTap!(row, col);
          }
        },
        child: CustomPaint(
          painter: BoardPainter(
            board: board,
            previewRow: previewRow,
            previewCol: previewCol,
            previewPlayer: previewPlayer,
            lastMoveRow: lastMoveRow,
            lastMoveCol: lastMoveCol,
          ),
        ),
      ),
    );
  }
}
