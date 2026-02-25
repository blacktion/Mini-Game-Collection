import 'package:flutter/material.dart';

class ChineseCheckersBoardPainter extends CustomPainter {
  final List<List<Map<String, dynamic>?>> board;
  final int? selectedRow;
  final int? selectedCol;
  final List<Map<String, int>> lastMovePath;
  final String myColor;
  final String currentPlayerColor;
  final double cellSize;
  final int? previewFromRow;
  final int? previewFromCol;
  final int? previewToRow;
  final int? previewToCol;

  ChineseCheckersBoardPainter({
    required this.board,
    this.selectedRow,
    this.selectedCol,
    this.lastMovePath = const [],
    required this.myColor,
    required this.currentPlayerColor,
    required this.cellSize,
    this.previewFromRow,
    this.previewFromCol,
    this.previewToRow,
    this.previewToCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 计算自适应的绘制参数
    final validPositions = _getValidPositions();
    if (validPositions.isEmpty) return;
    
    // 找到有效位置的边界
    int minRow = validPositions.map((p) => p['row']!).reduce((a, b) => a < b ? a : b);
    int maxRow = validPositions.map((p) => p['row']!).reduce((a, b) => a > b ? a : b);
    int minCol = validPositions.map((p) => p['col']!).reduce((a, b) => a < b ? a : b);
    int maxCol = validPositions.map((p) => p['col']!).reduce((a, b) => a > b ? a : b);
    
    // 计算实际需要的尺寸
    double contentWidth = (maxCol - minCol + 1) * cellSize;
    double contentHeight = (maxRow - minRow + 1) * cellSize * 1.5;
    
    // 计算居中偏移
    double offsetX = (size.width - contentWidth) / 2;
    double offsetY = (size.height - contentHeight) / 2;
    
    // 绘制棋盘边界
    final borderPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
    
    // 绘制上一步移动路径（浅色线条）
    if (lastMovePath.length > 1) {
      final pathPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      for (int i = 0; i < lastMovePath.length - 1; i++) {
        final fromPos = lastMovePath[i];
        final toPos = lastMovePath[i + 1];
        
        final fromX = offsetX + (fromPos['col']! - minCol) * cellSize + cellSize / 2;
        final fromY = offsetY + (fromPos['row']! - minRow) * cellSize * 1.5 + cellSize / 2;
        final toX = offsetX + (toPos['col']! - minCol) * cellSize + cellSize / 2;
        final toY = offsetY + (toPos['row']! - minRow) * cellSize * 1.5 + cellSize / 2;
        
        canvas.drawLine(Offset(fromX, fromY), Offset(toX, toY), pathPaint);
      }
    }
    
    // 绘制有效的六角星位置
    for (int row = 0; row < 17; row++) {
      for (int col = 0; col < 25; col++) {
        if (_isValidPosition(row, col)) {
          final x = offsetX + (col - minCol) * cellSize + cellSize / 2;
          final y = offsetY + (row - minRow) * cellSize * 1.5 + cellSize / 2;
          
          // 移除可视范围检查，确保所有有效位置都被绘制
          final isSelected = row == selectedRow && col == selectedCol;
          final piece = board[row][col];
          
          // 绘制格子背景
          Color bgColor = isSelected ? Colors.yellow[200]! : Colors.brown[200]!;
          final paint = Paint()
            ..color = bgColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x, y), cellSize * 0.4, paint);
          
          // 如果是选中的棋子，添加棕色边框圆圈
          if (isSelected && piece != null) {
            final selectionRing = Paint()
              ..color = Colors.brown
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3;
            canvas.drawCircle(Offset(x, y), cellSize * 0.6, selectionRing);
          }
          
          // 绘制棋子
          if (piece != null) {
            Color pieceColor = _getPieceColor(piece['color']);
            
            // 增强棋子可见性
            final piecePaint = Paint()
              ..color = pieceColor
              ..style = PaintingStyle.fill;
            // 稍微增大棋子半径，使其更容易点击
            final pieceRadius = cellSize * 0.55;
            canvas.drawCircle(Offset(x, y), pieceRadius, piecePaint);
            
            // 添加黑色外边框
            final borderPaint = Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2;
            canvas.drawCircle(Offset(x, y), pieceRadius, borderPaint);
            
            // 根据阵营添加中心点
            final centerDotColor = piece['color'] == myColor ? Colors.white : Colors.black;
            final centerDot = Paint()
              ..color = centerDotColor
              ..style = PaintingStyle.fill;
            canvas.drawCircle(Offset(x, y), cellSize * 0.15, centerDot);
            
            // 如果是当前玩家的棋子，添加细黑色边框
            if (piece['color'] == myColor) {
              final currentPlayerBorder = Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2;
              canvas.drawCircle(Offset(x, y), pieceRadius, currentPlayerBorder);
            }
          }
        }
      }
    }
    
    // 绘制预览移动
    if (previewFromRow != null && previewToRow != null) {
      final fromX = offsetX + (previewFromCol! - minCol) * cellSize + cellSize / 2;
      final fromY = offsetY + (previewFromRow! - minRow) * cellSize * 1.5 + cellSize / 2;
      final toX = offsetX + (previewToCol! - minCol) * cellSize + cellSize / 2;
      final toY = offsetY + (previewToRow! - minRow) * cellSize * 1.5 + cellSize / 2;
      
      // 绘制预览箭头
      final previewArrowPaint = Paint()
        ..color = Colors.orange.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      
      canvas.drawLine(
        Offset(fromX, fromY),
        Offset(toX, toY),
        previewArrowPaint,
      );
      
      // 绘制预览目标位置的高亮
      final previewHighlightPaint = Paint()
        ..color = Colors.orange.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(toX, toY), cellSize * 0.6, previewHighlightPaint);
      
      // 绘制预览目标位置的边框
      final previewBorderPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(toX, toY), cellSize * 0.6, previewBorderPaint);
    }
  }

  Color _getPieceColor(String color) {
    switch (color) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow;
      case 'blue': return Colors.blue;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      default: return Colors.grey;
    }
  }

  List<Map<String, int>> _getValidPositions() {
    // 返回所有有效位置的坐标列表
    final positions = <Map<String, int>>[];
    
    // 标准中国跳棋棋盘的有效位置 - 基于六角星布局
    final validPositionStrings = {
      // 上方三角形区域（红方起始位置）- 倒三角形
      '0,12',
      '1,11', '1,13',
      '2,10', '2,12', '2,14',
      '3,9',  '3,11', '3,13', '3,15',
      
      // 左上三角形区域（绿方起始位置）- 倒三角形
      '4,0', '4,2', '4,4', '4,6',
      '5,1', '5,3', '5,5',
      '6,2', '6,4',
      '7,3',
      
      // 右上三角形区域（黄方起始位置）- 倒三角形
      '4,18', '4,20', '4,22', '4,24',
      '5,19', '5,21', '5,23',
      '6,20', '6,22',
      '7,21',
      
      // 中心区域 - 六角星中心
      '4,8',  '4,10', '4,12',  '4,14',  '4,16',
      '5,7',  '5,9',  '5,11',  '5,13',  '5,15',  '5,17',
      '6,6',  '6,8',  '6,10',  '6,12',  '6,14',  '6,16',  '6,18',
      '7,5',  '7,7',  '7,9',   '7,11',  '7,13',  '7,15',  '7,17', '7,19',
      '8,4',  '8,6',  '8,8',   '8,10',  '8,12',  '8,14',  '8,16', '8,18', '8,20',
      '9,5',  '9,7',  '9,9',   '9,11',  '9,13',  '9,15',  '9,17', '9,19',
      '10,6', '10,8', '10,10', '10,12', '10,14', '10,16', '10,18',
      '11,7', '11,9', '11,11', '11,13', '11,15', '11,17',
      '12,8', '12,10', '12,12', '12,14', '12,16', 
      
      // 下方三角形区域（蓝方起始位置）- 正三角形
      '13,9',  '13,11', '13,13', '13,15',
      '14,10', '14,12', '14,14',
      '15,11', '15,13',
      '16,12',
      
      // 右下三角形区域（橙方起始位置）- 正三角形
      '9,21',
      '10,20', '10,22',
      '11,19', '11,21', '11,23',
      '12,18', '12,20', '12,22', '12,24',
      
      // 左下三角形区域（紫方起始位置）- 正三角形
      '9,3',
      '10,2', '10,4',
      '11,1', '11,3', '11,5',
      '12,0', '12,2', '12,4', '12,6'
    };
    
    for (final posStr in validPositionStrings) {
      final parts = posStr.split(',');
      positions.add({
        'row': int.parse(parts[0]),
        'col': int.parse(parts[1]),
      });
    }
    
    return positions;
  }
  
  bool _isValidPosition(int row, int col) {
    return _getValidPositions().any((pos) => pos['row'] == row && pos['col'] == col);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}