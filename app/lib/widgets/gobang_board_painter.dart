import 'package:flutter/material.dart';

class BoardPainter extends CustomPainter {
  final List<List<int>> board;
  final int? previewRow;
  final int? previewCol;
  final int? previewPlayer;
  final int? lastMoveRow;
  final int? lastMoveCol;

  BoardPainter({
    required this.board,
    this.previewRow,
    this.previewCol,
    this.previewPlayer,
    this.lastMoveRow,
    this.lastMoveCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 14;
    final padding = cellSize / 2;
    
    final bgPaint = Paint()
      ..color = Colors.brown[200]!
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    final linePaint = Paint()
      ..color = Colors.brown[800]!
      ..strokeWidth = 1.5;
    
    for (int i = 0; i < 15; i++) {
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
    
    final dotPaint = Paint()
      ..color = Colors.brown[900]!
      ..style = PaintingStyle.fill;
    
    final dots = [
      [3, 3], [3, 11], [11, 3], [11, 11],
      [7, 7],
    ];
    
    for (var dot in dots) {
      canvas.drawCircle(
        Offset(dot[1] * cellSize, dot[0] * cellSize),
        4,
        dotPaint,
      );
    }
    
    if (previewRow != null && previewCol != null) {
      final highlightPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(previewCol! * cellSize, previewRow! * cellSize),
        cellSize * 0.4,
        highlightPaint,
      );
    }
    
    for (int row = 0; row < 15; row++) {
      for (int col = 0; col < 15; col++) {
        final cell = board[row][col];
        if (cell != 0) {
          final center = Offset(col * cellSize, row * cellSize);
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

    // 绘制最后一步棋的标记
    if (lastMoveRow != null && lastMoveCol != null && board[lastMoveRow!][lastMoveCol!] != 0) {
      final center = Offset(lastMoveCol! * cellSize, lastMoveRow! * cellSize);
      final radius = cellSize * 0.4;
      
      final lastMovePaint = Paint()
        ..color = Colors.yellow.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius + 2, lastMovePaint);
    }

    if (previewRow != null && previewCol != null && board[previewRow!][previewCol!] == 0) {
      final center = Offset(previewCol! * cellSize, previewRow! * cellSize);
      final radius = cellSize * 0.4;
      
      final previewPaint = Paint()
        ..color = (previewPlayer == 1 ? Colors.black : Colors.white).withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, previewPaint);
      
      final previewBorderPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius + 2, previewBorderPaint);
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.previewRow != previewRow ||
        oldDelegate.previewCol != previewCol ||
        oldDelegate.previewPlayer != previewPlayer ||
        oldDelegate.lastMoveRow != lastMoveRow ||
        oldDelegate.lastMoveCol != lastMoveCol;
  }
}
