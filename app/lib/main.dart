import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/game_type_selection_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const GobangApp());
}

class GobangApp extends StatelessWidget {
  const GobangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '游戏大厅',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const GameTypeSelectionPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
