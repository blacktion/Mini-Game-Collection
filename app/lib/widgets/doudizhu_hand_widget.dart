import 'package:flutter/material.dart';
import 'doudizhu_playing_card.dart';

// 手牌显示组件
class DoudizhuHandWidget extends StatelessWidget {
  final List<PlayingCard> cards;
  final Set<int> selectedIndices;
  final Function(int index)? onCardTap;
  final bool isHorizontal;
  final bool showOpponent;

  const DoudizhuHandWidget({
    super.key,
    required this.cards,
    required this.selectedIndices,
    this.onCardTap,
    this.isHorizontal = true,
    this.showOpponent = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showOpponent) {
      // 对手手牌(只显示背面)
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            cards.length,
            (index) => Padding(
              padding: EdgeInsets.only(right: index < cards.length - 1 ? -40 : 0),
              child: const CardBackWidget(width: 50, height: 70),
            ),
          ),
        ),
      );
    }

    if (cards.isEmpty) {
      return Container(
        height: isHorizontal ? 90 : 100,
        alignment: Alignment.center,
        child: const Text(
          '无牌',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // 自己的手牌
    final cardWidth = isHorizontal ? 50.0 : 60.0;

    return Container(
      height: isHorizontal ? 90 : 100,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: cards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;
            final isSelected = selectedIndices.contains(index);

            return Padding(
              padding: EdgeInsets.only(
                right: index < cards.length - 1 ? -25 : 0,
              ),
              child: PlayingCardWidget(
                card: card,
                isVertical: !isHorizontal,
                isSelected: isSelected,
                width: cardWidth,
                onTap: onCardTap != null ? () => onCardTap!(index) : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// 出牌区组件
class DoudizhuPlayedCardsWidget extends StatelessWidget {
  final String playerName;
  final List<PlayingCard> cards;
  final String? actionText;
  final bool isLandlord;

  const DoudizhuPlayedCardsWidget({
    super.key,
    required this.playerName,
    required this.cards,
    this.actionText,
    this.isLandlord = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isLandlord) ...[
                const SizedBox(width: 4),
                const Icon(Icons.stars, size: 16, color: Colors.amber),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (actionText != null && cards.isEmpty)
            Text(
              actionText!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            )
          else if (cards.isEmpty)
            const Text(
              '等待出牌...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            )
          else
            SizedBox(
              height: 80,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: cards.map((card) {
                    return Padding(
                      padding: const EdgeInsets.only(right: -20),
                      child: PlayingCardWidget(
                        card: card,
                        isVertical: false,
                        width: 45,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
