import 'dart:math';
import 'package:flutter/material.dart';
import 'army_chess_board_painter.dart';

class ArmyChessBoardWidget extends StatelessWidget {
  final List<List<dynamic>> board;
  final Function(int, int)? onTap;
  final int? selectedRow;
  final int? selectedCol;
  final String? playerColor;
  final int? myPlayerNumber;  // 新增：玩家编号，用于视角翻转
  final Map<String, dynamic>? lastMove;  // 新增：上一步移动

  const ArmyChessBoardWidget({
    super.key,
    required this.board,
    this.onTap,
    this.selectedRow,
    this.selectedCol,
    this.playerColor,
    this.myPlayerNumber,  // 新增参数
    this.lastMove,  // 新增参数
  });

  @override
  Widget build(BuildContext context) {
    // 不使用Transform.rotate，而是在绘制时直接翻转坐标
    return AspectRatio(
      aspectRatio: 5 / 12,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.amber[50],
          border: Border.all(color: Colors.brown[800]!, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            
            // 四周留相同边距
            final padding = width * 0.05;
            final boardWidth = width - 2 * padding;
            final boardHeight = height - 2 * padding;
            
            final cellWidth = boardWidth / 5;
            final cellHeight = boardHeight / 12;
            final offsetX = padding;
            final offsetY = padding;

            return Stack(
              children: [
                // 绘制棋盘底层（连接线、行营、大本营等）
                CustomPaint(
                  painter: ArmyChessBoardPainter(
                    selectedRow: selectedRow,
                    selectedCol: selectedCol,
                  ),
                  size: Size(width, height),
                ),
                // 绘制上一步移动标记
                ..._buildLastMoveMarker(width, height, cellWidth, cellHeight, offsetX, offsetY),
                // 绘制棋子
                ..._buildPieces(width, height, cellWidth, cellHeight, offsetX, offsetY),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildPieces(double width, double height, double cellWidth,
                            double cellHeight, double offsetX, double offsetY) {
    List<Widget> pieces = [];

    for (int row = 0; row < 12; row++) {
      for (int col = 0; col < 5; col++) {
        final isSelected = selectedRow == row && selectedCol == col;

        // 视角翻转：让所有玩家都看到自己在下方
        int displayRow = row;
        int displayCol = col;
        if (myPlayerNumber == 1) {
          // 红方：数据在0-5行，需要翻转到视觉下方（6-11行）
          displayRow = 11 - row;
          displayCol = 4 - col;
        }
        // 蓝方：数据在6-11行，不翻转，本来就在视觉下方

        final cx = offsetX + displayCol * cellWidth + cellWidth / 2;
        final cy = offsetY + displayRow * cellHeight + cellHeight / 2;

        // 根据位置类型设置区域大小（棋子更扁，方便看出是否在行营）
        // 所有位置使用相同大小的棋子
        double areaWidth = cellWidth * 0.75;
        double areaHeight = cellHeight * 0.5;

        final piece = board[row][col];

        // 绘制棋子或点击区域
        pieces.add(
          Positioned(
            left: cx - areaWidth / 2,
            top: cy - areaHeight / 2,
            child: GestureDetector(
              onTap: onTap != null ? () {
                // 传递视觉坐标，displayRow和displayCol是用户看到的位置
                // 外部需要将其转换回原始数据坐标
                onTap!(displayRow, displayCol);
              } : null,
              behavior: HitTestBehavior.opaque,  // 确保空区域也能响应点击
              child: Container(
                width: areaWidth,
                height: areaHeight,
                decoration: piece != null ? BoxDecoration(
                  color: isSelected
                      ? Colors.yellow.withOpacity(0.7)
                      : (piece['color'] == 'red'
                          ? Colors.red[50]
                          : (piece['color'] == 'blue' ? Colors.blue[50] : Colors.grey[200])),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? Colors.green
                        : (piece['color'] == 'red'
                            ? Colors.red[700]!
                            : (piece['color'] == 'blue' ? Colors.blue[700]! : Colors.grey[700]!)),
                    width: isSelected ? 3 : 2,
                  ),
                ) : (isSelected ? BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green, width: 2),
                ) : null),
                child: piece != null ? Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        piece['color'] == playerColor
                            ? piece['type']
                            : '?',
                        style: TextStyle(
                          color: piece['color'] == 'red'
                              ? Colors.red[900]
                              : (piece['color'] == 'blue' ? Colors.blue[900] : Colors.grey[900]),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ) : null,
              ),
            ),
          ),
        );
      }
    }

    return pieces;
  }

  // 构建上一步移动标记
  List<Widget> _buildLastMoveMarker(double width, double height, double cellWidth,
                                   double cellHeight, double offsetX, double offsetY) {
    List<Widget> markers = [];

    if (lastMove == null) return markers;

    final fromRow = lastMove!['from_row'] as int?;
    final fromCol = lastMove!['from_col'] as int?;
    final toRow = lastMove!['to_row'] as int?;
    final toCol = lastMove!['to_col'] as int?;

    // 检查必要字段是否存在
    if (fromRow == null || fromCol == null || toRow == null || toCol == null) {
      return markers;
    }

    // 只标记对方的移动，不标记自己的移动
    final movePlayer = lastMove!['player'] as String?;
    if (movePlayer == playerColor) return markers;

    // 转换为显示坐标
    int displayFromRow = fromRow;
    int displayFromCol = fromCol;
    int displayToRow = toRow;
    int displayToCol = toCol;
    if (myPlayerNumber == 1) {
      displayFromRow = 11 - fromRow;
      displayFromCol = 4 - fromCol;
      displayToRow = 11 - toRow;
      displayToCol = 4 - toCol;
    }

    // 计算起点和终点的中心坐标
    final fromCx = offsetX + displayFromCol * cellWidth + cellWidth / 2;
    final fromCy = offsetY + displayFromRow * cellHeight + cellHeight / 2;
    final toCx = offsetX + displayToCol * cellWidth + cellWidth / 2;
    final toCy = offsetY + displayToRow * cellHeight + cellHeight / 2;

    // 棋子大小（与实际棋子一致）
    final pieceWidth = cellWidth * 0.75;
    final pieceHeight = cellHeight * 0.5;

    // 起点标记（空心长方形，比棋子稍大）
    final startRectWidth = pieceWidth * 1.1;
    final startRectHeight = pieceHeight * 1.1;

    markers.add(
      Positioned(
        left: fromCx - startRectWidth / 2,
        top: fromCy - startRectHeight / 2,
        child: Container(
          width: startRectWidth,
          height: startRectHeight,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange[700]!, width: 3),
          ),
        ),
      ),
    );

    // 终点标记（实心长方形，比棋子稍大）
    final endRectWidth = pieceWidth * 1.1;
    final endRectHeight = pieceHeight * 1.1;

    markers.add(
      Positioned(
        left: toCx - endRectWidth / 2,
        top: toCy - endRectHeight / 2,
        child: Container(
          width: endRectWidth,
          height: endRectHeight,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
            color: Colors.orange[400]!.withOpacity(0.4),
            border: Border.all(color: Colors.orange[700]!, width: 3),
          ),
        ),
      ),
    );

    // 检查是否是工兵沿铁路移动
    final isSapperRailway = lastMove!['is_sapper_railway'] as bool? ?? false;
    final pathData = lastMove!['path'] as List<dynamic>?;

    List<Offset> pathPoints = [];
    if (isSapperRailway && pathData != null && pathData.isNotEmpty) {
      // 工兵沿铁路移动，使用路径上的点
      for (var point in pathData) {
        final row = point[0] as int;
        final col = point[1] as int;
        int displayRow = row;
        int displayCol = col;
        if (myPlayerNumber == 1) {
          displayRow = 11 - row;
          displayCol = 4 - col;
        }
        pathPoints.add(Offset(
          offsetX + displayCol * cellWidth + cellWidth / 2,
          offsetY + displayRow * cellHeight + cellHeight / 2,
        ));
      }
    } else {
      // 普通移动，直接使用起点和终点
      pathPoints = [Offset(fromCx, fromCy), Offset(toCx, toCy)];
    }

    // 计算箭头起点和终点在长方形边上的位置
    double arrowStartWidth = startRectWidth;
    double arrowStartHeight = startRectHeight;
    double arrowTargetWidth = endRectWidth;
    double arrowTargetHeight = endRectHeight;

    // 绘制箭头路径，起点和终点都指向长方形边缘
    if (pathPoints.length >= 2) {
      markers.add(
        Positioned(
          left: 0,
          top: 0,
          child: CustomPaint(
            size: Size(width, height),
            painter: _ArrowPainter(
              pathPoints: pathPoints,
              color: Colors.orange[700]!,
              strokeWidth: 4.0,
              startWidth: arrowStartWidth,
              startHeight: arrowStartHeight,
              targetWidth: arrowTargetWidth,
              targetHeight: arrowTargetHeight,
            ),
          ),
        ),
      );
    }

    return markers;
  }
}

// 箭头绘制器
class _ArrowPainter extends CustomPainter {
  final List<Offset> pathPoints;
  final Color color;
  final double strokeWidth;
  final double startWidth;
  final double startHeight;
  final double targetWidth;
  final double targetHeight;

  _ArrowPainter({
    required this.pathPoints,
    required this.color,
    required this.strokeWidth,
    this.startWidth = 0,
    this.startHeight = 0,
    this.targetWidth = 0,
    this.targetHeight = 0,
  });

  // 计算两点与矩形边界的交点（用于路径中间点）
  Offset _getPointBetween(Offset center, Offset towardsPoint, double halfW, double halfH) {
    final dx = towardsPoint.dx - center.dx;
    final dy = towardsPoint.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance < 0.001) return center;

    final dirX = dx / distance;
    final dirY = dy / distance;

    // 计算射线与长方形边界的交点
    double t = double.infinity;

    // 检查左边界（x = -halfW）
    if (dirX < 0) {
      final tLeft = -halfW / dirX;
      if (tLeft > 0 && tLeft < t) {
        final y = tLeft * dirY;
        if (-halfH <= y && y <= halfH) {
          t = tLeft;
        }
      }
    }

    // 检查右边界（x = halfW）
    if (dirX > 0) {
      final tRight = halfW / dirX;
      if (tRight > 0 && tRight < t) {
        final y = tRight * dirY;
        if (-halfH <= y && y <= halfH) {
          t = tRight;
        }
      }
    }

    // 检查上边界（y = -halfH）
    if (dirY < 0) {
      final tTop = -halfH / dirY;
      if (tTop > 0 && tTop < t) {
        final x = tTop * dirX;
        if (-halfW <= x && x <= halfW) {
          t = tTop;
        }
      }
    }

    // 检查下边界（y = halfH）
    if (dirY > 0) {
      final tBottom = halfH / dirY;
      if (tBottom > 0 && tBottom < t) {
        final x = tBottom * dirX;
        if (-halfW <= x && x <= halfW) {
          t = tBottom;
        }
      }
    }

    if (t < double.infinity) {
      return Offset(
        center.dx + dirX * t,
        center.dy + dirY * t,
      );
    }

    return towardsPoint;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pathPoints.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 调整路径点：起点和终点都调整到长方形边上
    final adjustedPathPoints = List<Offset>.from(pathPoints);

    // 处理起点：从起点长方形的边出发
    if (startWidth > 0 && startHeight > 0) {
      final startCenter = pathPoints[0];
      final nextPoint = pathPoints[1];

      final halfStartW = startWidth / 2;
      final halfStartH = startHeight / 2;

      // 找到起点长方形边上的交点
      adjustedPathPoints[0] = _getPointBetween(
        startCenter,
        nextPoint,
        halfStartW,
        halfStartH,
      );
    }

    // 处理终点：指向终点长方形的边
    if (targetWidth > 0 && targetHeight > 0) {
      final endCenter = pathPoints.last;
      final prevPoint = pathPoints[pathPoints.length - 2];

      final halfTargetW = targetWidth / 2;
      final halfTargetH = targetHeight / 2;

      adjustedPathPoints[adjustedPathPoints.length - 1] = _getPointBetween(
        endCenter,
        prevPoint,
        halfTargetW,
        halfTargetH,
      );
    }

    // 绘制路径线（沿着路径上的所有点，形成拐弯的铁路路径）
    final path = Path();
    path.moveTo(adjustedPathPoints[0].dx, adjustedPathPoints[0].dy);
    for (int i = 1; i < adjustedPathPoints.length; i++) {
      path.lineTo(adjustedPathPoints[i].dx, adjustedPathPoints[i].dy);
    }
    canvas.drawPath(path, paint);

    // 绘制箭头（在修正后的终点）
    if (adjustedPathPoints.length >= 2) {
      _drawArrowHead(canvas, adjustedPathPoints[adjustedPathPoints.length - 2], adjustedPathPoints.last);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to) {
    final arrowLength = 15.0;
    final arrowAngle = 0.5; // 箭头角度

    // 计算箭头的方向
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final angle = atan2(dy, dx);

    // 箭头的两条边
    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final leftWing = Offset(
      to.dx - arrowLength * cos(angle - arrowAngle),
      to.dy - arrowLength * sin(angle - arrowAngle),
    );

    final rightWing = Offset(
      to.dx - arrowLength * cos(angle + arrowAngle),
      to.dy - arrowLength * sin(angle + arrowAngle),
    );

    canvas.drawLine(to, leftWing, arrowPaint);
    canvas.drawLine(to, rightWing, arrowPaint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return oldDelegate.pathPoints != pathPoints ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.startWidth != startWidth ||
        oldDelegate.startHeight != startHeight ||
        oldDelegate.targetWidth != targetWidth ||
        oldDelegate.targetHeight != targetHeight;
  }
}
