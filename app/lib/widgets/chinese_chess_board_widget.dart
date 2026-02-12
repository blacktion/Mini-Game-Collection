import 'package:flutter/material.dart';
import 'chinese_chess_piece.dart';
import 'chinese_chess_board_painter.dart';

class ChineseChessBoard extends StatelessWidget {
  final List<List<ChessPiece?>> board;
  final Function(int, int)? onTap;
  final int? selectedRow;
  final int? selectedCol;
  final int? lastMoveFromRow;
  final int? lastMoveFromCol;
  final int? lastMoveToRow;
  final int? lastMoveToCol;
  final List<Map<String, int>> possibleMoves;
  final bool isRotated;

  const ChineseChessBoard({
    super.key,
    required this.board,
    this.onTap,
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
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 10,  // 9列10行，保持正方形格子
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardWidth = constraints.maxWidth;
          final boardHeight = constraints.maxHeight;
          
          // 确保正方形格子
          final cellSize = (boardWidth / 9) < (boardHeight / 10) ? (boardWidth / 9) : (boardHeight / 10);
          final cellWidth = cellSize;
          final cellHeight = cellSize;
          
          // 居中棋盘，边缘各留半个单元格的空白
          final startX = (boardWidth - 8 * cellWidth) / 2;
          final startY = (boardHeight - 9 * cellHeight) / 2;
          final pieceSize = cellSize * 0.9;

          return Stack(
            children: [
              // 棋盘背景
              Container(
                decoration: BoxDecoration(
                  color: Colors.brown[100],
                  border: Border.all(
                    color: Colors.brown[800]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  size: Size(boardWidth, boardHeight),
                  painter: ChineseChessBoardPainter(
                    selectedRow: selectedRow,
                    selectedCol: selectedCol,
                    lastMoveFromRow: lastMoveFromRow,
                    lastMoveFromCol: lastMoveFromCol,
                    lastMoveToRow: lastMoveToRow,
                    lastMoveToCol: lastMoveToCol,
                    possibleMoves: possibleMoves,
                    isRotated: isRotated,
                  ),
                ),
              ),
              // 棋子
              ..._buildPieces(cellWidth, cellHeight, pieceSize, startX, startY),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPieces(double cellWidth, double cellHeight, double pieceSize, double startX, double startY) {
    List<Widget> pieces = [];

    for (int row = 0; row < 10; row++) {
      for (int col = 0; col < 9; col++) {
        final piece = board[row][col];
        
        // 根据视角计算物理位置
        int displayRow = isRotated ? 9 - row : row;
        int displayCol = isRotated ? 8 - col : col;

        final left = displayCol * cellWidth + startX - pieceSize / 2;
        final top = displayRow * cellHeight + startY - pieceSize / 2;
        
        if (piece != null) {
          pieces.add(
            Positioned(
              left: left,
              top: top,
              child: ChessPieceWidget(
                piece: piece,
                size: pieceSize,
                onTap: onTap != null ? () => onTap!(row, col) : null,
              ),
            ),
          );
        } else if (onTap != null) {
          pieces.add(
            Positioned(
              left: left,
              top: top,
              child: EmptyPieceWidget(
                size: pieceSize,
                onTap: () => onTap!(row, col),
              ),
            ),
          );
        }
      }
    }
    
    return pieces;
  }

  // 移除坐标标注生成函数
}
