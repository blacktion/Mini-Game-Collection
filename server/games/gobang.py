"""
五子棋游戏逻辑
"""

# 全局变量，由主程序设置
socketio = None
games = None


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
