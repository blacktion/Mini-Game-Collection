"""
五子棋游戏逻辑
"""

import random

# 全局变量，由主程序设置
socketio = None
games = None


def initialize_gobang_game(sid):
    """初始化五子棋游戏数据"""
    return {
        'game_type': 'gobang',
        'black_player': None,
        'white_player': None,
        'black_choice': None,
        'white_choice': None,
        'board': [[0]*15 for _ in range(15)],
        'current_player': 1,
        'game_over': False,
        'winner': None,
        'moves': [],
        'undo_requested': False,
        'last_undo_player': None
    }


def get_gobang_player_info(game, sid):
    """获取五子棋玩家信息，返回(玩家编号, 是否为黑方)"""
    if game['black_player'] == sid:
        return 1, True
    elif game['white_player'] == sid:
        return 2, False
    return None, None


def assign_gobang_player(game, sid):
    """分配五子棋玩家颜色"""
    if game['black_player'] is None:
        game['black_player'] = sid
        return 'black'
    elif game['white_player'] is None:
        game['white_player'] = sid
        return 'white'
    return None


def record_gobang_choice(game, sid, choice):
    """记录五子棋玩家的先后手选择"""
    if game['black_player'] == sid:
        game['black_choice'] = choice
    elif game['white_player'] == sid:
        game['white_choice'] = choice


def should_start_gobang(game):
    """检查是否可以开始五子棋游戏"""
    return game['black_choice'] is not None and game['white_choice'] is not None


def determine_gobang_first_player(game):
    """确定五子棋先后手并可能交换玩家"""
    if game['black_choice'] == game['white_choice']:
        # 选择相同，随机决定
        first_player_sid = random.choice([game['black_player'], game['white_player']])
        is_black_first = (first_player_sid == game['black_player'])
    else:
        # 选择不同，先选先手的为先手
        first_choice_sid = game['black_player'] if game['black_choice'] == 'first' else game['white_player']
        is_black_first = (first_choice_sid == game['black_player'])

    return is_black_first


def get_gobang_current_player_sid(game):
    """获取当前轮到的玩家sid"""
    return game['black_player'] if game['current_player'] == 1 else game['white_player']


def get_gobang_opponent_sid(game, sid):
    """获取对手的sid"""
    return game['white_player'] if sid == game['black_player'] else game['black_player']


def handle_gobang_disconnect(game, sid):
    """处理五子棋玩家断开连接，返回对手sid列表"""
    if game['black_player'] == sid or game['white_player'] == sid:
        opponent = get_gobang_opponent_sid(game, sid)
        return [opponent] if opponent else []
    return []


def execute_gobang_undo(game, last_move):
    """执行五子棋悔棋逻辑"""
    row = last_move['row']
    col = last_move['col']
    game['board'][row][col] = 0


def handle_gobang_surrender(game, sid):
    """处理五子棋认输，返回(赢家编号, 赢家sid, 输家sid)"""
    winner = 2 if sid == game['black_player'] else 1
    winner_sid = game['black_player'] if winner == 1 else game['white_player']
    loser_sid = game['white_player'] if winner == 1 else game['black_player']
    return winner, winner_sid, loser_sid


def get_gobang_winner_name(winner):
    """获取五子棋赢家名称"""
    return '黑棋' if winner == 1 else '白棋'


def check_gobang_winner(board, row, col):
    """检查五子棋是否有玩家获胜"""
    player = board[row][col]

    # 四个方向：水平、垂直、主对角线、副对角线
    directions = [
        [(0, 1), (0, -1)],    # 水平
        [(1, 0), (-1, 0)],    # 垂直
        [(1, 1), (-1, -1)],   # 主对角线
        [(1, -1), (-1, 1)]    # 副对角线
    ]

    for dir_pair in directions:
        count = 1
        for dr, dc in dir_pair:
            r, c = row + dr, col + dc
            while 0 <= r < 15 and 0 <= c < 15 and board[r][c] == player:
                count += 1
                r += dr
                c += dc
        if count >= 5:
            return player

    return None


def check_gobang_draw(board):
    """检查五子棋是否平局（棋盘已满）"""
    for row in board:
        if 0 in row:
            return False
    return True


def handle_gobang_move(game, room_id, sid, data):
    """处理五子棋落子"""
    row = data.get('row')
    col = data.get('col')

    # 检查游戏是否结束
    if game['game_over']:
        from flask_socketio import emit
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否轮到该玩家
    current_sid = game['black_player'] if game['current_player'] == 1 else game['white_player']
    if sid != current_sid:
        from flask_socketio import emit
        emit('error', {'message': '不是你的回合'})
        return

    # 检查位置是否有效
    if not (0 <= row < 15 and 0 <= col < 15):
        from flask_socketio import emit
        emit('error', {'message': '位置超出范围'})
        return

    if game['board'][row][col] != 0:
        from flask_socketio import emit
        emit('error', {'message': '该位置已有棋子'})
        return

    # 落子
    game['board'][row][col] = game['current_player']
    game['moves'].append({
        'player': game['current_player'],
        'row': row,
        'col': col
    })

    # 清除悔棋标记（新一步棋后允许再次悔棋）
    game['last_undo_player'] = None

    # 广播落子信息
    socketio.emit('move_made', {
        'player': game['current_player'],
        'row': row,
        'col': col
    }, room=room_id)

    # 检查胜负
    winner = check_gobang_winner(game['board'], row, col)
    if winner:
        game['game_over'] = True
        game['winner'] = winner
        winner_name = '黑棋' if winner == 1 else '白棋'
        socketio.emit('game_over', {
            'winner': winner,
            'message': f'{winner_name}获胜！'
        }, room=room_id)
    elif check_gobang_draw(game['board']):
        game['game_over'] = True
        socketio.emit('game_over', {
            'winner': 0,
            'message': '平局！'
        }, room=room_id)
    else:
        # 切换玩家
        game['current_player'] = 3 - game['current_player']
        socketio.emit('turn_changed', {
            'current_player': game['current_player']
        }, room=room_id)


def reset_gobang_game(game):
    """重置五子棋游戏"""
    game['board'] = [[0]*15 for _ in range(15)]
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []
    game['black_choice'] = None
    game['white_choice'] = None
