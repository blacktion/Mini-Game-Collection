"""
国际象棋游戏逻辑
"""

# 全局变量，由主程序设置
socketio = None
games = None

# 棋子编码：正数为白方，负数为黑方
# 1/King, 2/Queen, 3/Rook, 4/Bishop, 5/Knight, 6/Pawn
WHITE_KING = 1
WHITE_QUEEN = 2
WHITE_ROOK = 3
WHITE_BISHOP = 4
WHITE_KNIGHT = 5
WHITE_PAWN = 6

BLACK_KING = -1
BLACK_QUEEN = -2
BLACK_ROOK = -3
BLACK_BISHOP = -4
BLACK_KNIGHT = -5
BLACK_PAWN = -6


def initialize_international_chess_board():
    """初始化国际象棋棋盘 (8x8)"""
    # 0表示空位，正数白方，负数黑方
    board = [[0] * 8 for _ in range(8)]

    # 白方棋子 (第1行，索引0) - 视觉上的底部
    board[0][0] = WHITE_ROOK
    board[0][1] = WHITE_KNIGHT
    board[0][2] = WHITE_BISHOP
    board[0][3] = WHITE_QUEEN
    board[0][4] = WHITE_KING
    board[0][5] = WHITE_BISHOP
    board[0][6] = WHITE_KNIGHT
    board[0][7] = WHITE_ROOK

    # 白方兵 (第2行，索引1)
    for col in range(8):
        board[1][col] = WHITE_PAWN

    # 黑方兵 (第7行，索引6)
    for col in range(8):
        board[6][col] = BLACK_PAWN

    # 黑方棋子 (第8行，索引7) - 视觉上的顶部
    board[7][0] = BLACK_ROOK
    board[7][1] = BLACK_KNIGHT
    board[7][2] = BLACK_BISHOP
    board[7][3] = BLACK_QUEEN
    board[7][4] = BLACK_KING
    board[7][5] = BLACK_BISHOP
    board[7][6] = BLACK_KNIGHT
    board[7][7] = BLACK_ROOK

    return board


def is_valid_international_chess_position(row, col):
    """检查位置是否在棋盘内"""
    return 0 <= row < 8 and 0 <= col < 8


def get_piece_color(piece):
    """获取棋子颜色：1=白方，-1=黑方，0=空"""
    if piece > 0:
        return 1
    elif piece < 0:
        return -1
    return 0


def is_path_clear(board, start_row, start_col, end_row, end_col):
    """检查路径是否畅通（不包括起点和终点）"""
    if start_row == end_row:
        # 水平移动
        step = 1 if end_col > start_col else -1
        for col in range(start_col + step, end_col, step):
            if board[start_row][col] != 0:
                return False
        return True
    elif start_col == end_col:
        # 垂直移动
        step = 1 if end_row > start_row else -1
        for row in range(start_row + step, end_row, step):
            if board[row][start_col] != 0:
                return False
        return True
    elif abs(end_row - start_row) == abs(end_col - start_col):
        # 对角线移动
        row_step = 1 if end_row > start_row else -1
        col_step = 1 if end_col > start_col else -1
        row, col = start_row + row_step, start_col + col_step
        while (row, col) != (end_row, end_col):
            if board[row][col] != 0:
                return False
            row += row_step
            col += col_step
        return True
    return False


def get_valid_international_chess_moves(board, row, col, game=None):
    """获取棋子在当前位置的所有合法移动"""
    piece = board[row][col]
    if piece == 0:
        return []

    color = get_piece_color(piece)
    piece_type = abs(piece)
    moves = []

    if piece_type == 1:  # 王
        moves = get_king_moves(board, row, col, color, game)
    elif piece_type == 2:  # 后
        moves = get_queen_moves(board, row, col, color)
    elif piece_type == 3:  # 车
        moves = get_rook_moves(board, row, col, color)
    elif piece_type == 4:  # 象
        moves = get_bishop_moves(board, row, col, color)
    elif piece_type == 5:  # 马
        moves = get_knight_moves(board, row, col, color)
    elif piece_type == 6:  # 兵
        moves = get_pawn_moves(board, row, col, color, game)

    return moves


def get_king_moves(board, row, col, color, game=None):
    """获取王的合法移动"""
    moves = []
    directions = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

    for dr, dc in directions:
        new_row, new_col = row + dr, col + dc
        if is_valid_international_chess_position(new_row, new_col):
            target = board[new_row][new_col]
            if get_piece_color(target) != color:
                moves.append((new_row, new_col))

    # 王车易位
    if game:
        moves.extend(get_castling_moves(board, row, col, color, game))

    return moves


def get_castling_moves(board, row, col, color, game):
    """获取王车易位的合法移动"""
    moves = []

    # 王车易位条件：
    # 1. 王和车都未移动过
    # 2. 中间格子为空
    # 3. 王不在将军状态
    # 4. 王经过的格子不被对方攻击

    if is_check(board, color):
        return moves  # 王在将军状态，不能易位

    if color == 1:  # 白方
        # 短易位 (王翼)
        if not game.get('white_king_moved', False):
            # 车在 h1 (0, 7)
            if board[0][7] == WHITE_ROOK and not game.get('white_rook_h1_moved', False):
                # 检查中间格子 f1, g1 是否为空
                if board[0][5] == 0 and board[0][6] == 0:
                    # 检查 f1, g1 是否被攻击
                    if not is_square_attacked(board, 0, 5, -1) and not is_square_attacked(board, 0, 6, -1):
                        moves.append((0, 6))  # 短易位

            # 长易位 (后翼)
            if board[0][0] == WHITE_ROOK and not game.get('white_rook_a1_moved', False):
                # 检查中间格子 b1, c1, d1 是否为空
                if board[0][1] == 0 and board[0][2] == 0 and board[0][3] == 0:
                    # 检查 c1, d1 是否被攻击 (b1 不需要检查)
                    if not is_square_attacked(board, 0, 2, -1) and not is_square_attacked(board, 0, 3, -1):
                        moves.append((0, 2))  # 长易位
    else:  # 黑方
        # 短易位 (王翼)
        if not game.get('black_king_moved', False):
            # 车在 h8 (7, 7)
            if board[7][7] == BLACK_ROOK and not game.get('black_rook_h8_moved', False):
                # 检查中间格子 f8, g8 是否为空
                if board[7][5] == 0 and board[7][6] == 0:
                    # 检查 f8, g8 是否被攻击
                    if not is_square_attacked(board, 7, 5, 1) and not is_square_attacked(board, 7, 6, 1):
                        moves.append((7, 6))  # 短易位

            # 长易位 (后翼)
            if board[7][0] == BLACK_ROOK and not game.get('black_rook_a8_moved', False):
                # 检查中间格子 b8, c8, d8 是否为空
                if board[7][1] == 0 and board[7][2] == 0 and board[7][3] == 0:
                    # 检查 c8, d8 是否被攻击 (b8 不需要检查)
                    if not is_square_attacked(board, 7, 2, 1) and not is_square_attacked(board, 7, 3, 1):
                        moves.append((7, 2))  # 长易位

    return moves


def is_square_attacked(board, row, col, attacker_color):
    """检查指定格子是否被对方攻击"""
    # 检查所有敌方棋子是否能攻击到该格子
    for r in range(8):
        for c in range(8):
            piece = board[r][c]
            if get_piece_color(piece) == attacker_color:
                piece_type = abs(piece)
                if piece_type == 1:  # 王
                    if max(abs(r - row), abs(c - col)) == 1:
                        return True
                elif piece_type == 2:  # 后
                    if is_path_clear(board, r, c, row, col):
                        return True
                elif piece_type == 3:  # 车
                    if (r == row or c == col) and is_path_clear(board, r, c, row, col):
                        return True
                elif piece_type == 4:  # 象
                    if abs(r - row) == abs(c - col) and is_path_clear(board, r, c, row, col):
                        return True
                elif piece_type == 5:  # 马
                    if (abs(r - row), abs(c - col)) in [(2, 1), (1, 2)]:
                        return True
                elif piece_type == 6:  # 兵
                    direction = 1 if attacker_color == 1 else -1
                    if r + direction == row and abs(c - col) == 1:
                        return True
    return False


def get_queen_moves(board, row, col, color):
    """获取后的合法移动"""
    moves = []
    # 斜线方向
    directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
    for dr, dc in directions:
        for i in range(1, 8):
            new_row, new_col = row + dr * i, col + dc * i
            if not is_valid_international_chess_position(new_row, new_col):
                break
            target = board[new_row][new_col]
            if target == 0:
                moves.append((new_row, new_col))
            elif get_piece_color(target) != color:
                moves.append((new_row, new_col))
                break
            else:
                break

    # 直线方向
    directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    for dr, dc in directions:
        for i in range(1, 8):
            new_row, new_col = row + dr * i, col + dc * i
            if not is_valid_international_chess_position(new_row, new_col):
                break
            target = board[new_row][new_col]
            if target == 0:
                moves.append((new_row, new_col))
            elif get_piece_color(target) != color:
                moves.append((new_row, new_col))
                break
            else:
                break

    return moves


def get_rook_moves(board, row, col, color):
    """获取车的合法移动"""
    moves = []
    directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    for dr, dc in directions:
        for i in range(1, 8):
            new_row, new_col = row + dr * i, col + dc * i
            if not is_valid_international_chess_position(new_row, new_col):
                break
            target = board[new_row][new_col]
            if target == 0:
                moves.append((new_row, new_col))
            elif get_piece_color(target) != color:
                moves.append((new_row, new_col))
                break
            else:
                break

    return moves


def get_bishop_moves(board, row, col, color):
    """获取象的合法移动"""
    moves = []
    directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]

    for dr, dc in directions:
        for i in range(1, 8):
            new_row, new_col = row + dr * i, col + dc * i
            if not is_valid_international_chess_position(new_row, new_col):
                break
            target = board[new_row][new_col]
            if target == 0:
                moves.append((new_row, new_col))
            elif get_piece_color(target) != color:
                moves.append((new_row, new_col))
                break
            else:
                break

    return moves


def get_knight_moves(board, row, col, color):
    """获取马的合法移动"""
    moves = []
    jumps = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]

    for dr, dc in jumps:
        new_row, new_col = row + dr, col + dc
        if is_valid_international_chess_position(new_row, new_col):
            target = board[new_row][new_col]
            if get_piece_color(target) != color:
                moves.append((new_row, new_col))

    return moves


def get_pawn_moves(board, row, col, color, game=None):
    """获取兵的合法移动"""
    moves = []

    if color == 1:  # 白方兵向上走 (row 增加)
        # 前进一格
        if is_valid_international_chess_position(row + 1, col) and board[row + 1][col] == 0:
            moves.append((row + 1, col))
            # 初始位置可以走两格（row=1是白兵初始位置）
            if row == 1 and is_valid_international_chess_position(row + 2, col) and board[row + 2][col] == 0:
                moves.append((row + 2, col))
        # 吃子（斜前方）
        if is_valid_international_chess_position(row + 1, col - 1):
            target = board[row + 1][col - 1]
            if target != 0 and get_piece_color(target) == -1:
                moves.append((row + 1, col - 1))
        if is_valid_international_chess_position(row + 1, col + 1):
            target = board[row + 1][col + 1]
            if target != 0 and get_piece_color(target) == -1:
                moves.append((row + 1, col + 1))

        # 吃过路兵
        if game:
            last_move = game.get('moves', [])
            if last_move:
                last = last_move[-1]
                if abs(last['piece']) == WHITE_PAWN:  # 上一步是兵
                    # 如果上一步兵走了两格，正好在当前兵旁边
                    if last['to']['row'] == row and abs(last['to']['col'] - col) == 1:
                        # 白兵可以吃到对方兵后面
                        moves.append((row + 1, last['to']['col']))
    else:  # 黑方兵向下走 (row 减小)
        # 前进一格
        if is_valid_international_chess_position(row - 1, col) and board[row - 1][col] == 0:
            moves.append((row - 1, col))
            # 初始位置可以走两格（row=6是黑兵初始位置）
            if row == 6 and is_valid_international_chess_position(row - 2, col) and board[row - 2][col] == 0:
                moves.append((row - 2, col))
        # 吃子（斜前方）
        if is_valid_international_chess_position(row - 1, col - 1):
            target = board[row - 1][col - 1]
            if target != 0 and get_piece_color(target) == 1:
                moves.append((row - 1, col - 1))
        if is_valid_international_chess_position(row - 1, col + 1):
            target = board[row - 1][col + 1]
            if target != 0 and get_piece_color(target) == 1:
                moves.append((row - 1, col + 1))

        # 吃过路兵
        if game:
            last_move = game.get('moves', [])
            if last_move:
                last = last_move[-1]
                if abs(last['piece']) == BLACK_PAWN:  # 上一步是兵
                    if last['to']['row'] == row and abs(last['to']['col'] - col) == 1:
                        moves.append((row - 1, last['to']['col']))

    return moves


def is_check(board, color, game=None):
    """检查指定颜色的王是否被将军"""
    # 找到王的当前位置
    king_piece = WHITE_KING if color == 1 else BLACK_KING
    king_row, king_col = None, None

    for row in range(8):
        for col in range(8):
            if board[row][col] == king_piece:
                king_row, king_col = row, col
                break
        if king_row is not None:
            break

    if king_row is None:
        return False  # 王不在棋盘上（被吃掉了）

    # 检查敌方棋子是否能攻击到王
    enemy_color = -1 if color == 1 else 1

    for row in range(8):
        for col in range(8):
            piece = board[row][col]
            if get_piece_color(piece) == enemy_color:
                moves = get_valid_international_chess_moves(board, row, col, game)
                if (king_row, king_col) in moves:
                    return True

    return False


def has_valid_moves(board, color, game=None):
    """检查指定颜色是否有合法移动"""
    for row in range(8):
        for col in range(8):
            piece = board[row][col]
            if get_piece_color(piece) == color:
                moves = get_valid_international_chess_moves(board, row, col, game)
                for new_row, new_col in moves:
                    # 模拟移动
                    original = board[new_row][new_col]
                    board[new_row][new_col] = board[row][col]
                    board[row][col] = 0
                    in_check = is_check(board, color, game)
                    # 还原
                    board[row][col] = board[new_row][new_col]
                    board[new_row][new_col] = original
                    if not in_check:
                        return True
    return False


def check_international_chess_winner(board):
    """检查国际象棋胜负"""
    # 检查双方是否都有王
    white_king_exists = False
    black_king_exists = False

    for row in range(8):
        for col in range(8):
            if board[row][col] == WHITE_KING:
                white_king_exists = True
            elif board[row][col] == BLACK_KING:
                black_king_exists = True

    if not white_king_exists:
        return -1  # 黑方获胜
    if not black_king_exists:
        return 1  # 白方获胜

    # 检查白方是否被将死
    if is_check(board, 1) and not has_valid_moves(board, 1):
        return -1  # 黑方获胜

    # 检查黑方是否被将死
    if is_check(board, -1) and not has_valid_moves(board, -1):
        return 1  # 白方获胜

    return None  # 无胜负


def check_international_chess_draw(board):
    """检查国际象棋是否平局"""
    # 检查是否双方都没有合法移动但未被将军
    if not is_check(board, 1) and not has_valid_moves(board, 1):
        return True
    if not is_check(board, -1) and not has_valid_moves(board, -1):
        return True

    # 检查棋盘上是否只剩下王（理论上不可能，但也作为平局条件）
    pieces = [abs(p) for row in board for p in row if p != 0]
    if len(pieces) == 2:
        return True  # 王对王

    return False


def handle_international_chess_move(game, room_id, sid, data):
    """处理国际象棋移动"""
    from flask_socketio import emit

    row = data.get('row')
    col = data.get('col')
    to_row = data.get('to_row')
    to_col = data.get('to_col')

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否轮到该玩家
    current_sid = game['white_player'] if game['current_player'] == 1 else game['black_player']
    if sid != current_sid:
        emit('error', {'message': '不是你的回合'})
        return

    # 检查位置是否有效
    if not all(is_valid_international_chess_position(r, c) for r, c in [(row, col), (to_row, to_col)]):
        emit('error', {'message': '位置超出范围'})
        return

    # 检查是否有棋子
    piece = game['board'][row][col]
    if piece == 0:
        emit('error', {'message': '该位置没有棋子'})
        return

    # 检查是否是自己的棋子
    color = get_piece_color(piece)
    if color != game['current_player']:
        emit('error', {'message': '这是对方的棋子'})
        return

    # 检查是否是合法移动
    valid_moves = get_valid_international_chess_moves(game['board'], row, col, game)
    if (to_row, to_col) not in valid_moves:
        emit('error', {'message': '非法移动'})
        return

    # 检查移动后是否会导致己方被将军
    original = game['board'][to_row][to_col]
    game['board'][to_row][to_col] = game['board'][row][col]
    game['board'][row][col] = 0

    if is_check(game['board'], color, game):
        # 还原棋盘
        game['board'][row][col] = game['board'][to_row][to_col]
        game['board'][to_row][to_col] = original
        emit('error', {'message': '移动后会被将军'})
        return

    # 处理王车易位
    castling_move = None
    piece_type = abs(piece)
    if piece_type == 1 and abs(col - to_col) == 2:  # 王移动两格 = 易位
        castling_move = 'short' if to_col > col else 'long'
        # 移动车
        if color == 1:  # 白方
            if castling_move == 'short':
                game['board'][0][5] = game['board'][0][7]  # 车从 h1 到 f1
                game['board'][0][7] = 0
            else:  # long
                game['board'][0][3] = game['board'][0][0]  # 车从 a1 到 d1
                game['board'][0][0] = 0
        else:  # 黑方
            if castling_move == 'short':
                game['board'][7][5] = game['board'][7][7]  # 车从 h8 到 f8
                game['board'][7][7] = 0
            else:  # long
                game['board'][7][3] = game['board'][7][0]  # 车从 a8 到 d8
                game['board'][7][0] = 0

    # 记录移动
    game['moves'].append({
        'from': {'row': row, 'col': col},
        'to': {'row': to_row, 'col': to_col},
        'piece': piece,
        'captured': original,
        'player': color,
        'castling': castling_move
    })

    # 更新王和车的移动状态
    if piece_type == 1:  # 王
        if color == 1:
            game['white_king_moved'] = True
        else:
            game['black_king_moved'] = True
    elif piece_type == 3:  # 车
        if color == 1:
            if row == 0 and col == 7:
                game['white_rook_h1_moved'] = True
            elif row == 0 and col == 0:
                game['white_rook_a1_moved'] = True
        else:
            if row == 7 and col == 7:
                game['black_rook_h8_moved'] = True
            elif row == 7 and col == 0:
                game['black_rook_a8_moved'] = True

    # 处理吃过路兵
    en_passant_capture = None
    if piece_type == 6 and abs(to_row - row) == 1 and original == 0:
        # 兵斜走一格且目标是空的 = 吃过路兵
        if color == 1:  # 白方
            if game['board'][row][to_col] != 0:  # 原位置有黑兵
                en_passant_capture = {'row': row, 'col': to_col}
                game['board'][row][to_col] = 0  # 吃掉对方兵
        else:  # 黑方
            if game['board'][row][to_col] != 0:
                en_passant_capture = {'row': row, 'col': to_col}
                game['board'][row][to_col] = 0  # 吃掉对方兵

    # 广播移动信息
    socketio.emit('move_made', {
        'player': game['current_player'],
        'from': {'row': row, 'col': col},
        'to': {'row': to_row, 'col': to_col},
        'piece': piece,
        'captured': original,
        'castling': castling_move,
        'en_passant': en_passant_capture
    }, room=room_id)

    # 检查胜负
    winner = check_international_chess_winner(game['board'])
    if winner:
        game['game_over'] = True
        game['winner'] = winner
        winner_name = '白方' if winner == 1 else '黑方'
        socketio.emit('game_over', {
            'winner': winner,
            'message': f'{winner_name}获胜！'
        }, room=room_id)
        return

    # 检查平局
    if check_international_chess_draw(game['board']):
        game['game_over'] = True
        socketio.emit('game_over', {
            'winner': 0,
            'message': '和棋！'
        }, room=room_id)
        return

    # 切换玩家
    game['current_player'] = -game['current_player']
    socketio.emit('turn_changed', {
        'current_player': game['current_player']
    }, room=room_id)


def reset_international_chess_game(game):
    """重置国际象棋游戏"""
    game['board'] = initialize_international_chess_board()
    game['current_player'] = 1
    game['game_over'] = False
    game['winner'] = None
    game['moves'] = []
    game['white_choice'] = None
    game['black_choice'] = None
    # 重置王车易位状态
    game['white_king_moved'] = False
    game['black_king_moved'] = False
    game['white_rook_h1_moved'] = False
    game['white_rook_a1_moved'] = False
    game['black_rook_h8_moved'] = False
    game['black_rook_a8_moved'] = False
