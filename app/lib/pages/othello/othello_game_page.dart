import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../widgets/othello/othello_board_widget.dart';
import '../../widgets/gobang_color_choice_button.dart';

enum GameStatus {
  connecting,
  waiting,
  selecting,
  playing,
  gameOver,
}

class OthelloGamePage extends StatefulWidget {
  final String? roomId;

  const OthelloGamePage({super.key, this.roomId});

  @override
  State<OthelloGamePage> createState() => _OthelloGamePageState();
}

class _OthelloGamePageState extends State<OthelloGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  String? _mySid;
  String? _playerColor;
  int? _myPlayerNumber;
  GameStatus _status = GameStatus.connecting;
  String? _winner;
  String _myChoice = '';
  bool _isGameOver = false;

  List<List<int>> _board = List.generate(8, (i) => List.filled(8, 0));
  bool _myTurn = false;
  List<Map<String, int>> _validMoves = [];
  int? _lastMoveRow;
  int? _lastMoveCol;

  int _blackScore = 0;
  int _whiteScore = 0;

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  void _initializeSocket() {
    _socket = IO.io('http://49.232.112.230:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.onConnect((_) {
      print('Connected to server');
      _joinOrCreateRoom();
    });

    _socket.on('room_created', (data) {
      print('Room created: ${data['room_id']}');
      setState(() {
        _myRoomId = data['room_id'];
        _mySid = data['sid'];
        _status = GameStatus.waiting;
      });
    });

    _socket.on('room_joined', (data) {
      print('Room joined: ${data['room_id']}');
      setState(() {
        _myRoomId = data['room_id'];
        _playerColor = data['player_color'];
        _myPlayerNumber = data['player_color'] == 'black' ? 1 : 2;
        _status = GameStatus.waiting;
      });
    });

    _socket.on('waiting_for_choices', (data) {
      setState(() {
        _status = GameStatus.selecting;
      });
    });

    _socket.on('game_start', (data) {
      print('Game started');
      setState(() {
        _status = GameStatus.playing;
        _board = _parseBoard(data['board']);
        _myPlayerNumber = data['player'];
        _playerColor = data['player_color'];
        _myTurn = _myPlayerNumber == 1;
        _calculateScores();
        _validMoves = _calculateValidMoves(_myPlayerNumber!);
      });
    });

    _socket.on('move_made', (data) {
      print('Move made by player ${data['player']}');
      setState(() {
        final move = data['move'];
        _placePieceAndFlip(move['row'], move['col'], data['player']);
        _lastMoveRow = move['row'];
        _lastMoveCol = move['col'];
        _myTurn = data['current_player'] == _myPlayerNumber;
        _calculateScores();
        _validMoves = _calculateValidMoves(_myPlayerNumber!);

        if (_validMoves.isEmpty && !_isBoardFull() && !_hasAnyValidMoves(_myPlayerNumber == 1 ? 2 : 1)) {
          _status = GameStatus.gameOver;
          _determineWinner();
        }
      });
    });

    _socket.on('player_left', (data) {
      print('Player left');
      setState(() {
        _status = GameStatus.gameOver;
        _winner = _myPlayerNumber == 1 ? '黑方' : '白方';
      });
    });

    _socket.on('game_over', (data) {
      print('Game over: ${data['winner']}');
      setState(() {
        _status = GameStatus.gameOver;
        _winner = data['winner'];
      });
    });

    _socket.on('error', (data) {
      print('Error: ${data['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );
    });

    _socket.onDisconnect((_) {
      print('Disconnected from server');
    });

    _socket.connect();
  }

  void _joinOrCreateRoom() {
    if (widget.roomId == null) {
      _socket.emit('create_room', {'game_type': 'othello'});
    } else {
      _socket.emit('join_room', {
        'room_id': widget.roomId,
        'game_type': 'othello'
      });
    }
  }

  List<List<int>> _parseBoard(dynamic boardData) {
    if (boardData is List) {
      return List<List<int>>.from(boardData.map((row) => List<int>.from(row)));
    }
    return _initializeBoard();
  }

  List<List<int>> _initializeBoard() {
    final board = List.generate(8, (i) => List.filled(8, 0));
    board[3][3] = 2;
    board[3][4] = 1;
    board[4][3] = 1;
    board[4][4] = 2;
    return board;
  }

  void _calculateScores() {
    _blackScore = 0;
    _whiteScore = 0;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if (_board[row][col] == 1) {
          _blackScore++;
        } else if (_board[row][col] == 2) {
          _whiteScore++;
        }
      }
    }
  }

  List<Map<String, int>> _calculateValidMoves(int player) {
    List<Map<String, int>> moves = [];
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if (_isValidMove(row, col, player)) {
          moves.add({'row': row, 'col': col});
        }
      }
    }
    return moves;
  }

  bool _isValidMove(int row, int col, int player) {
    if (_board[row][col] != 0) return false;

    final opponent = player == 1 ? 2 : 1;
    final directions = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1],          [0, 1],
      [1, -1], [1, 0], [1, 1],
    ];

    for (var dir in directions) {
      int r = row + dir[0];
      int c = col + dir[1];
      bool foundOpponent = false;

      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        if (_board[r][c] == opponent) {
          foundOpponent = true;
        } else if (_board[r][c] == player) {
          if (foundOpponent) return true;
          break;
        } else {
          break;
        }
        r += dir[0];
        c += dir[1];
      }
    }
    return false;
  }

  List<Map<String, int>> _getFlippedPieces(int row, int col, int player) {
    List<Map<String, int>> flipped = [];
    final opponent = player == 1 ? 2 : 1;
    final directions = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1],          [0, 1],
      [1, -1], [1, 0], [1, 1],
    ];

    for (var dir in directions) {
      List<Map<String, int>> potentialFlips = [];
      int r = row + dir[0];
      int c = col + dir[1];

      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        if (_board[r][c] == opponent) {
          potentialFlips.add({'row': r, 'col': c});
        } else if (_board[r][c] == player) {
          if (potentialFlips.isNotEmpty) {
            flipped.addAll(potentialFlips);
          }
          break;
        } else {
          break;
        }
        r += dir[0];
        c += dir[1];
      }
    }
    return flipped;
  }

  void _placePieceAndFlip(int row, int col, int player) {
    _board[row][col] = player;
    final flipped = _getFlippedPieces(row, col, player);
    for (var piece in flipped) {
      _board[piece['row']!][piece['col']!] = player;
    }
  }

  bool _isBoardFull() {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if (_board[row][col] == 0) return false;
      }
    }
    return true;
  }

  bool _hasAnyValidMoves(int player) {
    return _calculateValidMoves(player).isNotEmpty;
  }

  void _determineWinner() {
    if (_blackScore > _whiteScore) {
      _winner = '黑方';
    } else if (_whiteScore > _blackScore) {
      _winner = '白方';
    } else {
      _winner = '平局';
    }
  }

  void _chooseColor(String choice) {
    if (_status != GameStatus.selecting) return;
    if (_myChoice.isNotEmpty) return;

    setState(() {
      _myChoice = choice;
    });

    _socket.emit('choose_color', {
      'room_id': _myRoomId,
      'choice': choice
    });
  }

  void _makeMove(int row, int col) {
    if (!_myTurn || _status != GameStatus.playing) return;

    _socket.emit('make_move', {
      'room_id': _myRoomId,
      'row': row,
      'col': col
    });
  }

  void _resetGame() {
    _socket.emit('reset_game', {
      'room_id': _myRoomId,
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

  Widget _buildStatusText() {
    switch (_status) {
      case GameStatus.connecting:
        return const Text('连接中...', style: TextStyle(fontSize: 20));
      case GameStatus.waiting:
        return const Text('等待对手加入...', style: TextStyle(fontSize: 20));
      case GameStatus.selecting:
        return const Text('选择先后手', style: TextStyle(fontSize: 20));
      case GameStatus.playing:
        return Text(
          _myTurn ? '轮到你了' : '对手思考中...',
          style: const TextStyle(fontSize: 20),
        );
      case GameStatus.gameOver:
        return Text(
          '游戏结束！$_winner获胜',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
    }
  }

  Widget _buildScoreBoard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              const Text('黑方', style: TextStyle(fontSize: 16)),
              Text('$_blackScore', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              const Text('白方', style: TextStyle(fontSize: 16)),
              Text('$_whiteScore', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelectionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '选择先后手',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ColorChoiceButton(
                  label: '先手',
                  icon: Icons.arrow_forward,
                  selected: _myChoice == 'first',
                  onTap: () => _chooseColor('first'),
                ),
                const SizedBox(width: 32),
                ColorChoiceButton(
                  label: '后手',
                  icon: Icons.arrow_back,
                  selected: _myChoice == 'second',
                  onTap: () => _chooseColor('second'),
                ),
              ],
            ),
            if (_myChoice.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Text(
                  '已提交，等待对手选择...',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStatusText(),
                const SizedBox(height: 20),
                _buildScoreBoard(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OthelloBoardWidget(
                    board: _board,
                    validMoves: _validMoves,
                    onTap: _myTurn ? _makeMove : null,
                    lastMoveRow: _lastMoveRow,
                    lastMoveCol: _lastMoveCol,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    Widget body;

    switch (_status) {
      case GameStatus.connecting:
      case GameStatus.waiting:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_status == GameStatus.connecting)
                const CircularProgressIndicator()
              else
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
        break;
      case GameStatus.selecting:
        body = _buildColorSelectionScreen();
        break;
      case GameStatus.playing:
      case GameStatus.gameOver:
        body = _buildGameScreen();
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showLeaveConfirmDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_myRoomId != null ? '房间: $_myRoomId' : '黑白棋'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _showLeaveConfirmDialog,
          ),
        ],
        ),
        body: body,
      ),
    );
  }
}
