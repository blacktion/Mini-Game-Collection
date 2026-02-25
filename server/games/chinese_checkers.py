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
    # 棋盘大小为17x25，根据用户定义的新布局
    board = [[None]*25 for _ in range(17)]
    
    # 根据用户重新定义的坐标初始化棋子
    
    # 红方（上方）- 倒三角形
    red_positions = [
        (0, 12),                           # 第1层：1个棋子（顶端）
        (1, 11), (1, 13),                  # 第2层：2个棋子
        (2, 10), (2, 12), (2, 14),         # 第3层：3个棋子
        (3, 9), (3, 11), (3, 13), (3, 15)  # 第4层：4个棋子
    ]
    for row, col in red_positions:
        board[row][col] = {'color': 'red', 'type': 'piece'}
    
    # 绿方（左上）- 倒三角形
    green_positions = [
        (4, 0), (4, 2), (4, 4), (4, 6),    # 第1层：4个棋子
        (5, 1), (5, 3), (5, 5),            # 第2层：3个棋子
        (6, 2), (6, 4),                    # 第3层：2个棋子
        (7, 3)                             # 第4层：1个棋子
    ]
    for row, col in green_positions:
        board[row][col] = {'color': 'green', 'type': 'piece'}
    
    # 黄方（右上）- 倒三角形
    yellow_positions = [
        (4, 18), (4, 20), (4, 22), (4, 24),  # 第1层：4个棋子
        (5, 19), (5, 21), (5, 23),           # 第2层：3个棋子
        (6, 20), (6, 22),                    # 第3层：2个棋子
        (7, 21)                              # 第4层：1个棋子
    ]
    for row, col in yellow_positions:
        board[row][col] = {'color': 'yellow', 'type': 'piece'}
    
    # 蓝方（下方）- 正三角形
    blue_positions = [
        (13, 9), (13, 11), (13, 13), (13, 15),  # 第1层：4个棋子
        (14, 10), (14, 12), (14, 14),           # 第2层：3个棋子
        (15, 11), (15, 13),                     # 第3层：2个棋子
        (16, 12)                                # 第4层：1个棋子（底端）
    ]
    for row, col in blue_positions:
        board[row][col] = {'color': 'blue', 'type': 'piece'}
    
    # 橙方（右下）- 正三角形
    orange_positions = [
        (9, 21),                             # 第1层：1个棋子
        (10, 20), (10, 22),                  # 第2层：2个棋子
        (11, 19), (11, 21), (11, 23),        # 第3层：3个棋子
        (12, 18), (12, 20), (12, 22), (12, 24)  # 第4层：4个棋子
    ]
    for row, col in orange_positions:
        board[row][col] = {'color': 'orange', 'type': 'piece'}
    
    # 紫方（左下）- 正三角形
    purple_positions = [
        (9, 3),                              # 第1层：1个棋子
        (10, 2), (10, 4),                    # 第2层：2个棋子
        (11, 1), (11, 3), (11, 5),           # 第3层：3个棋子
        (12, 0), (12, 2), (12, 4), (12, 6)   # 第4层：4个棋子
    ]
    for row, col in purple_positions:
        board[row][col] = {'color': 'purple', 'type': 'piece'}
    
    return board


def is_valid_position(row, col):
    """检查位置是否在棋盘有效范围内"""
    if not (0 <= row < 17 and 0 <= col < 25):
        return False
    
    # 基于用户定义的有效位置集合
    valid_positions = {
        # 上方三角形区域（红方起始位置）- 倒三角形
        (0, 12),
        (1, 11), (1, 13),
        (2, 10), (2, 12), (2, 14),
        (3, 9), (3, 11), (3, 13), (3, 15),
        
        # 左上三角形区域（绿方起始位置）- 倒三角形
        (4, 0), (4, 2), (4, 4), (4, 6),
        (5, 1), (5, 3), (5, 5),
        (6, 2), (6, 4),
        (7, 3),
        
        # 右上三角形区域（黄方起始位置）- 倒三角形
        (4, 18), (4, 20), (4, 22), (4, 24),
        (5, 19), (5, 21), (5, 23),
        (6, 20), (6, 22),
        (7, 21),
        
        # 中心区域 - 六角星中心
        (4, 8), (4, 10), (4, 12), (4, 14), (4, 16),
        (5, 7), (5, 9), (5, 11), (5, 13), (5, 15), (5, 17),
        (6, 6), (6, 8), (6, 10), (6, 12), (6, 14), (6, 16), (6, 18),
        (7, 5), (7, 7), (7, 9), (7, 11), (7, 13), (7, 15), (7, 17), (7, 19),
        (8, 4), (8, 6), (8, 8), (8, 10), (8, 12), (8, 14), (8, 16), (8, 18), (8, 20),
        (9, 5), (9, 7), (9, 9), (9, 11), (9, 13), (9, 15), (9, 17), (9, 19),
        (10, 6), (10, 8), (10, 10), (10, 12), (10, 14), (10, 16), (10, 18),
        (11, 7), (11, 9), (11, 11), (11, 13), (11, 15), (11, 17),
        (12, 8), (12, 10), (12, 12), (12, 14), (12, 16),
        
        # 下方三角形区域（蓝方起始位置）- 正三角形
        (13, 9), (13, 11), (13, 13), (13, 15),
        (14, 10), (14, 12), (14, 14),
        (15, 11), (15, 13),
        (16, 12),
        
        # 右下三角形区域（橙方起始位置）- 正三角形
        (9, 21),
        (10, 20), (10, 22),
        (11, 19), (11, 21), (11, 23),
        (12, 18), (12, 20), (12, 22), (12, 24),
        
        # 左下三角形区域（紫方起始位置）- 正三角形
        (9, 3),
        (10, 2), (10, 4),
        (11, 1), (11, 3), (11, 5),
        (12, 0), (12, 2), (12, 4), (12, 6)
    }
    
    return (row, col) in valid_positions


def get_neighbors(row, col):
    """获取指定位置的所有相邻位置（6个方向）"""
    directions = [
        (-1, -1), (-1, 1),  # 左上、右上
        (0, -2), (0, 2),    # 左边（隔一列）、右边（隔一列）
        (1, -1), (1, 1)     # 左下、右下
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
    
    # 检查6个方向的跳跃（六角网格）
    directions = [
        (-1, -1), (-1, 1),  # 左上、右上
        (0, -2), (0, 2),    # 左边（隔一列）、右边（隔一列）
        (1, -1), (1, 1)     # 左下、右下
    ]
    
    for dr, dc in directions:
        # 检查相邻位置是否有棋子
        mid_row, mid_col = row + dr, col + dc
        jump_row, jump_col = row + 2*dr, col + 2*dc
        
        # 调试信息
        # print(f"检查方向({dr},{dc}): 中间({mid_row},{mid_col}), 跳跃({jump_row},{jump_col})")
        # print(f"  中间有效: {is_valid_position(mid_row, mid_col)}, 有棋子: {board[mid_row][mid_col] is not None}")
        # print(f"  跳跃有效: {is_valid_position(jump_row, jump_col)}, 为空: {board[jump_row][jump_col] is None}")
        
        if (is_valid_position(mid_row, mid_col) and 
            is_valid_position(jump_row, jump_col) and
            board[mid_row][mid_col] is not None and  # 中间有棋子
            board[jump_row][jump_col] is None):      # 跳跃位置为空
            jumps.append((jump_row, jump_col))
    
    return jumps


def get_all_jump_sequences(board, row, col, visited_positions):
    """获取所有可能的连续跳跃序列（避免无限递归）"""
    sequences = []
    
    # 标记当前位置已访问
    current_path = list(visited_positions) + [(row, col)]
    
    # 获取当前可跳跃的位置
    jumps = get_jump_positions(board, row, col)
    
    # 如果没有可跳跃的位置，返回空序列
    if not jumps:
        return sequences
    
    # 对每个可跳跃的位置，查找后续跳跃
    for jump_row, jump_col in jumps:
        # 检查是否已经访问过这个位置（避免循环）
        if (jump_row, jump_col) in current_path:
            continue
            
        # 创建临时棋盘状态（模拟跳跃）
        temp_board = []
        for board_row in board:
            temp_board.append(board_row[:])
        
        piece = temp_board[row][col]
        temp_board[row][col] = None
        temp_board[jump_row][jump_col] = piece
        
        # 递归查找从新位置开始的跳跃序列
        new_visited = current_path[:]  # 创建新的访问记录
        sub_sequences = get_all_jump_sequences(temp_board, jump_row, jump_col, new_visited)
        
        # 组合序列
        if sub_sequences:
            for sub_seq in sub_sequences:
                full_sequence = [(jump_row, jump_col)] + sub_seq
                sequences.append(full_sequence)
        else:
            # 如果没有后续跳跃，这就是一个完整的跳跃序列
            sequences.append([(jump_row, jump_col)])
    
    return sequences


def get_all_possible_moves(board, row, col):
    """获取棋子的所有可能移动（平移+跳跃+连续跳跃）"""
    moves = []
    
    # 1. 平移移动（始终允许）
    neighbors = get_neighbors(row, col)
    print(f"位置({row},{col})的相邻位置: {neighbors}")
    
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
    
    # 2. 跳跃移动（包括所有可能的跳跃长度）
    jumps = get_jump_positions(board, row, col)
    print(f"位置({row},{col})的跳跃位置: {jumps}")
    
    if len(jumps) > 0:
        # 获取所有可能的跳跃路径，包括中间步骤
        all_jump_steps = get_all_jump_steps(board, row, col)
        
        for jump_step in all_jump_steps:
            moves.append({
                'type': 'jump',
                'from_row': row,
                'from_col': col,
                'to_row': jump_step['to_row'],
                'to_col': jump_step['to_col'],
                'jumped': True,
                'sequence': jump_step['sequence']
            })
    
    return moves


def get_all_jump_steps(board, row, col):
    """获取所有可能的跳跃步骤（包括单步跳跃和连续跳跃的每个中间步骤）"""
    all_steps = []
    visited_positions = set()
    
    # 使用广度优先搜索获取所有可能的跳跃
    def bfs_jump(current_row, current_col, path):
        # 获取当前可跳跃的位置
        jumps = get_jump_positions(board, current_row, current_col)
        
        for jump_row, jump_col in jumps:
            # 检查是否已经访问过
            if (jump_row, jump_col) in visited_positions:
                continue
            
            # 标记为已访问
            visited_positions.add((jump_row, jump_col))
            
            # 创建新的路径
            new_path = path + [(jump_row, jump_col)]
            
            # 添加这个跳跃步骤作为一个有效移动
            all_steps.append({
                'to_row': jump_row,
                'to_col': jump_col,
                'sequence': new_path
            })
            
            # 递归继续查找后续跳跃
            bfs_jump(jump_row, jump_col, new_path)
            
            # 回溯：取消访问标记（允许其他路径使用这个位置）
            visited_positions.remove((jump_row, jump_col))
    
    # 开始搜索
    bfs_jump(row, col, [])
    
    return all_steps

def is_in_target_zone(row, col, player_color):
    """检查位置是否在目标区域（对角）"""
    target_zones = {
        'red': [(13, 9), (13, 11), (13, 13), (13, 15), (14, 10), (14, 12), (14, 14), (15, 11), (15, 13), (16, 12)],
        'green': [(9, 18), (9, 20), (9, 22), (9, 24), (10, 19), (10, 21), (10, 23), (11, 20), (11, 22), (12, 21)],
        'yellow': [(9, 0), (9, 2), (9, 4), (9, 6), (10, 1), (10, 3), (10, 5), (11, 2), (11, 4), (12, 3)],
        'blue': [(0, 12), (1, 11), (1, 13), (2, 10), (2, 12), (2, 14), (3, 9), (3, 11), (3, 13), (3, 15)],
        'orange': [(4, 0), (4, 2), (4, 4), (4, 6), (5, 1), (5, 3), (5, 5), (6, 2), (6, 4), (7, 3)],
        'purple': [(4, 18), (4, 20), (4, 22), (4, 24), (5, 19), (5, 21), (5, 23), (6, 20), (6, 22), (7, 21)]
    }
    
    return (row, col) in target_zones.get(player_color, [])


def count_pieces_in_target(board, player_color):
    """统计目标区域中的己方棋子数量"""
    target_zones = {
        'red': [(13, 9), (13, 11), (13, 13), (13, 15), (14, 10), (14, 12), (14, 14), (15, 11), (15, 13), (16, 12)],
        'green': [(9, 18), (9, 20), (9, 22), (9, 24), (10, 19), (10, 21), (10, 23), (11, 20), (11, 22), (12, 21)],
        'yellow': [(9, 0), (9, 2), (9, 4), (9, 6), (10, 1), (10, 3), (10, 5), (11, 2), (11, 4), (12, 3)],
        'blue': [(0, 12), (1, 11), (1, 13), (2, 10), (2, 12), (2, 14), (3, 9), (3, 11), (3, 13), (3, 15)],
        'orange': [(4, 0), (4, 2), (4, 4), (4, 6), (5, 1), (5, 3), (5, 5), (6, 2), (6, 4), (7, 3)],
        'purple': [(4, 18), (4, 20), (4, 22), (4, 24), (5, 19), (5, 21), (5, 23), (6, 20), (6, 22), (7, 21)]
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
        
        print(f"\n=== 移动请求 ===")
        print(f"从 ({from_row},{from_col}) 移动到 ({to_row},{to_col})")
        print(f"请求数据: {data}")
        
        # 显示周围位置信息
        print(f"起始位置棋子: {game['board'][from_row][from_col]}")
        print(f"目标位置状态: {game['board'][to_row][to_col]}")
        print(f"目标位置是否为空: {game['board'][to_row][to_col] is None}")
        
        # 检查起始位置周围的棋子分布
        print(f"起始位置 ({from_row},{from_col}) 周围情况:")
        directions = [(-1, -1), (-1, 1), (0, -2), (0, 2), (1, -1), (1, 1)]
        for dr, dc in directions:
            nr, nc = from_row + dr, from_col + dc
            if is_valid_position(nr, nc):
                piece = game['board'][nr][nc]
                status = "有棋子" if piece else "空位"
                print(f"  ({nr},{nc}): {status} {piece if piece else ''}")
        
        # 显示所有可能的移动
        print(f"\n棋子 ({from_row},{from_col}) 的所有可能移动:")
        all_moves = get_all_possible_moves(game['board'], from_row, from_col)
        
        # 分别显示平移和跳跃移动
        moves_list = [move for move in all_moves if move['type'] == 'move']
        jumps_list = [move for move in all_moves if move['type'] == 'jump']
        
        if moves_list:
            print("  平移移动选项:")
            for move in moves_list:
                print(f"    类型: 平移, 到达: ({move['to_row']},{move['to_col']})")
        
        if jumps_list:
            print("  跳跃移动选项:")
            for move in jumps_list:
                if 'sequence' in move and len(move['sequence']) > 1:
                    sequence_str = ' -> '.join([f"({r},{c})" for r, c in move['sequence']])
                    print(f"    类型: 连续跳跃, 路径: ({from_row},{from_col}) -> {sequence_str}")
                else:
                    print(f"    类型: 单步跳跃, 到达: ({move['to_row']},{move['to_col']})")
        
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
        
        print(f"棋子 ({from_row},{from_col}) 的所有可能移动:")
        for move in possible_moves:
            print(f"  类型: {move['type']}, 到达: ({move['to_row']},{move['to_col']})")
        
        # 查找匹配的移动
        selected_move = None
        for move in possible_moves:
            if move['to_row'] == to_row and move['to_col'] == to_col:
                selected_move = move
                break
        
        if not selected_move:
            print(f"请求移动 ({from_row},{from_col}) -> ({to_row},{to_col}) 不在允许列表中")
            socketio.emit('error', {'message': '非法移动'}, to=sid)
            return
        
        # 执行移动
        piece = game['board'][from_row][from_col]
        game['board'][to_row][to_col] = piece
        game['board'][from_row][from_col] = None
        
        # 记录移动和路径
        move_record = {
            'player': current_player,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'jumped': selected_move['jumped']
        }
        
        # 如果是跳跃移动，记录完整路径
        if selected_move['jumped'] and 'sequence' in selected_move:
            move_record['path'] = [[from_row, from_col]] + [[pos[0], pos[1]] for pos in selected_move['sequence']]
        else:
            move_record['path'] = [[from_row, from_col], [to_row, to_col]]
        
        game['moves'].append(move_record)
        game['last_move'] = move_record
        game['last_move_path'] = move_record.get('path', [])
        
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
        
        # 切换到下一个玩家（仅在已加入的玩家中轮换）
        # 获取已加入的玩家列表
        active_players = [i + 1 for i, p in enumerate(game['players']) if p['joined']]
        current_index = active_players.index(game['current_player'])
        next_index = (current_index + 1) % len(active_players)
        game['current_player'] = active_players[next_index]
        
        # 通知所有玩家
        move_data = {
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'piece': piece,
            'current_player': game['current_player'],
            'jumped': selected_move['jumped'],
            'last_move_path': game['last_move_path']
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