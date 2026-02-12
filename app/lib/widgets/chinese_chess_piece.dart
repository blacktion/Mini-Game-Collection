import 'package:flutter/material.dart';

class ChessPiece {
  final String name;
  final String type;  // 'rook', 'knight', 'bishop', 'advisor', 'king', 'cannon', 'pawn'
  final String color;  // 'red', 'black'
  
  const ChessPiece({
    required this.name,
    required this.type,
    required this.color,
  });
}

class ChessPieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final double size;
  final VoidCallback? onTap;
  
  const ChessPieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRed = piece.color == 'red';
    final color = isRed ? Colors.red[700] : Colors.black;
    final bgColor = isRed ? Colors.red[50] : Colors.grey[200];
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: color!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            piece.name,
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyPieceWidget extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  
  const EmptyPieceWidget({
    super.key,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        color: Colors.transparent,
      ),
    );
  }
}
