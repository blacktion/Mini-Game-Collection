import 'package:flutter/material.dart';
import 'doudizhu_game_page.dart';

class DoudizhuHomePage extends StatefulWidget {
  const DoudizhuHomePage({super.key});

  @override
  State<DoudizhuHomePage> createState() => _DoudizhuHomePageState();
}

class _DoudizhuHomePageState extends State<DoudizhuHomePage> {
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
        builder: (context) => DoudizhuGamePage(roomId: null),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }).catchError((error) {
      if (mounted) {
        setState(() => _isCreating = false);
      }
      print('Error navigating to game page: $error');
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
        builder: (context) => DoudizhuGamePage(roomId: _controller.text.trim()),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }).catchError((error) {
      if (mounted) {
        setState(() => _isJoining = false);
      }
      print('Error navigating to game page: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('斗地主'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.style,
                size: 100,
                color: Colors.orange,
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
