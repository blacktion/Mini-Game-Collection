import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config.dart';
import '../../widgets/go_board_widget.dart';

class GoGamePage extends StatefulWidget {
  final String? roomId;
  
  const GoGamePage({super.key, this.roomId});

  @override
  State<GoGamePage> createState() => _GoGamePageState();
}

class _GoGamePageState extends State<GoGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  String? _mySid;
  String? _playerColor;
  bool _isConnected = false;
  bool _isWaitingForOpponent = false;
  bool _isChoosingColor = false;
  bool _isPlaying = false;
  bool _isGameOver = false;

  List<List<int>> _board = List.generate(19, (_) => List.filled(19, 0));
  int _currentPlayer = 1;  // 1:黑 2:白
  String? _winner;
  String? _gameMessage;
  int _myPlayerNumber = 0;
  String _myChoice = '';

  int? _previewRow;
  int? _previewCol;

  // 记录最后一步棋的位置
  int? _lastMoveRow;
  int? _lastMoveCol;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    final String serverUrl = serverUrlConfig;

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
        _socket.emit('create_room', {'game_type': 'go'});
      } else {
        _socket.emit('join_room', {'room_id': widget.roomId, 'game_type': 'go'});
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
      if (!mounted) return;
      setState(() => _mySid = data['sid']);
    });

    _socket.on('room_created', (data) {
      if (!mounted) return;
      setState(() {
        _myRoomId = data['room_id'];
        _isWaitingForOpponent = true;
      });
    });

    _socket.on('room_joined', (data) {
      setState(() {
        _myRoomId = data['room_id'];
        _playerColor = data['player_color'];
        _myPlayerNumber = data['player_color'] == 'black' ? 1 : 2;
        _isWaitingForOpponent = true;
      });
    });

    _socket.on('waiting_for_choices', (data) {
      setState(() {
        _isWaitingForOpponent = false;
        _isChoosingColor = true;
        _gameMessage = data['message'];
      });
    });

    _socket.on('game_start', (data) {
      setState(() {
        _isChoosingColor = false;
        _isPlaying = true;
        _gameMessage = data['message'];
        
        if (data['player_color'] == 'black') {
          _myPlayerNumber = 1;
          _playerColor = 'black';
        } else {
          _myPlayerNumber = 2;
          _playerColor = 'white';
        }
      });
    });

    _socket.on('move_made', (data) {
      setState(() {
        _board[data['row']][data['col']] = data['player'];
        _lastMoveRow = data['row'];
        _lastMoveCol = data['col'];
        _currentPlayer = data['player'] == 1 ? 2 : 1;
        
        // 处理被吃掉的子
        if (data['captured'] != null) {
          List<dynamic> captured = data['captured'];
          for (var pos in captured) {
            int capturedRow = pos[0];
            int capturedCol = pos[1];
            _board[capturedRow][capturedCol] = 0;  // 移除被吃掉的子
          }
        }
      });
    });

    _socket.on('turn_changed', (data) {
      setState(() => _currentPlayer = data['current_player']);
    });

    _socket.on('game_over', (data) {
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _winner = data['winner'] == 1 ? 'black' : data['winner'] == 2 ? 'white' : null;
        _gameMessage = data['message'];
      });
    });

    _socket.on('reset_game', (data) {
      setState(() {
        _board = List.generate(19, (_) => List.filled(19, 0));
        _currentPlayer = 1;
        _isGameOver = false;
        _isPlaying = false;
        _winner = null;
        _isChoosingColor = true;
        _myChoice = '';
        _gameMessage = data['message'];
      });
    });

    _socket.on('player_disconnected', (data) {
      setState(() {
        _gameMessage = data['message'];
        _isPlaying = false;
        _isGameOver = true;
      });
    });
  }

  void _chooseColor(String choice) {
    setState(() => _myChoice = choice);
    _socket.emit('choose_color', {
      'room_id': _myRoomId,
      'choice': choice,
    });
  }

  void _handleTap(int row, int col) {
    if (!_isPlaying || _isGameOver) return;
    if (_currentPlayer != _myPlayerNumber) return;
    if (_board[row][col] != 0) return;

    setState(() {
      _previewRow = row;
      _previewCol = col;
    });
  }

  void _confirmMove() {
    if (_previewRow == null || _previewCol == null) return;

    _socket.emit('make_move', {
      'room_id': _myRoomId,
      'row': _previewRow,
      'col': _previewCol,
    });

    setState(() {
      _previewRow = null;
      _previewCol = null;
    });
  }

  void _cancelMove() {
    setState(() {
      _previewRow = null;
      _previewCol = null;
    });
  }

  void _handleTapUp(int row, int col) {
    setState(() {
      _previewRow = null;
      _previewCol = null;
    });
  }

  void _leaveRoom() {
    if (_myRoomId != null) {
      _socket.emit('leave_room', {'room_id': _myRoomId});
    }

    try {
      _socket.clearListeners();
      _socket.disconnect();
      _socket.dispose();
    } catch (e) {
      print('Error cleaning up socket: $e');
    }

    Navigator.pop(context);
  }

  // 显示退出确认对话框
  void _showLeaveConfirmDialog() {
    // 游戏结束时不需要确认
    if (_isGameOver) {
      _leaveRoom();
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
              _leaveRoom();
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
    try {
      _socket.clearListeners();
      _socket.disconnect();
      _socket.dispose();
    } catch (e) {
      print('Error disposing socket: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showLeaveConfirmDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_myRoomId != null ? '房间: $_myRoomId' : '连接中...'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _showLeaveConfirmDialog,
            ),
          ],
        ),
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (!_isConnected) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isWaitingForOpponent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            if (_myRoomId != null)
              Column(
                children: [
                  const Text('等待对手加入...', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  Text(
                    '房间号: $_myRoomId',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _myRoomId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('房间号已复制')),
                      );
                    },
                  ),
                  const Text('点击复制房间号分享给好友', style: TextStyle(color: Colors.grey)),
                ],
              ),
          ],
        ),
      );
    }

    if (_isChoosingColor) {
      return _buildColorChoiceScreen();
    }

    if (_isGameOver) {
      return _buildGameOverScreen();
    }

    return _buildGameScreen();
  }

  Widget _buildColorChoiceScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _gameMessage ?? '请选择先后手',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_myChoice == 'first')
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  ElevatedButton(
                    onPressed: _myChoice.isEmpty ? () => _chooseColor('first') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('执黑（先手）'),
                  ),
                const SizedBox(width: 24),
                if (_myChoice == 'second')
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  ElevatedButton(
                    onPressed: _myChoice.isEmpty ? () => _chooseColor('second') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('执白（后手）'),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '黑方先行',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    String resultText;
    Color resultColor;
    
    if (_winner == null) {
      resultText = '和棋！';
      resultColor = Colors.orange;
    } else if (_winner == _playerColor) {
      resultText = '你赢了！🎉';
      resultColor = Colors.green;
    } else {
      resultText = '你输了！';
      resultColor = Colors.red;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _gameMessage ?? resultText,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: resultColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.brown[100],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: GoBoard(
                board: _board,
                onTap: null,
                lastMoveRow: _lastMoveRow,
                lastMoveCol: _lastMoveCol,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _leaveRoom,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('离开'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final isMyTurn = _currentPlayer == _myPlayerNumber;
    final myColorText = _playerColor == 'black' ? '黑方' : '白方';
    final myColor = _playerColor == 'black' ? Colors.black : Colors.grey;
    final hasPreview = _previewRow != null && _previewCol != null;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.brown[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _playerColor == 'black' ? Icons.circle : Icons.circle_outlined,
                        color: myColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '你是: $myColorText',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMyTurn ? '轮到你了' : '等待对手...',
                    style: TextStyle(
                      fontSize: 14,
                      color: isMyTurn ? Colors.green : Colors.grey,
                      fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isMyTurn ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isMyTurn ? '你的回合' : '对手回合',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 1.0,  // 保持正方形
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCB35C),  // 木纹色背景
                        border: Border.all(color: Colors.brown[800]!, width: 3),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GoBoard(
                        board: _board,
                        onTap: isMyTurn ? _handleTap : null,
                        previewRow: isMyTurn ? _previewRow : null,
                        previewCol: isMyTurn ? _previewCol : null,
                        previewPlayer: _myPlayerNumber,
                        lastMoveRow: _lastMoveRow,
                        lastMoveCol: _lastMoveCol,
                      ),
                    ),
                  ),
                ),
              ),
              if (hasPreview)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _cancelMove,
                            icon: const Icon(Icons.close),
                            label: const Text('取消'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmMove,
                            icon: const Icon(Icons.check),
                            label: const Text('确定'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.brown[100]!.withOpacity(0.5),
                Colors.brown[200]!.withOpacity(0.5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
