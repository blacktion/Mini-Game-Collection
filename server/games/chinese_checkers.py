#!/usr/bin/env python3
"""
中国跳棋游戏逻辑模块
使用六角星棋盘
"""

# 全局变量（将在app_new.py中设置）
socketio = None
games = None


def initialize_chinese_checkers_board():
    """初始化中国跳棋棋盘（六角星形）"""
    # 使用二维数组表示六角星棋盘
    # 棋盘大小为17x17，实际使用部分形成六角星形状
    board = [[None]*17 for _ in range(17)]
    
    # 定义六角星的6个角的起始位置和棋子布局
    # 每个角放置10枚棋子（2行三角形）
    
    # 红方（上方）
    red_positions = [
        (0, 8), (1, 7), (1, 8), (1, 9),
        (2, 6), (2, 7), (2, 8), (2, 9), (2, 10)
    ]
    for row, col in red_positions:
        board[row][col] = {'color': 'red', 'type': 'piece'}
    
    # 绿方（左上）
    green_positions = [
        (4, 0), (4, 1), (4, 2), (5, 0), (5, 1), 
        (5, 2), (6, 0), (6, 1), (6, 2), (7, 0)
    ]
    for row, col in green_positions:
        board[row][col] = {'color': 'green', 'type': 'piece'}
    
    # 黄方（右上）
    yellow_positions = [
        (4, 14), (4, 15), (4, 16), (5, 14), (5, 15),
        (5, 16), (6, 14), (6, 15), (6, 16), (7, 16)
    ]
    for row, col in yellow_positions:
        board[row][col] = {'color': 'yellow', 'type': 'piece'}
    
    # 蓝方（下方）
    blue_positions = [
        (14, 8), (15, 7), (15, 8), (15, 9),
        (16, 6), (16, 7), (16, 8), (16, 9), (16, 10)
    ]
    for row, col in blue_positions:
        board[row][col] = {'color': 'blue', 'type': 'piece'}
    
    # 橙方（右下）
    orange_positions = [
        (9, 16), (10, 14), (10, 15), (10, 16),
        (11, 14), (11, 15), (11, 16), (12, 14), (12, 15), (12, 16)
    ]
    for row, col in orange_positions:
        board[row][col] = {'color': 'orange', 'type': 'piece'}
    
    # 紫方（左下）
    purple_positions = [
        (9, 0), (10, 0), (10, 1), (10, 2),
        (11, 0), (11, 1), (11, 2), (12, 0), (12, 1), (12, 2)
    ]
    for row, col in purple_positions:
        board[row][col] = {'color': 'purple', 'type': 'piece'}
    
    return board


def is_valid_position(row, col):
    """检查位置是否在棋盘有效范围内"""
    if not (0 <= row < 17 and 0 <= col < 17):
        return False
    
    # 六角星棋盘的有效位置（中心对称）
    valid_positions = {
        # 中心区域
        (8, 6), (8, 7), (8, 8), (8, 9), (8, 10),
        (7, 5), (7, 6), (7, 7), (7, 8), (7, 9), (7, 10), (7, 11),
        (6, 4), (6, 5), (6, 6), (6, 7), (6, 8), (6, 9), (6, 10), (6, 11), (6, 12),
        (5, 3), (5, 4), (5, 5), (5, 6), (5, 7), (5, 8), (5, 9), (5, 10), (5, 11), (5, 12), (5, 13),
        (4, 2), (4, 3), (4, 4), (4, 5), (4, 6), (4, 7), (4, 8), (4, 9), (4, 10), (4, 11), (4, 12), (4, 13), (4, 14),
        (3, 3), (3, 4), (3, 5), (3, 6), (3, 7), (3, 8), (3, 9), (3, 10), (3, 11), (3, 12), (3, 13),
        (2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10), (2, 11), (2, 12),
        (1, 5), (1, 6), (1, 7), (1, 8), (1, 9), (1, 10), (1, 11),
        (0, 6), (0, 7), (0, 8), (0, 9), (0, 10),
        
        # 上方三角（红方起始位置）
        (0, 8), (1, 7), (1, 8), (1, 9), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10),
        
        # 左上三角（绿方起始位置）
        (4, 0), (4, 1), (4, 2), (5, 0), (5, 1), (5, 2), (6, 0), (6, 1), (6, 2), (7, 0),
        
        # 右上三角（黄方起始位置）
        (4, 14), (4, 15), (4, 16), (5, 14), (5, 15), (5, 16), (6, 14), (6, 15), (6, 16), (7, 16),
        
        # 下方三角（蓝方起始位置）
        (14, 8), (15, 7), (15, 8), (15, 9), (16, 6), (16, 7), (16, 8), (16, 9), (16, 10),
        
        # 右下三角（橙方起始位置）
        (9, 16), (10, 14), (10, 15), (10, 16), (11, 14), (11, 15), (11, 16), (12, 14), (12, 15), (12, 16),
        
        # 左下三角（紫方起始位置）
        (9, 0), (10, 0), (10, 1), (10, 2), (11, 0), (11, 1), (11, 2), (12, 0), (12, 1), (12, 2)
    }
    
    return (row, col) in valid_positions


def get_neighbors(row, col):
    """获取指定位置的所有相邻位置（6个方向）"""
    directions = [
        (-1, 0), (-1, 1),  # 左上、右上
        (0, -1), (0, 1),   # 左、右
        (1, -1), (1, 0)    # 左下、右下
    ]
    
    neighbors = []
    for dr, dc in directions:
        new_row, new_col = row + dr, col + dc
        if is_valid_position(new_row, new_col):
            neighbors.append((new_row, new_col))
    
    return neighbors


def get_jump_positions(board, row, col):
    """获取所有可以跳跃到的位置"""
    jumps = []
    
    # 检查6个方向的跳跃
    directions = [
        (-1, 0), (-1, 1),  # 左上、右上
        (0, -1), (0, 1),   # 左、右
        (1, -1), (1, 0)    # 左下、右下
    ]
    
    for dr, dc in directions:
        # 检查相邻位置是否有棋子
        mid_row, mid_col = row + dr, col + dc
        jump_row, jump_col = row + 2*dr, col + 2*dc
        
        if (is_valid_position(mid_row, mid_col) and 
            is_valid_position(jump_row, jump_col) and
            board[mid_row][mid_col] is not None and  # 中间有棋子
            board[jump_row][jump_col] is None):      # 跳跃位置为空
            jumps.append((jump_row, jump_col))
    
    return jumps


def get_all_possible_moves(board, row, col):
    """获取棋子的所有可能移动（平移+跳跃）"""
    moves = []
    
    # 1. 平移移动
    neighbors = get_neighbors(row, col)
    for n_row, n_col in neighbors:
        if board[n_row][n_col] is None:  # 相邻位置为空
            moves.append({
                'type': 'move',
                'from_row': row,
                'from_col': col,
                'to_row': n_row,
                'to_col': n_col,
                'jumped': False
            })
    
    # 2. 跳跃移动
    jumps = get_jump_positions(board, row, col)
    for j_row, j_col in jumps:
        moves.append({
            'type': 'jump',
            'from_row': row,
            'from_col': col,
            'to_row': j_row,
            'to_col': j_col,
            'jumped': True
        })
    
    return moves


def is_in_target_zone(row, col, player_color):
    """检查位置是否在目标区域（对角）"""
    target_zones = {
        'red': [(14, 8), (15, 7), (15, 8), (15, 9), (16, 6), (16, 7), (16, 8), (16, 9), (16, 10)],
        'green': [(9, 16), (10, 14), (10, 15), (10, 16), (11, 14), (11, 15), (11, 16), (12, 14), (12, 15), (12, 16)],
        'yellow': [(9, 0), (10, 0), (10, 1), (10, 2), (11, 0), (11, 1), (11, 2), (12, 0), (12, 1), (12, 2)],
        'blue': [(0, 8), (1, 7), (1, 8), (1, 9), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10)],
        'orange': [(4, 0), (4, 1), (4, 2), (5, 0), (5, 1), (5, 2), (6, 0), (6, 1), (6, 2), (7, 0)],
        'purple': [(4, 14), (4, 15), (4, 16), (5, 14), (5, 15), (5, 16), (6, 14), (6, 15), (6, 16), (7, 16)]
    }
    
    return (row, col) in target_zones.get(player_color, [])


def count_pieces_in_target(board, player_color):
    """统计目标区域中的己方棋子数量"""
    target_zones = {
        'red': [(14, 8), (15, 7), (15, 8), (15, 9), (16, 6), (16, 7), (16, 8), (16, 9), (16, 10)],
        'green': [(9, 16), (10, 14), (10, 15), (10, 16), (11, 14), (11, 15), (11, 16), (12, 14), (12, 15), (12, 16)],
        'yellow': [(9, 0), (10, 0), (10, 1), (10, 2), (11, 0), (11, 1), (11, 2), (12, 0), (12, 1), (12, 2)],
        'blue': [(0, 8), (1, 7), (1, 8), (1, 9), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10)],
        'orange': [(4, 0), (4, 1), (4, 2), (5, 0), (5, 1), (5, 2), (6, 0), (6, 1), (6, 2), (7, 0)],
        'purple': [(4, 14), (4, 15), (4, 16), (5, 14), (5, 15), (5, 16), (6, 14), (6, 15), (6, 16), (7, 16)]
    }
    
    count = 0
    for row, col in target_zones.get(player_color, []):
        if board[row][col] and board[row][col]['color'] == player_color:
            count += 1
    return count


def handle_chinese_checkers_move(game, room_id, sid, data):
    """处理中国跳棋移动"""
    try:
        from_row = data.get('from_row')
        from_col = data.get('from_col')
        to_row = data.get('to_row')
        to_col = data.get('to_col')
        
        if game['game_over']:
            socketio.emit('error', {'message': '游戏已结束'}, to=sid)
            return
        
        # 验证玩家身份
        current_player = game['current_player']
        player_info = game['players'][current_player - 1]
        player_sid = player_info['sid']
        player_color = player_info['color']
        
        if sid != player_sid:
            socketio.emit('error', {'message': '不是你的回合'}, to=sid)
            return
        
        # 验证位置
        if not is_valid_position(from_row, from_col) or not is_valid_position(to_row, to_col):
            socketio.emit('error', {'message': '无效的位置'}, to=sid)
            return
        
        # 验证棋子
        piece = game['board'][from_row][from_col]
        if not piece or piece['color'] != player_color:
            socketio.emit('error', {'message': '无效的棋子'}, to=sid)
            return
        
        # 验证目标位置为空
        if game['board'][to_row][to_col] is not None:
            socketio.emit('error', {'message': '目标位置已被占用'}, to=sid)
            return
        
        # 获取所有可能的移动
        possible_moves = get_all_possible_moves(game['board'], from_row, from_col)
        
        # 查找匹配的移动
        selected_move = None
        for move in possible_moves:
            if move['to_row'] == to_row and move['to_col'] == to_col:
                selected_move = move
                break
        
        if not selected_move:
            socketio.emit('error', {'message': '非法移动'}, to=sid)
            return
        
        # 执行移动
        game['board'][to_row][to_col] = game['board'][from_row][from_col]
        game['board'][from_row][from_col] = None
        
        # 检查是否胜利
        winner = None
        game_over_message = ""
        
        # 检查所有玩家的目标区域
        for i, player in enumerate(game['players']):
            pieces_in_target = count_pieces_in_target(game['board'], player['color'])
            if pieces_in_target >= 10:  # 所有棋子都到达目标区域
                winner = i + 1
                winner_color = player['color']
                game_over_message = f"{winner_color}方获胜！"
                break
        
        if winner:
            game['game_over'] = True
            game['winner'] = winner
        
        # 切换到下一个玩家
        game['current_player'] = (game['current_player'] % len(game['players'])) + 1
        
        # 通知所有玩家
        move_data = {
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'piece': piece,
            'current_player': game['current_player'],
            'jumped': selected_move['jumped']
        }
        
        if game['game_over']:
            move_data['game_over'] = True
            move_data['winner'] = winner
            move_data['message'] = game_over_message
        
        socketio.emit('move_made', move_data, to=room_id)
        
        print(f"Chinese Checkers move: {player_color} from ({from_row},{from_col}) to ({to_row},{to_col})")
        
    except Exception as e:
        print(f"Error in handle_chinese_checkers_move: {e}")
        socketio.emit('error', {'message': '移动失败'}, to=sid)


def reset_chinese_checkers_game(game):
    """重置中国跳棋游戏"""
    game['board'] = initialize_chinese_checkers_board()
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []