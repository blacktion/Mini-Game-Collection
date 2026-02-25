import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config.dart';
import '../../widgets/chinese_chess_board_widget.dart';
import '../../widgets/chinese_chess_piece.dart';

class ChineseChessGamePage extends StatefulWidget {
  final String? roomId;
  final String gameType;
  
  const ChineseChessGamePage({
    super.key,
    this.roomId,
    required this.gameType,
  });

  @override
  State<ChineseChessGamePage> createState() => _ChineseChessGamePageState();
}

class _ChineseChessGamePageState extends State<ChineseChessGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  String? _mySid;
  String? _playerColor;  // 'red' or 'black'
  bool _isConnected = false;
  bool _isWaitingForOpponent = false;
  bool _isChoosingColor = false;
  bool _isPlaying = false;
  bool _isGameOver = false;
  String _myChoice = '';  // 'first' or 'second'
  
  List<List<ChessPiece?>> _board = List.generate(10, (_) => List.filled(9, null));
  int _currentPlayer = 1;  // 1:红, 2:黑
  String? _winner;
  String? _gameMessage;
  int _myPlayerNumber = 0;  // 1:红, 2:黑
  
  int? _selectedRow;
  int? _selectedCol;
  int? _lastMoveFromRow;
  int? _lastMoveFromCol;
  int? _lastMoveToRow;
  int? _lastMoveToCol;
  List<Map<String, int>> _possibleMoves = [];

  // 悔棋和和棋相关状态
  bool _canUndo = false;
  bool _undoRequested = false;
  bool _waitingForUndoResponse = false;
  bool _drawRequested = false;
  bool _drawRequestPending = false;
  bool _waitingForDrawResponse = false;
  String _checkMessage = '';  // 将军提示信息

  @override
  void initState() {
    super.initState();
    _initBoard();
    _initSocket();
  }

  void _initBoard() {
    // 初始化红方棋子（下方）
    _board[9][0] = const ChessPiece(name: '車', type: 'rook', color: 'red');
    _board[9][1] = const ChessPiece(name: '馬', type: 'knight', color: 'red');
    _board[9][2] = const ChessPiece(name: '相', type: 'bishop', color: 'red');
    _board[9][3] = const ChessPiece(name: '仕', type: 'advisor', color: 'red');
    _board[9][4] = const ChessPiece(name: '帥', type: 'king', color: 'red');
    _board[9][5] = const ChessPiece(name: '仕', type: 'advisor', color: 'red');
    _board[9][6] = const ChessPiece(name: '相', type: 'bishop', color: 'red');
    _board[9][7] = const ChessPiece(name: '馬', type: 'knight', color: 'red');
    _board[9][8] = const ChessPiece(name: '車', type: 'rook', color: 'red');
    _board[7][1] = const ChessPiece(name: '炮', type: 'cannon', color: 'red');
    _board[7][7] = const ChessPiece(name: '炮', type: 'cannon', color: 'red');
    _board[6][0] = const ChessPiece(name: '兵', type: 'pawn', color: 'red');
    _board[6][2] = const ChessPiece(name: '兵', type: 'pawn', color: 'red');
    _board[6][4] = const ChessPiece(name: '兵', type: 'pawn', color: 'red');
    _board[6][6] = const ChessPiece(name: '兵', type: 'pawn', color: 'red');
    _board[6][8] = const ChessPiece(name: '兵', type: 'pawn', color: 'red');

    // 初始化黑方棋子（上方）
    _board[0][0] = const ChessPiece(name: '車', type: 'rook', color: 'black');
    _board[0][1] = const ChessPiece(name: '馬', type: 'knight', color: 'black');
    _board[0][2] = const ChessPiece(name: '象', type: 'bishop', color: 'black');
    _board[0][3] = const ChessPiece(name: '士', type: 'advisor', color: 'black');
    _board[0][4] = const ChessPiece(name: '將', type: 'king', color: 'black');
    _board[0][5] = const ChessPiece(name: '士', type: 'advisor', color: 'black');
    _board[0][6] = const ChessPiece(name: '象', type: 'bishop', color: 'black');
    _board[0][7] = const ChessPiece(name: '馬', type: 'knight', color: 'black');
    _board[0][8] = const ChessPiece(name: '車', type: 'rook', color: 'black');
    _board[2][1] = const ChessPiece(name: '砲', type: 'cannon', color: 'black');
    _board[2][7] = const ChessPiece(name: '砲', type: 'cannon', color: 'black');
    _board[3][0] = const ChessPiece(name: '卒', type: 'pawn', color: 'black');
    _board[3][2] = const ChessPiece(name: '卒', type: 'pawn', color: 'black');
    _board[3][4] = const ChessPiece(name: '卒', type: 'pawn', color: 'black');
    _board[3][6] = const ChessPiece(name: '卒', type: 'pawn', color: 'black');
    _board[3][8] = const ChessPiece(name: '卒', type: 'pawn', color: 'black');
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
        _socket.emit('create_room', {'game_type': widget.gameType});
      } else {
        _socket.emit('join_room', {'room_id': widget.roomId, 'game_type': widget.gameType});
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
        _myPlayerNumber = data['player_color'] == 'red' ? 1 : 2;
        _isWaitingForOpponent = true;
      });
    });

    _socket.on('waiting_for_choices', (data) {
      if (!mounted) return;
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
        
        if (data['player_color'] == 'red') {
          _myPlayerNumber = 1;
          _playerColor = 'red';
        } else {
          _myPlayerNumber = 2;
          _playerColor = 'black';
        }
        
        // 从服务器同步棋盘数据
        if (data['board'] != null) {
          List<dynamic> serverBoard = data['board'];
          for (int r = 0; r < 10; r++) {
            for (int c = 0; c < 9; c++) {
              dynamic pieceData = serverBoard[r][c];
              if (pieceData != null) {
                _board[r][c] = ChessPiece(
                  name: pieceData['name'],
                  type: pieceData['type'],
                  color: pieceData['color'],
                );
              } else {
                _board[r][c] = null;
              }
            }
          }
        }
      });
    });

    _socket.on('move_made', (data) {
      setState(() {
        _board[data['from_row']][data['from_col']] = null;
        _board[data['to_row']][data['to_col']] = _getPieceByName(
          data['piece_name'],
          data['piece_type'],
          data['piece_color'],
        );
        _lastMoveFromRow = data['from_row'];
        _lastMoveFromCol = data['from_col'];
        _lastMoveToRow = data['to_row'];
        _lastMoveToCol = data['to_col'];
        _currentPlayer = data['player'] == 1 ? 2 : 1;
        _canUndo = true;
        _selectedRow = null;
        _selectedCol = null;
        _possibleMoves = [];
      });
    });

    _socket.on('turn_changed', (data) {
      setState(() => _currentPlayer = data['current_player']);
    });

    _socket.on('game_over', (data) {
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _winner = data['winner'] == 1 ? 'red' : data['winner'] == 2 ? 'black' : null;
        _gameMessage = data['message'];
      });
    });

    _socket.on('reset_game', (data) {
      setState(() {
        _initBoard();
        _currentPlayer = 1;
        _isGameOver = false;
        _isPlaying = false;
        _winner = null;
        _selectedRow = null;
        _selectedCol = null;
        _lastMoveFromRow = null;
        _lastMoveFromCol = null;
        _lastMoveToRow = null;
        _lastMoveToCol = null;
        _possibleMoves = [];
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

    // 认输事件
    _socket.on('surrender', (data) {
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _gameMessage = data['message'];
      });
    });

    // 悔棋请求事件
    _socket.on('undo_request', (data) {
      setState(() {
        _undoRequested = true;
      });
      _showUndoRequestDialog();
    });

    // 悔棋移动事件
    _socket.on('undo_move', (data) {
      setState(() {
        _canUndo = false;
        if (data['from_row'] != null) {
          // 象棋悔棋
          _board[data['from_row']][data['from_col']] = _board[data['to_row']][data['to_col']];
          if (data['captured'] != null) {
            final captured = data['captured'];
            _board[data['to_row']][data['to_col']] = _getPieceByName(
              captured['name'],
              captured['type'],
              captured['color'],
            );
          } else {
            _board[data['to_row']][data['to_col']] = null;
          }
          // 悔棋后清除最后一步轨迹
          _lastMoveFromRow = null;
          _lastMoveFromCol = null;
          _lastMoveToRow = null;
          _lastMoveToCol = null;
        }
        _currentPlayer = data['current_player'];
        _selectedRow = null;
        _selectedCol = null;
        _possibleMoves = [];
        _undoRequested = false;
        _waitingForUndoResponse = false;
      });
    });

    // 和棋请求事件
    _socket.on('draw_request', (data) {
      setState(() {
        _drawRequested = true;
        _drawRequestPending = true;
      });
      _showDrawRequestWaitingDialog();
    });

    // 和棋结果事件
    _socket.on('draw', (data) {
      if (!mounted) return;
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _gameMessage = data['message'];
        _drawRequested = false;
        _drawRequestPending = false;
        _waitingForDrawResponse = false;
      });
    });

    // 和棋响应事件
    _socket.on('draw_response', (data) {
      if (!mounted) return;
      setState(() {
        _waitingForDrawResponse = false;
      });
      if (data['approved']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对方同意和棋')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对方拒绝和棋')),
        );
      }
    });

    // 将军事件
    _socket.on('check', (data) {
      setState(() {
        _checkMessage = data['message'];
      });
      _showCheckDialog();
    });

    // 悔棋响应事件
    _socket.on('undo_response', (data) {
      if (!mounted) return;
      setState(() {
        _waitingForUndoResponse = false;
      });
      if (data['approved']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对方同意悔棋')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对方拒绝悔棋')),
        );
      }
    });

    // 错误处理
    _socket.on('error', (data) {
      if (!mounted) return;
      setState(() {
        _waitingForUndoResponse = false;
        _waitingForDrawResponse = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? '发生错误')),
      );
    });
  }

  ChessPiece _getPieceByName(String name, String type, String color) {
    return ChessPiece(name: name, type: type, color: color);
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
    
    final piece = _board[row][col];
    
    if (_selectedRow != null && _selectedCol != null) {
      // 已选择棋子，尝试移动
      final isValidMove = _possibleMoves.any((move) => move['row'] == row && move['col'] == col);
      
      if (isValidMove) {
        // 发送移动请求
        _socket.emit('make_move', {
          'room_id': _myRoomId,
          'game_type': widget.gameType,
          'from_row': _selectedRow,
          'from_col': _selectedCol,
          'to_row': row,
          'to_col': col,
        });
        
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
          _possibleMoves = [];
        });
        return;
      }
    }
    
    // 选择新棋子
    if (piece != null && piece.color == _playerColor) {
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
        _possibleMoves = _calculatePossibleMoves(row, col, piece);
      });
    } else {
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _possibleMoves = [];
      });
    }
  }

  List<Map<String, int>> _calculatePossibleMoves(int row, int col, ChessPiece piece) {
    List<Map<String, int>> moves = [];
    
    switch (piece.type) {
      case 'rook':
        moves.addAll(_getRookMoves(row, col));
        break;
      case 'knight':
        moves.addAll(_getKnightMoves(row, col));
        break;
      case 'bishop':
        moves.addAll(_getBishopMoves(row, col, piece.color));
        break;
      case 'advisor':
        moves.addAll(_getAdvisorMoves(row, col, piece.color));
        break;
      case 'king':
        moves.addAll(_getKingMoves(row, col, piece.color));
        break;
      case 'cannon':
        moves.addAll(_getCannonMoves(row, col));
        break;
      case 'pawn':
        moves.addAll(_getPawnMoves(row, col, piece.color));
        break;
    }
    
    return moves;
  }

  List<Map<String, int>> _getRookMoves(int row, int col) {
    List<Map<String, int>> moves = [];
    final directions = [[0, 1], [0, -1], [1, 0], [-1, 0]];
    
    for (var dir in directions) {
      int r = row + dir[0];
      int c = col + dir[1];
      
      while (r >= 0 && r < 10 && c >= 0 && c < 9) {
        if (_board[r][c] == null) {
          moves.add({'row': r, 'col': c});
        } else {
          if (_board[r][c]!.color != _playerColor) {
            moves.add({'row': r, 'col': c});
          }
          break;
        }
        r += dir[0];
        c += dir[1];
      }
    }
    
    return moves;
  }

  List<Map<String, int>> _getKnightMoves(int row, int col) {
    List<Map<String, int>> moves = [];
    final offsets = [
      [-2, -1], [-2, 1], [2, -1], [2, 1],
      [-1, -2], [-1, 2], [1, -2], [1, 2],
    ];
    
    for (var offset in offsets) {
      int r = row + offset[0];
      int c = col + offset[1];
      
      if (r >= 0 && r < 10 && c >= 0 && c < 9) {
        final blockRow = row + (offset[0].abs() == 2 ? offset[0] ~/ 2 : 0);
        final blockCol = col + (offset[1].abs() == 2 ? offset[1] ~/ 2 : 0);
        
        if (_board[blockRow][blockCol] == null) {
          if (_board[r][c] == null || _board[r][c]!.color != _playerColor) {
            moves.add({'row': r, 'col': c});
          }
        }
      }
    }
    
    return moves;
  }

  List<Map<String, int>> _getBishopMoves(int row, int col, String color) {
    List<Map<String, int>> moves = [];
    final offsets = [[2, 2], [2, -2], [-2, 2], [-2, -2]];
    
    for (var offset in offsets) {
      int r = row + offset[0];
      int c = col + offset[1];
      final blockRow = row + offset[0] ~/ 2;
      final blockCol = col + offset[1] ~/ 2;
      
      if (r >= 0 && r < 10 && c >= 0 && c < 9) {
        if (_board[blockRow][blockCol] == null) {
          if (color == 'red' && r >= 5 || color == 'black' && r <= 4) {
            if (_board[r][c] == null || _board[r][c]!.color != _playerColor) {
              moves.add({'row': r, 'col': c});
            }
          }
        }
      }
    }
    
    return moves;
  }

  List<Map<String, int>> _getAdvisorMoves(int row, int col, String color) {
    List<Map<String, int>> moves = [];
    final offsets = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
    
    for (var offset in offsets) {
      int r = row + offset[0];
      int c = col + offset[1];
      
      if (c >= 3 && c <= 5) {
        if (color == 'red' && r >= 7 && r <= 9 || color == 'black' && r >= 0 && r <= 2) {
          if (_board[r][c] == null || _board[r][c]!.color != _playerColor) {
            moves.add({'row': r, 'col': c});
          }
        }
      }
    }
    
    return moves;
  }

  List<Map<String, int>> _getKingMoves(int row, int col, String color) {
    List<Map<String, int>> moves = [];
    final directions = [[0, 1], [0, -1], [1, 0], [-1, 0]];
    
    for (var dir in directions) {
      int r = row + dir[0];
      int c = col + dir[1];
      
      if (c >= 3 && c <= 5) {
        if (color == 'red' && r >= 7 && r <= 9 || color == 'black' && r >= 0 && r <= 2) {
          if (_board[r][c] == null || _board[r][c]!.color != _playerColor) {
            moves.add({'row': r, 'col': c});
          }
        }
      }
    }
    
    // 将帅对面
    int opponentKingRow = -1;
    for (int r = 0; r < 10; r++) {
      if (_board[r][col] != null && 
          _board[r][col]!.type == 'king' && 
          _board[r][col]!.color != color) {
        opponentKingRow = r;
        break;
      }
    }
    
    if (opponentKingRow != -1) {
      bool hasObstacle = false;
      int start = (color == 'red') ? opponentKingRow + 1 : row + 1;
      int end = (color == 'red') ? row : opponentKingRow;
      
      for (int r = start; r < end; r++) {
        if (_board[r][col] != null) {
          hasObstacle = true;
          break;
        }
      }
      
      if (!hasObstacle) {
        moves.add({'row': opponentKingRow, 'col': col});
      }
    }
    
    return moves;
  }

  List<Map<String, int>> _getCannonMoves(int row, int col) {
    List<Map<String, int>> moves = [];
    final directions = [[0, 1], [0, -1], [1, 0], [-1, 0]];
    
    for (var dir in directions) {
      int r = row + dir[0];
      int c = col + dir[1];
      bool hasJumped = false;
      
      while (r >= 0 && r < 10 && c >= 0 && c < 9) {
        if (!hasJumped) {
          if (_board[r][c] == null) {
            moves.add({'row': r, 'col': c});
          } else {
            hasJumped = true;
          }
        } else {
          if (_board[r][c] != null) {
            if (_board[r][c]!.color != _playerColor) {
              moves.add({'row': r, 'col': c});
            }
            break;
          }
        }
        r += dir[0];
        c += dir[1];
      }
    }
    
    return moves;
  }

  List<Map<String, int>> _getPawnMoves(int row, int col, String color) {
    List<Map<String, int>> moves = [];
    
    if (color == 'red') {
      // 红兵向上
      if (row > 0) {
        if (_board[row - 1][col] == null || _board[row - 1][col]!.color != _playerColor) {
          moves.add({'row': row - 1, 'col': col});
        }
      }
      // 过河后可以左右移动
      if (row <= 4) {
        if (col > 0) {
          if (_board[row][col - 1] == null || _board[row][col - 1]!.color != _playerColor) {
            moves.add({'row': row, 'col': col - 1});
          }
        }
        if (col < 8) {
          if (_board[row][col + 1] == null || _board[row][col + 1]!.color != _playerColor) {
            moves.add({'row': row, 'col': col + 1});
          }
        }
      }
    } else {
      // 黑卒向下
      if (row < 9) {
        if (_board[row + 1][col] == null || _board[row + 1][col]!.color != _playerColor) {
          moves.add({'row': row + 1, 'col': col});
        }
      }
      // 过河后可以左右移动
      if (row >= 5) {
        if (col > 0) {
          if (_board[row][col - 1] == null || _board[row][col - 1]!.color != _playerColor) {
            moves.add({'row': row, 'col': col - 1});
          }
        }
        if (col < 8) {
          if (_board[row][col + 1] == null || _board[row][col + 1]!.color != _playerColor) {
            moves.add({'row': row, 'col': col + 1});
          }
        }
      }
    }
    
    return moves;
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

  // 认输
  void _surrender() {
    if (_isGameOver) return;
    _socket.emit('surrender', {
      'room_id': _myRoomId,
      'game_type': widget.gameType,
    });
  }

  // 请求悔棋
  void _requestUndo() {
    if (_isGameOver) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('请求悔棋'),
        content: const Text('确定要请求悔棋吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _waitingForUndoResponse = true;
              });
              _socket.emit('undo_request', {
                'room_id': _myRoomId,
                'game_type': widget.gameType,
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 显示悔棋请求对话框
  void _showUndoRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('悔棋请求'),
          content: const Text('对方请求悔棋，是否同意？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _socket.emit('undo_response', {
                  'room_id': _myRoomId,
                  'approved': false,
                });
                setState(() {
                  _undoRequested = false;
                });
              },
              child: const Text('拒绝'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _socket.emit('undo_response', {
                  'room_id': _myRoomId,
                  'approved': true,
                });
                setState(() {
                  _undoRequested = false;
                });
              },
              child: const Text('同意'),
            ),
          ],
        );
      },
    );
  }

  // 请求和棋
  void _requestDraw() {
    if (_isGameOver) return;
    _socket.emit('draw_request', {
      'room_id': _myRoomId,
      'game_type': widget.gameType,
    });
    setState(() {
      _waitingForDrawResponse = true;
    });
    _showDrawWaitingDialog();
  }

  // 显示和棋等待对话框（收到请求时，类似于悔棋）
  void _showDrawRequestWaitingDialog() {
    setState(() {
      _waitingForDrawResponse = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('和棋请求'),
          content: const Text('对方请求和棋，是否同意？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _socket.emit('draw_response', {
                  'room_id': _myRoomId,
                  'approved': false,
                });
                setState(() {
                  _drawRequested = false;
                  _waitingForDrawResponse = false;
                });
              },
              child: const Text('拒绝'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _socket.emit('draw_response', {
                  'room_id': _myRoomId,
                  'approved': true,
                });
                setState(() {
                  _drawRequested = false;
                  _waitingForDrawResponse = false;
                });
              },
              child: const Text('同意'),
            ),
          ],
        );
      },
    );
  }

  // 显示和棋等待对话框（提出方等待对方回应）
  void _showDrawWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('和棋请求'),
          content: const Text('等待对方回应和棋请求...'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _waitingForDrawResponse = false;
                });
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  // 显示将军对话框
  void _showCheckDialog() {
    if (_checkMessage.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _checkMessage,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      _checkMessage = '';
    });
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
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('先手'),
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
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('后手'),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '红方默认先行',
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
              padding: const EdgeInsets.all(4),
              child: AspectRatio(
                aspectRatio: 0.9,
                child: ChineseChessBoard(
                  board: _board,
                  onTap: null,
                  lastMoveFromRow: _lastMoveFromRow,
                  lastMoveFromCol: _lastMoveFromCol,
                  lastMoveToRow: _lastMoveToRow,
                  lastMoveToCol: _lastMoveToCol,
                  isRotated: _playerColor == 'black',
                ),
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
    final myColorText = _playerColor == 'red' ? '红方' : '黑方';
    final myColor = _playerColor == 'red' ? Colors.red : Colors.black;
    
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
                        _playerColor == 'red' ? Icons.circle : Icons.circle_outlined,
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
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChineseChessBoard(
              board: _board,
              onTap: isMyTurn ? _handleTap : null,
              selectedRow: _selectedRow,
              selectedCol: _selectedCol,
              lastMoveFromRow: _lastMoveFromRow,
              lastMoveFromCol: _lastMoveFromCol,
              lastMoveToRow: _lastMoveToRow,
              lastMoveToCol: _lastMoveToCol,
              possibleMoves: _possibleMoves,
              isRotated: _playerColor == 'black',
            ),
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
              // 和棋按钮
              ElevatedButton.icon(
                onPressed: (!_isGameOver) ? _requestDraw : null,
                icon: const Icon(Icons.handshake, size: 20),
                label: const Text('和棋'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
