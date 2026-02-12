import 'package:flutter/material.dart';
import 'othello_board_painter.dart';

class OthelloBoardWidget extends StatelessWidget {
  final List<List<int>> board;
  final List<Map<String, int>> validMoves;
  final Function(int, int)? onTap;
  final int? lastMoveRow;
  final int? lastMoveCol;

  const OthelloBoardWidget({
    super.key,
    required this.board,
    required this.validMoves,
    this.onTap,
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

          final cellSize = size.width / 8;

          final col = (localPosition.dx / cellSize).floor().clamp(0, 7);
          final row = (localPosition.dy / cellSize).floor().clamp(0, 7);

          if (board[row][col] == 0) {
            onTap!(row, col);
          }
        },
        child: CustomPaint(
          painter: OthelloBoardPainter(
            board: board,
            validMoves: validMoves,
            lastMoveRow: lastMoveRow,
            lastMoveCol: lastMoveCol,
          ),
        ),
      ),
    );
  }
}
