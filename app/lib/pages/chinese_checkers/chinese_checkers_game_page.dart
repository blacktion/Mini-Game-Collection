import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../widgets/chinese_checkers_board_widget.dart';
import '../../config.dart';

class ChineseCheckersGamePage extends StatefulWidget {
  final String? roomId;

  const ChineseCheckersGamePage({super.key, this.roomId});

  @override
  State<ChineseCheckersGamePage> createState() => _ChineseCheckersGamePageState();
}

class _ChineseCheckersGamePageState extends State<ChineseCheckersGamePage> {
  late IO.Socket _socket;
  String? _myRoomId;
  bool _isConnected = false;
  bool _isWaitingForOpponents = false;
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isHost = false;  // 是否为房主
  int _joinedPlayerCount = 1;  // 已加入玩家数量

  // 游戏数据
  String _myColor = ''; // 玩家颜色
  List<List<Map<String, dynamic>?>> _board = List.generate(17, (_) => List.filled(25, null));
  int _currentPlayer = 1; // 当前玩家编号
  String? _gameMessage;
  int? _winner;
  List<Map<String, dynamic>> _playerStatus = []; // 玩家状态列表

  // 选中的棋子
  int? _selectedRow;
  int? _selectedCol;
  
  // 预览状态（用于移动确认）
  int? _previewFromRow;
  int? _previewFromCol;
  int? _previewToRow;
  int? _previewToCol;
  
  // 上一步移动路径
  List<Map<String, int>> _lastMovePath = [];
  
  // 悔棋功能
  bool _canUndo = false;  // 是否可以悔棋（不能连续悔棋）
  bool _undoRequested = false;  // 对方是否请求悔棋
  bool _waitingForUndoResponse = false;  // 等待对方回应悔棋请求
  Map<String, bool> _undoVotes = {};  // 多人悔棋投票记录
  int _totalPlayersInRoom = 2;  // 房间总玩家数（默认2人，实际应从服务器获取）
  
  // 等待弹窗
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
                  '等待其他玩家回复...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '其他玩家正在考虑是否同意悔棋',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // 多人悔棋投票处理
  void _handleUndoVote(String playerId, bool approved) {
    setState(() {
      _undoVotes[playerId] = approved;
    });
    
    // 检查是否所有玩家都已投票
    _checkUndoVotes();
  }
  
  void _checkUndoVotes() {
    final votedPlayers = _undoVotes.length;
    
    if (votedPlayers >= _totalPlayersInRoom) {
      // 检查是否所有人都同意
      bool allApproved = _undoVotes.values.every((vote) => vote);
      
      if (allApproved) {
        // 所有人都同意，执行悔棋
        _executeUndo();
      } else {
        // 有人拒绝，悔棋失败
        _rejectUndo();
      }
    }
  }
  
  void _executeUndo() {
    setState(() {
      _waitingForUndoResponse = false;
      _undoVotes.clear();
      _canUndo = false;
    });
    
    _socket.emit('undo_execute', {'room_id': _myRoomId});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('悔棋成功')),
    );
  }
  
  void _rejectUndo() {
    setState(() {
      _waitingForUndoResponse = false;
      _undoVotes.clear();
    });
    
    _socket.emit('undo_reject', {'room_id': _myRoomId});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('悔棋被拒绝')),
    );
  }

  @override
  void initState() {
    super.initState();
    // 不设置横屏，保持竖屏
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
        _socket.emit('create_room', {'game_type': 'chinese_checkers'});
      } else {
        _socket.emit('join_room', {'room_id': widget.roomId, 'game_type': 'chinese_checkers'});
      }
    });

    _socket.onConnectError((data) {
      if (!mounted) return;
      setState(() => _isConnected = false);
    });
    
    _socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() => _isConnected = false);
    });

    _socket.on('room_created', (data) {

      if (!mounted) return;
      setState(() {
        _myRoomId = data['room_id'];
        _isWaitingForOpponents = true;
        _myColor = 'red'; // 创建者是红方
        _isHost = true;   // 房主
        _joinedPlayerCount = 1;
      });
    });

    _socket.on('room_joined', (data) {
      if (!mounted) return;
      setState(() {
        _myRoomId = data['room_id'];
        _myColor = data['player_color'];
        _isWaitingForOpponents = true;
        _isHost = false;  // 非房主
        // 更新已加入玩家数量
        if (data.containsKey('joined_count')) {
          _joinedPlayerCount = data['joined_count'];
        }
      });
    });

    _socket.on('player_status_update', (data) {

      if (!mounted) return;
      setState(() {
        _joinedPlayerCount = data['joined_count'];
        _playerStatus = List<Map<String, dynamic>>.from(data['players']);
        
      });
    });

    _socket.on('game_start', (data) {

      if (!mounted) return;
      setState(() {
        _isWaitingForOpponents = false;
        _isPlaying = true;
        _gameMessage = data['message'];
        _currentPlayer = data['first_player'];
        
        // 初始化棋盘
        if (data['board'] != null) {
          _board = (data['board'] as List)
              .map((row) => (row as List)
                  .map((cell) => cell == null ? null : cell as Map<String, dynamic>)
                  .toList())
              .toList();
          
          // 统计各颜色棋子数量
          Map<String, int> pieceCount = {};
          for (int r = 0; r < _board.length; r++) {
            for (int c = 0; c < _board[r].length; c++) {
              if (_board[r][c] != null) {
                String color = _board[r][c]!['color'];
                pieceCount[color] = (pieceCount[color] ?? 0) + 1;
              }
            }
          }

        }
      });
    });

    _socket.on('move_made', (data) {
      if (!mounted) return;
      setState(() {
        // 更新棋盘
        final fromRow = data['from_row'];
        final fromCol = data['from_col'];
        final toRow = data['to_row'];
        final toCol = data['to_col'];
        
        // 移动棋子
        _board[toRow][toCol] = data['piece'];
        _board[fromRow][fromCol] = null;
        
        _currentPlayer = data['current_player'];
        _selectedRow = null;
        _selectedCol = null;
        
        // 记录上一步移动路径
        if (data.containsKey('last_move_path') && data['last_move_path'].isNotEmpty) {
          _lastMovePath = (data['last_move_path'] as List)
              .map((pos) => {
                'row': pos[0] as int,
                'col': pos[1] as int
              })
              .toList();
        } else {
          _lastMovePath = [];
        }
        
        if (data['game_over'] == true) {
          _isGameOver = true;
          _isPlaying = false;
          _winner = data['winner'];
          _gameMessage = data['message'];
        }
      });
    });

    _socket.on('game_over', (data) {
      if (!mounted) return;
      setState(() {
        _isGameOver = true;
        _isPlaying = false;
        _winner = data['winner'];
        _gameMessage = data['message'];
      });
    });

    // 悔棋请求

    _socket.on('undo_request', (data) {
      if (!mounted) return;
      setState(() {
        _undoRequested = true;
      });
      // 延迟到下一帧显示对话框，避免在initState期间调用BuildContext
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showUndoRequestDialog();
        }
      });
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
        // 恢复棋子位置
        if (data['from_row'] != null) {
          _board[data['from_row']][data['from_col']] = _board[data['to_row']][data['to_col']];
          _board[data['to_row']][data['to_col']] = null;
          
          // 恢复上一步路径
          if (data['path'] != null && data['path'].length > 1) {
            _lastMovePath = List<Map<String, int>>.from(
              data['path'].map((p) => {'row': p[0], 'col': p[1]})
            );
          } else {
            _lastMovePath = [
              {'row': data['from_row'], 'col': data['from_col']},
              {'row': data['to_row'], 'col': data['to_col']}
            ];
          }
        }
        
        // 切换回合
        _currentPlayer = data['current_player'];
        _canUndo = false;  // 悔棋后不能再悔棋
        _undoVotes.clear(); // 清除投票记录
      });
    });

    _socket.on('error', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );
    });
    
    // 多人悔棋投票
    _socket.on('undo_vote', (data) {
      if (!mounted) return;
      final playerId = data['player_id'];
      final approved = data['approved'];
      _handleUndoVote(playerId, approved);
    });
    
    // 多人悔棋结果
    _socket.on('undo_result', (data) {
      if (!mounted) return;
      final success = data['success'];
      setState(() {
        _waitingForUndoResponse = false;
        _undoVotes.clear();
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('悔棋成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('悔棋被拒绝')),
        );
      }
    });
  }

  // 选择棋子或移动
  void _handleCellTap(int row, int col) {



    
    if (!_isPlaying) {

      return;
    }

    final piece = _board[row][col];

    
    // 如果已经有预览状态
    if (_previewFromRow != null && _previewToRow != null) {
      if (row == _previewToRow && col == _previewToCol) {
        // 点击预览目标位置，确认移动
        _confirmMove();
        return;
      } else if (piece != null && piece['color'] == _myColor) {
        // 点击自己的其他棋子，取消当前预览并选择新棋子
        setState(() {
          _previewFromRow = null;
          _previewFromCol = null;
          _previewToRow = null;
          _previewToCol = null;
          _selectedRow = row;
          _selectedCol = col;
        });

        return;
      } else {
        // 点击无效位置，取消预览
        setState(() {
          _previewFromRow = null;
          _previewFromCol = null;
          _previewToRow = null;
          _previewToCol = null;
        });

        return;
      }
    }
    
    // 如果已经选中棋子
    if (_selectedRow != null && _selectedCol != null) {
      // 点击已选中的棋子，取消选择
      if (row == _selectedRow && col == _selectedCol) {
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
        });
        
        return;
      }
      
      // 点击的是自己的其他棋子，切换选择
      if (piece != null && piece['color'] == _myColor) {
        setState(() {
          _selectedRow = row;
          _selectedCol = col;
        });
        
        return;
      }
      
      // 点击空位，设置预览状态
      if (piece == null) {
        final isValidMove = _isValidMove(_selectedRow!, _selectedCol!, row, col);
        if (isValidMove) {
          setState(() {
            _previewFromRow = _selectedRow;
            _previewFromCol = _selectedCol;
            _previewToRow = row;
            _previewToCol = col;
            _selectedRow = null;
            _selectedCol = null;
          });
          
        }
        return;
      }
    }
    
    // 选择棋子（必须是己方棋子）
    if (piece != null && piece['color'] == _myColor) {
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
      });

    }
  }

  // 验证移动是否合法（简化版本）
  bool _isValidMove(int fromRow, int fromCol, int toRow, int toCol) {
    // 基本验证：检查目标位置是否为空且在棋盘范围内
    if (toRow < 0 || toRow >= 17 || toCol < 0 || toCol >= 25) {
      return false;
    }
    
    if (_board[toRow][toCol] != null) {
      return false;
    }
    
    // 检查是否是相邻位置（六角网格的6个方向）
    final directions = [
      [-1, -1], [-1, 1],  // 左上、右上
      [0, -2], [0, 2],    // 左边（隔一列）、右边（隔一列）
      [1, -1], [1, 1]     // 左下、右下
    ];
    
    for (final dir in directions) {
      final newRow = fromRow + dir[0];
      final newCol = fromCol + dir[1];
      if (newRow == toRow && newCol == toCol) {
        return true;
      }
    }
    
    // TODO: 这里可以添加更复杂的跳跃验证逻辑
    // 暂时允许所有移动，让服务器端进行最终验证
    return true;
  }
  
  // 确认移动
  void _confirmMove() {
    if (_previewFromRow == null || _previewToRow == null) return;
    
    _makeMove(_previewFromRow!, _previewFromCol!, _previewToRow!, _previewToCol!);
    
    setState(() {
      _previewFromRow = null;
      _previewFromCol = null;
      _previewToRow = null;
      _previewToCol = null;
    });
  }
  
  // 取消移动预览
  void _cancelMove() {
    setState(() {
      _previewFromRow = null;
      _previewFromCol = null;
      _previewToRow = null;
      _previewToCol = null;
      _selectedRow = null;
      _selectedCol = null;
    });
  }
  void _makeMove(int fromRow, int fromCol, int toRow, int toCol) {




    
    _socket.emit('make_move', {
      'room_id': _myRoomId,
      'from_row': fromRow,
      'from_col': fromCol,
      'to_row': toRow,
      'to_col': toCol,
    });


    setState(() {
      _selectedRow = null;
      _selectedCol = null;
      _canUndo = true;  // 移动后可以悔棋
    });
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
    // 验证是否轮到自己（只有不是当前轮到的玩家才能悔棋）
    if (_currentPlayerColor() == _myColor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请等待对方走棋后再请求悔棋')),
      );
      return;
    }

    _showConfirmDialog(
      '请求悔棋',
      '确定要请求悔棋吗？',
      () {
        setState(() {
          _waitingForUndoResponse = true;
          _undoVotes.clear(); // 清除之前的投票记录
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
  void _showUndoRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('悔棋请求'),
        content: const Text('对方请求悔棋，是否同意？'),
        actions: [
          TextButton(
            onPressed: () => _respondUndoRequest(false),
            child: const Text('拒绝'),
          ),
          TextButton(
            onPressed: () => _respondUndoRequest(true),
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }

  // 房主开始游戏
  void _startGame() {
    if (!_isHost || _joinedPlayerCount < 2) return;
    
    _socket.emit('start_game', {
      'room_id': _myRoomId,
    });
  }

  // 清理Socket连接
  void _cleanup() {
    _socket.clearListeners();
    _socket.disconnect();
  }

  // 显示退出确认对话框
  void _showLeaveConfirmDialog() {
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
              Navigator.pop(context);
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                const SizedBox(height: 16),
                Text(
                  '你是${_getColorName(_myColor)}${_isHost ? ' (房主)' : ''}',
                  style: TextStyle(
                    fontSize: 16,
                    color: _getColorValue(_myColor),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // 玩家列表
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '已加入的玩家',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ..._buildPlayerList(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 房主开始按钮
                if (_isHost && _joinedPlayerCount >= 2)
                  ElevatedButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('开始游戏 ($_joinedPlayerCount人)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            ),
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
                  color: _winner != null ? Colors.green : Colors.red,
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
        appBar: AppBar(
          title: Text(_myRoomId != null ? '房间: $_myRoomId' : '中国跳棋'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          centerTitle: true,
          actions: [
            if (_isPlaying)
              IconButton(
                icon: const Icon(Icons.flag),
                onPressed: _surrender,
              ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _showLeaveConfirmDialog,
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // 顶部信息栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('房间号: $_myRoomId'),
                      const SizedBox(width: 16),
                      Text('你是${_getColorName(_myColor)}'),
                      const SizedBox(width: 16),
                      Text(
                        '当前: ${_getCurrentPlayerColor()}',
                        style: TextStyle(
                          color: _currentPlayerColor() == _myColor 
                              ? Colors.green 
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 游戏状态信息
                if (_gameMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.yellow[100],
                    child: Text(
                      _gameMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                // 棋盘
                Expanded(
                  flex: 5, // 给棋盘更多空间
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Center(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.98, // 98%宽度充分利用空间
                                maxHeight: constraints.maxHeight * 0.95, // 95%高度
                              ),
                              child: _buildBoard(),
                            ),
                          ),
                          // 移动确认按钮覆盖层
                          if (_previewFromRow != null && _previewToRow != null)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Container(
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
                      );
                    },
                  ),
                ),
                
                // 底部按钮栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 悔棋按钮 - 只有不是当前轮到的玩家才能悔棋
                      ElevatedButton.icon(
                        onPressed: (!_isGameOver && !_undoRequested && _canUndo && _currentPlayerColor() != _myColor) ? _requestUndo : null,
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
                
                // 底部渐变装饰
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
            ),
            _buildWaitingOverlay(),
          ],
        ),
      ),
    );
  }

  // 构建六角星棋盘
  Widget _buildBoard() {
    return Container(
      padding: const EdgeInsets.all(4),
      child: ChineseCheckersBoardWidget(
        board: _board,
        selectedRow: _selectedRow,
        selectedCol: _selectedCol,
        lastMovePath: _lastMovePath,
        previewFromRow: _previewFromRow,
        previewFromCol: _previewFromCol,
        previewToRow: _previewToRow,
        previewToCol: _previewToCol,
        onTap: _handleCellTap,
        myColor: _myColor,
        currentPlayerColor: _currentPlayerColor(),
      ),
    );
  }

  String _getColorName(String color) {
    const colorNames = {
      'red': '红方',
      'green': '绿方',
      'yellow': '黄方',
      'blue': '蓝方',
      'orange': '橙方',
      'purple': '紫方',
    };
    return colorNames[color] ?? color;
  }

  Color _getColorValue(String color) {
    const colorValues = {
      'red': Colors.red,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'blue': Colors.blue,
      'orange': Colors.orange,
      'purple': Colors.purple,
    };
    return colorValues[color] ?? Colors.grey;
  }

  String _getCurrentPlayerColor() {
    // 简化处理，实际应该从服务器获取当前玩家颜色
    const colors = ['红方', '绿方', '黄方', '蓝方', '橙方', '紫方'];
    return colors[(_currentPlayer - 1) % colors.length];
  }

  String _currentPlayerColor() {
    // 简化处理
    const colors = ['red', 'green', 'yellow', 'blue', 'orange', 'purple'];
    return colors[(_currentPlayer - 1) % colors.length];
  }

  bool _getPlayerStatus(String color) {
    // 根据_playerStatus列表检查指定颜色的玩家是否已加入
    for (var player in _playerStatus) {
      if (player['color'] == color && player['joined'] == true) {
        return true;
      }
    }
    return false;
  }

  // 构建玩家列表
  List<Widget> _buildPlayerList() {
    const colors = ['red', 'green', 'yellow', 'blue', 'orange', 'purple'];
    const colorNames = ['红方', '绿方', '黄方', '蓝方', '橙方', '紫方'];
    
    List<Widget> players = [];
    for (int i = 0; i < colors.length; i++) {
      players.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _getColorValue(colors[i]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: 1),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                colorNames[i],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,  // 房主加粗
                ),
              ),
              const Spacer(),
              Icon(
                i == 0 
                    ? Icons.star  // 房主显示星星
                    : (_getPlayerStatus(colors[i]) ? Icons.check : Icons.close),
                color: i == 0 
                    ? Colors.orange 
                    : (_getPlayerStatus(colors[i]) ? Colors.green : Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return players;
  }
}

