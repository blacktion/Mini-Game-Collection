import 'package:flutter/material.dart';

class GoBoardPainter extends CustomPainter {
  final List<List<int>> board;  // 0:空 1:黑 2:白
  final int? previewRow;
  final int? previewCol;
  final int? previewPlayer;
  final int? lastMoveRow;
  final int? lastMoveCol;
  final int boardSize;  // 棋盘大小，默认19

  GoBoardPainter({
    required this.board,
    this.previewRow,
    this.previewCol,
    this.previewPlayer,
    this.lastMoveRow,
    this.lastMoveCol,
    this.boardSize = 19,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / (boardSize - 1);
    final padding = cellSize / 2;
    
    // 绘制背景
    final bgPaint = Paint()
      ..color = const Color(0xFFDCB35C)  // 木纹色
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // 绘制网格线
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.8;
    
    for (int i = 0; i < boardSize; i++) {
      final offset = i * cellSize;
      // 横线
      canvas.drawLine(
        Offset(padding, offset + padding),
        Offset(size.width - padding, offset + padding),
        linePaint,
      );
      // 竖线
      canvas.drawLine(
        Offset(offset + padding, padding),
        Offset(offset + padding, size.height - padding),
        linePaint,
      );
    }
    
    // 绘制星位（天元等）
    final starPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // 19路棋盘的星位
    final stars = [
      [3, 3], [3, 9], [3, 15],
      [9, 3], [9, 9], [9, 15],
      [15, 3], [15, 9], [15, 15],
    ];
    
    if (boardSize == 19) {
      for (var star in stars) {
        canvas.drawCircle(
          Offset(star[1] * cellSize + padding, star[0] * cellSize + padding),
          3,
          starPaint,
        );
      }
    }
    
    // 绘制棋子
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        final cell = board[row][col];
        if (cell != 0) {
          final center = Offset(col * cellSize + padding, row * cellSize + padding);
          final radius = cellSize * 0.45;
          
          // 阴影
          final shadowPaint = Paint()
            ..color = Colors.black.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(
            center + const Offset(2, 2),
            radius,
            shadowPaint,
          );
          
          // 棋子
          final stonePaint = Paint()
            ..color = cell == 1 ? Colors.black : Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(center, radius, stonePaint);
          
          // 白棋加边框
          if (cell == 2) {
            final borderPaint = Paint()
              ..color = Colors.grey[400]!
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5;
            canvas.drawCircle(center, radius, borderPaint);
          }
          
          // 棋子光泽
          final shinePaint = Paint()
            ..color = Colors.white.withOpacity(0.15)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            center - Offset(radius * 0.2, radius * 0.2),
            radius * 0.3,
            shinePaint,
          );
        }
      }
    }
    
    // 绘制最后一步棋的标记
    if (lastMoveRow != null && lastMoveCol != null && board[lastMoveRow!][lastMoveCol!] != 0) {
      final center = Offset(
        lastMoveCol! * cellSize + padding,
        lastMoveRow! * cellSize + padding,
      );
      final radius = cellSize * 0.45;
      
      final lastMovePaint = Paint()
        ..color = Colors.red.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius + 1, lastMovePaint);
    }
    
    // 绘制预览棋子
    if (previewRow != null && previewCol != null && board[previewRow!][previewCol!] == 0) {
      final center = Offset(
        previewCol! * cellSize + padding,
        previewRow! * cellSize + padding,
      );
      final radius = cellSize * 0.45;
      
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
  bool shouldRepaint(GoBoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.previewRow != previewRow ||
        oldDelegate.previewCol != previewCol ||
        oldDelegate.previewPlayer != previewPlayer ||
        oldDelegate.lastMoveRow != lastMoveRow ||
        oldDelegate.lastMoveCol != lastMoveCol;
  }
}
