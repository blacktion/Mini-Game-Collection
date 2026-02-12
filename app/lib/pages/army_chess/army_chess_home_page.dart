import 'package:flutter/material.dart';
import 'army_chess_game_page.dart';

class ArmyChessHomePage extends StatefulWidget {
  const ArmyChessHomePage({super.key});

  @override
  State<ArmyChessHomePage> createState() => _ArmyChessHomePageState();
}

class _ArmyChessHomePageState extends State<ArmyChessHomePage> {
  final _controller = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _createRoom() {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArmyChessGamePage(roomId: null),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }).catchError((error) {
      if (mounted) {
        setState(() => _isCreating = false);
      }
      // 导航错误
    });
  }

  void _joinRoom() {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入房间号')),
      );
      return;
    }
    
    if (_isJoining) return;
    
    setState(() => _isJoining = true);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArmyChessGamePage(
          roomId: _controller.text.trim(),
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }).catchError((error) {
      if (mounted) {
        setState(() => _isJoining = false);
      }
      // 导航错误
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('布阵军旗'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag,
                size: 100,
                color: Colors.green[700],
              ),
              const SizedBox(height: 48),
              const Text(
                '布阵军旗',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: '房间号',
                  hintText: '输入房间号加入游戏',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room),
                ),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreating || _isJoining ? null : _createRoom,
                  icon: const Icon(Icons.add),
                  label: const Text('创建房间'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCreating || _isJoining ? null : _joinRoom,
                  icon: const Icon(Icons.login),
                  label: const Text('加入房间'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: Colors.green[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '创建房间后，将房间号分享给好友即可开始对战',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
