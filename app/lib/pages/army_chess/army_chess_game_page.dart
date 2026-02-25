import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config.dart';
import '../../widgets/army_chess_board_widget.dart';

class ArmyChessGamePage extends StatefulWidget {
  final String? roomId;

  const ArmyChessGamePage({super.key, this.roomId});

  @override
  State<ArmyChessGamePage> createState() => _ArmyChessGamePageState();
}

class _ArmyChessGamePageState extends State<ArmyChessGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  String? _mySid;
  String? _playerColor; // 'red' or 'blue'
  bool _isConnected = false;
  bool _isWaitingForOpponent = false;
  bool _isChoosingColor = false;
  bool _isArranging = false;
  bool _hasArranged = false;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // 12行5列的军旗棋盘
  List<List<dynamic>> _board = List.generate(12, (_) => List.filled(5, null));
  int _currentPlayer = 1;
  String? _winner;
  String? _gameMessage;
  int _myPlayerNumber = 0;
  String _myChoice = '';

  // 军旗棋子类型和数量
  final Map<String, int> _pieceCount = {
    '司令': 1,
    '军长': 1,
    '师长': 2,
    '旅长': 2,
    '团长': 2,
    '营长': 2,
    '连长': 3,
    '排长': 3,
    '工兵': 3,
    '炸弹': 2,
    '地雷': 3,
    '军旗': 1,
  };

  Map<String, int> _availablePieces = {};
  String? _selectedPiece;
  int? _selectedRow;
  int? _selectedCol;

  // 阵亡棋子列表
  List<String> _myLostPieces = [];

  // 上一步移动提示
  Map<String, dynamic>? _lastMove;

  // 行营位置（每边有5个，对称布局）
  final Set<String> _camps = {
    '2_1', '2_3', '3_2', '4_1', '4_3', // 上半区（红方）5个行营
    '7_1', '7_3', '8_2', '9_1', '9_3', // 下半区（蓝方）5个行营
  };

  // 大本营位置（每边有2个）
  final Set<String> _headquarters = {
    '0_1', '0_3', // 上方2个大本营
    '11_1', '11_3', // 下方2个大本营
  };

  @override
  void initState() {
    super.initState();
    _initSocket();
    _resetAvailablePieces();
  }

  void _resetAvailablePieces() {
    _availablePieces = Map.from(_pieceCount);
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
      if (!mounted) return;

      setState(() => _isConnected = true);

      if (widget.roomId == null) {
        _socket.emit('create_room', {'game_type': 'army_chess'});
      } else {
        _socket.emit('join_room', {
          'room_id': widget.roomId,
          'game_type': 'army_chess',
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
        _isArranging = true;
        _gameMessage = '请布置您的棋子';

        if (data['player_color'] == 'red') {
          _myPlayerNumber = 1;
          _playerColor = 'red';
        } else {
          _myPlayerNumber = 2;
          _playerColor = 'blue';
        }
      });
    });

    _socket.on('arrange_complete', (data) {
      setState(() {
        _hasArranged = true;
        _gameMessage = '布阵完成，等待对方...';
      });
    });

    _socket.on('game_begin', (data) {
      setState(() {
        _isArranging = false;
        _isPlaying = true;
        _gameMessage = '游戏开始！';
        _currentPlayer = data['current_player'];

        // 同步对方的棋子位置（只知道有棋子，不知道是什么）
        if (data['opponent_pieces'] != null) {
          List<dynamic> opponentPieces = data['opponent_pieces'];
          for (var piece in opponentPieces) {
            int row = piece['row'];
            int col = piece['col'];
            _board[row][col] = {
              'type': '?', // 对方棋子类型未知
              'color': _playerColor == 'red' ? 'blue' : 'red',
            };
          }
        }
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
            'type': piece['type'] ?? '?',
            'color': piece['color'],
          };
        }
        _board[fromRow][fromCol] = null;
        _currentPlayer = data['current_player'];

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
        String result =
            data['result']; // 'attacker_win', 'defender_win', 'both_die'

        if (result == 'attacker_win') {
          // 攻击方胜，移动到目标位置 - 深拷贝棋子数据
          final piece = _board[attackRow][attackCol];
          if (piece != null) {
            _board[defendRow][defendCol] = {
              'type': piece['type'] ?? '?',
              'color': piece['color'],
            };
          }
          _board[attackRow][attackCol] = null;
        } else if (result == 'defender_win') {
          // 防守方胜，攻击方消失
          _board[attackRow][attackCol] = null;
        } else {  // both_die
          // 同归于尽
          _board[attackRow][attackCol] = null;
          _board[defendRow][defendCol] = null;
        }

        _currentPlayer = data['current_player'];

        // 记录上一步移动 - 构造完整的移动信息
        _lastMove = {
          'player': data['player'],
          'from_row': data['from_row'],
          'from_col': data['from_col'],
          'to_row': data['to_row'],
          'to_col': data['to_col'],
          'piece_type': data.containsKey('piece_type') ? data['piece_type'] : '?',
          'is_attack': true,
          'target_type': data.containsKey('target_type') ? data['target_type'] : '?',
          'battle_result': result,
        };
      });
    });

    _socket.on('lost_pieces', (data) {
      setState(() {
        // 更新自己的阵亡棋子列表
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

  void _selectPiece(String piece) {
    if (_availablePieces[piece]! > 0) {
      setState(() {
        _selectedPiece = piece;
      });
    }
  }

  void _placePiece(int row, int col) {
    if (!_isArranging || _hasArranged) {
      return;
    }
    if (_selectedPiece == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择一个棋子')));
      return;
    }
    if (_board[row][col] != null) {
      return;
    }

    // 检查是否在自己的区域
    if ((_myPlayerNumber == 1 && row > 5) ||
        (_myPlayerNumber == 2 && row < 6)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('只能在自己的区域布阵')));
      return;
    }

    // 检查是否在行营
    if (_camps.contains('${row}_${col}')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('布阵时不能放入行营')));
      return;
    }

    // 检查军旗位置（只能在大本营）
    String posKey = '${row}_$col';
    if (_selectedPiece == '军旗') {
      if (!_headquarters.contains(posKey)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('军旗只能放在大本营！')));
        return;
      }
    }

    // 检查地雷位置（只能在最后两排）
    if (_selectedPiece == '地雷') {
      bool validMine =
          (_myPlayerNumber == 1 && (row == 0 || row == 1)) || // 红方：第4、5行
          (_myPlayerNumber == 2 && (row == 10 || row == 11)); // 蓝方：第6、7行
      if (!validMine) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地雷只能放在最后两排！')));
        return;
      }
    }

    // 放置棋子
    setState(() {
      _board[row][col] = {'type': _selectedPiece!, 'color': _playerColor};
      _availablePieces[_selectedPiece!] =
          _availablePieces[_selectedPiece!]! - 1;
      _selectedPiece = null;
    });
  }

  void _removePiece(int row, int col) {
    if (!_isArranging || _hasArranged) return;
    if (_board[row][col] == null) return;
    if (_board[row][col]['color'] != _playerColor) return;

    setState(() {
      String pieceType = _board[row][col]['type'];
      _availablePieces[pieceType] = _availablePieces[pieceType]! + 1;
      _board[row][col] = null;
    });
  }

  void _confirmArrange() {
    if (!_isArranging) return;

    // 检查是否所有棋子都已放置
    int totalRemaining = _availablePieces.values.fold(
      0,
      (sum, count) => sum + count,
    );
    if (totalRemaining > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('还有 $totalRemaining 个棋子未放置')));
      return;
    }

    // 发送布阵数据
    List<Map<String, dynamic>> pieces = [];
    for (int i = 0; i < 12; i++) {
      for (int j = 0; j < 5; j++) {
        if (_board[i][j] != null && _board[i][j]['color'] == _playerColor) {
          pieces.add({'row': i, 'col': j, 'type': _board[i][j]['type']});
        }
      }
    }

    _socket.emit('arrange_complete', {'room_id': _myRoomId, 'pieces': pieces});
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
          backgroundColor: Colors.green[700],
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

    if (_isArranging) {
      return _buildArrangeScreen();
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
                    color: Colors.green,
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
        backgroundColor: isSelected ? Colors.green[800] : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        elevation: isSelected ? 8 : 2, // 选中时阴影更明显
        shadowColor: isSelected ? Colors.green[900] : Colors.grey,
        side: isSelected
            ? BorderSide(color: Colors.green[900]!, width: 3) // 选中时添加边框
            : BorderSide(color: Colors.grey[400]!, width: 1),
      ),
      child: Text(label),
    );
  }

  Widget _buildArrangeScreen() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green[50],
          child: Column(
            children: [
              Text(
                _gameMessage ?? '开始布阵',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '我方: ${_playerColor == "red" ? "红方" : "蓝方"}',
                style: TextStyle(
                  fontSize: 16,
                  color: _playerColor == 'red' ? Colors.red : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // 可用棋子列表
              Container(
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border(
                    right: BorderSide(color: Colors.green[700]!, width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.green[700],
                      width: double.infinity,
                      child: const Text(
                        '可用棋子',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _availablePieces.length,
                        itemBuilder: (context, index) {
                          String piece = _availablePieces.keys.elementAt(index);
                          int count = _availablePieces[piece]!;
                          return GestureDetector(
                            onTap: () => _selectPiece(piece),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedPiece == piece
                                    ? Colors.green[700]
                                    : Colors.white,
                                border: Border.all(
                                  color: count > 0
                                      ? Colors.green[700]!
                                      : Colors.grey,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    piece,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedPiece == piece
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: count > 0
                                          ? Colors.red
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'x$count',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // 棋盘
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 5 / 12,
                          child: _buildBoard(),
                        ),
                      ),
                    ),
                    if (!_hasArranged)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: _confirmArrange,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('确认布阵'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
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

  Widget _buildGameScreen() {
    final isMyTurn = _currentPlayer == _myPlayerNumber;
    final myColorText = _playerColor == 'red' ? '红方' : '蓝方';

    return Column(
      children: [
        // 顶部信息栏
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green[50],
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
              // 认输按钮
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
              // 离开按钮
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
    return ArmyChessBoardWidget(
      board: _board,
      selectedRow: _selectedRow,
      selectedCol: _selectedCol,
      playerColor: _playerColor,
      myPlayerNumber: _myPlayerNumber, // 传递玩家编号用于视角翻转
      lastMove: _lastMove, // 传递上一步移动用于显示
      onTap: (visualRow, visualCol) {
        // 将视觉坐标转换回原始数据坐标
        int dataRow = visualRow;
        int dataCol = visualCol;
        if (_myPlayerNumber == 1) {
          // 红方：视觉坐标被翻转了，需要转换回来
          dataRow = 11 - visualRow;
          dataCol = 4 - visualCol;
        }

        if (_isArranging && !_hasArranged) {
          dynamic piece = _board[dataRow][dataCol];
          if (piece == null) {
            _placePiece(dataRow, dataCol);
          } else if (piece['color'] == _playerColor) {
            _removePiece(dataRow, dataCol);
          }
        } else if (_isPlaying) {
          if (_selectedRow != null && _selectedCol != null) {
            _makeMove(_selectedRow!, _selectedCol!, dataRow, dataCol);
            setState(() {
              _selectedRow = null;
              _selectedCol = null;
            });
          } else {
            dynamic piece = _board[dataRow][dataCol];
            if (piece != null && piece['color'] == _playerColor) {
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
