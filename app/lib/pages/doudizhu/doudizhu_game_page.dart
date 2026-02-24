import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config.dart';
import '../../widgets/doudizhu_playing_card.dart';
import '../../widgets/doudizhu_hand_widget.dart';

class DoudizhuGamePage extends StatefulWidget {
  final String? roomId;

  const DoudizhuGamePage({super.key, this.roomId});

  @override
  State<DoudizhuGamePage> createState() => _DoudizhuGamePageState();
}

class _DoudizhuGamePageState extends State<DoudizhuGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  bool _isConnected = false;
  bool _isWaitingForOpponents = false;
  bool _isChoosingLandlord = false;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // 游戏数据
  int _myPlayerNumber = 0; // 1, 2, 3
  List<PlayingCard> _myCards = [];
  List<PlayingCard> _landlordCards = []; // 底牌
  Set<int> _selectedCardIndices = {};

  // 出牌记录
  List<PlayingCard>? _lastPlayedCards;
  int? _lastPlayedPlayer;
  String? _gameMessage;

  // 地主信息
  int? _landlordPlayer;

  @override
  void initState() {
    super.initState();
    _setLandscapeMode();
    _initSocket();
  }

  // 设置横屏
  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // 恢复竖屏
  void _setPortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void _initSocket() {
    const String serverUrl = serverUrlConfig;

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setReconnectionAttempts(3)
          .setReconnectionDelay(1000)
          .setTimeout(5000)
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      print('Connected to server: ${_socket.id}');
      if (!mounted) return;

      setState(() => _isConnected = true);

      if (widget.roomId == null) {
        print('Emitting create_room...');
        _socket.emit('create_room', {'game_type': 'doudizhu'});
      } else {
        print('Emitting join_room: ${widget.roomId}');
        _socket.emit('join_room', {'room_id': widget.roomId, 'game_type': 'doudizhu'});
      }
    });

    _socket.onConnectError((data) {
      print('Connection error: $data');
      if (!mounted) return;
      setState(() => _isConnected = false);
    });

    _socket.onConnectTimeout((data) {
      print('Connection timeout: $data');
      if (!mounted) return;
      setState(() => _isConnected = false);
    });

    _socket.onError((data) {
      print('Socket error: $data');
    });

    _socket.onDisconnect((_) {
      print('Disconnected from server');
      if (!mounted) return;
      setState(() => _isConnected = false);
    });

    _socket.on('connected', (data) {
      print('Received connected event: $data');
      if (!mounted) return;
    });

    _socket.on('room_created', (data) {
      print('Room created: ${data['room_id']}');
      if (!mounted) return;
      setState(() {
        _myRoomId = data['room_id'];
        _isWaitingForOpponents = true;
      });
    });

    _socket.on('room_joined', (data) {
      print('Room joined: ${data['room_id']}');
      if (!mounted) return;
      setState(() {
        _myRoomId = data['room_id'];
        _myPlayerNumber = data['player_number'];
        _isWaitingForOpponents = true;
      });
    });

    _socket.on('game_start', (data) {
      print('Game started');
      if (!mounted) return;
      setState(() {
        _isWaitingForOpponents = false;
        _isChoosingLandlord = true;
        _gameMessage = data['message'];
        // 收到初始手牌
        if (data['my_cards'] != null) {
          _myCards = (data['my_cards'] as List)
              .map((json) => PlayingCard.fromJson(json))
              .toList();
          _sortCards();
        }
      });
    });

    _socket.on('landlord_chosen', (data) {
      if (!mounted) return;
      setState(() {
        _landlordPlayer = data['landlord_player'];
        _isChoosingLandlord = false;
        _isPlaying = true;
        // 收到底牌
        if (data['landlord_cards'] != null && data['my_cards'] != null) {
          _landlordCards = (data['landlord_cards'] as List)
              .map((json) => PlayingCard.fromJson(json))
              .toList();
          _myCards = (data['my_cards'] as List)
              .map((json) => PlayingCard.fromJson(json))
              .toList();
          _sortCards();
        }
      });
    });

    _socket.on('cards_played', (data) {
      if (!mounted) return;
      setState(() {
        _lastPlayedPlayer = data['player_number'];
        if (data['cards'] != null) {
          _lastPlayedCards = (data['cards'] as List)
              .map((json) => PlayingCard.fromJson(json))
              .toList();
        } else {
          _lastPlayedCards = null;
        }
      });
    });

    _socket.on('cards_removed', (data) {
      if (!mounted) return;
      setState(() {
        // 更新手牌
        if (data['my_cards'] != null) {
          _myCards = (data['my_cards'] as List)
              .map((json) => PlayingCard.fromJson(json))
              .toList();
          _sortCards();
        }
      });
    });

    _socket.on('game_over', (data) {
      if (!mounted) return;
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _gameMessage = data['message'];
      });
    });

    _socket.on('player_disconnected', (data) {
      if (!mounted) return;
      setState(() {
        _gameMessage = data['message'];
        _isPlaying = false;
        _isGameOver = true;
      });
    });
  }

  // 排序手牌(从大到小)
  void _sortCards() {
    _myCards.sort((a, b) => b.value.compareTo(a.value));
    setState(() {});
  }

  // 选择/取消选择牌
  void _toggleCardSelection(int index) {
    setState(() {
      if (_selectedCardIndices.contains(index)) {
        _selectedCardIndices.remove(index);
      } else {
        _selectedCardIndices.add(index);
      }
    });
  }

  // 叫地主
  void _callLandlord() {
    _socket.emit('choose_landlord', {
      'room_id': _myRoomId,
      'player_number': _myPlayerNumber,
      'call': true,
    });
  }

  // 不叫地主
  void _passLandlord() {
    _socket.emit('choose_landlord', {
      'room_id': _myRoomId,
      'player_number': _myPlayerNumber,
      'call': false,
    });
  }

  // 出牌
  void _playCards() {
    if (_selectedCardIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择要出的牌')),
      );
      return;
    }

    final selectedCards = _selectedCardIndices.map((index) => _myCards[index]).toList();

    _socket.emit('play_cards', {
      'room_id': _myRoomId,
      'player_number': _myPlayerNumber,
      'cards': selectedCards.map((card) => card.toJson()).toList(),
    });

    setState(() {
      _selectedCardIndices.clear();
    });
  }

  // 不出牌
  void _pass() {
    _socket.emit('pass_turn', {
      'room_id': _myRoomId,
      'player_number': _myPlayerNumber,
    });
  }

  // 清理Socket连接
  void _cleanup() {
    _socket.clearListeners();
    _socket.disconnect();
    _setPortraitMode();
  }

  // 显示退出确认对话框
  void _showLeaveConfirmDialog() {
    // 游戏结束时不需要确认
    if (_isGameOver) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出当前对局吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cleanup();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在连接服务器...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isWaitingForOpponents) {
      return Scaffold(
        appBar: AppBar(
          title: Text('房间号: $_myRoomId'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                '等待其他玩家加入...',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 16),
              Text(
                '房间号: $_myRoomId',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isGameOver) {
      return Scaffold(
        appBar: AppBar(
          title: Text('房间号: $_myRoomId'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.celebration,
                  size: 80,
                  color: _gameMessage?.contains('胜利') == true ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _gameMessage ?? '游戏结束',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home),
                  label: const Text('返回大厅'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showLeaveConfirmDialog();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2E7D32), // 绿色桌面背景
        body: SafeArea(
          child: Column(
            children: [
              // 顶部信息栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text('房间号: $_myRoomId'),
                          const SizedBox(width: 16),
                          Text('我是玩家$_myPlayerNumber'),
                          if (_landlordPlayer != null) ...[
                            const SizedBox(width: 16),
                            const Text('地主: '),
                            Text(
                              '玩家$_landlordPlayer',
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.exit_to_app),
                      onPressed: _showLeaveConfirmDialog,
                    ),
                  ],
                ),
              ),

            // 上方玩家信息
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPlayerInfo(2),
                  _buildPlayerInfo(3),
                ],
              ),
            ),

            // 出牌区
            Expanded(
              child: Center(
                child: _lastPlayedCards != null
                    ? DoudizhuPlayedCardsWidget(
                        playerName: '玩家$_lastPlayedPlayer',
                        cards: _lastPlayedCards!,
                        isLandlord: _lastPlayedPlayer == _landlordPlayer,
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _gameMessage ?? '等待出牌...',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
              ),
            ),

            // 底牌
            if (_landlordCards.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '底牌: ',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _landlordCards.map((card) {
                        return Padding(
                          padding: const EdgeInsets.only(right: -20),
                          child: PlayingCardWidget(
                            card: card,
                            isVertical: false,
                            width: 40,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            // 底部操作区
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (_isChoosingLandlord)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _callLandlord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: const Text('叫地主', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _passLandlord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: const Text('不叫', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  if (_isPlaying)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _playCards,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: const Text('出牌', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _pass,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: const Text('不出', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // 我的手牌
                  DoudizhuHandWidget(
                    cards: _myCards,
                    selectedIndices: _selectedCardIndices,
                    onCardTap: _toggleCardSelection,
                    isHorizontal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // 构建玩家信息
  Widget _buildPlayerInfo(int playerNumber) {
    final isLandlord = playerNumber == _landlordPlayer;
    final isMe = playerNumber == _myPlayerNumber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLandlord ? Colors.amber.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLandlord ? Colors.amber : Colors.grey,
          width: isLandlord ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMe ? '我' : '玩家$playerNumber',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (isLandlord) ...[
            const SizedBox(width: 4),
            const Icon(Icons.stars, size: 16, color: Colors.amber),
          ],
        ],
      ),
    );
  }
}
