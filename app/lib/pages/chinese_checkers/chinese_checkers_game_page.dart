import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
  List<List<Map<String, dynamic>?>> _board = List.generate(17, (_) => List.filled(17, null));
  int _currentPlayer = 1; // 当前玩家编号
  String? _gameMessage;
  int? _winner;

  // 选中的棋子
  int? _selectedRow;
  int? _selectedCol;

  @override
  void initState() {
    super.initState();
    // 不设置横屏，保持竖屏
    _initSocket();
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
        _socket.emit('create_room', {'game_type': 'chinese_checkers'});
      } else {
        print('Emitting join_room: ${widget.roomId}');
        _socket.emit('join_room', {'room_id': widget.roomId, 'game_type': 'chinese_checkers'});
      }
    });

    _socket.onConnectError((data) {
      print('Connection error: $data');
      if (!mounted) return;
      setState(() => _isConnected = false);
    });

    _socket.on('room_created', (data) {
      print('Room created: ${data['room_id']}');
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
      print('Room joined: ${data['room_id']}');
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
      print('Player status updated: ${data['joined_count']} players joined');
      if (!mounted) return;
      setState(() {
        _joinedPlayerCount = data['joined_count'];
      });
    });

    _socket.on('game_start', (data) {
      print('Game started');
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

    _socket.on('error', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );
    });
  }

  // 选择棋子或移动
  void _handleCellTap(int row, int col) {
    if (!_isPlaying) return;

    final piece = _board[row][col];
    
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
      
      // 尝试移动到目标位置
      _makeMove(_selectedRow!, _selectedCol!, row, col);
      return;
    }
    
    // 选择棋子（必须是己方棋子）
    if (piece != null && piece['color'] == _myColor) {
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
      });
    }
  }

  // 执行移动
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
    });
  }

  // 认输
  void _surrender() {
    _socket.emit('surrender', {
      'room_id': _myRoomId,
    });
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
    if (_socket != null) {
      _socket.clearListeners();
      _socket.disconnect();
    }
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
        body: Column(
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
              child: Center(
                child: _buildBoard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建六角星棋盘
  Widget _buildBoard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CustomPaint(
          painter: ChineseCheckersBoardPainter(
            board: _board,
            selectedRow: _selectedRow,
            selectedCol: _selectedCol,
            onTap: _handleCellTap,
            myColor: _myColor,
            currentPlayerColor: _currentPlayerColor(),
          ),
        ),
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
                    : (_joinedPlayerCount > i ? Icons.check : Icons.close),
                color: i == 0 
                    ? Colors.orange 
                    : (_joinedPlayerCount > i ? Colors.green : Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return players;
  }
}

class ChineseCheckersBoardPainter extends CustomPainter {
  final List<List<Map<String, dynamic>?>> board;
  final int? selectedRow;
  final int? selectedCol;
  final Function(int, int) onTap;
  final String myColor;
  final String currentPlayerColor; // 当前轮到的颜色

  ChineseCheckersBoardPainter({
    required this.board,
    this.selectedRow,
    this.selectedCol,
    required this.onTap,
    required this.myColor,
    required this.currentPlayerColor,
  });

  // 获取当前玩家的视角旋转角度
  int _getPlayerRotationAngle() {
    switch (myColor) {
      case 'red': return 0;     // 红方视角（上方）
      case 'blue': return 180;  // 蓝方视角（下方）
      case 'green': return 60;  // 绿方视角（左上）
      case 'yellow': return 120; // 黄方视角（右上）
      case 'orange': return 240; // 橙方视角（右下）
      case 'purple': return 300; // 紫方视角（左下）
      default: return 0;
    }
  }

  // 将逻辑坐标转换为显示坐标（根据玩家视角）
  Map<String, int> _transformCoordinate(int row, int col) {
    // 标准六角星棋盘的坐标变换
    // 由于棋盘对称，我们可以根据玩家颜色旋转视角
    int rotationAngle = _getPlayerRotationAngle();
    
    if (rotationAngle == 0) {
      // 无旋转，返回原始坐标
      return {'row': row, 'col': col};
    }
    
    // 为了简化，我们使用预定义的旋转映射
    // 在中国跳棋中，每个方向相对于红方（标准视角）的旋转
    // 这里我们实现一个简化的旋转逻辑
    int maxCoord = 16; // 棋盘最大坐标
    
    // 根据旋转角度应用坐标变换
    switch (rotationAngle) {
      case 180: // 旋转180度
        // 中心对称变换
        int newRow = maxCoord - row;
        int newCol = maxCoord - col;
        return {'row': newRow, 'col': newCol};
      case 60: // 顺时针旋转60度（近似）
        // 简化的60度旋转
        // 这里我们使用一种映射方法
        // 为了简化，使用预计算的变换
        // 将(row, col)映射到新的坐标系
        int transformedRow = col;
        int transformedCol = maxCoord - row;
        return {'row': transformedRow.clamp(0, maxCoord), 'col': transformedCol.clamp(0, maxCoord)};
      case 120: // 顺时针旋转120度（近似）
        int transformedRow = maxCoord - (row + col) ~/ 2;
        int transformedCol = (row - col + maxCoord) ~/ 2;
        return {'row': transformedRow.clamp(0, maxCoord), 'col': transformedCol.clamp(0, maxCoord)};
      case 240: // 顺时针旋转240度（近似）
        int transformedRow = (row + col) ~/ 2;
        int transformedCol = maxCoord - (row - col + maxCoord) ~/ 2;
        return {'row': transformedRow.clamp(0, maxCoord), 'col': transformedCol.clamp(0, maxCoord)};
      case 300: // 顺时针旋转300度（近似）
        int transformedRow = maxCoord - col;
        int transformedCol = row;
        return {'row': transformedRow.clamp(0, maxCoord), 'col': transformedCol.clamp(0, maxCoord)};
      default:
        return {'row': row, 'col': col};
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 17;
    
    // 绘制有效的六角星位置
    for (int row = 0; row < 17; row++) {
      for (int col = 0; col < 17; col++) {
        if (_isValidPosition(row, col)) {
          // 根据玩家视角变换坐标
          Map<String, int> displayPos = _transformCoordinate(row, col);
          int displayRow = displayPos['row']!;
          int displayCol = displayPos['col']!;
          
          final x = displayCol * cellSize + cellSize / 2;
          final y = displayRow * cellSize + cellSize / 2;
          
          // 检查变换后的坐标是否在可视区域内
          if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
            final isSelected = row == selectedRow && col == selectedCol;
            final piece = board[row][col];
            
            // 绘制格子背景
            final paint = Paint()
              ..color = isSelected ? Colors.yellow[200]! : Colors.brown[200]!
              ..style = PaintingStyle.fill;
            canvas.drawCircle(Offset(x, y), cellSize * 0.4, paint);
            
            // 绘制棋子
            if (piece != null) {
              final piecePaint = Paint()
                ..color = _getPieceColor(piece['color'])
                ..style = PaintingStyle.fill;
              canvas.drawCircle(Offset(x, y), cellSize * 0.35, piecePaint);
              
              // 如果是当前玩家的棋子或当前回合的棋子，添加特殊标记
              bool isCurrentPlayerPiece = piece['color'] == myColor;
              bool isCurrentTurn = piece['color'] == currentPlayerColor;
              
              if (isCurrentPlayerPiece) {
                final borderPaint = Paint()
                  ..color = Colors.black
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2;
                canvas.drawCircle(Offset(x, y), cellSize * 0.35, borderPaint);
              } else if (isCurrentTurn) {
                // 当前回合的棋子添加一个圆点标记
                final turnMarkerPaint = Paint()
                  ..color = Colors.white
                  ..style = PaintingStyle.fill;
                canvas.drawCircle(Offset(x, y), cellSize * 0.15, turnMarkerPaint);
              }
            }
          }
        }
      }
    }
  }

  bool _isValidPosition(int row, int col) {
    // 六角星棋盘的有效位置 - 与服务器端完全一致（共124个位置）
    final validPositions = {
      // 按照服务器端计算出的124个有效位置
      '0,6', '0,7', '0,8', '0,9', '0,10',
      '1,5', '1,6', '1,7', '1,8', '1,9', '1,10', '1,11',
      '2,4', '2,5', '2,6', '2,7', '2,8', '2,9', '2,10', '2,11', '2,12',
      '3,3', '3,4', '3,5', '3,6', '3,7', '3,8', '3,9', '3,10', '3,11', '3,12', '3,13',
      '4,0', '4,1', '4,2', '4,3', '4,4', '4,5', '4,6', '4,7', '4,8', '4,9', '4,10', '4,11', '4,12', '4,13', '4,14', '4,15', '4,16',
      '5,0', '5,1', '5,2', '5,3', '5,4', '5,5', '5,6', '5,7', '5,8', '5,9', '5,10', '5,11', '5,12', '5,13', '5,14', '5,15', '5,16',
      '6,0', '6,1', '6,2', '6,4', '6,5', '6,6', '6,7', '6,8', '6,9', '6,10', '6,11', '6,12', '6,14', '6,15', '6,16',
      '7,0', '7,5', '7,6', '7,7', '7,8', '7,9', '7,10', '7,11', '7,16',
      '8,6', '8,7', '8,8', '8,9', '8,10',
      '9,0', '9,16',
      '10,0', '10,1', '10,2', '10,14', '10,15', '10,16',
      '11,0', '11,1', '11,2', '11,14', '11,15', '11,16',
      '12,0', '12,1', '12,2', '12,14', '12,15', '12,16',
      '14,8', '15,7', '15,8', '15,9', '16,6', '16,7', '16,8', '16,9', '16,10'
    };
    
    return validPositions.contains('$row,$col');
  }

  Color _getPieceColor(String color) {
    switch (color) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow;
      case 'blue': return Colors.blue;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}