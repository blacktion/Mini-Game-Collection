import 'package:flutter/material.dart';
import 'dart:math';
import 'chinese_checkers_board_painter.dart';

class ChineseCheckersBoardWidget extends StatefulWidget {
  final List<List<Map<String, dynamic>?>> board;
  final int? selectedRow;
  final int? selectedCol;
  final List<Map<String, int>> lastMovePath;
  final Function(int, int) onTap;
  final String myColor;
  final String currentPlayerColor;
  final int? previewFromRow;
  final int? previewFromCol;
  final int? previewToRow;
  final int? previewToCol;

  const ChineseCheckersBoardWidget({
    super.key,
    required this.board,
    this.selectedRow,
    this.selectedCol,
    this.lastMovePath = const [],
    required this.onTap,
    required this.myColor,
    required this.currentPlayerColor,
    this.previewFromRow,
    this.previewFromCol,
    this.previewToRow,
    this.previewToCol,
  });

  @override
  State<ChineseCheckersBoardWidget> createState() => _ChineseCheckersBoardWidgetState();
}

class _ChineseCheckersBoardWidgetState extends State<ChineseCheckersBoardWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算适合25列的宽度和17行的高度
        double availableWidth = constraints.maxWidth;
        double availableHeight = constraints.maxHeight;
        
        // 优化的自适应计算 - 确保所有棋子完整显示
        // 设置合理的单元格大小范围
        double minCellSize = 12.0;  // 减小最小尺寸
        double maxCellSize = 35.0;  // 增大最大尺寸
        
        // 计算有效可用空间
        double effectiveWidth = availableWidth - 16; // 减去左右padding
        double effectiveHeight = availableHeight - 16; // 减去上下padding
        
        // 获取实际需要显示的有效位置边界
        final validPositions = _getValidPositions();
        if (validPositions.isEmpty) {
          return Container();
        }
        
        int minRow = validPositions.map((p) => p['row']!).reduce((a, b) => a < b ? a : b);
        int maxRow = validPositions.map((p) => p['row']!).reduce((a, b) => a > b ? a : b);
        int minCol = validPositions.map((p) => p['col']!).reduce((a, b) => a < b ? a : b);
        int maxCol = validPositions.map((p) => p['col']!).reduce((a, b) => a > b ? a : b);
        
        // 基于实际内容计算最优单元格大小
        int colCount = maxCol - minCol + 1;
        int rowCount = maxRow - minRow + 1;
        
        // 计算两种约束下的单元格大小
        double cellSizeByWidth = effectiveWidth / colCount;
        double cellSizeByHeight = effectiveHeight / (rowCount * 1.5); // 考虑垂直间距
        
        // 选择较小的值以确保完整显示
        double cellSize = min(cellSizeByWidth, cellSizeByHeight);
        
        // 应用大小限制
        cellSize = cellSize.clamp(minCellSize, maxCellSize);
        
        // 使用前面已经计算好的边界值
        
        double contentWidth = (maxCol - minCol + 1) * cellSize;
        double contentHeight = (maxRow - minRow + 1) * cellSize * 1.5;
        
        double boardWidth = contentWidth;
        double boardHeight = contentHeight;
        
        return GestureDetector(
          onTapUp: (details) {
            // 精确的点击检测 - 基于棋子实际绘制位置和大小
            final local = details.localPosition;
            
            // 遍历所有有效位置，检查点击是否在棋子范围内
            for (final pos in validPositions) {
              final row = pos['row']!;
              final col = pos['col']!;
              
              // 计算该位置棋子的中心坐标（与painter中保持一致）
              final centerX = (col - minCol) * cellSize + cellSize / 2;
              final centerY = (row - minRow) * cellSize * 1.5 + cellSize / 2;
              
              // 棋子实际绘制半径（与painter中保持一致）
              final pieceRadius = cellSize * 0.55;
              
              // 计算点击点到棋子中心的距离
              final dx = local.dx - centerX;
              final dy = local.dy - centerY;
              final distance = sqrt(dx * dx + dy * dy);
              
              // 如果点击在棋子范围内
              if (distance <= pieceRadius) {
                widget.onTap(row, col);
                return;
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4), // 减少内边距以增加显示空间
            width: boardWidth,
            height: boardHeight,
            child: CustomPaint(
              painter: ChineseCheckersBoardPainter(
                board: widget.board,
                selectedRow: widget.selectedRow,
                selectedCol: widget.selectedCol,
                lastMovePath: widget.lastMovePath,
                myColor: widget.myColor,
                currentPlayerColor: widget.currentPlayerColor,
                cellSize: cellSize,
                previewFromRow: widget.previewFromRow,
                previewFromCol: widget.previewFromCol,
                previewToRow: widget.previewToRow,
                previewToCol: widget.previewToCol,
              ),
            ),
          ),
        );
      },
    );
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
}