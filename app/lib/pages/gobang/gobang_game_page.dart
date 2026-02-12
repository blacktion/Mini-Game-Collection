import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../widgets/gobang_board_widget.dart';
import '../../widgets/gobang_color_choice_button.dart';

class GobangGamePage extends StatefulWidget {
  final String? roomId;
  
  const GobangGamePage({super.key, this.roomId});

  @override
  State<GobangGamePage> createState() => _GobangGamePageState();
}

class _GobangGamePageState extends State<GobangGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  String? _mySid;
  String? _playerColor;
  bool _isConnected = false;
  bool _isWaitingForOpponent = false;
  bool _isChoosingColor = false;
  bool _isPlaying = false;
  bool _isGameOver = false;

  List<List<int>> _board = List.generate(15, (_) => List.filled(15, 0));
  int _currentPlayer = 1;
  String? _winner;
  String? _gameMessage;
  int _myPlayerNumber = 0;
  String _myChoice = '';

  int? _previewRow;
  int? _previewCol;

  // 记录最后一步棋的位置（对方上一步）
  int? _lastMoveRow;
  int? _lastMoveCol;

  // 悔棋功能
  bool _canUndo = false;  // 是否可以悔棋（不能连续悔棋）
  bool _undoRequested = false;  // 对方是否请求悔棋
  bool _waitingForUndoResponse = false;  // 等待对方回应悔棋请求

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    const String serverUrl = 'http://49.232.112.230:5000';

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
        _socket.emit('create_room', {});
      } else {
        print('Emitting join_room: ${widget.roomId}');
        _socket.emit('join_room', {'room_id': widget.roomId});
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
      setState(() => _mySid = data['sid']);
    });

    _socket.on('room_created', (data) {
      print('Room created: ${data['room_id']}');
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
        _currentPlayer = data['player'] == 1 ? 2 : 1;
        // 记录最后一步棋（对方上一步）
        _lastMoveRow = data['row'];
        _lastMoveCol = data['col'];
        // 每走一步棋，可以悔棋
        _canUndo = true;
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
        _board = List.generate(15, (_) => List.filled(15, 0));
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

    // 悔棋请求
    _socket.on('undo_request', (data) {
      if (!mounted) return;
      final requestor = data['player'] == 1 ? '黑棋' : '白棋';
      _showUndoRequestDialog(requestor);
    });

    // 悔棋响应
    _socket.on('undo_response', (data) {
      if (!mounted) return;
      setState(() {
        _waitingForUndoResponse = false;
      });
      if (data['approved']) {
        setState(() {
          _canUndo = false;  // 悔棋后不能再悔棋
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对方同意悔棋')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对方拒绝悔棋')),
        );
      }
    });

    // 悔棋执行
    _socket.on('undo_move', (data) {
      if (!mounted) return;
      setState(() {
        _board[data['row']][data['col']] = 0;
        _currentPlayer = data['current_player'];
        // 清除最后一步记录
        _lastMoveRow = null;
        _lastMoveCol = null;
        _undoRequested = false;
        _waitingForUndoResponse = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('悔棋成功')),
      );
    });

    // 错误处理
    _socket.on('error', (data) {
      if (!mounted) return;
      setState(() {
        _waitingForUndoResponse = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? '发生错误')),
      );
    });

    // 认输
    _socket.on('surrender', (data) {
      if (!mounted) return;
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _winner = data['winner'] == 1 ? 'black' : 'white';
        final winnerName = data['winner'] == 1 ? '黑棋' : '白棋';
        _gameMessage = '$winnerName认输！';
      });
    });

    _socket.onError((error) {
      print('Socket error: $error');
    });
  }

  void _chooseColor(String choice) {
    setState(() => _myChoice = choice);
    _socket.emit('choose_color', {
      'room_id': _myRoomId,
      'choice': choice,
    });
  }

  void _previewMove(int row, int col) {
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

  void _playAgain() {
    _socket.emit('play_again', {'room_id': _myRoomId});
  }

  // 认输
  void _surrender() {
    if (!_isPlaying || _isGameOver) return;

    _showConfirmDialog(
      '确认认输',
      '确定要认输吗？',
      () {
        _socket.emit('surrender', {'room_id': _myRoomId});
      },
    );
  }

  // 请求悔棋
  void _requestUndo() {
    if (!_isPlaying || _isGameOver) return;
    if (!_canUndo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能连续悔棋')),
      );
      return;
    }

    _showConfirmDialog(
      '请求悔棋',
      '确定要请求悔棋吗？',
      () {
        setState(() {
          _waitingForUndoResponse = true;
        });
        _socket.emit('undo_request', {'room_id': _myRoomId});
      },
    );
  }

  // 响应悔棋请求
  void _respondUndoRequest(bool approved) {
    setState(() {
      _undoRequested = false;
    });
    _socket.emit('undo_response', {
      'room_id': _myRoomId,
      'approved': approved,
    });
  }

  // 显示确认对话框
  void _showConfirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 显示悔棋请求对话框
  void _showUndoRequestDialog(String requestor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('悔棋请求'),
        content: Text('$requestor请求悔棋，是否同意？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondUndoRequest(false);
            },
            child: const Text('拒绝'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondUndoRequest(true);
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );
    setState(() {
      _undoRequested = true;
    });
  }

  void _leaveRoom() {
    print('Leaving room: $_myRoomId');

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
    print('Disposing GamePage');
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
        body: Stack(
          children: [
            _buildContent(),
            _buildWaitingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    if (!_waitingForUndoResponse) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  '等待对方回复...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '对方正在处理您的悔棋请求',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
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
      return _buildColorSelection();
    }

    if (_isGameOver) {
      return _buildGameOverScreen();
    }

    return _buildGameScreen();
  }

  Widget _buildColorSelection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '选择先后手',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ColorChoiceButton(
                  icon: Icons.looks_one,
                  label: '先手',
                  selected: _myChoice == 'first',
                  onTap: () => _chooseColor('first'),
                ),
                const SizedBox(width: 32),
                ColorChoiceButton(
                  icon: Icons.looks_two,
                  label: '后手',
                  selected: _myChoice == 'second',
                  onTap: () => _chooseColor('second'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              '双方选择相同则随机决定',
              style: TextStyle(color: Colors.grey[600]),
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
      resultText = '平局！';
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
        padding: const EdgeInsets.all(24.0),
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
            const SizedBox(height: 48),
            Container(
              decoration: BoxDecoration(
                color: Colors.brown[100],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: BoardWidget(
                board: _board,
                onTap: null,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _playAgain,
                  icon: const Icon(Icons.replay),
                  label: const Text('再来一局'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _showLeaveConfirmDialog,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('离开'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final isMyTurn = _currentPlayer == _myPlayerNumber;
    final myColorText = _playerColor == 'black' ? '黑棋' : '白棋';
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
                  Text(
                    '你是: $myColorText',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.brown[200],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(8),
                  child: BoardWidget(
                    board: _board,
                    onTap: isMyTurn ? _previewMove : null,
                    previewRow: _previewRow,
                    previewCol: _previewCol,
                    previewPlayer: _myPlayerNumber,
                    lastMoveRow: _lastMoveRow,
                    lastMoveCol: _lastMoveCol,
                  ),
                ),
              ),
              if (hasPreview)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.brown[700],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _cancelMove,
                              icon: const Icon(Icons.close, size: 20),
                              label: const Text('取消'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _confirmMove,
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: const Text('确认'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 悔棋按钮
              ElevatedButton.icon(
                onPressed: (!_isGameOver && !_undoRequested && _canUndo) ? _requestUndo : null,
                icon: const Icon(Icons.undo, size: 20),
                label: Text(_waitingForUndoResponse ? '等待回复' : '悔棋'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              // 认输按钮
              ElevatedButton.icon(
                onPressed: (!_isGameOver) ? _surrender : null,
                icon: const Icon(Icons.flag, size: 20),
                label: const Text('认输'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
