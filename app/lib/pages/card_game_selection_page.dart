import 'package:flutter/material.dart';
import '../widgets/card_game_card.dart';
import 'doudizhu/doudizhu_home_page.dart';

class CardGameSelectionPage extends StatelessWidget {
  const CardGameSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('牌类游戏'),
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
              CardGameCard(
                icon: Icons.style,
                title: '斗地主',
                subtitle: '经典三人对战牌类游戏',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoudizhuHomePage(),
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
