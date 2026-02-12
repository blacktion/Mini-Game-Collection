import 'package:flutter/material.dart';
import 'go_board_painter.dart';

class GoBoard extends StatelessWidget {
  final List<List<int>> board;
  final Function(int, int)? onTap;
  final int? previewRow;
  final int? previewCol;
  final int? previewPlayer;
  final int? lastMoveRow;
  final int? lastMoveCol;
  final int boardSize;

  const GoBoard({
    super.key,
    required this.board,
    this.onTap,
    this.previewRow,
    this.previewCol,
    this.previewPlayer,
    this.lastMoveRow,
    this.lastMoveCol,
    this.boardSize = 19,
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
          
          final padding = size.width / (boardSize - 1) / 2;
          final cellSize = size.width / (boardSize - 1);
          
          final col = ((localPosition.dx - padding) / cellSize).round().clamp(0, boardSize - 1);
          final row = ((localPosition.dy - padding) / cellSize).round().clamp(0, boardSize - 1);
          
          if (board[row][col] == 0) {
            onTap!(row, col);
          }
        },
        child: CustomPaint(
          painter: GoBoardPainter(
            board: board,
            previewRow: previewRow,
            previewCol: previewCol,
            previewPlayer: previewPlayer,
            lastMoveRow: lastMoveRow,
            lastMoveCol: lastMoveCol,
            boardSize: boardSize,
          ),
        ),
      ),
    );
  }
}
