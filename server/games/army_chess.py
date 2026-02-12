"""
军棋游戏逻辑 - 完整版
包含工兵铁路路径、行营移动、路径显示等所有功能
"""

# 全局变量，由主程序设置
socketio = None
games = None


def resolve_army_chess_battle(attacker_type, defender_type):
    """解决军棋战斗结果
    返回: 'attacker_win', 'defender_win', 'both_die'
    """
    # 棋子大小顺序（从大到小）:
    # 司令 > 军长 > 师长 > 旅长 > 团长 > 营长 > 连长 > 排长 > 工兵
    ranks = {
        '司令': 9,
        '军长': 8,
        '师长': 7,
        '旅长': 6,
        '团长': 5,
        '营长': 4,
        '连长': 3,
        '排长': 2,
        '工兵': 1,
        '地雷': 0,  # 特殊
        '军旗': -1,  # 特殊
        '炸弹': -2,  # 特殊
    }

    # 炸弹与任何棋子同归于尽
    if attacker_type == '炸弹' or defender_type == '炸弹':
        return 'both_die'

    # 地雷: 工兵可以挖地雷，其他棋子碰到地雷阵亡
    if defender_type == '地雷':
        if attacker_type == '工兵':
            return 'attacker_win'
        else:
            return 'both_die'

    # 军旗: 任何棋子可以夺取军旗
    if defender_type == '军旗':
        return 'attacker_win'

    # 正常比较
    attacker_rank = ranks.get(attacker_type, 0)
    defender_rank = ranks.get(defender_type, 0)

    if attacker_rank > defender_rank:
        return 'attacker_win'
    elif attacker_rank < defender_rank:
        return 'defender_win'
    else:
        return 'both_die'


def _check_sapper_railway_path(from_row, from_col, to_row, to_col,
                                railways, railway_horizontal, railway_vertical,
                                pieces_dict, opponent_pieces, from_key):
    """
    检查工兵是否可以通过铁路网络从起点到达终点（允许拐弯）
    使用BFS算法查找路径，要求路径上无棋子阻挡
    """
    from collections import deque

    # 检查起点和终点是否都在铁路上
    start_key = f"{from_row}_{from_col}"
    end_key = f"{to_row}_{to_col}"
    if start_key not in railways or end_key not in railways:
        return False

    # BFS查找
    queue = deque([(from_row, from_col)])
    visited = {start_key}

    # 方向：上下左右
    directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    while queue:
        cur_row, cur_col = queue.popleft()

        # 找到目标
        if cur_row == to_row and cur_col == to_col:
            return True

        # 检查四个方向
        for dr, dc in directions:
            new_row = cur_row + dr
            new_col = cur_col + dc
            new_key = f"{new_row}_{new_col}"

            # 检查是否越界
            if not (0 <= new_row < 12 and 0 <= new_col < 5):
                continue

            # 检查是否在铁路上
            if new_key not in railways:
                continue

            # 检查是否访问过
            if new_key in visited:
                continue

            # 检查路径上是否有棋子（不包括起点和终点）
            if new_key != end_key:
                if new_key in opponent_pieces or new_key in pieces_dict:
                    continue

            # 对于横向移动，检查是否在横向铁路上
            if dr == 0:  # 横向
                check_row = cur_row
                if f"{check_row}_{new_col}" not in railway_horizontal and f"{new_row}_{new_col}" not in railway_horizontal:
                    continue
            # 对于纵向移动，检查是否在纵向铁路上
            elif dc == 0:  # 纵向
                check_col = cur_col
                if f"{new_row}_{check_col}" not in railway_vertical and f"{new_row}_{new_col}" not in railway_vertical:
                    continue

            visited.add(new_key)
            queue.append((new_row, new_col))

    return False


def get_sapper_railway_path(from_row, from_col, to_row, to_col,
                            railways, railway_horizontal, railway_vertical,
                            pieces_dict, opponent_pieces):
    """
    获取工兵在铁路上的完整路径（用于显示）
    使用BFS算法查找路径，返回路径上的所有点
    """
    from collections import deque

    # 检查起点和终点是否都在铁路上
    start_key = f"{from_row}_{from_col}"
    end_key = f"{to_row}_{to_col}"
    if start_key not in railways or end_key not in railways:
        return []

    # BFS查找，记录路径
    queue = deque([(from_row, from_col, [(from_row, from_col)])])
    visited = {start_key}

    # 方向：上下左右
    directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    while queue:
        cur_row, cur_col, path = queue.popleft()

        # 找到目标
        if cur_row == to_row and cur_col == to_col:
            return path

        # 检查四个方向
        for dr, dc in directions:
            new_row = cur_row + dr
            new_col = cur_col + dc
            new_key = f"{new_row}_{new_col}"

            # 检查是否越界
            if not (0 <= new_row < 12 and 0 <= new_col < 5):
                continue

            # 检查是否在铁路上
            if new_key not in railways:
                continue

            # 检查是否访问过
            if new_key in visited:
                continue

            # 检查路径上是否有棋子（不包括起点和终点）
            if new_key != end_key:
                if new_key in opponent_pieces or new_key in pieces_dict:
                    continue

            # 对于横向移动，检查是否在横向铁路上
            if dr == 0:  # 横向
                check_row = cur_row
                if f"{check_row}_{new_col}" not in railway_horizontal and f"{new_row}_{new_col}" not in railway_horizontal:
                    continue
            # 对于纵向移动，检查是否在纵向铁路上
            elif dc == 0:  # 纵向
                check_col = cur_col
                if f"{new_row}_{check_col}" not in railway_vertical and f"{new_row}_{new_col}" not in railway_vertical:
                    continue

            visited.add(new_key)
            queue.append((new_row, new_col, path + [(new_row, new_col)]))

    return []


def handle_army_chess_move(game, room_id, sid, data):
    """处理军旗移动 - 完整版"""
    from flask_socketio import emit

    from_row = data.get('from_row')
    from_col = data.get('from_col')
    to_row = data.get('to_row')
    to_col = data.get('to_col')

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否轮到该玩家
    current_sid = game['red_player'] if game['current_player'] == 1 else game['blue_player']
    if sid != current_sid:
        emit('error', {'message': '不是你的回合'})
        return

    # 检查位置是否有效 (12x5 棋盘)
    if not (0 <= from_row < 12 and 0 <= from_col < 5 and 
            0 <= to_row < 12 and 0 <= to_col < 5):
        emit('error', {'message': '位置超出范围'})
        return

    # 获取当前玩家颜色和棋子信息
    current_color = 'red' if game['current_player'] == 1 else 'blue'
    from_key = f"{from_row}_{from_col}"
    to_key = f"{to_row}_{to_col}"
    
    pieces_dict = game['red_pieces'] if current_color == 'red' else game['blue_pieces']
    
    # 检查起点是否有自己的棋子
    if from_key not in pieces_dict:
        emit('error', {'message': '起点没有你的棋子'})
        return
    
    moving_piece = pieces_dict[from_key]
    piece_type = moving_piece['type']
    
    # 检查地雷、军旗不能移动
    if piece_type in ['地雷', '军旗']:
        emit('error', {'message': f'{piece_type}不能移动'})
        return
    
    # 行营和大本营位置定义
    camps = {
        '2_1', '2_3', '3_2', '4_1', '4_3',  # 上半区（红方）
        '7_1', '7_3', '8_2', '9_1', '9_3',  # 下半区（蓝方）
    }
    headquarters = {'0_1', '0_3', '11_1', '11_3'}
    
    # 铁路位置定义
    # 横向铁路: 第1、5、6、10行的所有列
    railway_horizontal = {
        '1_0', '1_1', '1_2', '1_3', '1_4',
        '5_0', '5_1', '5_2', '5_3', '5_4',
        '6_0', '6_1', '6_2', '6_3', '6_4',
        '10_0', '10_1', '10_2', '10_3', '10_4',
    }
    # 纵向铁路: 第0列和第4列的第1-10行, 第2列的第5-6行
    railway_vertical = {
        # 左列 (col 0)
        '1_0', '2_0', '3_0', '4_0', '5_0', '6_0', '7_0', '8_0', '9_0', '10_0',
        # 右列 (col 4)
        '1_4', '2_4', '3_4', '4_4', '5_4', '6_4', '7_4', '8_4', '9_4', '10_4',
        # 中列 (col 2)
        '5_2', '6_2',
    }
    # 所有铁路位置
    railways = railway_horizontal | railway_vertical
    
    # 检查起点是否在大本营（大本营中的棋子不能移动）
    if from_key in headquarters:
        emit('error', {'message': '大本营中的棋子不能移动'})
        return
    
    # 检查移动是否合法
    dr = abs(to_row - from_row)
    dc = abs(to_col - from_col)
    
    # 斜向移动的特殊规则：只有行营和行营的相邻格子之间可以斜向移动
    is_from_camp = from_key in camps
    is_to_camp = to_key in camps
    
    # 判断目标位置是否是行营的相邻位置
    is_diagonal_adjacent_to_camp = False
    if is_to_camp or (is_from_camp and not is_to_camp):
        # 如果目标在行营，或者从行营出发，检查是否是行营的相邻格子
        for row_offset in [-1, 1]:
            for col_offset in [-1, 1]:
                adj_row = from_row + row_offset
                adj_col = from_col + col_offset
                adj_key = f"{adj_row}_{adj_col}"
                if adj_key in camps and adj_row == to_row and adj_col == to_col:
                    is_diagonal_adjacent_to_camp = True
                    break
            if is_diagonal_adjacent_to_camp:
                break
    
    # 判断起点是否是行营的相邻位置（用于从非行营进入行营的情况）
    is_from_diagonal_adjacent_to_camp = False
    if not is_from_camp and is_to_camp:
        for row_offset in [-1, 1]:
            for col_offset in [-1, 1]:
                adj_row = to_row + row_offset
                adj_col = to_col + col_offset
                adj_key = f"{adj_row}_{adj_col}"
                if adj_key in camps and adj_row == from_row and adj_col == from_col:
                    is_from_diagonal_adjacent_to_camp = True
                    break
            if is_from_diagonal_adjacent_to_camp:
                break
    
    # 移动规则验证
    valid_move = False

    # 提前定义 opponent_pieces 用于铁路移动检查
    opponent_color = 'blue' if current_color == 'red' else 'red'
    opponent_pieces = game['blue_pieces'] if current_color == 'red' else game['red_pieces']

    # 1. 铁路长距离移动：起点和终点都在铁路上
    is_from_railway = from_key in railways
    is_to_railway = to_key in railways

    # 工兵的特殊规则：可以在铁路上拐弯
    is_sapper = piece_type == '工兵'

    if is_from_railway and is_to_railway:
        if is_sapper:
            # 工兵可以在铁路上任意移动（允许拐弯），使用BFS查找路径
            valid_move = _check_sapper_railway_path(from_row, from_col, to_row, to_col,
                                                    railways, railway_horizontal, railway_vertical,
                                                    pieces_dict, opponent_pieces, from_key)
        else:
            # 其他棋子只能在同一直线上移动
            if from_row == to_row:
                # 横向移动，检查路径上所有格子是否都是铁路且无棋子阻挡
                min_col = min(from_col, to_col)
                max_col = max(from_col, to_col)
                path_clear = True
                path_blocked = False
                for c in range(min_col, max_col + 1):
                    key = f"{from_row}_{c}"
                    if key not in railway_horizontal:
                        path_clear = False
                        break
                    # 检查路径上是否有棋子（不包括起点和终点）
                    if c != from_col and c != to_col:
                        if key in opponent_pieces or key in pieces_dict:
                            path_blocked = True
                            break
                if path_clear and not path_blocked:
                    valid_move = True
            elif from_col == to_col:
                # 纵向移动，检查路径上所有格子是否都是铁路且无棋子阻挡
                min_row = min(from_row, to_row)
                max_row = max(from_row, to_row)
                path_clear = True
                path_blocked = False
                for r in range(min_row, max_row + 1):
                    key = f"{r}_{from_col}"
                    if key not in railway_vertical:
                        path_clear = False
                        break
                    # 检查路径上是否有棋子（不包括起点和终点）
                    if r != from_row and r != to_row:
                        if key in opponent_pieces or key in pieces_dict:
                            path_blocked = True
                            break
                if path_clear and not path_blocked:
                    valid_move = True
    
    # 2. 上下左右移动一步（非铁路或短距离）
    if not valid_move:
        if (dr == 1 and dc == 0) or (dr == 0 and dc == 1):
            valid_move = True
    
    # 3. 斜向移动：在行营与相邻格子之间，或两个相邻的行营之间
    if not valid_move and dr == 1 and dc == 1:
        # 从行营到相邻格子
        if is_from_camp and not is_to_camp:
            valid_move = True
        # 从相邻格子到行营
        elif not is_from_camp and is_to_camp:
            valid_move = True
        # 从一个行营到另一个紧挨着的行营
        elif is_from_camp and is_to_camp:
            valid_move = True
    
    if not valid_move:
        emit('error', {'message': '不合法的移动'})
        return

    # 目标位置没有棋子，直接移动
    if to_key not in opponent_pieces and to_key not in pieces_dict:
        # 更新棋子位置
        pieces_dict[to_key] = pieces_dict.pop(from_key)
        game['board'][to_row][to_col] = {'color': current_color}
        game['board'][from_row][from_col] = None

        # 计算移动路径（如果是工兵沿铁路移动）
        move_path = []
        is_sapper_move = False
        if piece_type == '工兵' and (from_key in railways and to_key in railways):
            # 检查是否是工兵沿铁路移动
            if not (dr == 1 and dc == 0) and not (dr == 0 and dc == 1):
                # 不是相邻一步，可能是工兵沿铁路移动
                path = get_sapper_railway_path(from_row, from_col, to_row, to_col,
                                                railways, railway_horizontal, railway_vertical,
                                                pieces_dict, opponent_pieces)
                if path:
                    move_path = path
                    is_sapper_move = True

        # 添加移动日志
        color_name = '红方' if current_color == 'red' else '蓝方'
        move_type = '沿铁路移动' if is_sapper_move else '移动'
        print(f"[军棋移动] {color_name}{piece_type} 从 ({from_row},{from_col}) {move_type}到 ({to_row},{to_col})")

        # 记录上一步移动（用于给对方提示）
        game['last_move'] = {
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'piece_type': piece_type,
            'is_attack': False,
            'is_sapper_railway': is_sapper_move,
            'path': move_path
        }

        # 广播移动
        socketio.emit('move_made', {
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'is_sapper_railway': is_sapper_move,
            'path': move_path,
            'current_player': 3 - game['current_player']
        }, to=room_id)
        
        # 切换玩家
        game['current_player'] = 3 - game['current_player']
        return
    
    # 目标位置有自己的棋子，不能移动
    if to_key in pieces_dict:
        emit('error', {'message': '不能移动到自己的棋子位置'})
        return
    
    # 目标位置有敌方棋子，检查是否在行营中（行营中的单位不能被攻击）
    if to_key in opponent_pieces:
        if to_key in camps:
            emit('error', {'message': '不能攻击行营中的棋子'})
            return
        
        # 不在行营中，可以进行战斗
        target_piece = opponent_pieces[to_key]
        target_type = target_piece['type']
    
    # 战斗逻辑
    battle_result = resolve_army_chess_battle(piece_type, target_type)

    # 添加战斗日志
    attacker_color_name = '红方' if current_color == 'red' else '蓝方'
    defender_color_name = '蓝方' if current_color == 'red' else '红方'
    if battle_result == 'attacker_win':
        print(f"[军棋战斗] {attacker_color_name}{piece_type} ({from_row},{from_col}) 攻击 {defender_color_name}{target_type} ({to_row},{to_col}) -> {attacker_color_name}获胜")
    elif battle_result == 'defender_win':
        print(f"[军棋战斗] {attacker_color_name}{piece_type} ({from_row},{from_col}) 攻击 {defender_color_name}{target_type} ({to_row},{to_col}) -> {defender_color_name}获胜")
    else:  # both_die
        print(f"[军棋战斗] {attacker_color_name}{piece_type} ({from_row},{from_col}) 攻击 {defender_color_name}{target_type} ({to_row},{to_col}) -> 同归于尽")

    if battle_result == 'attacker_win':
        # 攻击方胜，防守方阵亡
        del opponent_pieces[to_key]
        pieces_dict[to_key] = pieces_dict.pop(from_key)
        game['board'][to_row][to_col] = {'color': current_color}
        game['board'][from_row][from_col] = None

        # 记录阵亡棋子
        lost_key = 'red_lost' if current_color == 'blue' else 'blue_lost'
        game[lost_key].append(target_type)

        # 检查是否夺取军旗
        if target_type == '军旗':
            game['game_over'] = True
            game['winner'] = game['current_player']
            winner_name = '红方' if game['current_player'] == 1 else '蓝方'
            socketio.emit('game_over', {
                'winner': game['current_player'],
                'message': f'{winner_name}夺取军旗获胜！'
            }, to=room_id)
            return
        
        # 记录上一步移动
        game['last_move'] = {
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'piece_type': piece_type,
            'is_attack': True,
            'target_type': target_type,
            'battle_result': 'attacker_win'
        }

        socketio.emit('battle_result', {
            'result': 'attacker_win',
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'attack_row': from_row,
            'attack_col': from_col,
            'defend_row': to_row,
            'defend_col': to_col,
            'current_player': 3 - game['current_player']
        }, to=room_id)

        # 广播阵亡棋子列表（只发给每个玩家自己的阵亡列表）
        if game['red_player']:
            socketio.emit('lost_pieces', {
                'pieces': game['red_lost']
            }, to=game['red_player'])
        if game['blue_player']:
            socketio.emit('lost_pieces', {
                'pieces': game['blue_lost']
            }, to=game['blue_player'])

    elif battle_result == 'defender_win':
        # 防守方胜，攻击方阵亡
        del pieces_dict[from_key]
        game['board'][from_row][from_col] = None

        # 记录攻击方阵亡棋子
        lost_key = 'red_lost' if current_color == 'red' else 'blue_lost'
        game[lost_key].append(piece_type)

        socketio.emit('battle_result', {
            'result': 'defender_win',
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'attack_row': from_row,
            'attack_col': from_col,
            'defend_row': to_row,
            'defend_col': to_col,
            'current_player': 3 - game['current_player']
        }, to=room_id)

        # 记录上一步移动
        game['last_move'] = {
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'piece_type': piece_type,
            'is_attack': True,
            'target_type': target_type,
            'battle_result': 'defender_win'
        }

        # 广播阵亡棋子列表（只发给每个玩家自己的阵亡列表）
        if game['red_player']:
            socketio.emit('lost_pieces', {
                'pieces': game['red_lost']
            }, to=game['red_player'])
        if game['blue_player']:
            socketio.emit('lost_pieces', {
                'pieces': game['blue_lost']
            }, to=game['blue_player'])

    else:  # both_die
        # 同归于尽
        del pieces_dict[from_key]
        del opponent_pieces[to_key]
        game['board'][from_row][from_col] = None
        game['board'][to_row][to_col] = None

        # 记录双方阵亡棋子
        lost_key = 'red_lost' if current_color == 'red' else 'blue_lost'
        opponent_lost_key = 'blue_lost' if current_color == 'red' else 'red_lost'
        game[lost_key].append(piece_type)
        game[opponent_lost_key].append(target_type)

        socketio.emit('battle_result', {
            'result': 'both_die',
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'attack_row': from_row,
            'attack_col': from_col,
            'defend_row': to_row,
            'defend_col': to_col,
            'current_player': 3 - game['current_player']
        }, to=room_id)

        # 记录上一步移动
        game['last_move'] = {
            'player': current_color,
            'from_row': from_row,
            'from_col': from_col,
            'to_row': to_row,
            'to_col': to_col,
            'piece_type': piece_type,
            'is_attack': True,
            'target_type': target_type,
            'battle_result': 'both_die'
        }

        # 广播阵亡棋子列表（只发给每个玩家自己的阵亡列表）
        if game['red_player']:
            socketio.emit('lost_pieces', {
                'pieces': game['red_lost']
            }, to=game['red_player'])
        if game['blue_player']:
            socketio.emit('lost_pieces', {
                'pieces': game['blue_lost']
            }, to=game['blue_player'])

    # 切换玩家
    game['current_player'] = 3 - game['current_player']


def reset_army_chess_game(game):
    """重置军棋游戏"""
    game['board'] = [[None]*5 for _ in range(12)]
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []
    game['red_choice'] = None
    game['blue_choice'] = None
    game['red_arranged'] = False
    game['blue_arranged'] = False
    game['red_mines'] = 3
    game['blue_mines'] = 3
    game['red_pieces'] = {}
    game['blue_pieces'] = {}
    game['red_lost'] = []
    game['blue_lost'] = []
