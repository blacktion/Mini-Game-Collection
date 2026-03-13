"""
翻子军棋游戏逻辑
- 所有棋子初始都是盖住的（不显示类型）
- 双方轮流操作，可以选择翻棋或移动已翻开的棋子
- 大本营中的棋子可以移动（与布阵军棋不同）
- 其他规则与布阵军棋相同
"""

import random

# 全局变量，由主程序设置
socketio = None
games = None


def initialize_flip_army_chess_game(sid):
    """初始化翻子军棋游戏数据"""
    return {
        'game_type': 'flip_army_chess',
        'red_player': None,
        'blue_player': None,
        'red_choice': None,
        'blue_choice': None,
        'board': [[None]*5 for _ in range(12)],
        'pieces': {},
        'current_player': 1,
        'game_over': False,
        'winner': None,
        'moves': [],
        'red_lost': [],
        'blue_lost': [],
        'flipped_pieces': set(),
    }


def assign_flip_army_chess_player(game, sid):
    """分配翻子军棋玩家颜色"""
    if game['red_player'] is None:
        game['red_player'] = sid
        return 'red'
    elif game['blue_player'] is None:
        game['blue_player'] = sid
        return 'blue'
    return None


def record_flip_army_chess_choice(game, sid, choice):
    """记录翻子军棋玩家的先后手选择"""
    if game['red_player'] == sid:
        game['red_choice'] = choice
    elif game['blue_player'] == sid:
        game['blue_choice'] = choice


def should_start_flip_army_chess(game):
    """检查是否可以开始翻子军棋游戏"""
    return game['red_choice'] is not None and game['blue_choice'] is not None


def determine_flip_army_chess_first_player(game):
    """确定翻子军棋先后手并可能交换玩家"""
    if game['red_choice'] == game['blue_choice']:
        # 选择相同，随机决定
        first_player_sid = random.choice([game['red_player'], game['blue_player']])
        is_red_first = (first_player_sid == game['red_player'])
    else:
        # 选择不同，先选先手的为先手
        first_choice_sid = game['red_player'] if game['red_choice'] == 'first' else game['blue_player']
        is_red_first = (first_choice_sid == game['red_player'])

    # 如果蓝方先手，交换红蓝身份
    if not is_red_first:
        game['red_player'], game['blue_player'] = game['blue_player'], game['red_player']
        game['red_choice'], game['blue_choice'] = game['blue_choice'], game['red_choice']

    return is_red_first


def get_flip_army_chess_current_player_sid(game):
    """获取当前轮到的玩家sid"""
    return game['red_player'] if game['current_player'] == 1 else game['blue_player']


def get_flip_army_chess_opponent_sid(game, sid):
    """获取对手的sid"""
    return game['blue_player'] if sid == game['red_player'] else game['red_player']


def handle_flip_army_chess_disconnect(game, sid):
    """处理翻子军棋玩家断开连接，返回对手sid列表"""
    if game['red_player'] == sid or game['blue_player'] == sid:
        opponent = get_flip_army_chess_opponent_sid(game, sid)
        return [opponent] if opponent else []
    return []


def handle_flip_army_chess_surrender(game, sid):
    """处理翻子军棋认输，返回(赢家编号, 赢家sid, 输家sid)"""
    winner = 2 if sid == game['red_player'] else 1
    winner_sid = game['red_player'] if winner == 1 else game['blue_player']
    loser_sid = game['blue_player'] if winner == 1 else game['red_player']
    return winner, winner_sid, loser_sid


def get_flip_army_chess_winner_name(winner):
    """获取翻子军棋赢家名称"""
    return '红方' if winner == 1 else '蓝方'


def resolve_army_chess_battle(attacker_type, defender_type):
    """解决军棋战斗结果
    返回: 'attacker_win', 'defender_win', 'both_die'
    
    战斗规则：
    - 棋子大小顺序：司令 > 军长 > 师长 > 旅长 > 团长 > 营长 > 连长 > 排长 > 工兵
    - 炸弹：与任何棋子同归于尽
    - 地雷：工兵可以挖地雷，其他棋子碰到地雷同归于尽
    - 军旗：任何棋子可以夺取军旗
    - 同等级：同归于尽
    """
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
        '地雷': 0,  # 特殊：不能移动
        '军旗': -1,  # 特殊：不能移动，被夺取则游戏结束
        '炸弹': -2,  # 特殊：与任何棋子同归于尽
    }

    # 炸弹与任何棋子同归于尽
    if attacker_type == '炸弹' or defender_type == '炸弹':
        return 'both_die'

    # 地雷规则：工兵可以挖地雷，其他棋子碰到地雷同归于尽
    if defender_type == '地雷':
        if attacker_type == '工兵':
            return 'attacker_win'
        else:
            return 'both_die'

    # 军旗：任何棋子可以夺取军旗
    if defender_type == '军旗':
        return 'attacker_win'

    # 正常比较：根据棋子大小判断胜负
    attacker_rank = ranks.get(attacker_type, 0)
    defender_rank = ranks.get(defender_type, 0)

    if attacker_rank > defender_rank:
        return 'attacker_win'
    elif attacker_rank < defender_rank:
        return 'defender_win'
    else:
        return 'both_die'


def initialize_flip_army_chess_pieces(game):
    """初始化翻子军棋棋子，打乱后放置在除行营外的位置
    
    棋子构成：
    - 红蓝双方各25枚棋子，共50枚
    - 司令、军长各1枚
    - 师长、旅长各2枚
    - 团长、营长各2枚
    - 连长3枚
    - 排长3枚
    - 工兵3枚
    - 炸弹2枚
    - 地雷3枚
    - 军旗1枚
    
    布局：
    - 所有棋子初始都是盖住的（flipped=False）
    - 随机分布在50个可用位置上（除去10个行营位置）
    - 每个位置有棋子时会显示为橙色背景和'?'符号
    """
    piece_types = (
        ['司令'] * 1 +
        ['军长'] * 1 +
        ['师长'] * 2 +
        ['旅长'] * 2 +
        ['团长'] * 2 +
        ['营长'] * 2 +
        ['连长'] * 3 +
        ['排长'] * 3 +
        ['工兵'] * 3 +
        ['炸弹'] * 2 +
        ['地雷'] * 3 +
        ['军旗'] * 1
    )

    # 行营位置（不能放棋子，共10个）
    camps = {
        '2_1', '2_3', '3_2', '4_1', '4_3',  # 上半区5个
        '7_1', '7_3', '8_2', '9_1', '9_3',  # 下半区5个
    }

    # 收集所有可用位置（50个）
    available_positions = []
    for row in range(12):
        for col in range(5):
            key = f"{row}_{col}"
            if key not in camps:
                available_positions.append((row, col))

    # 验证棋子数量与位置数量
    total_pieces = len(piece_types) * 2  # 50枚
    if total_pieces != len(available_positions):
        print(f"警告: 棋子数量({total_pieces})与可用位置数量({len(available_positions)})不匹配")

    # 分别创建红蓝双方的棋子
    red_pieces = [{'type': p, 'color': 'red'} for p in piece_types]
    blue_pieces = [{'type': p, 'color': 'blue'} for p in piece_types]
    all_pieces = red_pieces + blue_pieces

    # 打乱所有棋子的顺序
    random.shuffle(all_pieces)

    # 初始化游戏数据
    game['pieces'] = {}        # 存储所有棋子信息
    game['board'] = [[None]*5 for _ in range(12)]  # 初始化棋盘
    game['flipped_pieces'] = set()  # 记录已翻开的棋子位置

    # 将棋子放置到棋盘上（都是盖住状态）
    for idx, pos in enumerate(available_positions):
        if idx < len(all_pieces):
            piece = all_pieces[idx]
            row, col = pos
            key = f"{row}_{col}"
            game['pieces'][key] = piece
            game['board'][row][col] = {
                'color': piece['color'],
                'flipped': False  # 初始都是盖住的
            }


def _check_sapper_railway_path(from_row, from_col, to_row, to_col,
                                railways, railway_horizontal, railway_vertical,
                                pieces_dict, opponent_pieces, from_key):
    """检查工兵是否可以通过铁路网络从起点到达终点（允许拐弯）"""
    from collections import deque

    start_key = f"{from_row}_{from_col}"
    end_key = f"{to_row}_{to_col}"
    if start_key not in railways or end_key not in railways:
        return False

    queue = deque([(from_row, from_col)])
    visited = {start_key}
    directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    while queue:
        cur_row, cur_col = queue.popleft()

        if cur_row == to_row and cur_col == to_col:
            return True

        for dr, dc in directions:
            new_row = cur_row + dr
            new_col = cur_col + dc
            new_key = f"{new_row}_{new_col}"

            if not (0 <= new_row < 12 and 0 <= new_col < 5):
                continue

            if new_key not in railways:
                continue

            if new_key in visited:
                continue

            if new_key != end_key:
                if new_key in opponent_pieces or new_key in pieces_dict:
                    continue

            if dr == 0:
                check_row = cur_row
                if f"{check_row}_{new_col}" not in railway_horizontal and f"{new_row}_{new_col}" not in railway_horizontal:
                    continue
            elif dc == 0:
                check_col = cur_col
                if f"{new_row}_{check_col}" not in railway_vertical and f"{new_row}_{new_col}" not in railway_vertical:
                    continue

            visited.add(new_key)
            queue.append((new_row, new_col))

    return False


def get_sapper_railway_path(from_row, from_col, to_row, to_col,
                            railways, railway_horizontal, railway_vertical,
                            pieces_dict, opponent_pieces):
    """获取工兵在铁路上的完整路径（用于显示）"""
    from collections import deque

    start_key = f"{from_row}_{from_col}"
    end_key = f"{to_row}_{to_col}"
    if start_key not in railways or end_key not in railways:
        return []

    queue = deque([(from_row, from_col, [(from_row, from_col)])])
    visited = {start_key}
    directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    while queue:
        cur_row, cur_col, path = queue.popleft()

        if cur_row == to_row and cur_col == to_col:
            return path

        for dr, dc in directions:
            new_row = cur_row + dr
            new_col = cur_col + dc
            new_key = f"{new_row}_{new_col}"

            if not (0 <= new_row < 12 and 0 <= new_col < 5):
                continue

            if new_key not in railways:
                continue

            if new_key in visited:
                continue

            if new_key != end_key:
                if new_key in opponent_pieces or new_key in pieces_dict:
                    continue

            if dr == 0:
                check_row = cur_row
                if f"{check_row}_{new_col}" not in railway_horizontal and f"{new_row}_{new_col}" not in railway_horizontal:
                    continue
            elif dc == 0:
                check_col = cur_col
                if f"{new_row}_{check_col}" not in railway_vertical and f"{new_row}_{new_col}" not in railway_vertical:
                    continue

            visited.add(new_key)
            queue.append((new_row, new_col, path + [(new_row, new_col)]))

    return []


def handle_flip_army_chess_move(game, room_id, sid, data):
    """处理翻子军棋的移动和翻棋操作
    
    支持两种操作：
    1. 翻棋（action='flip'）：翻开一个盖住的棋子
       - 双方都能看到翻开的棋子类型和颜色
       - 棋子状态从未翻转变为已翻开
    
    2. 移动（action='move'）：移动自己已翻开的棋子
       - 只能移动已翻开的己方棋子
       - 可以移动到空位或攻击敌方已翻开的棋子
       - 大本营中的棋子可以移动（与布阵军棋不同）
    """
    from flask_socketio import emit

    from_row = data.get('from_row')
    from_col = data.get('from_col')
    to_row = data.get('to_row')
    to_col = data.get('to_col')
    action = data.get('action', 'move')

    # 检查游戏是否已结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否轮到该玩家
    current_sid = game['red_player'] if game['current_player'] == 1 else game['blue_player']
    if sid != current_sid:
        emit('error', {'message': '不是你的回合'})
        return

    # 获取当前玩家的颜色
    current_color = 'red' if game['current_player'] == 1 else 'blue'

    # 处理翻棋操作
    if action == 'flip':
        flip_row = from_row
        flip_col = from_col
        flip_key = f"{flip_row}_{flip_col}"

        # 验证位置是否在有效范围内
        if not (0 <= flip_row < 12 and 0 <= flip_col < 5):
            emit('error', {'message': '位置超出范围'})
            return

        # 检查该位置是否有棋子
        if flip_key not in game['pieces']:
            emit('error', {'message': '该位置没有棋子'})
            return

        # 检查该棋子是否已经翻开
        if flip_key in game['flipped_pieces']:
            emit('error', {'message': '该棋子已经翻开'})
            return

        # 获取棋子信息
        piece = game['pieces'][flip_key]
        piece_color = piece['color']
        piece_type = piece['type']

        # 更新棋子状态为已翻开
        game['flipped_pieces'].add(flip_key)
        game['board'][flip_row][flip_col] = {
            'color': piece_color,
            'flipped': True,
            'type': piece_type
        }

        # 记录翻棋日志
        color_name = '红方' if piece_color == 'red' else '蓝方'
        print(f"[翻子军棋翻棋] 位置 ({flip_row},{flip_col}) 翻开 {color_name}{piece_type}")

        # 广播翻棋结果（双方都能看到翻开的棋子类型和颜色）
        socketio.emit('flip_result', {
            'row': flip_row,
            'col': flip_col,
            'color': piece_color,
            'type': piece_type,
            'current_player': 3 - game['current_player']
        }, to=room_id)

        # 切换玩家
        game['current_player'] = 3 - game['current_player']
        return

    # 处理移动操作
    if action == 'move':
        # 验证移动位置是否在有效范围内
        if not (0 <= from_row < 12 and 0 <= from_col < 5 and
                0 <= to_row < 12 and 0 <= to_col < 5):
            emit('error', {'message': '位置超出范围'})
            return

        from_key = f"{from_row}_{from_col}"
        to_key = f"{to_row}_{to_col}"

        # 检查起点是否有棋子
        if from_key not in game['pieces']:
            emit('error', {'message': '起点没有棋子'})
            return

        # 检查起点棋子是否已翻开
        if from_key not in game['flipped_pieces']:
            emit('error', {'message': '该棋子还未翻开，不能移动'})
            return

        # 检查是否是自己的棋子
        piece = game['pieces'][from_key]
        if piece['color'] != current_color:
            emit('error', {'message': '这不是你的棋子'})
            return

        # 获取棋子类型
        piece_type = piece['type']

        # 地雷和军旗不能移动
        if piece_type in ['地雷', '军旗']:
            emit('error', {'message': f'{piece_type}不能移动'})
            return

        # 如果终点有己方棋子，直接返回错误
        if to_key in game['pieces'] and game['pieces'][to_key]['color'] == current_color:
            emit('error', {'message': '不能移动到自己的棋子位置'})
            return

        # 行营和大本营位置定义
        camps = {
            '2_1', '2_3', '3_2', '4_1', '4_3',
            '7_1', '7_3', '8_2', '9_1', '9_3',
        }

        # 铁路位置定义（横向和纵向）
        railway_horizontal = {
            '1_0', '1_1', '1_2', '1_3', '1_4',
            '5_0', '5_1', '5_2', '5_3', '5_4',
            '6_0', '6_1', '6_2', '6_3', '6_4',
            '10_0', '10_1', '10_2', '10_3', '10_4',
        }
        railway_vertical = {
            '1_0', '2_0', '3_0', '4_0', '5_0', '6_0', '7_0', '8_0', '9_0', '10_0',
            '1_4', '2_4', '3_4', '4_4', '5_4', '6_4', '7_4', '8_4', '9_4', '10_4',
            '5_2', '6_2',
        }
        railways = railway_horizontal | railway_vertical

        # 计算移动距离
        dr = abs(to_row - from_row)
        dc = abs(to_col - from_col)

        # 检查起点和终点是否在行营中
        is_from_camp = from_key in camps
        is_to_camp = to_key in camps

        # 移动规则验证
        # 支持：普通移动、铁路移动、斜向移动
        # 限制：大本营中的棋子可以移动（与布阵军棋不同）
        valid_move = False

        opponent_color = 'blue' if current_color == 'red' else 'red'
        opponent_pieces = {k: v for k, v in game['pieces'].items() if v['color'] == opponent_color and k in game['flipped_pieces']}
        my_pieces = {k: v for k, v in game['pieces'].items() if v['color'] == current_color and k in game['flipped_pieces']}

        is_from_railway = from_key in railways
        is_to_railway = to_key in railways
        is_sapper = piece_type == '工兵'

        if is_from_railway and is_to_railway:
            if is_sapper:
                valid_move = _check_sapper_railway_path(from_row, from_col, to_row, to_col,
                                                        railways, railway_horizontal, railway_vertical,
                                                        my_pieces, opponent_pieces, from_key)
            else:
                if from_row == to_row:
                    min_col = min(from_col, to_col)
                    max_col = max(from_col, to_col)
                    path_clear = True
                    path_blocked = False
                    for c in range(min_col, max_col + 1):
                        key = f"{from_row}_{c}"
                        if key not in railway_horizontal:
                            path_clear = False
                            break
                        if c != from_col and c != to_col:
                            if key in opponent_pieces or key in my_pieces:
                                path_blocked = True
                                break
                    if path_clear and not path_blocked:
                        valid_move = True
                elif from_col == to_col:
                    min_row = min(from_row, to_row)
                    max_row = max(from_row, to_row)
                    path_clear = True
                    path_blocked = False
                    for r in range(min_row, max_row + 1):
                        key = f"{r}_{from_col}"
                        if key not in railway_vertical:
                            path_clear = False
                            break
                        if r != from_row and r != to_row:
                            if key in opponent_pieces or key in my_pieces:
                                path_blocked = True
                                break
                    if path_clear and not path_blocked:
                        valid_move = True

        if not valid_move:
            if (dr == 1 and dc == 0) or (dr == 0 and dc == 1):
                valid_move = True
            else:
                is_diagonal_adjacent_to_camp = False
                if is_to_camp or (is_from_camp and not is_to_camp):
                    for row_offset in [-1, 1]:
                        for col_offset in [-1, 1]:
                            adj_row = from_row + row_offset
                            adj_col = from_col + col_offset
                            adj_key = f"{adj_row}_{adj_col}"
                            if adj_key in camps and adj_row == to_row and adj_col == to_col:
                                is_diagonal_adjacent_to_camp = True
                                break
                if is_diagonal_adjacent_to_camp:
                    valid_move = True

        if not valid_move:
            emit('error', {'message': '不合法的移动'})
            return

        if to_key not in game['pieces']:
            game['pieces'][to_key] = game['pieces'].pop(from_key)
            game['board'][to_row][to_col] = game['board'][from_row][from_col]
            game['board'][from_row][from_col] = None

            move_path = []
            is_sapper_move = False
            if piece_type == '工兵' and (from_key in railways and to_key in railways):
                if not (dr == 1 and dc == 0) and not (dr == 0 and dc == 1):
                    path = get_sapper_railway_path(from_row, from_col, to_row, to_col,
                                                    railways, railway_horizontal, railway_vertical,
                                                    my_pieces, opponent_pieces)
                    if path:
                        move_path = path
                        is_sapper_move = True

            color_name = '红方' if current_color == 'red' else '蓝方'
            print(f"[翻子军棋移动] {color_name}{piece_type} 从 ({from_row},{from_col}) 移动到 ({to_row},{to_col})")

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

            game['current_player'] = 3 - game['current_player']
            return

        # 处理攻击敌方棋子的情况（终点位置有敌方棋子且已翻开）
        elif to_key in opponent_pieces:
            if to_key in camps:
                emit('error', {'message': '不能攻击行营中的棋子'})
                return

            target_piece = opponent_pieces[to_key]

            if to_key not in game['flipped_pieces']:
                emit('error', {'message': '不能攻击未翻开的棋子'})
                return

            target_type = target_piece['type']

            battle_result = resolve_army_chess_battle(piece_type, target_type)

            attacker_color_name = '红方' if current_color == 'red' else '蓝方'
            defender_color_name = '蓝方' if current_color == 'red' else '红方'

            if battle_result == 'attacker_win':
                print(f"[翻子军棋战斗] {attacker_color_name}{piece_type} 攻击 {defender_color_name}{target_type} -> {attacker_color_name}获胜")
                del game['pieces'][to_key]
                game['flipped_pieces'].discard(to_key)
                game['pieces'][to_key] = game['pieces'].pop(from_key)
                game['board'][to_row][to_col] = game['board'][from_row][from_col]
                game['board'][from_row][from_col] = None

                lost_key = 'red_lost' if current_color == 'blue' else 'blue_lost'
                game[lost_key].append(target_type)

                if target_type == '军旗':
                    game['game_over'] = True
                    game['winner'] = game['current_player']
                    winner_name = '红方' if game['current_player'] == 1 else '蓝方'
                    socketio.emit('game_over', {
                        'winner': game['current_player'],
                        'message': f'{winner_name}夺取军旗获胜！'
                    }, to=room_id)
                    return

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

                if game['red_player']:
                    socketio.emit('lost_pieces', {
                        'pieces': game['red_lost']
                    }, to=game['red_player'])
                if game['blue_player']:
                    socketio.emit('lost_pieces', {
                        'pieces': game['blue_lost']
                    }, to=game['blue_player'])

            elif battle_result == 'defender_win':
                print(f"[翻子军棋战斗] {attacker_color_name}{piece_type} 攻击 {defender_color_name}{target_type} -> {defender_color_name}获胜")
                del game['pieces'][from_key]
                game['flipped_pieces'].discard(from_key)
                game['board'][from_row][from_col] = None

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

                if game['red_player']:
                    socketio.emit('lost_pieces', {
                        'pieces': game['red_lost']
                    }, to=game['red_player'])
                if game['blue_player']:
                    socketio.emit('lost_pieces', {
                        'pieces': game['blue_lost']
                    }, to=game['blue_player'])

            else:
                print(f"[翻子军棋战斗] {attacker_color_name}{piece_type} 攻击 {defender_color_name}{target_type} -> 同归于尽")
                del game['pieces'][from_key]
                del game['pieces'][to_key]
                game['flipped_pieces'].discard(from_key)
                game['flipped_pieces'].discard(to_key)
                game['board'][from_row][from_col] = None
                game['board'][to_row][to_col] = None

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

                if game['red_player']:
                    socketio.emit('lost_pieces', {
                        'pieces': game['red_lost']
                    }, to=game['red_player'])
                if game['blue_player']:
                    socketio.emit('lost_pieces', {
                        'pieces': game['blue_lost']
                    }, to=game['blue_player'])

            game['current_player'] = 3 - game['current_player']


def reset_flip_army_chess_game(game):
    """重置翻子军棋游戏"""
    game['board'] = [[None]*5 for _ in range(12)]
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []
    game['red_choice'] = None
    game['blue_choice'] = None
    game['red_lost'] = []
    game['blue_lost'] = []
    game['pieces'] = {}
    game['flipped_pieces'] = set()
