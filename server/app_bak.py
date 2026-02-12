#!/usr/bin/env python3
"""
联机游戏服务器
支持五子棋、中国象棋等多种游戏在线对战
"""

# 检测eventlet是否可用，并在导入其他模块之前执行monkey_patch
try:
    import eventlet
    eventlet.monkey_patch()
    ASYNC_MODE = 'eventlet'
    print("Eventlet monkey_patch applied successfully")
except ImportError:
    ASYNC_MODE = 'threading'
    print("Eventlet not available, using threading mode")

from flask import Flask, render_template_string, request
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_cors import CORS
import threading
import random

app = Flask(__name__)
app.config['SECRET_KEY'] = 'game-secret-key-2026'
CORS(app)

print(f"Initializing Flask-SocketIO with async_mode: {ASYNC_MODE}")
if ASYNC_MODE == 'threading':
    print("WARNING: eventlet not installed, using threading mode")
    print("For better stability, run: pip install eventlet")

socketio = SocketIO(
    app, 
    cors_allowed_origins="*", 
    async_mode=ASYNC_MODE,
    logger=False,
    engineio_logger=False,
    ping_timeout=60,
    ping_interval=25
)

# 游戏房间管理
games = {}  # room_id -> game_data


# ================== 斗地主游戏逻辑 ==================

def create_doudizhu_deck():
    """创建一副扑克牌(54张)"""
    deck = []
    # 普通牌: 3-K, A, 2 (rank: 3-15)
    for suit in range(4):  # 0=方块, 1=梅花, 2=红桃, 3=黑桃
        for rank in range(3, 16):  # 3-15
            deck.append({'rank': rank, 'suit': suit})

    # 大小王
    deck.append({'rank': 16, 'suit': 0})  # 小王
    deck.append({'rank': 17, 'suit': 0})  # 大王

    return deck


def shuffle_deck(deck):
    """洗牌"""
    import random
    shuffled = deck.copy()
    random.shuffle(shuffled)
    return shuffled


def deal_cards(deck):
    """发牌: 三个玩家各17张,底牌3张"""
    # 排序: 从小到大
    sorted_cards = sorted(deck, key=lambda x: (x['rank'], x['suit']))

    # 分发
    player1_cards = sorted_cards[0:17]
    player2_cards = sorted_cards[17:34]
    player3_cards = sorted_cards[34:51]
    landlord_cards = sorted_cards[51:54]

    # 每个玩家从大到小排序
    for cards in [player1_cards, player2_cards, player3_cards]:
        cards.sort(key=lambda x: x['rank'], reverse=True)

    # 底牌从小到大排序
    landlord_cards.sort(key=lambda x: x['rank'])

    return player1_cards, player2_cards, player3_cards, landlord_cards

# game_data结构（五子棋）:
# {
#     'game_type': 'gobang',
#     'black_player': sid,  # 黑棋玩家sid
#     'white_player': sid,  # 白棋玩家sid
#     'black_choice': None, # 黑棋选择(first/second)
#     'white_choice': None, # 白棋选择(first/second)
#     'board': [[0]*15 for _ in range(15)],  # 0:空 1:黑 2:白
#     'current_player': 1,  # 1:黑 2:白
#     'game_over': False,
#     'winner': None,
#     'moves': []  # 记录落子顺序
# }
# game_data结构（中国象棋）:
# {
#     'game_type': 'chinese_chess',
#     'red_player': sid,    # 红方玩家sid
#     'black_player': sid,  # 黑方玩家sid
#     'red_choice': None,   # 红方选择(first/second)
#     'black_choice': None, # 黑方选择(first/second)
#     'board': [[None]*9 for _ in range(10)],  # 棋盘
#     'current_player': 1,  # 1:红 2:黑
#     'game_over': False,
#     'winner': None,
#     'moves': []
# }
# game_data结构（围棋）:
# {
#     'game_type': 'go',
#     'black_player': sid,  # 黑棋玩家sid
#     'white_player': sid,  # 白棋玩家sid
#     'black_choice': None, # 黑棋选择(first/second)
#     'white_choice': None, # 白棋选择(first/second)
#     'board': [[0]*19 for _ in range(19)],  # 棋盘 0:空 1:黑 2:白
#     'current_player': 1,  # 1:黑 2:白
#     'game_over': False,
#     'winner': None,
#     'moves': []
# }
# game_data结构（黑白棋）:
# {
#     'game_type': 'othello',
#     'black_player': sid,  # 黑棋玩家sid
#     'white_player': sid,  # 白棋玩家sid
#     'board': [[0]*8 for _ in range(8)],  # 棋盘 0:空 1:黑 2:白
#     'current_player': 1,  # 1:黑 2:白（黑棋固定先手）
#     'game_over': False,
#     'winner': None,
#     'moves': []
# }


@app.route('/')
def index():
    """健康检查接口"""
    return "Gobang Server is Running!"


@socketio.on('connect')
def handle_connect():
    """客户端连接"""
    try:
        print(f"Client connected: {request.sid}")
        emit('connected', {'sid': request.sid})
    except Exception as e:
        print(f"Error in handle_connect: {e}")
        return False


@socketio.on('disconnect')
def handle_disconnect():
    """客户端断开连接"""
    try:
        sid = request.sid
        print(f"Client disconnected: {sid}")

        # 清理断开玩家所在的房间
        rooms_to_remove = []
        for room_id, game in list(games.items()):
            opponent_sids = []
            is_connected = False

            if game['game_type'] == 'doudizhu':
                if game['player1'] == sid or game['player2'] == sid or game['player3'] == sid:
                    is_connected = True
                    if game['player1'] != sid:
                        opponent_sids.append(game['player1'])
                    if game['player2'] != sid:
                        opponent_sids.append(game['player2'])
                    if game['player3'] != sid:
                        opponent_sids.append(game['player3'])
            elif game['game_type'] == 'chinese_chess':
                if game['red_player'] == sid or game['black_player'] == sid:
                    is_connected = True
                    opponent_sids = [game['black_player'] if game['red_player'] == sid else game['red_player']]
            elif game['game_type'] == 'go':
                if game['black_player'] == sid or game['white_player'] == sid:
                    is_connected = True
                    opponent_sids = [game['white_player'] if game['black_player'] == sid else game['black_player']]
            elif game['game_type'] == 'army_chess':
                if game['red_player'] == sid or game['blue_player'] == sid:
                    is_connected = True
                    opponent_sids = [game['blue_player'] if game['red_player'] == sid else game['red_player']]
            elif game['game_type'] == 'othello':
                if game['black_player'] == sid or game['white_player'] == sid:
                    is_connected = True
                    opponent_sids = [game['white_player'] if game['black_player'] == sid else game['black_player']]
            else:  # gobang
                if game['black_player'] == sid or game['white_player'] == sid:
                    is_connected = True
                    opponent_sids = [game['white_player'] if game['black_player'] == sid else game['black_player']]

            if is_connected:
                # 通知其他玩家已断开
                for opponent_sid in opponent_sids:
                    if opponent_sid and opponent_sid != sid:
                        try:
                            socketio.emit('player_disconnected', {'message': '对手已断开连接'}, to=opponent_sid)
                        except Exception as e:
                            print(f"Error notifying opponent: {e}")
                rooms_to_remove.append(room_id)

        for room_id in rooms_to_remove:
            if room_id in games:
                del games[room_id]
                print(f"Room removed: {room_id}")
    except Exception as e:
        print(f"Error in handle_disconnect: {e}")


@socketio.on('create_room')
def handle_create_room(data):
    """创建游戏房间"""
    try:
        game_type = data.get('game_type', 'gobang')  # 默认五子棋
        
        # 生成不重复的房间号（只使用数字）
        max_attempts = 10
        room_id = None
        for _ in range(max_attempts):
            potential_id = str(random.randint(1000, 9999))
            if potential_id not in games:
                room_id = potential_id
                break
        
        if room_id is None:
            emit('error', {'message': '无法创建房间，请稍后重试'})
            return
        
        sid = request.sid

        # 根据游戏类型初始化游戏数据
        if game_type == 'chinese_chess':
            games[room_id] = {
                'game_type': 'chinese_chess',
                'red_player': None,
                'black_player': None,
                'red_choice': None,
                'black_choice': None,
                'board': initialize_chess_board(),
                'current_player': 1,  # 1:红 2:黑
                'game_over': False,
                'winner': None,
                'moves': [],
                'undo_requested': False,  # 是否有悔棋请求
                'last_undo_player': None  # 上次悔棋的玩家
            }
            games[room_id]['red_player'] = sid
            player_color = 'red'
        elif game_type == 'go':
            games[room_id] = {
                'game_type': 'go',
                'black_player': None,
                'white_player': None,
                'black_choice': None,
                'white_choice': None,
                'board': [[0]*19 for _ in range(19)],
                'current_player': 1,  # 1:黑 2:白
                'game_over': False,
                'winner': None,
                'moves': []
            }
            games[room_id]['black_player'] = sid
            player_color = 'black'
        elif game_type == 'army_chess':
            games[room_id] = {
                'game_type': 'army_chess',
                'red_player': None,
                'blue_player': None,
                'red_choice': None,
                'blue_choice': None,
                'board': [[None]*5 for _ in range(12)],  # 12x5军旗棋盘
                'red_pieces': {},  # 存储红方棋子位置和类型
                'blue_pieces': {},  # 存储蓝方棋子位置和类型
                'current_player': 1,  # 1:红 2:蓝
                'game_over': False,
                'winner': None,
                'moves': [],
                'red_arranged': False,
                'blue_arranged': False,
            }
            games[room_id]['red_player'] = sid
            player_color = 'red'
        elif game_type == 'othello':
            games[room_id] = {
                'game_type': 'othello',
                'black_player': None,
                'white_player': None,
                'black_choice': None,
                'white_choice': None,
                'board': initialize_othello_board(),
                'current_player': 1,  # 1:黑 2:白
                'game_over': False,
                'winner': None,
                'moves': []
            }
            games[room_id]['black_player'] = sid
            player_color = 'black'
        else:  # gobang or doudizhu
            if game_type == 'doudizhu':
                games[room_id] = {
                    'game_type': 'doudizhu',
                    'player1': None,
                    'player2': None,
                    'player3': None,
                    'player1_cards': [],
                    'player2_cards': [],
                    'player3_cards': [],
                    'landlord_cards': [],
                    'landlord': None,
                    'current_player': 1,
                    'game_over': False,
                    'last_played_player': None,
                    'last_played_cards': [],
                    'pass_count': 0,  # 连续pass次数
                    'landlord_calls': {},  # 叫地主记录
                }
                games[room_id]['player1'] = sid
                player_number = 1
            else:  # gobang default
                games[room_id] = {
                    'game_type': 'gobang',
                    'black_player': None,
                    'white_player': None,
                    'black_choice': None,
                    'white_choice': None,
                    'board': [[0]*15 for _ in range(15)],
                    'current_player': 1,
                    'game_over': False,
                    'winner': None,
                    'moves': []
                }
                games[room_id]['black_player'] = sid
                player_color = 'black'

        join_room(room_id)
        if game_type == 'doudizhu':
            emit('room_created', {'room_id': room_id, 'player_number': player_number})
        else:
            emit('room_created', {'room_id': room_id, 'player_color': player_color})
        print(f"Room created: {room_id} ({game_type}) by {sid}")
    except Exception as e:
        print(f"Error in handle_create_room: {e}")
        emit('error', {'message': '创建房间失败'})


@socketio.on('join_room')
def handle_join_room(data):
    """加入游戏房间"""
    room_id = data.get('room_id')
    game_type = data.get('game_type')
    sid = request.sid

    if room_id not in games:
        emit('error', {'message': '房间不存在'})
        return

    game = games[room_id]

    # 检查游戏类型是否匹配
    if game_type and game['game_type'] != game_type:
        emit('error', {'message': '游戏类型不匹配'})
        return

    # 根据游戏类型分配玩家身份
    if game['game_type'] == 'chinese_chess':
        if game['red_player'] is None:
            game['red_player'] = sid
            player_color = 'red'
        elif game['black_player'] is None:
            game['black_player'] = sid
            player_color = 'black'
        else:
            emit('error', {'message': '房间已满'})
            return
    elif game['game_type'] == 'go':
        if game['black_player'] is None:
            game['black_player'] = sid
            player_color = 'black'
        elif game['white_player'] is None:
            game['white_player'] = sid
            player_color = 'white'
        else:
            emit('error', {'message': '房间已满'})
            return
    elif game['game_type'] == 'army_chess':
        if game['red_player'] is None:
            game['red_player'] = sid
            player_color = 'red'
        elif game['blue_player'] is None:
            game['blue_player'] = sid
            player_color = 'blue'
        else:
            emit('error', {'message': '房间已满'})
            return
    elif game['game_type'] == 'othello':
        if game['black_player'] is None:
            game['black_player'] = sid
            player_color = 'black'
        elif game['white_player'] is None:
            game['white_player'] = sid
            player_color = 'white'
        else:
            emit('error', {'message': '房间已满'})
            return
    elif game['game_type'] == 'doudizhu':
        if game['player1'] is None:
            game['player1'] = sid
            player_number = 1
        elif game['player2'] is None:
            game['player2'] = sid
            player_number = 2
        elif game['player3'] is None:
            game['player3'] = sid
            player_number = 3
        else:
            emit('error', {'message': '房间已满'})
            return
    else:  # gobang default
        if game['black_player'] is None:
            game['black_player'] = sid
            player_color = 'black'
        elif game['white_player'] is None:
            game['white_player'] = sid
            player_color = 'white'
        else:
            emit('error', {'message': '房间已满'})
            return

    # 先加入房间
    join_room(room_id)
    if game['game_type'] == 'doudizhu':
        emit('room_joined', {'room_id': room_id, 'player_number': player_number})
    else:
        emit('room_joined', {'room_id': room_id, 'player_color': player_color})

    # 检查是否所有玩家都已加入
    if game['game_type'] == 'doudizhu':
        if game['player1'] and game['player2'] and game['player3']:
            # 三个玩家都加入了,开始发牌
            deck = create_doudizhu_deck()
            shuffled_deck = shuffle_deck(deck)
            p1_cards, p2_cards, p3_cards, landlord_cards = deal_cards(shuffled_deck)

            game['player1_cards'] = p1_cards
            game['player2_cards'] = p2_cards
            game['player3_cards'] = p3_cards
            game['landlord_cards'] = landlord_cards

            # 发送游戏开始和各自的手牌
            socketio.emit('game_start', {
                'message': '游戏开始，请选择是否叫地主',
                'my_cards': p1_cards
            }, room=game['player1'])
            socketio.emit('game_start', {
                'message': '游戏开始，请选择是否叫地主',
                'my_cards': p2_cards
            }, room=game['player2'])
            socketio.emit('game_start', {
                'message': '游戏开始，请选择是否叫地主',
                'my_cards': p3_cards
            }, room=game['player3'])

            print(f"Doudizhu game started in room {room_id}")
    else:
        # 检查是否两个玩家都已加入，如果是则开始游戏或等待选择
        if game['game_type'] == 'chinese_chess':
            if game['red_player'] and game['black_player']:
                socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, room=room_id)
        elif game['game_type'] == 'go':
            if game['black_player'] and game['white_player']:
                socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, room=room_id)
        elif game['game_type'] == 'army_chess':
            if game['red_player'] and game['blue_player']:
                socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, room=room_id)
        elif game['game_type'] == 'othello':
            if game['black_player'] and game['white_player']:
                socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, room=room_id)
        else:  # gobang
            if game['black_player'] and game['white_player']:
                socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, room=room_id)


@socketio.on('choose_color')
def handle_choose_color(data):
    """玩家选择先手或后手"""
    room_id = data.get('room_id')
    sid = request.sid
    choice = data.get('choice')  # 'first' or 'second'

    if room_id not in games:
        return

    game = games[room_id]

    # 记录玩家的选择
    if game['game_type'] == 'chinese_chess':
        if game['red_player'] == sid:
            game['red_choice'] = choice
        elif game['black_player'] == sid:
            game['black_choice'] = choice
    elif game['game_type'] == 'go':
        if game['black_player'] == sid:
            game['black_choice'] = choice
        elif game['white_player'] == sid:
            game['white_choice'] = choice
    elif game['game_type'] == 'army_chess':
        if game['red_player'] == sid:
            game['red_choice'] = choice
        elif game['blue_player'] == sid:
            game['blue_choice'] = choice
    elif game['game_type'] == 'othello':
        if game['black_player'] == sid:
            game['black_choice'] = choice
        elif game['white_player'] == sid:
            game['white_choice'] = choice
    else:  # gobang
        if game['black_player'] == sid:
            game['black_choice'] = choice
        elif game['white_player'] == sid:
            game['white_choice'] = choice

    # 检查是否两人都已选择
    if game['game_type'] == 'chinese_chess':
        if game['red_choice'] and game['black_choice']:
            # 确定先后手
            if game['red_choice'] == game['black_choice']:
                # 选择相同，随机决定
                first_player_sid = random.choice([game['red_player'], game['black_player']])
                is_red_first = (first_player_sid == game['red_player'])
            else:
                # 选择不同，先选先手的为先手
                first_choice_sid = game['red_player'] if game['red_choice'] == 'first' else game['black_player']
                is_red_first = (first_choice_sid == game['red_player'])

            # 如果黑方先手，交换红黑身份，因为象棋规则中红方总是先手
            if not is_red_first:
                game['red_player'], game['black_player'] = game['black_player'], game['red_player']
                # 同时也需要交换 choice 记录，虽然在这里已经没用了但为了数据一致性
                game['red_choice'], game['black_choice'] = game['black_choice'], game['red_choice']

            # 准备棋盘数据
            board_data = []
            for row in game['board']:
                row_data = []
                for piece in row:
                    if piece:
                        row_data.append({
                            'name': piece['name'],
                            'type': piece['type'],
                            'color': piece['color']
                        })
                    else:
                        row_data.append(None)
                board_data.append(row_data)

            # 通知双方结果（现在 red_player 总是先手）
            socketio.emit('game_start', {
                'message': '游戏开始！红方先手',
                'first_player': 'red',
                'player_color': 'red',
                'board': board_data
            }, to=game['red_player'])
            socketio.emit('game_start', {
                'message': '游戏开始！黑方后手',
                'first_player': 'red',
                'player_color': 'black',
                'board': board_data
            }, to=game['black_player'])
    elif game['game_type'] == 'go':
        if game['black_choice'] and game['white_choice']:
            # 确定先后手
            if game['black_choice'] == game['white_choice']:
                # 选择相同，随机决定
                first_player_sid = random.choice([game['black_player'], game['white_player']])
                is_black_first = (first_player_sid == game['black_player'])
            else:
                # 选择不同，先选先手的为先手
                first_choice_sid = game['black_player'] if game['black_choice'] == 'first' else game['white_player']
                is_black_first = (first_choice_sid == game['black_player'])

            # 通知双方结果
            if is_black_first:
                socketio.emit('game_start', {
                    'message': '游戏开始！黑棋先手',
                    'first_player': 'black',
                    'player_color': 'black'
                }, to=game['black_player'])
                socketio.emit('game_start', {
                    'message': '游戏开始！白棋后手',
                    'first_player': 'black',
                    'player_color': 'white'
                }, to=game['white_player'])
            else:
                socketio.emit('game_start', {
                    'message': '游戏开始！黑棋后手',
                    'first_player': 'white',
                    'player_color': 'white'
                }, to=game['black_player'])
                socketio.emit('game_start', {
                    'message': '游戏开始！白棋先手',
                    'first_player': 'white',
                    'player_color': 'black'
                }, to=game['white_player'])
    elif game['game_type'] == 'army_chess':
        if game['red_choice'] and game['blue_choice']:
            # 确定先后手
            if game['red_choice'] == game['blue_choice']:
                first_player_sid = random.choice([game['red_player'], game['blue_player']])
                is_red_first = (first_player_sid == game['red_player'])
            else:
                first_choice_sid = game['red_player'] if game['red_choice'] == 'first' else game['blue_player']
                is_red_first = (first_choice_sid == game['red_player'])

            # 如果蓝方先手，交换红蓝身份
            if not is_red_first:
                game['red_player'], game['blue_player'] = game['blue_player'], game['red_player']
                game['red_choice'], game['blue_choice'] = game['blue_choice'], game['red_choice']

            # 通知双方开始布阵（红方总是先手）
            socketio.emit('game_start', {
                'message': '游戏开始！请布置您的棋子',
                'first_player': 'red',
                'player_color': 'red'
            }, to=game['red_player'])
            socketio.emit('game_start', {
                'message': '游戏开始！请布置您的棋子',
                'first_player': 'red',
                'player_color': 'blue'
            }, to=game['blue_player'])
    elif game['game_type'] == 'othello':
        if game['black_choice'] and game['white_choice']:
            # 确定先后手
            if game['black_choice'] == game['white_choice']:
                # 选择相同，随机决定
                first_player_sid = random.choice([game['black_player'], game['white_player']])
                is_black_first = (first_player_sid == game['black_player'])
            else:
                # 选择不同，先选先手的为先手
                first_choice_sid = game['black_player'] if game['black_choice'] == 'first' else game['white_player']
                is_black_first = (first_choice_sid == game['black_player'])

            # 如果白方先手，交换黑白身份
            if not is_black_first:
                game['black_player'], game['white_player'] = game['white_player'], game['black_player']
                game['black_choice'], game['white_choice'] = game['white_choice'], game['black_choice']

            # 通知双方结果（现在 black_player 总是先手）
            socketio.emit('game_start', {
                'message': '游戏开始！黑棋先手',
                'first_player': 'black',
                'player': 1,
                'player_color': 'black',
                'board': game['board'],
                'current_player': 1
            }, to=game['black_player'])
            socketio.emit('game_start', {
                'message': '游戏开始！白棋后手',
                'first_player': 'black',
                'player': 2,
                'player_color': 'white',
                'board': game['board'],
                'current_player': 1
            }, to=game['white_player'])
    elif game['black_choice'] and game['white_choice']:
        # 确定先后手
        if game['black_choice'] == game['white_choice']:
            # 选择相同，随机决定
            first_player_sid = random.choice([game['black_player'], game['white_player']])
            is_black_first = (first_player_sid == game['black_player'])
        else:
            # 选择不同，先选先手的为先手
            first_choice_sid = game['black_player'] if game['black_choice'] == 'first' else game['white_player']
            is_black_first = (first_choice_sid == game['black_player'])

        # 如果白方先手，交换黑白身份，因为五子棋规则中黑棋（Player 1）总是先手
        if not is_black_first:
            game['black_player'], game['white_player'] = game['white_player'], game['black_player']
            game['black_choice'], game['white_choice'] = game['white_choice'], game['black_choice']

        # 通知双方结果（现在 black_player 总是先手）
        socketio.emit('game_start', {
            'message': '游戏开始！黑棋先手',
            'first_player': 'black',
            'player_color': 'black'
        }, to=game['black_player'])
        socketio.emit('game_start', {
            'message': '游戏开始！白棋后手',
            'first_player': 'black',
            'player_color': 'white'
        }, to=game['white_player'])


@socketio.on('arrange_complete')
def handle_arrange_complete(data):
    """玩家完成布阵"""
    room_id = data.get('room_id')
    sid = request.sid
    pieces = data.get('pieces')  # [{row, col, type}, ...]

    if room_id not in games:
        return

    game = games[room_id]

    if game['game_type'] != 'army_chess':
        return

    # 验证玩家身份并保存棋子位置
    if sid == game['red_player']:
        game['red_arranged'] = True
        game['red_pieces'] = {}
        game['red_lost'] = []  # 红方阵亡棋子列表
        # 保存红方棋子信息
        for piece_data in pieces:
            row = piece_data['row']
            col = piece_data['col']
            piece_type = piece_data['type']
            key = f"{row}_{col}"
            game['red_pieces'][key] = {
                'type': piece_type,
                'color': 'red'
            }
            # 在棋盘上标记有棋子（但不显示类型）
            game['board'][row][col] = {'color': 'red'}
        
        socketio.emit('arrange_complete', {'message': '布阵完成，等待对方...'}, to=sid)
        
    elif sid == game['blue_player']:
        game['blue_arranged'] = True
        game['blue_pieces'] = {}
        game['blue_lost'] = []  # 蓝方阵亡棋子列表
        # 保存蓝方棋子信息
        for piece_data in pieces:
            row = piece_data['row']
            col = piece_data['col']
            piece_type = piece_data['type']
            key = f"{row}_{col}"
            game['blue_pieces'][key] = {
                'type': piece_type,
                'color': 'blue'
            }
            # 在棋盘上标记有棋子
            game['board'][row][col] = {'color': 'blue'}
        
        socketio.emit('arrange_complete', {'message': '布阵完成，等待对方...'}, to=sid)

    # 检查双方是否都已完成布阵
    if game['red_arranged'] and game['blue_arranged']:
        game['current_player'] = 1  # 红方先手
        
        # 通知红方游戏开始，包含对方棋子位置（但不含类型）
        blue_positions = [{'row': int(k.split('_')[0]), 'col': int(k.split('_')[1])} 
                         for k in game['blue_pieces'].keys()]
        socketio.emit('game_begin', {
            'message': '双方布阵完成，游戏开始！',
            'current_player': 1,
            'opponent_pieces': blue_positions
        }, to=game['red_player'])
        
        # 通知蓝方游戏开始，包含对方棋子位置
        red_positions = [{'row': int(k.split('_')[0]), 'col': int(k.split('_')[1])} 
                        for k in game['red_pieces'].keys()]
        socketio.emit('game_begin', {
            'message': '双方布阵完成，游戏开始！',
            'current_player': 1,
            'opponent_pieces': red_positions
        }, to=game['blue_player'])


@socketio.on('make_move')
def handle_make_move(data):
    """玩家移动棋子"""
    room_id = data.get('room_id')
    sid = request.sid

    if room_id not in games:
        return

    game = games[room_id]

    # 根据游戏类型处理移动
    if game['game_type'] == 'chinese_chess':
        handle_chess_move(game, room_id, sid, data)
    elif game['game_type'] == 'go':
        handle_go_move(game, room_id, sid, data)
    elif game['game_type'] == 'army_chess':
        handle_army_chess_move(game, room_id, sid, data)
    elif game['game_type'] == 'othello':
        handle_othello_move(game, room_id, sid, data)
    else:  # gobang
        handle_gobang_move(game, room_id, sid, data)


def handle_chess_move(game, room_id, sid, data):
    """处理象棋移动"""
    from_row = data.get('from_row')
    from_col = data.get('from_col')
    to_row = data.get('to_row')
    to_col = data.get('to_col')

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否轮到该玩家
    current_sid = game['red_player'] if game['current_player'] == 1 else game['black_player']
    if sid != current_sid:
        emit('error', {'message': '不是你的回合'})
        return

    # 检查位置是否有效
    if not (0 <= from_row < 10 and 0 <= from_col < 9 and 
            0 <= to_row < 10 and 0 <= to_col < 9):
        emit('error', {'message': '位置超出范围'})
        return

    # 检查起点是否有棋子
    piece = game['board'][from_row][from_col]
    if piece is None:
        emit('error', {'message': '起点没有棋子'})
        return

    # 检查是否是自己的棋子
    current_color = 'red' if game['current_player'] == 1 else 'black'
    if piece['color'] != current_color:
        emit('error', {'message': '不能移动对手的棋子'})
        return

    # 检查移动是否合法
    if not is_valid_chess_move(game['board'], from_row, from_col, to_row, to_col, piece):
        emit('error', {'message': '不合法的移动'})
        return

    # 获取被吃掉的棋子信息（如果有）
    captured_piece = game['board'][to_row][to_col]

    # 执行移动
    game['board'][to_row][to_col] = piece
    game['board'][from_row][from_col] = None
    game['moves'].append({
        'player': game['current_player'],
        'from_row': from_row,
        'from_col': from_col,
        'to_row': to_row,
        'to_col': to_col,
        'piece': piece,  # 移动的棋子
        'captured': captured_piece  # 被吃的棋子
    })

    # 清除悔棋标记（新一步棋后允许再次悔棋）
    game['last_undo_player'] = None

    # 广播移动信息
    socketio.emit('move_made', {
        'player': game['current_player'],
        'from_row': from_row,
        'from_col': from_col,
        'to_row': to_row,
        'to_col': to_col,
        'piece_name': piece['name'],
        'piece_type': piece['type'],
        'piece_color': piece['color']
    }, room=room_id)

    # 检查是否吃掉了将帅
    if captured_piece and captured_piece['type'] == 'king':
        winner_name = '红方' if game['current_player'] == 1 else '黑方'
        game['game_over'] = True
        game['winner'] = game['current_player']
        socketio.emit('game_over', {
            'winner': game['current_player'],
            'message': f'{winner_name}获胜！'
        }, room=room_id)
    else:
        # 切换玩家
        game['current_player'] = 3 - game['current_player']
        socketio.emit('turn_changed', {
            'current_player': game['current_player']
        }, room=room_id)

        # 检查是否将军
        opponent_color = 'red' if game['current_player'] == 1 else 'black'
        if is_check(game['board'], opponent_color):
            check_message = '红方将军！' if opponent_color == 'red' else '黑方将军！'
            socketio.emit('check', {
                'message': check_message,
                'checked_color': opponent_color
            }, room=room_id)


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
    """处理军旗移动"""
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
        }, room=room_id)
        
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
            }, room=room_id)
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
        }, room=room_id)

        # 广播阵亡棋子列表（只发给每个玩家自己的阵亡列表）
        socketio.emit('lost_pieces', {
            'pieces': game['red_lost']
        }, to=game['red_player'])
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
            'attack_row': from_row,
            'attack_col': from_col,
            'defend_row': to_row,
            'defend_col': to_col,
            'current_player': 3 - game['current_player']
        }, room=room_id)

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
        }, room=room_id)

        # 广播阵亡棋子列表（只发给每个玩家自己的阵亡列表）
        socketio.emit('lost_pieces', {
            'pieces': game['red_lost']
        }, to=game['red_player'])
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
            'attack_row': from_row,
            'attack_col': from_col,
            'defend_row': to_row,
            'defend_col': to_col,
            'current_player': 3 - game['current_player']
        }, room=room_id)

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
        }, room=room_id)

        # 广播阵亡棋子列表（只发给每个玩家自己的阵亡列表）
        socketio.emit('lost_pieces', {
            'pieces': game['red_lost']
        }, to=game['red_player'])
        socketio.emit('lost_pieces', {
            'pieces': game['blue_lost']
        }, to=game['blue_player'])
    
    # 切换玩家
    game['current_player'] = 3 - game['current_player']


def resolve_army_chess_battle(attacker_type, defender_type):
    """解决军旗战斗结果"""
    # 炸弹与任何目标同归于尽
    if attacker_type == '炸弹' or defender_type == '炸弹':
        return 'both_die'
    
    # 工兵可以挖地雷
    if defender_type == '地雷':
        if attacker_type == '工兵':
            return 'attacker_win'
        else:
            return 'both_die'
    
    # 军旗不反击
    if defender_type == '军旗':
        return 'attacker_win'
    
    # 普通战斗：司令>军长>师长>旅长>团长>营长>连长>排长>工兵
    ranks = {
        '司令': 9, '军长': 8, '师长': 7, '旅长': 6, '团长': 5,
        '营长': 4, '连长': 3, '排长': 2, '工兵': 1
    }
    
    attacker_rank = ranks.get(attacker_type, 0)
    defender_rank = ranks.get(defender_type, 0)
    
    if attacker_rank > defender_rank:
        return 'attacker_win'
    elif attacker_rank < defender_rank:
        return 'defender_win'
    else:
        return 'both_die'


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


def handle_gobang_move(game, room_id, sid, data):
    """处理五子棋落子"""
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
    if not (0 <= row < 15 and 0 <= col < 15):
        emit('error', {'message': '位置超出范围'})
        return

    if game['board'][row][col] != 0:
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


@socketio.on('play_again')
def handle_play_again(data):
    """再玩一局"""
    room_id = data.get('room_id')

    if room_id not in games:
        return

    game = games[room_id]

    # 根据游戏类型重置游戏
    if game['game_type'] == 'chinese_chess':
        game['board'] = initialize_chess_board()
        game['current_player'] = 1
        game['game_over'] = False
        game['winner'] = None
        game['moves'] = []
        game['red_choice'] = None
        game['black_choice'] = None
        socketio.emit('reset_game', {'message': '请重新选择先后手'}, room=room_id)
    elif game['game_type'] == 'go':
        game['board'] = [[0]*19 for _ in range(19)]
        game['current_player'] = 1
        game['game_over'] = False
        game['winner'] = None
        game['moves'] = []
        game['black_choice'] = None
        game['white_choice'] = None
        socketio.emit('reset_game', {'message': '请重新选择先后手'}, room=room_id)
    elif game['game_type'] == 'army_chess':
        game['board'] = [[None]*9 for _ in range(10)]
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
        socketio.emit('reset_game', {'message': '请重新选择先后手'}, room=room_id)
    elif game['game_type'] == 'othello':
        game['board'] = initialize_othello_board()
        game['current_player'] = 1
        game['game_over'] = False
        game['winner'] = None
        game['moves'] = []
        game['black_choice'] = None
        game['white_choice'] = None
        socketio.emit('reset_game', {'message': '请重新选择先后手'}, room=room_id)
    else:  # gobang
        game['board'] = [[0]*15 for _ in range(15)]
        game['current_player'] = 1
        game['game_over'] = False
        game['winner'] = None
        game['moves'] = []
        game['black_choice'] = None
        game['white_choice'] = None
        socketio.emit('reset_game', {'message': '请重新选择先后手'}, room=room_id)


@socketio.on('surrender')
def handle_surrender(data):
    """认输"""
    room_id = data.get('room_id')
    sid = request.sid

    if room_id not in games:
        return

    game = games[room_id]

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 确定赢家（对方）
    if game['game_type'] == 'chinese_chess':
        winner = 2 if sid == game['red_player'] else 1
    elif game['game_type'] == 'army_chess':
        winner = 2 if sid == game['red_player'] else 1
    elif game['game_type'] == 'othello':
        winner = 2 if sid == game['black_player'] else 1
    else:  # gobang
        winner = 2 if sid == game['black_player'] else 1

    game['game_over'] = True
    game['winner'] = winner

    if game['game_type'] == 'chinese_chess':
        winner_name = '红方' if winner == 1 else '黑方'
    elif game['game_type'] == 'army_chess':
        winner_name = '红方' if winner == 1 else '蓝方'
    elif game['game_type'] == 'othello':
        winner_name = '黑方' if winner == 1 else '白方'
    else:  # gobang
        winner_name = '黑棋' if winner == 1 else '白棋'
    print(f"Player {sid} surrendered, {winner_name} wins in room {room_id}")

    socketio.emit('surrender', {
        'winner': winner,
        'message': f'{winner_name}认输！'
    }, room=room_id)


@socketio.on('undo_request')
def handle_undo_request(data):
    """悔棋请求"""
    room_id = data.get('room_id')
    sid = request.sid

    if room_id not in games:
        return

    game = games[room_id]

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否有走棋记录
    if not game['moves']:
        emit('error', {'message': '还没有走棋，无法悔棋'})
        return

    # 获取当前玩家编号
    current_player = game['current_player']

    # 根据游戏类型获取对手 sid
    if game['game_type'] == 'chinese_chess':
        player_sid = game['red_player'] if current_player == 1 else game['black_player']
    else:  # gobang
        player_sid = game['black_player'] if current_player == 1 else game['white_player']

    # 检查是否已经有待处理的悔棋请求
    if game.get('undo_requested', False):
        emit('error', {'message': '已经有待处理的悔棋请求'})
        return

    # 只能悔自己刚才走的那一步（轮到对方的时候请求）
    if sid == player_sid:
        emit('error', {'message': '只能请求悔棋自己的棋'})
        return

    # 检查是否连续悔棋（上次悔棋的玩家不能连续悔棋）
    last_undo_player = game.get('last_undo_player')
    if last_undo_player == sid:
        emit('error', {'message': '不能连续悔棋'})
        return

    # 标记有悔棋请求
    game['undo_requested'] = True
    game['undo_requester_sid'] = sid

    # 通知对方有悔棋请求
    socketio.emit('undo_request', {
        'player': current_player,
        'room_id': room_id
    }, to=player_sid)

    print(f"Undo request from {sid} in room {room_id}")


@socketio.on('undo_response')
def handle_undo_response(data):
    """悔棋响应"""
    room_id = data.get('room_id')
    approved = data.get('approved', False)
    sid = request.sid

    if room_id not in games:
        return

    game = games[room_id]

    # 检查游戏是否结束
    if game['game_over']:
        return

    # 获取当前玩家（轮到的那一方）
    current_player = game['current_player']
    if game['game_type'] == 'chinese_chess':
        current_sid = game['red_player'] if current_player == 1 else game['black_player']
    else:  # gobang
        current_sid = game['black_player'] if current_player == 1 else game['white_player']

    # 只有轮到的一方才能响应
    if sid != current_sid:
        return

    requester_sid = game.get('undo_requester_sid')

    # 如果同意悔棋，执行悔棋
    if approved:
        # 撤销最后一步棋
        if not game['moves']:
            return
            
        last_move = game['moves'].pop()

        if game['game_type'] == 'chinese_chess':
            # 象棋悔棋：恢复被移动的棋子到原位置，恢复被吃的棋子
            game['board'][last_move['from_row']][last_move['from_col']] = last_move['piece']
            game['board'][last_move['to_row']][last_move['to_col']] = last_move['captured']
        else:  # gobang
            # 五子棋悔棋
            row = last_move['row']
            col = last_move['col']
            game['board'][row][col] = 0

        # 切换回之前的玩家
        game['current_player'] = last_move['player']

        # 记录悔棋玩家（申请者），防止连续悔棋
        if requester_sid:
            game['last_undo_player'] = requester_sid

        # 广播悔棋信息
        socketio.emit('undo_move', {
            'from_row': last_move.get('from_row'),
            'from_col': last_move.get('from_col'),
            'to_row': last_move.get('to_row'),
            'to_col': last_move.get('to_col'),
            'captured': last_move.get('captured'),
            'row': last_move.get('row'),
            'col': last_move.get('col'),
            'current_player': game['current_player']
        }, room=room_id)

        print(f"Undo approved in room {room_id}")
    else:
        print(f"Undo rejected in room {room_id}")

    # 通知申请者结果
    if requester_sid:
        socketio.emit('undo_response', {
            'approved': approved,
            'room_id': room_id
        }, to=requester_sid)

    # 清除悔棋请求标记
    game['undo_requested'] = False
    game['undo_requester_sid'] = None


@socketio.on('draw_request')
def handle_draw_request(data):
    """和棋请求"""
    room_id = data.get('room_id')
    sid = request.sid

    if room_id not in games:
        return

    game = games[room_id]

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 获取当前玩家编号
    current_player = game['current_player']

    # 根据游戏类型获取对手 sid
    if game['game_type'] == 'chinese_chess':
        opponent_sid = game['black_player'] if current_player == 1 else game['red_player']
    else:  # gobang
        opponent_sid = game['white_player'] if current_player == 1 else game['black_player']

    # 通知对方有和棋请求
    socketio.emit('draw_request', {
        'room_id': room_id
    }, to=opponent_sid)

    print(f"Draw request from {sid} in room {room_id}")


@socketio.on('draw_response')
def handle_draw_response(data):
    """和棋响应"""
    room_id = data.get('room_id')
    approved = data.get('approved', False)
    sid = request.sid

    if room_id not in games:
        return

    game = games[room_id]

    # 检查游戏是否结束
    if game['game_over']:
        return

    if approved:
        # 同意和棋，游戏结束
        game['game_over'] = True
        game['winner'] = None  # 和棋没有赢家

        socketio.emit('draw', {
            'message': '双方同意和棋！'
        }, room=room_id)

        print(f"Draw approved in room {room_id}")
    else:
        print(f"Draw rejected in room {room_id}")


@socketio.on('leave_room')
def handle_leave_room(data):
    """离开房间"""
    try:
        room_id = data.get('room_id')
        sid = request.sid
        
        print(f"Player {sid} leaving room {room_id}")

        if room_id in games:
            game = games[room_id]
            
            # 通知对手
            opponent_sid = None
            if game['game_type'] == 'chinese_chess':
                if game['red_player'] == sid:
                    opponent_sid = game['black_player']
                    game['red_player'] = None
                elif game['black_player'] == sid:
                    opponent_sid = game['red_player']
                    game['black_player'] = None
            elif game['game_type'] == 'army_chess':
                if game['red_player'] == sid:
                    opponent_sid = game['blue_player']
                    game['red_player'] = None
                elif game['blue_player'] == sid:
                    opponent_sid = game['red_player']
                    game['blue_player'] = None
            else:  # gobang
                if game['black_player'] == sid:
                    opponent_sid = game['white_player']
                    game['black_player'] = None
                elif game['white_player'] == sid:
                    opponent_sid = game['black_player']
                    game['white_player'] = None
            
            # 只在对手存在且有效时才发送通知
            if opponent_sid and opponent_sid != sid:
                try:
                    socketio.emit('player_disconnected', {'message': '对手已离开房间'}, to=opponent_sid)
                except Exception as e:
                    print(f"Error notifying opponent on leave: {e}")
            
            # 离开socket.io房间
            try:
                leave_room(room_id)
            except Exception as e:
                print(f"Error leaving room: {e}")

            # 如果房间空了，删除房间
            players_exist = False
            if game['game_type'] == 'chinese_chess':
                players_exist = game['red_player'] or game['black_player']
            elif game['game_type'] == 'army_chess':
                players_exist = game['red_player'] or game['blue_player']
            else:
                players_exist = game['black_player'] or game['white_player']
            
            if not players_exist:
                del games[room_id]
                print(f"Room removed: {room_id}")
    except Exception as e:
        print(f"Error in handle_leave_room: {e}")


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


# ==================== 黑白棋相关函数 ====================

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


def validate_cards(cards, last_cards):
    """验证出牌是否合法"""
    if not cards:
        return False, "请选择要出的牌"

    # 如果是首出,只要是合法的牌型即可
    if not last_cards:
        return check_card_type(cards)

    # 如果不是首出,必须跟得上
    last_type, last_rank = check_card_type(last_cards)
    if not last_type:
        return False, "上一手牌无效"

    current_type, current_rank = check_card_type(cards)

    if not current_type:
        return False, "牌型不合法"

    # 炸弹可以炸任何牌
    if current_type == 'bomb' and last_type != 'bomb':
        return True, current_type

    # 王炸最大
    if current_type == 'rocket':
        return True, current_type

    # 同类型比较
    if current_type == last_type and len(cards) == len(last_cards):
        if current_rank > last_rank:
            return True, current_type

    return False, "上家的牌更大或牌型不匹配"


def check_card_type(cards):
    """判断牌型并返回(类型, 最大牌值)"""
    if not cards:
        return None, 0

    # 按rank排序
    sorted_cards = sorted(cards, key=lambda x: x['rank'])
    n = len(cards)

    ranks = [card['rank'] for card in sorted_cards]

    # 单张
    if n == 1:
        return 'single', ranks[0]

    # 对子
    if n == 2:
        if ranks[0] == ranks[1]:
            return 'pair', ranks[0]
        # 王炸
        if ranks[0] == 16 and ranks[1] == 17:
            return 'rocket', 17

    # 三张
    if n == 3:
        if ranks[0] == ranks[1] == ranks[2]:
            return 'triple', ranks[0]

    # 炸弹
    if n == 4:
        if ranks[0] == ranks[1] == ranks[2] == ranks[3]:
            return 'bomb', ranks[0]

    # 三带一
    if n == 4:
        if ranks.count(ranks[0]) == 3 or ranks.count(ranks[3]) == 3:
            triple_rank = ranks[1] if ranks.count(ranks[0]) == 3 else ranks[0]
            return 'triple_one', triple_rank

    # 三带二(对子)
    if n == 5:
        if ranks.count(ranks[0]) == 3 and ranks.count(ranks[3]) == 2:
            return 'triple_pair', ranks[0]
        if ranks.count(ranks[0]) == 2 and ranks.count(ranks[2]) == 3:
            return 'triple_pair', ranks[2]

    # 顺子(至少5张,不能有2和王)
    if n >= 5 and n <= 12:
        if max(ranks) <= 14:  # 不能有2和王
            is_consecutive = all(ranks[i] + 1 == ranks[i + 1] for i in range(n - 1))
            if is_consecutive:
                return 'straight', max(ranks)

    return None, 0


def check_game_over(cards):
    """判断游戏是否结束(牌出完)"""
    return len(cards) == 0


# 斗地主事件处理
@socketio.on('choose_landlord')
def handle_choose_landlord(data):
    """玩家选择是否叫地主"""
    room_id = data.get('room_id')
    player_number = data.get('player_number')
    call = data.get('call', False)

    if room_id not in games:
        return

    game = games[room_id]

    if game['game_type'] != 'doudizhu':
        return

    # 记录玩家选择
    game['landlord_calls'][player_number] = call

    # 如果三个玩家都选择了,确定地主
    if len(game['landlord_calls']) == 3:
        # 简单逻辑:第一个叫地主的当地主
        landlord = None
        for pn in [1, 2, 3]:
            if game['landlord_calls'].get(pn, False):
                landlord = pn
                break

        # 如果都没叫,随机一个
        if landlord is None:
            landlord = random.randint(1, 3)

        game['landlord'] = landlord

        # 地主获得底牌
        landlord_key = f'player{landlord}_cards'
        game[landlord_key].extend(game['landlord_cards'])
        # 重新排序
        game[landlord_key].sort(key=lambda x: x['rank'], reverse=True)

        # 通知所有玩家地主已确定
        socketio.emit('landlord_chosen', {
            'landlord_player': landlord,
            'landlord_cards': game['landlord_cards']
        }, room=room_id)

        # 分别发送更新后的手牌
        for pn in [1, 2, 3]:
            player_key = f'player{pn}'
            cards_key = f'player{pn}_cards'
            if game[player_key]:
                socketio.emit('cards_removed', {
                    'my_cards': game[cards_key]
                }, room=game[player_key])

        # 从地主开始游戏
        game['current_player'] = landlord
        print(f"Landlord chosen: {landlord} in room {room_id}")


@socketio.on('play_cards')
def handle_play_cards(data):
    """玩家出牌"""
    room_id = data.get('room_id')
    player_number = data.get('player_number')
    cards = data.get('cards', [])

    if room_id not in games:
        return

    game = games[room_id]

    if game['game_type'] != 'doudizhu':
        return

    # 检查是否轮到该玩家
    if game['current_player'] != player_number:
        return

    # 验证出牌
    is_valid, message = validate_cards(cards, game['last_played_cards'])

    if not is_valid:
        print(f"Invalid cards from player {player_number}: {message}")
        return

    # 从玩家手牌中移除出的牌
    player_cards_key = f'player{player_number}_cards'
    player_cards = game[player_cards_key]

    # 移除已出的牌
    cards_to_remove = set()
    for card_data in cards:
        rank = card_data['rank']
        suit = card_data['suit']
        for i, pc in enumerate(player_cards):
            if pc['rank'] == rank and pc['suit'] == suit and i not in cards_to_remove:
                cards_to_remove.add(i)
                break

    # 按索引从大到小移除,避免索引错位
    for i in sorted(cards_to_remove, reverse=True):
        player_cards.pop(i)

    # 更新游戏状态
    game['last_played_cards'] = cards
    game['last_played_player'] = player_number
    game['pass_count'] = 0

    # 检查是否游戏结束
    if check_game_over(player_cards):
        game['game_over'] = True
        winner_is_landlord = (player_number == game['landlord'])

        # 通知所有玩家游戏结束
        socketio.emit('game_over', {
            'message': f'玩家{player_number}胜利!' if winner_is_landlord else f'农民胜利!',
            'winner': player_number
        }, room=room_id)

        print(f"Game over in room {room_id}, winner: player{player_number}")
        return

    # 广播出牌信息
    socketio.emit('cards_played', {
        'player_number': player_number,
        'cards': cards
    }, room=room_id)

    # 通知该玩家更新手牌
    player_sid = game[f'player{player_number}']
    if player_sid:
        socketio.emit('cards_removed', {
            'my_cards': player_cards
        }, room=player_sid)

    # 轮到下一位玩家
    game['current_player'] = (player_number % 3) + 1
    print(f"Player {player_number} played {len(cards)} cards, next: {game['current_player']}")


@socketio.on('pass_turn')
def handle_pass_turn(data):
    """玩家不出牌"""
    room_id = data.get('room_id')
    player_number = data.get('player_number')

    if room_id not in games:
        return

    game = games[room_id]

    if game['game_type'] != 'doudizhu':
        return

    # 检查是否轮到该玩家
    if game['current_player'] != player_number:
        return

    # 如果是首出,不能pass
    if not game['last_played_cards'] or game['pass_count'] >= 2:
        return

    # 记录pass
    game['pass_count'] += 1

    # 广播pass信息
    socketio.emit('cards_played', {
        'player_number': player_number,
        'cards': None
    }, room=room_id)

    # 如果连续两人pass,下一轮可以任意出牌
    if game['pass_count'] >= 2:
        game['last_played_cards'] = []
        game['pass_count'] = 0

    # 轮到下一位玩家
    game['current_player'] = (player_number % 3) + 1
    print(f"Player {player_number} passed, next: {game['current_player']}")


if __name__ == '__main__':
    print("="*50)
    print("Online Game Server Starting")
    print("Supported Games: Gobang, Chinese Chess, Army Chess")
    print("="*50)
    print(f"Async mode: {ASYNC_MODE}")
    print(f"Host: 0.0.0.0")
    print(f"Port: 5000")
    print("="*50)

    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)


