"""
中国象棋游戏逻辑
"""

# 全局变量，由主程序设置
socketio = None
games = None


def initialize_chess_board():
    """初始化中国象棋棋盘"""
    board = [[None for _ in range(9)] for _ in range(10)]
    
    # 红方棋子（下方）
    board[9][0] = {'name': '車', 'type': 'rook', 'color': 'red'}
    board[9][1] = {'name': '馬', 'type': 'knight', 'color': 'red'}
    board[9][2] = {'name': '相', 'type': 'bishop', 'color': 'red'}
    board[9][3] = {'name': '仕', 'type': 'advisor', 'color': 'red'}
    board[9][4] = {'name': '帥', 'type': 'king', 'color': 'red'}
    board[9][5] = {'name': '仕', 'type': 'advisor', 'color': 'red'}
    board[9][6] = {'name': '相', 'type': 'bishop', 'color': 'red'}
    board[9][7] = {'name': '馬', 'type': 'knight', 'color': 'red'}
    board[9][8] = {'name': '車', 'type': 'rook', 'color': 'red'}
    board[7][1] = {'name': '炮', 'type': 'cannon', 'color': 'red'}
    board[7][7] = {'name': '炮', 'type': 'cannon', 'color': 'red'}
    board[6][0] = {'name': '兵', 'type': 'pawn', 'color': 'red'}
    board[6][2] = {'name': '兵', 'type': 'pawn', 'color': 'red'}
    board[6][4] = {'name': '兵', 'type': 'pawn', 'color': 'red'}
    board[6][6] = {'name': '兵', 'type': 'pawn', 'color': 'red'}
    board[6][8] = {'name': '兵', 'type': 'pawn', 'color': 'red'}

    # 黑方棋子（上方）
    board[0][0] = {'name': '車', 'type': 'rook', 'color': 'black'}
    board[0][1] = {'name': '馬', 'type': 'knight', 'color': 'black'}
    board[0][2] = {'name': '象', 'type': 'bishop', 'color': 'black'}
    board[0][3] = {'name': '士', 'type': 'advisor', 'color': 'black'}
    board[0][4] = {'name': '將', 'type': 'king', 'color': 'black'}
    board[0][5] = {'name': '士', 'type': 'advisor', 'color': 'black'}
    board[0][6] = {'name': '象', 'type': 'bishop', 'color': 'black'}
    board[0][7] = {'name': '馬', 'type': 'knight', 'color': 'black'}
    board[0][8] = {'name': '車', 'type': 'rook', 'color': 'black'}
    board[2][1] = {'name': '砲', 'type': 'cannon', 'color': 'black'}
    board[2][7] = {'name': '砲', 'type': 'cannon', 'color': 'black'}
    board[3][0] = {'name': '卒', 'type': 'pawn', 'color': 'black'}
    board[3][2] = {'name': '卒', 'type': 'pawn', 'color': 'black'}
    board[3][4] = {'name': '卒', 'type': 'pawn', 'color': 'black'}
    board[3][6] = {'name': '卒', 'type': 'pawn', 'color': 'black'}
    board[3][8] = {'name': '卒', 'type': 'pawn', 'color': 'black'}
    
    return board


def is_valid_chess_move(board, from_row, from_col, to_row, to_col, piece):
    """检查象棋移动是否合法"""
    piece_type = piece['type']
    piece_color = piece['color']
    
    dr = to_row - from_row
    dc = to_col - from_col
    abs_dr = abs(dr)
    abs_dc = abs(dc)
    
    # 检查目标位置是否有己方棋子
    target_piece = board[to_row][to_col]
    if target_piece and target_piece['color'] == piece_color:
        return False
    
    if piece_type == 'rook':
        # 车：直线移动
        if dr != 0 and dc != 0:
            return False
        return is_path_clear(board, from_row, from_col, to_row, to_col)
    
    elif piece_type == 'knight':
        # 马：日字形移动
        if not ((abs_dr == 2 and abs_dc == 1) or (abs_dr == 1 and abs_dc == 2)):
            return False
        # 检查蹩马腿
        if abs_dr == 2:
            block_row = from_row + (1 if dr > 0 else -1)
            if board[block_row][from_col] is not None:
                return False
        else:
            block_col = from_col + (1 if dc > 0 else -1)
            if board[from_row][block_col] is not None:
                return False
        return True
    
    elif piece_type == 'bishop':
        # 相/象：田字形移动，不能过河
        if abs_dr != 2 or abs_dc != 2:
            return False
        # 检查塞象眼
        block_row = from_row + (1 if dr > 0 else -1)
        block_col = from_col + (1 if dc > 0 else -1)
        if board[block_row][block_col] is not None:
            return False
        # 检查过河
        if piece_color == 'red' and to_row < 5:
            return False
        if piece_color == 'black' and to_row > 4:
            return False
        return True
    
    elif piece_type == 'advisor':
        # 仕/士：斜线移动，只能在九宫格内
        if abs_dr != 1 or abs_dc != 1:
            return False
        if to_col < 3 or to_col > 5:
            return False
        if piece_color == 'red' and to_row < 7:
            return False
        if piece_color == 'black' and to_row > 2:
            return False
        return True
    
    elif piece_type == 'king':
        # 帥/将：直线移动一格，只能在九宫格内
        if abs_dr + abs_dc != 1:
            return False
        if to_col < 3 or to_col > 5:
            return False
        if piece_color == 'red' and to_row < 7:
            return False
        if piece_color == 'black' and to_row > 2:
            return False
        return True
    
    elif piece_type == 'cannon':
        # 炮：直线移动，吃子时需要隔一个棋子
        if dr != 0 and dc != 0:
            return False
        pieces_between = count_pieces_between(board, from_row, from_col, to_row, to_col)
        if target_piece is None:
            # 移动到空位，中间不能有棋子
            return pieces_between == 0
        else:
            # 吃子，中间必须恰好有一个棋子
            return pieces_between == 1
    
    elif piece_type == 'pawn':
        # 兵/卒：过河前只能前进，过河后可以左右
        forward = -1 if piece_color == 'red' else 1
        
        # 前进
        if dr == forward and dc == 0:
            return True
        
        # 过河后左右移动
        if piece_color == 'red' and from_row <= 4:
            # 红兵过河后
            if dr == 0 and abs_dc == 1:
                return True
        elif piece_color == 'black' and from_row >= 5:
            # 黑卒过河后
            if dr == 0 and abs_dc == 1:
                return True
        
        return False
    
    return False


def is_path_clear(board, from_row, from_col, to_row, to_col):
    """检查路径上是否有棋子"""
    dr = 1 if to_row > from_row else (-1 if to_row < from_row else 0)
    dc = 1 if to_col > from_col else (-1 if to_col < from_col else 0)
    
    r, c = from_row + dr, from_col + dc
    
    while r != to_row or c != to_col:
        if board[r][c] is not None:
            return False
        r += dr
        c += dc
    
    return True


def count_pieces_between(board, from_row, from_col, to_row, to_col):
    """计算路径上的棋子数量"""
    count = 0
    dr = 1 if to_row > from_row else (-1 if to_row < from_row else 0)
    dc = 1 if to_col > from_col else (-1 if to_col < from_col else 0)

    r, c = from_row + dr, from_col + dc

    while r != to_row or c != to_col:
        if board[r][c] is not None:
            count += 1
        r += dr
        c += dc

    return count


def is_check(board, checking_color):
    """检查指定颜色的将军是否被将军"""
    # 找到该颜色的将军
    king_pos = None
    for row in range(10):
        for col in range(9):
            piece = board[row][col]
            if piece and piece['type'] == 'king' and piece['color'] == checking_color:
                king_pos = (row, col)
                break
        if king_pos:
            break
    
    if not king_pos:
        return False
    
    # 检查对方的所有棋子是否能吃掉将军
    king_row, king_col = king_pos
    opponent_color = 'black' if checking_color == 'red' else 'red'
    
    for row in range(10):
        for col in range(9):
            piece = board[row][col]
            if piece and piece['color'] == opponent_color:
                # 检查这个棋子是否能移动到将军的位置
                if is_valid_chess_move(board, row, col, king_row, king_col, piece):
                    return True
    
    return False


def handle_chess_move(game, room_id, sid, data):
    """处理象棋移动"""
    from_row = data.get('from_row')
    from_col = data.get('from_col')
    to_row = data.get('to_row')
    to_col = data.get('to_col')

    # 检查游戏是否结束
    if game['game_over']:
        socketio.emit('error', {'message': '游戏已结束'}, to=sid)
        return

    # 检查是否轮到该玩家
    current_sid = game['red_player'] if game['current_player'] == 1 else game['black_player']
    if sid != current_sid:
        socketio.emit('error', {'message': '不是你的回合'}, to=sid)
        return

    # 检查位置是否有效
    if not (0 <= from_row < 10 and 0 <= from_col < 9 and
            0 <= to_row < 10 and 0 <= to_col < 9):
        socketio.emit('error', {'message': '位置超出范围'}, to=sid)
        return

    # 检查起点是否有棋子
    piece = game['board'][from_row][from_col]
    if piece is None:
        socketio.emit('error', {'message': '起点没有棋子'}, to=sid)
        return

    # 检查是否是自己的棋子
    current_color = 'red' if game['current_player'] == 1 else 'black'
    if piece['color'] != current_color:
        socketio.emit('error', {'message': '不能移动对手的棋子'}, to=sid)
        return

    # 检查移动是否合法
    if not is_valid_chess_move(game['board'], from_row, from_col, to_row, to_col, piece):
        socketio.emit('error', {'message': '不合法的移动'}, to=sid)
        return

    # 获取被吃掉的棋子信息（如果有）
    captured_piece = game['board'][to_row][to_col]

    # 执行移动
    game['board'][to_row][to_col] = game['board'][from_row][from_col]
    game['board'][from_row][from_col] = None
    game['moves'].append({
        'player': game['current_player'],
        'from_row': from_row,
        'from_col': from_col,
        'to_row': to_row,
        'to_col': to_col,
        'piece': piece,
        'captured': captured_piece
    })

    # 清除悔棋标记
    game['last_undo_player'] = None

    # 广播移动信息
    move_data = {
        'player': game['current_player'],
        'from_row': from_row,
        'from_col': from_col,
        'to_row': to_row,
        'to_col': to_col,
        'piece_name': piece['name'],
        'piece_type': piece['type'],
        'piece_color': piece['color']
    }
    # 只有吃子时才添加 captured 字段
    if captured_piece is not None:
        move_data['captured_name'] = captured_piece['name']
        move_data['captured_type'] = captured_piece['type']
        move_data['captured_color'] = captured_piece['color']
    socketio.emit('move_made', move_data, to=room_id)

    # 检查是否被将军
    opponent_color = 'black' if current_color == 'red' else 'red'
    if is_check(game['board'], opponent_color):
        socketio.emit('check', {
            'checked_color': opponent_color,
            'message': f"{'黑方' if opponent_color == 'black' else '红方'}被将军！"
        }, to=room_id)

    # 切换玩家
    game['current_player'] = 3 - game['current_player']
    socketio.emit('turn_changed', {
        'current_player': game['current_player']
    }, to=room_id)


def reset_chess_game(game):
    """重置中国象棋游戏"""
    game['board'] = initialize_chess_board()
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []
    game['red_choice'] = None
    game['black_choice'] = None
