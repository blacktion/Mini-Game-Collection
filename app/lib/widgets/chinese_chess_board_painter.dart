import 'package:flutter/material.dart';

class ChineseChessBoardPainter extends CustomPainter {
  final int? selectedRow;
  final int? selectedCol;
  final int? lastMoveFromRow;
  final int? lastMoveFromCol;
  final int? lastMoveToRow;
  final int? lastMoveToCol;
  final List<Map<String, int>> possibleMoves;
  final bool isRotated;

  ChineseChessBoardPainter({
    this.selectedRow,
    this.selectedCol,
    this.lastMoveFromRow,
    this.lastMoveFromCol,
    this.lastMoveToRow,
    this.lastMoveToCol,
    this.possibleMoves = const [],
    this.isRotated = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 确保正方形格子：取可用空间中能容纳 9x10 比例的最大正方形单元格
    final cellSize = (size.width / 9) < (size.height / 10) 
        ? size.width / 9 
        : size.height / 10;
    
    final cellWidth = cellSize;
    final cellHeight = cellSize;
    
    // 居中棋盘，边缘各留半个单元格的空白
    final startX = (size.width - 8 * cellWidth) / 2;
    final startY = (size.height - 9 * cellHeight) / 2;
    
    final paint = Paint()
      ..color = Colors.brown[800]!
      ..strokeWidth = 1.5;
    
    // 绘制横线
    for (int i = 0; i < 10; i++) {
      final y = startY + i * cellHeight;
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + 8 * cellWidth, y),
        paint,
      );
    }

    // 绘制竖线（上半部分）
    for (int i = 0; i < 9; i++) {
      final x = startX + i * cellWidth;
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, startY + 4 * cellHeight),
        paint,
      );
    }

    // 绘制竖线（下半部分）
    for (int i = 0; i < 9; i++) {
      final x = startX + i * cellWidth;
      canvas.drawLine(
        Offset(x, startY + 5 * cellHeight),
        Offset(x, startY + 9 * cellHeight),
        paint,
      );
    }
    
    // 绘制左右两侧的竖线（连接上下）
    canvas.drawLine(
      Offset(startX, startY + 4 * cellHeight),
      Offset(startX, startY + 5 * cellHeight),
      paint,
    );
    canvas.drawLine(
      Offset(startX + 8 * cellWidth, startY + 4 * cellHeight),
      Offset(startX + 8 * cellWidth, startY + 5 * cellHeight),
      paint,
    );
    
    // 绘制九宫格斜线（上方）
    canvas.drawLine(
      Offset(startX + 3 * cellWidth, startY),
      Offset(startX + 5 * cellWidth, startY + 2 * cellHeight),
      paint,
    );
    canvas.drawLine(
      Offset(startX + 5 * cellWidth, startY),
      Offset(startX + 3 * cellWidth, startY + 2 * cellHeight),
      paint,
    );
    
    // 绘制九宫格斜线（下方）
    canvas.drawLine(
      Offset(startX + 3 * cellWidth, startY + 7 * cellHeight),
      Offset(startX + 5 * cellWidth, startY + 9 * cellHeight),
      paint,
    );
    canvas.drawLine(
      Offset(startX + 5 * cellWidth, startY + 7 * cellHeight),
      Offset(startX + 3 * cellWidth, startY + 9 * cellHeight),
      paint,
    );
    
    // 绘制楚河汉界文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: isRotated ? '汉界' : '楚河',
        style: TextStyle(
          color: Colors.brown[800],
          fontSize: cellHeight * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(startX + cellWidth, startY + 4.25 * cellHeight),
    );
    
    textPainter.text = TextSpan(
      text: isRotated ? '楚河' : '汉界',
      style: TextStyle(
        color: Colors.brown[800],
        fontSize: cellHeight * 0.5,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(startX + 6 * cellWidth, startY + 4.25 * cellHeight),
    );
    
    // 绘制选中棋子的高亮
    if (selectedRow != null && selectedCol != null) {
      final highlightPaint = Paint()
        ..color = Colors.green.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      int dRow = isRotated ? 9 - selectedRow! : selectedRow!;
      int dCol = isRotated ? 8 - selectedCol! : selectedCol!;

      canvas.drawRect(
        Rect.fromLTWH(
          startX + dCol * cellWidth - cellWidth * 0.45,
          startY + dRow * cellHeight - cellHeight * 0.45,
          cellWidth * 0.9,
          cellHeight * 0.9,
        ),
        highlightPaint,
      );
    }
    
    // 绘制最后一步棋的标记（起点和终点）
    if (lastMoveToRow != null && lastMoveToCol != null) {
      final lastMovePaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      // 绘制终点标记（稍微明显一点）
      int toDRow = isRotated ? 9 - lastMoveToRow! : lastMoveToRow!;
      int toDCol = isRotated ? 8 - lastMoveToCol! : lastMoveToCol!;

      canvas.drawCircle(
        Offset(
          startX + toDCol * cellWidth,
          startY + toDRow * cellHeight,
        ),
        cellWidth * 0.42,
        lastMovePaint,
      );

      // 绘制起点标记
      if (lastMoveFromRow != null && lastMoveFromCol != null) {
        int fromDRow = isRotated ? 9 - lastMoveFromRow! : lastMoveFromRow!;
        int fromDCol = isRotated ? 8 - lastMoveFromCol! : lastMoveFromCol!;

        // 绘制从起点到终点的移动路径箭头
        final pathPaint = Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

        final fromOffset = Offset(
          startX + fromDCol * cellWidth,
          startY + fromDRow * cellHeight,
        );
        final toOffset = Offset(
          startX + toDCol * cellWidth,
          startY + toDRow * cellHeight,
        );

        // 绘制连接线
        canvas.drawLine(fromOffset, toOffset, pathPaint);

        // 计算箭头方向
        final dx = toOffset.dx - fromOffset.dx;
        final dy = toOffset.dy - fromOffset.dy;
        final distance = (dx * dx + dy * dy) as double;
        if (distance > 0) {
          final length = distance.isFinite ? (distance as num).toDouble() : 0.0;
          if (length > 0) {
            final sqrtLength = length > 0 ? (length as double) : 0.0;
            final unitDx = dx / sqrtLength;
            final unitDy = dy / sqrtLength;

            // 箭头大小
            final arrowSize = cellWidth * 0.2;

            // 箭头末端位置（留出一点空间不覆盖终点）
            final arrowEndX = toOffset.dx - unitDx * cellWidth * 0.3;
            final arrowEndY = toOffset.dy - unitDy * cellHeight * 0.3;

            // 绘制箭头
            final arrowPath = Path();
            arrowPath.moveTo(arrowEndX, arrowEndY);
            arrowPath.lineTo(
              arrowEndX - unitDx * arrowSize - unitDy * arrowSize * 0.5,
              arrowEndY - unitDy * arrowSize + unitDx * arrowSize * 0.5,
            );
            arrowPath.lineTo(
              arrowEndX - unitDx * arrowSize + unitDy * arrowSize * 0.5,
              arrowEndY - unitDy * arrowSize - unitDx * arrowSize * 0.5,
            );
            arrowPath.close();

            final arrowPaint = Paint()
              ..color = Colors.blue.withOpacity(0.25)
              ..style = PaintingStyle.fill;

            canvas.drawPath(arrowPath, arrowPaint);
          }
        }

        // 绘制起点的空心圆环（更明显）
        final fromMovePaint = Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

        canvas.drawCircle(
          fromOffset,
          cellWidth * 0.35,
          fromMovePaint,
        );
        
        // 绘制一个稍大的小圆点表示起点
        final fromDotPaint = Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          fromOffset,
          cellWidth * 0.12,
          fromDotPaint,
        );
      }
    }
    
    // 绘制可能的移动位置
    for (var move in possibleMoves) {
      final row = move['row']!;
      final col = move['col']!;
      
      int dRow = isRotated ? 9 - row : row;
      int dCol = isRotated ? 8 - col : col;

      final movePaint = Paint()
        ..color = Colors.orange.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(
          startX + dCol * cellWidth,
          startY + dRow * cellHeight,
        ),
        cellWidth * 0.2,
        movePaint,
      );
    }
    
    // 绘制兵站和炮位标记
    final markPositions = [
      (2, 1), (2, 7),  // 炮位
      (3, 0), (3, 2), (3, 4), (3, 6), (3, 8),  // 兵站
      (6, 0), (6, 2), (6, 4), (6, 6), (6, 8),
      (7, 1), (7, 7),
    ];
    
    final markPaint = Paint()
      ..color = Colors.brown[800]!
      ..strokeWidth = 1;
    
    for (var pos in markPositions) {
      final row = pos.$1;
      final col = pos.$2;
      
      // 物理坐标始终固定在棋盘底图上
      final x = startX + col * cellWidth;
      final y = startY + row * cellHeight;
      final markSize = cellWidth * 0.1;
      final gap = markSize * 0.5;
      
      // 左上
      if (col > 0) {
        canvas.drawLine(Offset(x - gap, y - markSize), Offset(x - gap - markSize, y - markSize), markPaint);
        canvas.drawLine(Offset(x - gap, y - markSize), Offset(x - gap, y - markSize - markSize), markPaint);
      }
      // 右上
      if (col < 8) {
        canvas.drawLine(Offset(x + gap, y - markSize), Offset(x + gap + markSize, y - markSize), markPaint);
        canvas.drawLine(Offset(x + gap, y - markSize), Offset(x + gap, y - markSize - markSize), markPaint);
      }
      // 左下
      if (col > 0) {
        canvas.drawLine(Offset(x - gap, y + markSize), Offset(x - gap - markSize, y + markSize), markPaint);
        canvas.drawLine(Offset(x - gap, y + markSize), Offset(x - gap, y + markSize + markSize), markPaint);
      }
      // 右下
      if (col < 8) {
        canvas.drawLine(Offset(x + gap, y + markSize), Offset(x + gap + markSize, y + markSize), markPaint);
        canvas.drawLine(Offset(x + gap, y + markSize), Offset(x + gap, y + markSize + markSize), markPaint);
      }
    }
  }

  @override
  bool shouldRepaint(ChineseChessBoardPainter oldDelegate) {
    return oldDelegate.selectedRow != selectedRow ||
        oldDelegate.selectedCol != selectedCol ||
        oldDelegate.lastMoveFromRow != lastMoveFromRow ||
        oldDelegate.lastMoveFromCol != lastMoveFromCol ||
        oldDelegate.lastMoveToRow != lastMoveToRow ||
        oldDelegate.lastMoveToCol != lastMoveToCol ||
        oldDelegate.possibleMoves != possibleMoves ||
        oldDelegate.isRotated != isRotated;
  }
}
