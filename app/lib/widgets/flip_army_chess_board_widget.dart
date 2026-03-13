import 'dart:math';
import 'package:flutter/material.dart';
import 'flip_army_chess_board_painter.dart';

class FlipArmyChessBoardWidget extends StatelessWidget {
  final List<List<dynamic>> board;
  final Function(int, int)? onTap;
  final int? selectedRow;
  final int? selectedCol;
  final String? playerColor;
  final int? myPlayerNumber;
  final Map<String, dynamic>? lastMove;
  final Set<String> flippedPieces;  // 已翻开的棋子位置

  const FlipArmyChessBoardWidget({
    super.key,
    required this.board,
    this.onTap,
    this.selectedRow,
    this.selectedCol,
    this.playerColor,
    this.myPlayerNumber,
    this.lastMove,
    required this.flippedPieces,
  });

  @override
  Widget build(BuildContext context) {
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

            final padding = width * 0.05;
            final boardWidth = width - 2 * padding;
            final boardHeight = height - 2 * padding;

            final cellWidth = boardWidth / 5;
            final cellHeight = boardHeight / 12;
            final offsetX = padding;
            final offsetY = padding;

            return Stack(
              children: [
                // 绘制棋盘底层
                CustomPaint(
                  painter: FlipArmyChessBoardPainter(
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

        // 视角翻转
        int displayRow = row;
        int displayCol = col;
        if (myPlayerNumber == 1) {
          displayRow = 11 - row;
          displayCol = 4 - col;
        }

        final cx = offsetX + displayCol * cellWidth + cellWidth / 2;
        final cy = offsetY + displayRow * cellHeight + cellHeight / 2;

        double areaWidth = cellWidth * 0.75;
        double areaHeight = cellHeight * 0.5;

        final piece = board[row][col];
        final pieceKey = '${row}_$col';
        final isFlipped = flippedPieces.contains(pieceKey);

        pieces.add(
          Positioned(
            left: cx - areaWidth / 2,
            top: cy - areaHeight / 2,
            child: GestureDetector(
              onTap: onTap != null ? () {
                onTap!(displayRow, displayCol);
              } : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: areaWidth,
                height: areaHeight,
                decoration: piece != null ? BoxDecoration(
                  color: isSelected
                      ? Colors.yellow.withOpacity(0.7)
                      : (piece['color'] == 'red'
                          ? Colors.red[50]
                          : (piece['color'] == 'blue' ? Colors.blue[50] : Colors.orange[100])),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? Colors.green
                        : (piece['color'] == 'red'
                            ? Colors.red[700]!
                            : (piece['color'] == 'blue' ? Colors.blue[700]! : Colors.orange[700]!)),
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
                        isFlipped
                            ? piece['type']
                            : '?',  // 未翻开的棋子显示为问号
                        style: TextStyle(
                          color: isFlipped
                              ? (piece['color'] == 'red'
                                  ? Colors.red[900]
                                  : Colors.blue[900])
                              : Colors.black,
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

  List<Widget> _buildLastMoveMarker(double width, double height, double cellWidth,
                                   double cellHeight, double offsetX, double offsetY) {
    List<Widget> markers = [];

    if (lastMove == null) return markers;

    final fromRow = lastMove!['from_row'] as int?;
    final fromCol = lastMove!['from_col'] as int?;
    final toRow = lastMove!['to_row'] as int?;
    final toCol = lastMove!['to_col'] as int?;

    if (fromRow == null || fromCol == null || toRow == null || toCol == null) {
      return markers;
    }

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

    final fromCx = offsetX + displayFromCol * cellWidth + cellWidth / 2;
    final fromCy = offsetY + displayFromRow * cellHeight + cellHeight / 2;
    final toCx = offsetX + displayToCol * cellWidth + cellWidth / 2;
    final toCy = offsetY + displayToRow * cellHeight + cellHeight / 2;

    final pieceWidth = cellWidth * 0.75;
    final pieceHeight = cellHeight * 0.5;

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

    final isSapperRailway = lastMove!['is_sapper_railway'] as bool? ?? false;
    final pathData = lastMove!['path'] as List<dynamic>?;

    List<Offset> pathPoints = [];
    if (isSapperRailway && pathData != null && pathData.isNotEmpty) {
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
      pathPoints = [Offset(fromCx, fromCy), Offset(toCx, toCy)];
    }

    double arrowStartWidth = startRectWidth;
    double arrowStartHeight = startRectHeight;
    double arrowTargetWidth = endRectWidth;
    double arrowTargetHeight = endRectHeight;

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

  Offset _getPointBetween(Offset center, Offset towardsPoint, double halfW, double halfH) {
    final dx = towardsPoint.dx - center.dx;
    final dy = towardsPoint.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance < 0.001) return center;

    final dirX = dx / distance;
    final dirY = dy / distance;

    double t = double.infinity;

    if (dirX < 0) {
      final tLeft = -halfW / dirX;
      if (tLeft > 0 && tLeft < t) {
        final y = tLeft * dirY;
        if (-halfH <= y && y <= halfH) {
          t = tLeft;
        }
      }
    }

    if (dirX > 0) {
      final tRight = halfW / dirX;
      if (tRight > 0 && tRight < t) {
        final y = tRight * dirY;
        if (-halfH <= y && y <= halfH) {
          t = tRight;
        }
      }
    }

    if (dirY < 0) {
      final tTop = -halfH / dirY;
      if (tTop > 0 && tTop < t) {
        final x = tTop * dirX;
        if (-halfW <= x && x <= halfW) {
          t = tTop;
        }
      }
    }

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

    final adjustedPathPoints = List<Offset>.from(pathPoints);

    if (startWidth > 0 && startHeight > 0) {
      final startCenter = pathPoints[0];
      final nextPoint = pathPoints[1];

      final halfStartW = startWidth / 2;
      final halfStartH = startHeight / 2;

      adjustedPathPoints[0] = _getPointBetween(
        startCenter,
        nextPoint,
        halfStartW,
        halfStartH,
      );
    }

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

    final path = Path();
    path.moveTo(adjustedPathPoints[0].dx, adjustedPathPoints[0].dy);
    for (int i = 1; i < adjustedPathPoints.length; i++) {
      path.lineTo(adjustedPathPoints[i].dx, adjustedPathPoints[i].dy);
    }
    canvas.drawPath(path, paint);

    if (adjustedPathPoints.length >= 2) {
      _drawArrowHead(canvas, adjustedPathPoints[adjustedPathPoints.length - 2], adjustedPathPoints.last);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to) {
    final arrowLength = 15.0;
    final arrowAngle = 0.5;

    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final angle = atan2(dy, dx);

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
