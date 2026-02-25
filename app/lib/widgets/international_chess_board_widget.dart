import 'package:flutter/material.dart';

class InternationalChessBoardWidget extends StatefulWidget {
  final List<List<int>> board;
  final Function(int fromRow, int fromCol, int toRow, int toCol)? onMove;
  final int? lastMoveFromRow;
  final int? lastMoveFromCol;
  final int? lastMoveToRow;
  final int? lastMoveToCol;

  const InternationalChessBoardWidget({
    super.key,
    required this.board,
    this.onMove,
    this.lastMoveFromRow,
    this.lastMoveFromCol,
    this.lastMoveToRow,
    this.lastMoveToCol,
  });

  @override
  State<InternationalChessBoardWidget> createState() => _InternationalChessBoardWidgetState();
}

class _InternationalChessBoardWidgetState extends State<InternationalChessBoardWidget> {
  int? _selectedRow;
  int? _selectedCol;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown[900]!, width: 4),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final col = index % 8;
            final piece = widget.board[row][col];
            final isLightSquare = (row + col) % 2 == 1;

            final isSelected = _selectedRow == row && _selectedCol == col;
            final isLastMoveFrom = widget.lastMoveFromRow == row && widget.lastMoveFromCol == col;
            final isLastMoveTo = widget.lastMoveToRow == row && widget.lastMoveToCol == col;

            Color backgroundColor;
            if (isSelected) {
              backgroundColor = Colors.yellow;
            } else if (isLastMoveFrom || isLastMoveTo) {
              backgroundColor = Colors.lightBlue;
            } else {
              backgroundColor = isLightSquare ? Colors.brown[300]! : Colors.brown[800]!;
            }

            return GestureDetector(
              onTap: () => _handleTap(row, col),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                ),
                child: piece != 0
                    ? Center(
                        child: _buildPiece(piece),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPiece(int piece) {
    final isWhite = piece > 0;
    final absPiece = piece.abs();

    String pieceChar;
    Color color;

    switch (absPiece) {
      case 1: // King
        pieceChar = '♔';
        break;
      case 2: // Queen
        pieceChar = '♕';
        break;
      case 3: // Rook
        pieceChar = '♖';
        break;
      case 4: // Bishop
        pieceChar = '♗';
        break;
      case 5: // Knight
        pieceChar = '♘';
        break;
      case 6: // Pawn
        pieceChar = '♙';
        break;
      default:
        pieceChar = '';
    }

    color = isWhite ? Colors.white : Colors.black;

    // Use text with proper styling
    return Text(
      pieceChar,
      style: TextStyle(
        fontSize: 32,
        color: color,
        shadows: [
          Shadow(
            color: isWhite ? Colors.black : Colors.white,
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }

  void _handleTap(int row, int col) {
    if (widget.onMove == null) return;

    final piece = widget.board[row][col];

    // If a piece is already selected
    if (_selectedRow != null && _selectedCol != null) {
      // If tapping on the same piece, deselect
      if (_selectedRow == row && _selectedCol == col) {
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
        });
        return;
      }

      // If tapping on own piece, select that instead
      final selectedPiece = widget.board[_selectedRow!][_selectedCol!];
      final isMyPiece = (selectedPiece > 0 && piece > 0) || (selectedPiece < 0 && piece < 0);

      if (isMyPiece) {
        setState(() {
          _selectedRow = row;
          _selectedCol = col;
        });
        return;
      }

      // Move the selected piece
      widget.onMove!(_selectedRow!, _selectedCol!, row, col);
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
      });
    } else {
      // Select a piece if it belongs to the current player
      if (piece != 0) {
        setState(() {
          _selectedRow = row;
          _selectedCol = col;
        });
      }
    }
  }
}
