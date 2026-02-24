import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config.dart';
import '../../widgets/international_chess_board_widget.dart';
import '../../widgets/gobang_color_choice_button.dart';

enum GameStatus {
  connecting,
  waiting,
  selecting,
  playing,
  gameOver,
}

class InternationalChessGamePage extends StatefulWidget {
  final String? roomId;

  const InternationalChessGamePage({super.key, this.roomId});

  @override
  State<InternationalChessGamePage> createState() => _InternationalChessGamePageState();
}

class _InternationalChessGamePageState extends State<InternationalChessGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  String? _mySid;
  String? _playerColor;
  int? _myPlayerNumber;
  GameStatus _status = GameStatus.connecting;
  String? _winner;
  String _myChoice = '';
  bool _isGameOver = false;

  // 8x8 board: 0=empty, positive=white, negative=black
  // 1/King, 2/Queen, 3/Rook, 4/Bishop, 5/Knight, 6/Pawn
  List<List<int>> _board = List.generate(8, (i) => List.filled(8, 0));
  bool _myTurn = false;
  int? _lastMoveFromRow;
  int? _lastMoveFromCol;
  int? _lastMoveToRow;
  int? _lastMoveToCol;

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  void _initializeSocket() {
    _socket = IO.io(serverUrlConfig, <String, dynamic>{
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
        _myPlayerNumber = data['player_color'] == 'white' ? 1 : 2;
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
        _myTurn = data['current_player'] == 1 || data['current_player'] == -1
            ? (data['current_player'] == 1 && _playerColor == 'white') ||
               (data['current_player'] == -1 && _playerColor == 'black')
            : false;
      });
    });

    _socket.on('move_made', (data) {
      print('Move made by player ${data['player']}');
      setState(() {
        final from = data['from'];
        final to = data['to'];
        _board[to['row']][to['col']] = _board[from['row']][from['col']];
        _board[from['row']][from['col']] = 0;
        _lastMoveFromRow = from['row'];
        _lastMoveFromCol = from['col'];
        _lastMoveToRow = to['row'];
        _lastMoveToCol = to['col'];
        _myTurn = data['current_player'] == 1
            ? _playerColor == 'white'
            : _playerColor == 'black';
      });
    });

    _socket.on('player_left', (data) {
      print('Player left');
      setState(() {
        _status = GameStatus.gameOver;
        _winner = _myPlayerNumber == 1 ? '白方' : '黑方';
      });
    });

    _socket.on('game_over', (data) {
      print('Game over: ${data['winner']}');
      setState(() {
        _status = GameStatus.gameOver;
        _isGameOver = true;
        _winner = data['winner'] == 1 ? '白方' : (data['winner'] == -1 ? '黑方' : '平局');
      });
    });

    _socket.on('error', (data) {
      print('Error: ${data['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );
    });

    _socket.on('turn_changed', (data) {
      setState(() {
        _myTurn = data['current_player'] == 1
            ? _playerColor == 'white'
            : _playerColor == 'black';
      });
    });

    _socket.on('reset_game', (data) {
      setState(() {
        _status = GameStatus.selecting;
        _myChoice = '';
        _board = List.generate(8, (i) => List.filled(8, 0));
      });
    });

    _socket.onDisconnect((_) {
      print('Disconnected from server');
    });

    _socket.connect();
  }

  void _joinOrCreateRoom() {
    if (widget.roomId == null) {
      _socket.emit('create_room', {'game_type': 'international_chess'});
    } else {
      _socket.emit('join_room', {
        'room_id': widget.roomId,
        'game_type': 'international_chess'
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

    // White pieces (row 0) - bottom visually
    board[0][0] = 3;   // Rook
    board[0][1] = 5;   // Knight
    board[0][2] = 4;   // Bishop
    board[0][3] = 2;   // Queen
    board[0][4] = 1;   // King
    board[0][5] = 4;   // Bishop
    board[0][6] = 5;   // Knight
    board[0][7] = 3;   // Rook

    // White pawns (row 1)
    for (int col = 0; col < 8; col++) {
      board[1][col] = 6;
    }

    // Black pawns (row 6)
    for (int col = 0; col < 8; col++) {
      board[6][col] = -6;
    }

    // Black pieces (row 7) - top visually
    board[7][0] = -3;  // Rook
    board[7][1] = -5;  // Knight
    board[7][2] = -4;  // Bishop
    board[7][3] = -2;  // Queen
    board[7][4] = -1;  // King
    board[7][5] = -4;  // Bishop
    board[7][6] = -5;  // Knight
    board[7][7] = -3;  // Rook

    return board;
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

  void _makeMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (!_myTurn || _status != GameStatus.playing) return;

    _socket.emit('make_move', {
      'room_id': _myRoomId,
      'row': fromRow,
      'col': fromCol,
      'to_row': toRow,
      'to_col': toCol
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
          '游戏结束！$_winner',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
    }
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
                  label: '先手(白方)',
                  icon: Icons.arrow_forward,
                  selected: _myChoice == 'first',
                  onTap: () => _chooseColor('first'),
                ),
                const SizedBox(width: 32),
                ColorChoiceButton(
                  label: '后手(黑方)',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InternationalChessBoardWidget(
                    board: _board,
                    onMove: _myTurn ? _makeMove : null,
                    lastMoveFromRow: _lastMoveFromRow,
                    lastMoveFromCol: _lastMoveFromCol,
                    lastMoveToRow: _lastMoveToRow,
                    lastMoveToCol: _lastMoveToCol,
                  ),
                ),
                const SizedBox(height: 20),
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
          title: Text(_myRoomId != null ? '房间: $_myRoomId' : '国际象棋'),
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
