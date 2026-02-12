import 'package:flutter/material.dart';
import '../widgets/game_type_card.dart';
import 'board_game_selection_page.dart';
import 'card_game_selection_page.dart';

class GameTypeSelectionPage extends StatelessWidget {
  const GameTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏大厅'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            GameTypeCard(
              icon: Icons.grid_on,
              title: '棋类游戏',
              subtitle: '五子棋、中国象棋、围棋等',
              color: Colors.brown,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BoardGameSelectionPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            GameTypeCard(
              icon: Icons.casino,
              title: '牌类游戏',
              subtitle: '斗地主等',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CardGameSelectionPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            GameTypeCard(
              icon: Icons.sports_esports,
              title: '其他游戏',
              subtitle: '即将推出',
              color: Colors.green,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('其他游戏即将推出，敬请期待！')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
