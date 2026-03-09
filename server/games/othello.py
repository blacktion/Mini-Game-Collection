"""
黑白棋游戏逻辑
"""

# 全局变量，由主程序设置
socketio = None
games = None


def initialize_othello_game(sid):
    """初始化黑白棋游戏数据"""
    return {
        'game_type': 'othello',
        'black_player': None,
        'white_player': None,
        'black_choice': None,
        'white_choice': None,
        'board': initialize_othello_board(),
        'current_player': 1,
        'game_over': False,
        'winner': None,
        'moves': [],
        'undo_requested': False,
        'last_undo_player': None
    }


def initialize_othello_board():
    """初始化黑白棋棋盘"""
    board = [[0]*8 for _ in range(8)]
    # 初始四个棋子：中心位置
    board[3][3] = 2  # 白
    board[3][4] = 1  # 黑
    board[4][3] = 1  # 黑
    board[4][4] = 2  # 白
    return board


def get_othello_flips(board, row, col, player):
    """获取落子后能翻转的棋子位置"""
    if board[row][col] != 0:
        return []

    opponent = 3 - player
    all_flips = []

    # 8个方向
    directions = [
        (-1, -1), (-1, 0), (-1, 1),
        (0, -1),          (0, 1),
        (1, -1), (1, 0), (1, 1)
    ]

    for dr, dc in directions:
        flips = []
        r, c = row + dr, col + dc

        # 沿着这个方向前进
        while 0 <= r < 8 and 0 <= c < 8:
            if board[r][c] == opponent:
                flips.append((r, c))
            elif board[r][c] == player:
                # 找到己方棋子，可以翻转中间的对手棋子
                all_flips.extend(flips)
                break
            else:
                # 遇到空位，这个方向不能翻转
                break
            r += dr
            c += dc

    return all_flips


def is_valid_othello_move(board, row, col, player):
    """检查落子是否合法"""
    if not (0 <= row < 8 and 0 <= col < 8):
        return False
    if board[row][col] != 0:
        return False

    flips = get_othello_flips(board, row, col, player)
    return len(flips) > 0


def get_valid_othello_moves(board, player):
    """获取所有合法的落子位置"""
    valid_moves = []
    for row in range(8):
        for col in range(8):
            if is_valid_othello_move(board, row, col, player):
                valid_moves.append((row, col))
    return valid_moves


def can_play_othello_move(board, player):
    """检查某个玩家是否有合法落子位置"""
    return len(get_valid_othello_moves(board, player)) > 0


def is_othello_board_full(board):
    """检查棋盘是否已满"""
    for row in range(8):
        for col in range(8):
            if board[row][col] == 0:
                return False
    return True


def determine_othello_winner(board):
    """确定黑白棋胜负"""
    black_count = 0
    white_count = 0

    for row in range(8):
        for col in range(8):
            if board[row][col] == 1:
                black_count += 1
            elif board[row][col] == 2:
                white_count += 1

    if black_count > white_count:
        return 1  # 黑棋胜
    elif white_count > black_count:
        return 2  # 白棋胜
    else:
        return 0  # 平局


def handle_othello_move(game, room_id, sid, data):
    """处理黑白棋落子"""
    from flask_socketio import emit

    row = data.get('row')
    col = data.get('col')

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否轮到该玩家
    current_sid = game['black_player'] if game['current_player'] == 1 else game['white_player']
    if sid != current_sid:
        emit('error', {'message': '不是你的回合'})
        return

    # 检查位置是否有效
    if not (0 <= row < 8 and 0 <= col < 8):
        emit('error', {'message': '位置超出范围'})
        return

    if game['board'][row][col] != 0:
        emit('error', {'message': '该位置已有棋子'})
        return

    # 检查是否是合法的落子位置
    current_player = game['current_player']
    flips = get_othello_flips(game['board'], row, col, current_player)

    if not flips:
        emit('error', {'message': '必须放置在能翻转对手棋子的位置'})
        return

    # 执行落子和翻转
    game['board'][row][col] = current_player
    for fr, fc in flips:
        game['board'][fr][fc] = current_player

    # 记录移动
    game['moves'].append({
        'row': row,
        'col': col,
        'player': current_player
    })

    # 检查游戏状态
    opponent = 3 - current_player

    # 广播落子信息
    socketio.emit('move_made', {
        'player': current_player,
        'move': {'row': row, 'col': col},
        'current_player': opponent if can_play_othello_move(game['board'], opponent) else current_player
    }, room=room_id)

    if can_play_othello_move(game['board'], opponent):
        # 对方可以落子，切换回合
        game['current_player'] = opponent
    elif can_play_othello_move(game['board'], current_player):
        # 对方无法落子，当前玩家继续
        pass
    else:
        # 双方都无法落子，游戏结束
        winner = determine_othello_winner(game['board'])
        game['game_over'] = True
        game['winner'] = winner

        winner_name = '黑方' if winner == 1 else '白方'
        if winner == 0:
            winner_name = '平局'

        socketio.emit('game_over', {
            'winner': winner_name,
            'message': f'{winner_name}！'
        }, room=room_id)


def reset_othello_game(game):
    """重置黑白棋游戏"""
    game['board'] = initialize_othello_board()
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []
    game['black_choice'] = None
    game['white_choice'] = None


def assign_othello_player(game, sid):
    """分配黑白棋玩家颜色"""
    if game['black_player'] is None:
        game['black_player'] = sid
        return 'black'
    elif game['white_player'] is None:
        game['white_player'] = sid
        return 'white'
    return None


def record_othello_choice(game, sid, choice):
    """记录黑白棋玩家的先后手选择"""
    if game['black_player'] == sid:
        game['black_choice'] = choice
    elif game['white_player'] == sid:
        game['white_choice'] = choice


def should_start_othello(game):
    """检查是否可以开始黑白棋游戏"""
    return game['black_choice'] is not None and game['white_choice'] is not None


def determine_othello_first_player(game):
    """确定黑白棋先后手"""
    if game['black_choice'] == 'first':
        # 黑棋先手
        is_black_first = True
    else:
        # 白棋先手
        is_black_first = False
    return is_black_first


def get_othello_current_player_sid(game):
    """获取当前轮到的玩家sid"""
    return game['black_player'] if game['current_player'] == 1 else game['white_player']


def get_othello_opponent_sid(game, sid):
    """获取对手的sid"""
    return game['white_player'] if sid == game['black_player'] else game['black_player']


def handle_othello_disconnect(game, sid):
    """处理黑白棋玩家断开连接，返回对手sid"""
    if game['black_player'] == sid or game['white_player'] == sid:
        opponent = get_othello_opponent_sid(game, sid)
        return [opponent] if opponent else []
    return []


def handle_othello_surrender(game, sid):
    """处理黑白棋认输，返回(赢家编号, 赢家sid, 输家sid)"""
    winner = 2 if sid == game['black_player'] else 1
    winner_sid = game['black_player'] if winner == 1 else game['white_player']
    loser_sid = game['white_player'] if winner == 1 else game['black_player']
    return winner, winner_sid, loser_sid


def get_othello_winner_name(winner):
    """获取黑白棋赢家名称"""
    if winner == 1:
        return '黑方'
    elif winner == 2:
        return '白方'
    else:
        return '平局'


def execute_othello_undo(game, last_move):
    """执行黑白棋悔棋"""
    row = last_move['row']
    col = last_move['col']
    game['board'][row][col] = 0
    # 恢复被翻转的棋子
    if 'flipped' in last_move:
        for flipped_pos in last_move['flipped']:
            game['board'][flipped_pos['row']][flipped_pos['col']] = flipped_pos['old_color']
