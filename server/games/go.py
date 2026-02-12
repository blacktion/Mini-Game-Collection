"""
围棋游戏逻辑
"""

# 全局变量，由主程序设置
socketio = None
games = None


def get_go_liberties(board, row, col, player, visited=None):
    """获取围棋棋子的气（自由度）"""
    if visited is None:
        visited = set()
    
    if (row, col) in visited:
        return set(), set()
    
    visited.add((row, col))
    
    if not (0 <= row < 19 and 0 <= col < 19):
        return set(), visited
    
    if board[row][col] == 0:
        return {(row, col)}, visited
    
    if board[row][col] != player:
        return set(), visited
    
    liberties = set()
    directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
    
    for dr, dc in directions:
        new_row, new_col = row + dr, col + dc
        if 0 <= new_row < 19 and 0 <= new_col < 19:
            if board[new_row][new_col] == 0:
                liberties.add((new_row, new_col))
            elif board[new_row][new_col] == player and (new_row, new_col) not in visited:
                group_liberties, visited = get_go_liberties(board, new_row, new_col, player, visited)
                liberties.update(group_liberties)
    
    return liberties, visited


def capture_dead_groups(board, player):
    """提取死子（没有气的棋子组）"""
    captured = []
    checked = set()
    
    for row in range(19):
        for col in range(19):
            if board[row][col] == player and (row, col) not in checked:
                liberties, group = get_go_liberties(board, row, col, player)
                checked.update(group)
                
                if not liberties:  # 没有气，被提
                    for r, c in group:
                        board[r][c] = 0
                        captured.append((r, c))
    
    return captured


def handle_go_move(game, room_id, sid, data):
    """处理围棋落子"""
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
    if not (0 <= row < 19 and 0 <= col < 19):
        emit('error', {'message': '位置超出范围'})
        return

    if game['board'][row][col] != 0:
        emit('error', {'message': '该位置已有棋子'})
        return

    # 落子
    current_player = game['current_player']
    opponent = 3 - current_player
    game['board'][row][col] = current_player

    # 检查对方是否有被吃掉的子（但还不移除）
    captured_opponent = []
    checked = set()
    for r in range(19):
        for c in range(19):
            if game['board'][r][c] == opponent and (r, c) not in checked:
                liberties, group = get_go_liberties(game['board'], r, c, opponent)
                checked.update(group)
                if not liberties:  # 对方这个组没有气
                    captured_opponent.extend(list(group))
    
    # 检查自己是否被吃（在对方还没移除的情况下）
    liberties_self, _ = get_go_liberties(game['board'], row, col, current_player)
    
    if not liberties_self and not captured_opponent:
        # 自己没有气，且没有吃掉对方的子，这是自杀手
        game['board'][row][col] = 0
        emit('error', {'message': '不能下在此处，这是自杀手'})
        return
    
    # 现在移除对方被吃掉的子
    for r, c in captured_opponent:
        game['board'][r][c] = 0

    # 记录移动
    game['moves'].append({
        'player': current_player,
        'row': row,
        'col': col
    })

    # 清除悔棋标记（新一步棋后允许再次悔棋）
    game['last_undo_player'] = None

    # 广播落子信息（包含被吃掉的子）
    socketio.emit('move_made', {
        'player': current_player,
        'row': row,
        'col': col,
        'captured': captured_opponent  # 发送被吃掉的子的坐标列表
    }, room=room_id)

    # 切换玩家
    game['current_player'] = opponent
    socketio.emit('turn_changed', {
        'current_player': game['current_player']
    }, room=room_id)


def reset_go_game(game):
    """重置围棋游戏"""
    game['board'] = [[0]*19 for _ in range(19)]
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []
    game['black_choice'] = None
    game['white_choice'] = None
