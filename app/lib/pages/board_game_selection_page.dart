import 'package:flutter/material.dart';
import '../widgets/board_game_card.dart';
import 'gobang/gobang_home_page.dart';
import 'chinese_chess/chinese_chess_home_page.dart';
import 'go/go_home_page.dart';
import 'army_chess/army_chess_home_page.dart';
import 'othello/othello_home_page.dart';
import 'chinese_checkers/chinese_checkers_home_page.dart';

class BoardGameSelectionPage extends StatelessWidget {
  const BoardGameSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('棋类游戏'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              BoardGameCard(
                icon: Icons.circle_outlined,
                title: '五子棋',
                subtitle: '经典策略游戏，五子连珠即可获胜',
                color: Colors.brown,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GobangHomePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BoardGameCard(
                icon: Icons.crop_square,
                title: '中国象棋',
                subtitle: '经典策略游戏',
                color: Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChineseChessHomePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BoardGameCard(
                icon: Icons.radio_button_unchecked,
                title: '围棋',
                subtitle: '经典策略游戏，黑白博弈',
                color: Colors.black,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoHomePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BoardGameCard(
                icon: Icons.flag,
                title: '布阵军旗',
                subtitle: '经典策略游戏，布阵对战',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ArmyChessHomePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BoardGameCard(
                icon: Icons.flip,
                title: '黑白棋',
                subtitle: '翻转策略游戏，黑白博弈',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OthelloHomePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BoardGameCard(
                icon: Icons.star,
                title: '中国跳棋',
                subtitle: '六角星棋盘，2-6人对战',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChineseCheckersHomePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

