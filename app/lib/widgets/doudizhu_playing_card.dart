import 'package:flutter/material.dart';

// 扑克牌类
class PlayingCard {
  final int rank;      // 3-15 (3-K, 14=A, 15=2)
  final int suit;      // 0=方块, 1=梅花, 2=红桃, 3=黑桃
  final int value;     // 用于比较大小的值

  PlayingCard({required this.rank, required this.suit})
      : value = rank;

  // 获取牌面显示
  String get displayRank {
    const ranks = ['3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2'];
    if (rank >= 3 && rank <= 15) {
      return ranks[rank - 3];
    }
    return '?';
  }

  // 获取花色符号
  String get suitSymbol {
    const suits = ['♦', '♣', '♥', '♠'];
    return suits[suit];
  }

  // 是否红色花色
  bool get isRed => suit == 0 || suit == 2;

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {'rank': rank, 'suit': suit};
  }

  // 从JSON创建
  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(rank: json['rank'], suit: json['suit']);
  }
}

// 扑克牌Widget
class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool isVertical;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isVertical = false,
    this.isSelected = false,
    this.onTap,
    this.width = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: isVertical ? width * 1.4 : width * 1.3,
        margin: EdgeInsets.only(
          bottom: isSelected ? 10 : 0,
          right: isVertical ? 0 : -25,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  card.displayRank,
                  style: TextStyle(
                    fontSize: isVertical ? width * 0.25 : width * 0.22,
                    fontWeight: FontWeight.bold,
                    color: card.isRed ? Colors.red : Colors.black,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  card.suitSymbol,
                  style: TextStyle(
                    fontSize: isVertical ? width * 0.35 : width * 0.3,
                    color: card.isRed ? Colors.red : Colors.black,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Transform.rotate(
                  angle: 3.14159,
                  child: Text(
                    card.displayRank,
                    style: TextStyle(
                      fontSize: isVertical ? width * 0.25 : width * 0.22,
                      fontWeight: FontWeight.bold,
                      color: card.isRed ? Colors.red : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 底牌Widget(背面)
class CardBackWidget extends StatelessWidget {
  final double width;
  final double height;

  const CardBackWidget({
    super.key,
    this.width = 60,
    this.height = 84,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.style,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
