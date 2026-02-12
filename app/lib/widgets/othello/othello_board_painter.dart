import 'package:flutter/material.dart';

class OthelloBoardPainter extends CustomPainter {
  final List<List<int>> board;
  final List<Map<String, int>> validMoves;
  final int? lastMoveRow;
  final int? lastMoveCol;

  OthelloBoardPainter({
    required this.board,
    required this.validMoves,
    this.lastMoveRow,
    this.lastMoveCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 8;

    final bgPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 8; i++) {
      final offset = i * cellSize;
      canvas.drawLine(
        Offset(0, offset),
        Offset(size.width, offset),
        linePaint,
      );
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset, size.height),
        linePaint,
      );
    }

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final cell = board[row][col];
        if (cell != 0) {
          final center = Offset(col * cellSize + cellSize / 2, row * cellSize + cellSize / 2);
          final radius = cellSize * 0.4;

          final shadowPaint = Paint()
            ..color = Colors.black.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(
            center + const Offset(2, 2),
            radius,
            shadowPaint,
          );

          final stonePaint = Paint()
            ..color = cell == 1 ? Colors.black : Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(center, radius, stonePaint);

          if (cell == 2) {
            final borderPaint = Paint()
              ..color = Colors.grey[400]!
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1;
            canvas.drawCircle(center, radius, borderPaint);
          }
        }
      }
    }

    for (var move in validMoves) {
      final row = move['row']!;
      final col = move['col']!;
      final center = Offset(col * cellSize + cellSize / 2, row * cellSize + cellSize / 2);
      final radius = cellSize * 0.15;

      final hintPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, hintPaint);
    }

    if (lastMoveRow != null && lastMoveCol != null) {
      final center = Offset(lastMoveCol! * cellSize + cellSize / 2, lastMoveRow! * cellSize + cellSize / 2);
      final radius = cellSize * 0.4;

      final lastMovePaint = Paint()
        ..color = Colors.red.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius + 2, lastMovePaint);
    }
  }

  @override
  bool shouldRepaint(OthelloBoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.validMoves != validMoves ||
        oldDelegate.lastMoveRow != lastMoveRow ||
        oldDelegate.lastMoveCol != lastMoveCol;
  }
}
