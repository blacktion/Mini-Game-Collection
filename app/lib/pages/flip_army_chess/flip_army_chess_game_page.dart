import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config.dart';
import '../../widgets/flip_army_chess_board_widget.dart';

class FlipArmyChessGamePage extends StatefulWidget {
  final String? roomId;

  const FlipArmyChessGamePage({super.key, this.roomId});

  @override
  State<FlipArmyChessGamePage> createState() => _FlipArmyChessGamePageState();
}

class _FlipArmyChessGamePageState extends State<FlipArmyChessGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  String? _mySid;
  String? _playerColor; // 'red' or 'blue'
  bool _isConnected = false;
  bool _isWaitingForOpponent = false;
  bool _isChoosingColor = false;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // 12行5列的军旗棋盘
  List<List<dynamic>> _board = List.generate(12, (_) => List.filled(5, null));
  int _currentPlayer = 1;
  String? _winner;
  String? _gameMessage;
  int _myPlayerNumber = 0;
  String _myChoice = '';

  // 已翻开的棋子位置集合
  final Set<String> _flippedPieces = {};

  // 阵亡棋子列表
  List<String> _myLostPieces = [];

  // 上一步移动提示
  Map<String, dynamic>? _lastMove;

  // 选中的棋子
  int? _selectedRow;
  int? _selectedCol;

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
      if (!mounted) return;

      setState(() => _isConnected = true);

      if (widget.roomId == null) {
        _socket.emit('create_room', {'game_type': 'flip_army_chess'});
      } else {
        _socket.emit('join_room', {
          'room_id': widget.roomId,
          'game_type': 'flip_army_chess',
        });
      }
    });

    _socket.onConnectError((data) {
      if (!mounted) return;
      setState(() => _isConnected = false);
    });

    _socket.onConnectTimeout((data) {
      if (!mounted) return;
      setState(() => _isConnected = false);
    });

    _socket.onError((data) {
      // Socket错误
    });

    _socket.onDisconnect((_) {
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
        _myPlayerNumber = data['player_color'] == 'red' ? 1 : 2;
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
        _gameMessage = '游戏开始！';
        _currentPlayer = data['current_player'];

        if (data['player_color'] == 'red') {
          _myPlayerNumber = 1;
          _playerColor = 'red';
        } else {
          _myPlayerNumber = 2;
          _playerColor = 'blue';
        }

        // 初始化棋盘上的棋子（所有棋子都是盖住的）
        if (data['pieces'] != null) {
          List<dynamic> pieces = data['pieces'];
          for (var pieceData in pieces) {
            int row = pieceData['row'];
            int col = pieceData['col'];
            _board[row][col] = {
              'color': 'hidden',  // 初始颜色（盖住状态）
              'flipped': false,   // 盖住状态
              'type': '?',        // 类型未知
            };
          }
        }
      });
    });

    _socket.on('flip_result', (data) {
      setState(() {
        int row = data['row'];
        int col = data['col'];
        String pieceColor = data['color'];
        String pieceType = data['type'];

        _board[row][col] = {
          'type': pieceType,
          'color': pieceColor,
          'flipped': true,
        };
        _flippedPieces.add('${row}_$col');
        _currentPlayer = data['current_player'];
      });
    });

    _socket.on('move_made', (data) {
      setState(() {
        int fromRow = data['from_row'];
        int fromCol = data['from_col'];
        int toRow = data['to_row'];
        int toCol = data['to_col'];

        // 移动棋子 - 深拷贝棋子数据
        final piece = _board[fromRow][fromCol];
        if (piece != null) {
          _board[toRow][toCol] = {
            'type': piece['type'],
            'color': piece['color'],
            'flipped': piece['flipped'],
          };
        }
        _board[fromRow][fromCol] = null;
        _currentPlayer = data['current_player'];

        // 更新已翻开位置
        _flippedPieces.remove('${fromRow}_$fromCol');
        _flippedPieces.add('${toRow}_$toCol');

        // 记录上一步移动
        _lastMove = data;
      });
    });

    _socket.on('battle_result', (data) {
      setState(() {
        int attackRow = data['attack_row'];
        int attackCol = data['attack_col'];
        int defendRow = data['defend_row'];
        int defendCol = data['defend_col'];
        String result = data['result'];

        if (result == 'attacker_win') {
          final piece = _board[attackRow][attackCol];
          if (piece != null) {
            _board[defendRow][defendCol] = {
              'type': piece['type'],
              'color': piece['color'],
              'flipped': piece['flipped'],
            };
          }
          _board[attackRow][attackCol] = null;
          _flippedPieces.remove('${attackRow}_$attackCol');
          _flippedPieces.add('${defendRow}_$defendCol');
        } else if (result == 'defender_win') {
          _board[attackRow][attackCol] = null;
          _flippedPieces.remove('${attackRow}_$attackCol');
        } else {  // both_die
          _board[attackRow][attackCol] = null;
          _board[defendRow][defendCol] = null;
          _flippedPieces.remove('${attackRow}_$attackCol');
          _flippedPieces.remove('${defendRow}_$defendCol');
        }

        _currentPlayer = data['current_player'];
        _lastMove = data;
      });
    });

    _socket.on('lost_pieces', (data) {
      setState(() {
        _myLostPieces = List<String>.from(data['pieces'] ?? []);
      });
    });

    _socket.on('game_over', (data) {
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _winner = data['winner'] == 1 ? 'red' : 'blue';
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

    _socket.on('error', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data['message'] ?? '发生错误')));
    });
  }

  void _chooseColor(String choice) {
    setState(() => _myChoice = choice);
    _socket.emit('choose_color', {'room_id': _myRoomId, 'choice': choice});
  }

  void _flipPiece(int row, int col) {
    if (!_isPlaying || _isGameOver) return;
    if (_currentPlayer != _myPlayerNumber) return;

    // 检查该位置是否有棋子
    if (_board[row][col] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该位置没有棋子')));
      return;
    }

    // 检查是否已经翻开
    if (_flippedPieces.contains('${row}_$col')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该棋子已经翻开')));
      return;
    }

    _socket.emit('make_move', {
      'room_id': _myRoomId,
      'from_row': row,
      'from_col': col,
      'to_row': row,
      'to_col': col,
      'action': 'flip',
    });
  }

  void _makeMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (!_isPlaying || _isGameOver) return;
    if (_currentPlayer != _myPlayerNumber) return;

    _socket.emit('make_move', {
      'room_id': _myRoomId,
      'from_row': fromRow,
      'from_col': fromCol,
      'to_row': toRow,
      'to_col': toCol,
      'action': 'move',
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
      // Socket清理错误
    }

    Navigator.pop(context);
  }

  void _showLeaveConfirmDialog() {
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _surrender() {
    if (!_isPlaying || _isGameOver) return;

    _showConfirmDialog('确认认输', '确定要认输吗？', () {
      _socket.emit('surrender', {'room_id': _myRoomId});
    });
  }

  void _showConfirmDialog(
    String title,
    String content,
    VoidCallback onConfirm,
  ) {
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

  @override
  void dispose() {
    try {
      _socket.clearListeners();
      _socket.disconnect();
      _socket.dispose();
    } catch (e) {
      // Socket释放错误
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
          backgroundColor: Colors.orange[700],
          foregroundColor: Colors.white,
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
      return _buildWaitingScreen();
    }

    if (_isChoosingColor) {
      return _buildColorSelection();
    }

    if (_isGameOver) {
      return _buildGameOverScreen();
    }

    if (_isPlaying) {
      return _buildGameScreen();
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildWaitingScreen() {
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
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _myRoomId!));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('房间号已复制')));
                  },
                ),
                const Text(
                  '点击复制房间号分享给好友',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
        ],
      ),
    );
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
                _buildChoiceButton('先手', 'first', _myChoice == 'first'),
                const SizedBox(width: 32),
                _buildChoiceButton('后手', 'second', _myChoice == 'second'),
              ],
            ),
            if (_myChoice.isNotEmpty) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('等待对方选择...', style: TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 32),
            const Text('双方选择相同则随机决定', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton(String label, String choice, bool isSelected) {
    return ElevatedButton(
      onPressed: _myChoice.isEmpty ? () => _chooseColor(choice) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.orange[800] : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        elevation: isSelected ? 8 : 2,
        shadowColor: isSelected ? Colors.orange[900] : Colors.grey,
        side: isSelected
            ? BorderSide(color: Colors.orange[900]!, width: 3)
            : BorderSide(color: Colors.grey[400]!, width: 1),
      ),
      child: Text(label),
    );
  }

  Widget _buildGameScreen() {
    final isMyTurn = _currentPlayer == _myPlayerNumber;
    final myColorText = _playerColor == 'red' ? '红方' : '蓝方';

    return Column(
      children: [
        // 顶部信息栏
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange[50],
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
                      color: isMyTurn ? Colors.orange : Colors.grey,
                      fontWeight: isMyTurn
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isMyTurn ? Colors.orange : Colors.grey,
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
          child: Row(
            children: [
              // 左侧阵亡棋子列表
              Container(
                width: 80,
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '阵亡棋子',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _myLostPieces.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _myLostPieces[index],
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // 中间棋盘
              Expanded(
                child: Center(
                  child: AspectRatio(aspectRatio: 5 / 12, child: _buildBoard()),
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
              ElevatedButton.icon(
                onPressed: (!_isGameOver) ? _surrender : null,
                icon: const Icon(Icons.flag, size: 20),
                label: const Text('认输'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _leaveRoom,
                icon: const Icon(Icons.exit_to_app, size: 20),
                label: const Text('离开'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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

  Widget _buildGameOverScreen() {
    String resultText;
    Color resultColor;

    if (_winner == _playerColor) {
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
            OutlinedButton.icon(
              onPressed: _leaveRoom,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('离开'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return FlipArmyChessBoardWidget(
      board: _board,
      selectedRow: _selectedRow,
      selectedCol: _selectedCol,
      playerColor: _playerColor,
      myPlayerNumber: _myPlayerNumber,
      flippedPieces: _flippedPieces,
      lastMove: _lastMove,
      onTap: (visualRow, visualCol) {
        // 将视觉坐标转换回原始数据坐标
        int dataRow = visualRow;
        int dataCol = visualCol;
        if (_myPlayerNumber == 1) {
          // 红方：视觉坐标被翻转了，需要转换回来
          dataRow = 11 - visualRow;
          dataCol = 4 - visualCol;
        }

        if (!_isPlaying) return;

        if (_selectedRow != null && _selectedCol != null) {
          // 已经选中了棋子，尝试移动
          if (_flippedPieces.contains('${_selectedRow}_$_selectedCol')) {
            _makeMove(_selectedRow!, _selectedCol!, dataRow, dataCol);
            setState(() {
              _selectedRow = null;
              _selectedCol = null;
            });
          }
        } else {
          // 没有选中棋子，检查点击位置
          if (_board[dataRow][dataCol] != null) {
            if (!_flippedPieces.contains('${dataRow}_$dataCol')) {
              // 未翻开的棋子，执行翻棋
              _flipPiece(dataRow, dataCol);
            } else if (_board[dataRow][dataCol]['color'] == _playerColor) {
              // 已翻开的己方棋子，选中它
              setState(() {
                _selectedRow = dataRow;
                _selectedCol = dataCol;
              });
            }
          }
        }
      },
    );
  }
}
