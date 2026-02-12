import 'package:flutter/material.dart';

class ArmyChessBoardPainter extends CustomPainter {
  final int? selectedRow;
  final int? selectedCol;

  ArmyChessBoardPainter({this.selectedRow, this.selectedCol});

  @override
  void paint(Canvas canvas, Size size) {
    // 计算格子大小，12行5列，四周留相同边距
    final padding = size.width * 0.05; // 四周统一留5%边距
    final boardWidth = size.width - 2 * padding;
    final boardHeight = size.height - 2 * padding;

    final cellWidth = boardWidth / 5; // 5列平均分配
    final cellHeight = boardHeight / 12; // 12行平均分配
    final offsetX = padding; // 左边距
    final offsetY = padding; // 上边距

    final linePaint = Paint()
      ..color = Colors.brown[700]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final railwayPaint = Paint()
      ..color = Colors.brown[800]!
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // 绘制连接线（先画线，后画图形，这样图形会覆盖线）
    _drawConnections(
      canvas,
      cellWidth,
      cellHeight,
      offsetX,
      offsetY,
      linePaint,
      railwayPaint,
    );

    // 绘制大本营（梯形）
    _drawHeadquarters(canvas, cellWidth, cellHeight, offsetX, offsetY);

    // 绘制行营（圆形）
    _drawCamps(canvas, cellWidth, cellHeight, offsetX, offsetY);

    // 绘制普通位置（长方形）
    _drawNormalPositions(canvas, cellWidth, cellHeight, offsetX, offsetY);
  }

  void _drawConnections(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    double offsetX,
    double offsetY,
    Paint linePaint,
    Paint railwayPaint,
  ) {
    // 绘制所有横线连接
    for (int row = 0; row < 12; row++) {
      for (int col = 0; col < 4; col++) {
        final x1 = offsetX + col * cellWidth + cellWidth / 2;
        final y = offsetY + row * cellHeight + cellHeight / 2;
        final x2 = offsetX + (col + 1) * cellWidth + cellWidth / 2;

        // 铁路线使用双线+枕木效果
        if (row == 1 || row == 5 || row == 6 || row == 10) {
          _drawRailwayLine(
            canvas,
            Offset(x1, y),
            Offset(x2, y),
            railwayPaint.strokeWidth,
          );
        } else {
          canvas.drawLine(Offset(x1, y), Offset(x2, y), linePaint);
        }
      }
    }

    // 绘制所有竖线连接（铁路线加粗）
    for (int col = 0; col < 5; col++) {
      final x = offsetX + col * cellWidth + cellWidth / 2;
      // 上半区 (0-5行)
      if (col == 0 || col == 4) {
        // 先处理最上面位置，不是铁路线
        int row = 0;
        final yy1 = offsetY + row * cellHeight + cellHeight / 2;
        final yy2 = offsetY + (row + 1) * cellHeight + cellHeight / 2;
        canvas.drawLine(Offset(x, yy1), Offset(x, yy2), linePaint);
        // 处理所有铁路线
        for (row = 1; row < 5; row++) {
          final y1 = offsetY + row * cellHeight + cellHeight / 2;
          final y2 = offsetY + (row + 1) * cellHeight + cellHeight / 2;
          _drawRailwayLine(
            canvas,
            Offset(x, y1),
            Offset(x, y2),
            railwayPaint.strokeWidth,
          );
        }
      } else {
        for (int row = 0; row < 5; row++) {
          final y1 = offsetY + row * cellHeight + cellHeight / 2;
          final y2 = offsetY + (row + 1) * cellHeight + cellHeight / 2;
          canvas.drawLine(Offset(x, y1), Offset(x, y2), linePaint);
        }
      }

      // 中间连接 (5-6行)：只有左中右三列连通（col = 0, 2, 4），两侧列（1, 3）断开
      if (col == 0 || col == 2 || col == 4) {
        final y5 = offsetY + 5 * cellHeight + cellHeight / 2;
        final y6 = offsetY + 6 * cellHeight + cellHeight / 2;
        _drawRailwayLine(
          canvas,
          Offset(x, y5),
          Offset(x, y6),
          railwayPaint.strokeWidth,
        );
      }

      // 下半区 (6-11行)
      if (col == 0 || col == 4) {
        // 先处理最后位置，不是铁路线，普通线段
        int row = 10;
        final yy1 = offsetY + row * cellHeight + cellHeight / 2;
        final yy2 = offsetY + (row + 1) * cellHeight + cellHeight / 2;
        canvas.drawLine(Offset(x, yy1), Offset(x, yy2), linePaint);
        // 处理所有铁路线
        for (row = 6; row < 10; row++) {
          final y1 = offsetY + row * cellHeight + cellHeight / 2;
          final y2 = offsetY + (row + 1) * cellHeight + cellHeight / 2;
          _drawRailwayLine(
            canvas,
            Offset(x, y1),
            Offset(x, y2),
            railwayPaint.strokeWidth,
          );
        }
      } else {
        for (int row = 6; row < 11; row++) {
          final y1 = offsetY + row * cellHeight + cellHeight / 2;
          final y2 = offsetY + (row + 1) * cellHeight + cellHeight / 2;
          canvas.drawLine(Offset(x, y1), Offset(x, y2), linePaint);
        }
      }
    }

    // 绘制行营斜线连接
    _drawCampDiagonals(
      canvas,
      cellWidth,
      cellHeight,
      offsetX,
      offsetY,
      linePaint,
    );
  }

  void _drawRailwayLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double strokeWidth,
  ) {
    final totalDistance = (end - start).distance;
    if (totalDistance < 1.0) return;

    final direction = (end - start) / totalDistance;
    final perpendicular = Offset(-direction.dy, direction.dx); // 垂直方向

    final railSpacing = strokeWidth * 0.4; // 两条铁轨的间距

    final railPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = strokeWidth * 0.25
      ..style = PaintingStyle.stroke;

    final sleeperPaint = Paint()
      ..color = Colors.brown[600]!
      ..strokeWidth = strokeWidth * 0.3
      ..style = PaintingStyle.stroke;

    // 绘制两条铁轨
    canvas.drawLine(
      start + perpendicular * railSpacing,
      end + perpendicular * railSpacing,
      railPaint,
    );
    canvas.drawLine(
      start - perpendicular * railSpacing,
      end - perpendicular * railSpacing,
      railPaint,
    );

    // 绘制枕木（黑白相间的短横线）
    final sleeperSpacing = strokeWidth * 1.5;
    int sleeperCount = (totalDistance / sleeperSpacing).floor();

    for (int i = 0; i <= sleeperCount; i++) {
      final t = i / sleeperCount;
      final center = Offset.lerp(start, end, t)!;
      canvas.drawLine(
        center + perpendicular * railSpacing * 0.8,
        center - perpendicular * railSpacing * 0.8,
        sleeperPaint,
      );
    }
  }

  void _drawCampDiagonals(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    double offsetX,
    double offsetY,
    Paint paint,
  ) {
    // 上半区行营斜线 (红方)
    final topCamps = [
      [2, 1],
      [2, 3],
      [3, 2],
      [4, 1],
      [4, 3],
    ];
    for (var camp in topCamps) {
      final row = camp[0];
      final col = camp[1];
      final cx = offsetX + col * cellWidth + cellWidth / 2;
      final cy = offsetY + row * cellHeight + cellHeight / 2;

      // 四个方向斜线
      for (var dir in [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
      ]) {
        final tr = row + dir[0];
        final tc = col + dir[1];
        if (tr >= 0 && tr < 12 && tc >= 0 && tc < 5) {
          final tx = offsetX + tc * cellWidth + cellWidth / 2;
          final ty = offsetY + tr * cellHeight + cellHeight / 2;
          canvas.drawLine(Offset(cx, cy), Offset(tx, ty), paint);
        }
      }
    }

    // 下半区行营斜线 (蓝方)
    final bottomCamps = [
      [7, 1],
      [7, 3],
      [8, 2],
      [9, 1],
      [9, 3],
    ];
    for (var camp in bottomCamps) {
      final row = camp[0];
      final col = camp[1];
      final cx = offsetX + col * cellWidth + cellWidth / 2;
      final cy = offsetY + row * cellHeight + cellHeight / 2;

      for (var dir in [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
      ]) {
        final tr = row + dir[0];
        final tc = col + dir[1];
        if (tr >= 0 && tr < 12 && tc >= 0 && tc < 5) {
          final tx = offsetX + tc * cellWidth + cellWidth / 2;
          final ty = offsetY + tr * cellHeight + cellHeight / 2;
          canvas.drawLine(Offset(cx, cy), Offset(tx, ty), paint);
        }
      }
    }
  }

  void _drawHeadquarters(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    double offsetX,
    double offsetY,
  ) {
    final hqFillPaint = Paint()
      ..color = Colors.red[100]!
      ..style = PaintingStyle.fill;

    final hqStrokePaint = Paint()
      ..color = Colors.red[700]!
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // 大本营位置
    final hqPositions = [
      [0, 1, false], [0, 3, false], // 上方
      [11, 1, true], [11, 3, true], // 下方
    ];

    for (var pos in hqPositions) {
      final row = pos[0] as int;
      final col = pos[1] as int;
      final isBottom = pos[2] as bool;
      _drawTrapezoid(
        canvas,
        row,
        col,
        cellWidth,
        cellHeight,
        offsetX,
        offsetY,
        hqFillPaint,
        hqStrokePaint,
        isBottom,
      );
    }
  }

  void _drawTrapezoid(
    Canvas canvas,
    int row,
    int col,
    double cellWidth,
    double cellHeight,
    double offsetX,
    double offsetY,
    Paint fillPaint,
    Paint strokePaint,
    bool isBottom,
  ) {
    final cx = offsetX + col * cellWidth + cellWidth / 2;
    final cy = offsetY + row * cellHeight + cellHeight / 2;
    final w = cellWidth * 0.7;
    final h = cellHeight * 0.65;

    final path = Path();

    if (isBottom) {
      // 下方大本营：上宽下窄
      path.moveTo(cx - w * 0.5, cy - h * 0.5);
      path.lineTo(cx + w * 0.5, cy - h * 0.5);
      path.lineTo(cx + w * 0.3, cy + h * 0.5);
      path.lineTo(cx - w * 0.3, cy + h * 0.5);
    } else {
      // 上方大本营：下宽上窄
      path.moveTo(cx - w * 0.3, cy - h * 0.5);
      path.lineTo(cx + w * 0.3, cy - h * 0.5);
      path.lineTo(cx + w * 0.5, cy + h * 0.5);
      path.lineTo(cx - w * 0.5, cy + h * 0.5);
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawCamps(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    double offsetX,
    double offsetY,
  ) {
    final campFillPaint = Paint()
      ..color = Colors.green[100]!
      ..style = PaintingStyle.fill;

    final campStrokePaint = Paint()
      ..color = Colors.green[700]!
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // 行营位置：每边有5个（修正为对称布局）
    final allCamps = [
      [2, 1], [2, 3], [3, 2], [4, 1], [4, 3], // 上半区（红方）
      [7, 1], [7, 3], [8, 2], [9, 1], [9, 3], // 下半区（蓝方）
    ];

    final campRadius = cellWidth * 0.35; // 增大行营圆圈

    for (var pos in allCamps) {
      final row = pos[0];
      final col = pos[1];
      final cx = offsetX + col * cellWidth + cellWidth / 2;
      final cy = offsetY + row * cellHeight + cellHeight / 2;

      canvas.drawCircle(Offset(cx, cy), campRadius, campFillPaint);
      canvas.drawCircle(Offset(cx, cy), campRadius, campStrokePaint);
    }
  }

  void _drawNormalPositions(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    double offsetX,
    double offsetY,
  ) {
    final rectFillPaint = Paint()
      ..color = Colors.brown[50]!
      ..style = PaintingStyle.fill;

    final rectStrokePaint = Paint()
      ..color = Colors.brown[600]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 行营位置
    final camps = {
      '2_1',
      '2_3',
      '3_2',
      '4_1',
      '4_3',
      '7_1',
      '7_3',
      '8_2',
      '9_1',
      '9_3',
    };

    // 大本营位置
    final hqs = {'0_1', '0_3', '11_1', '11_3'};

    // 绘制所有普通位置的长方形
    for (int row = 0; row < 12; row++) {
      for (int col = 0; col < 5; col++) {
        final key = '${row}_$col';
        // 跳过行营和大本营
        if (camps.contains(key) || hqs.contains(key)) continue;

        final cx = offsetX + col * cellWidth + cellWidth / 2;
        final cy = offsetY + row * cellHeight + cellHeight / 2;
        final w = cellWidth * 0.65; // 增大长方形宽度
        final h = cellHeight * 0.6; // 增大长方形高度

        final rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: w,
          height: h,
        );

        canvas.drawRect(rect, rectFillPaint);
        canvas.drawRect(rect, rectStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(ArmyChessBoardPainter oldDelegate) {
    return selectedRow != oldDelegate.selectedRow ||
        selectedCol != oldDelegate.selectedCol;
  }
}
