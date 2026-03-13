#!/usr/bin/env python3
"""
联机游戏服务器 - 主程序（完整版）
支持五子棋、中国象棋、围棋、黑白棋、军棋、斗地主等多种游戏在线对战
所有游戏功能已完整移植，包括：
- 军棋：工兵铁路移动（含拐弯）、行营移动、路径显示
- 斗地主：完整牌型验证（飞机、连对等）
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
import yaml
import os

# 读取配置文件（根目录的 config.yaml）
def load_config():
    config_path = os.path.join(os.path.dirname(__file__), '..', 'config.yaml')
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    return {'server_url': 'http://localhost:5000'}

config = load_config()
SERVER_URL = config.get('server_url', 'http://localhost:5000')

# 导入游戏模块
from games import gobang, chinese_chess, go, othello, chinese_checkers, international_chess
from games.army_chess import handle_army_chess_move, reset_army_chess_game  # 保留以兼容
from games.doudizhu import handle_choose_landlord, handle_play_cards, handle_pass_turn
from games.flip_army_chess import handle_flip_army_chess_move, reset_flip_army_chess_game  # 翻子军棋

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

# 设置全局变量到各个游戏模块
gobang.socketio = socketio
gobang.games = games
chinese_chess.socketio = socketio
chinese_chess.games = games
go.socketio = socketio
go.games = games
othello.socketio = socketio
othello.games = games
chinese_checkers.socketio = socketio
chinese_checkers.games = games
international_chess.socketio = socketio
international_chess.games = games

# 导入并设置军棋和斗地主模块的全局变量
import games.army_chess as army_chess_module
import games.doudizhu as doudizhu_module
import games.flip_army_chess as flip_army_chess_module
army_chess_module.socketio = socketio
army_chess_module.games = games
doudizhu_module.socketio = socketio
doudizhu_module.games = games
flip_army_chess_module.socketio = socketio
flip_army_chess_module.games = games


@app.route('/')
def index():
    """健康检查接口"""
    return "Game Server is Running!"


@socketio.on('connect')
def handle_connect():
    """客户端连接"""
    try:
        print(f"Client connected: {request.sid}")  # pyright: ignore[reportAttributeAccessIssue]
        emit('connected', {'sid': request.sid})  # pyright: ignore[reportAttributeAccessIssue]
    except Exception as e:
        print(f"Error in handle_connect: {e}")
        return False


@socketio.on('start_game')
def handle_start_game(data):
    """房主开始游戏"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

        if room_id not in games:
            return

        game = games[room_id]

        if game['game_type'] != 'chinese_checkers':
            emit('error', {'message': '该游戏不支持此功能'})
            return

        # 验证是否为房主（第一个加入的玩家）
        host_player = game['players'][0]
        if host_player['sid'] != sid:
            emit('error', {'message': '只有房主可以开始游戏'})
            return

        # 检查是否有至少2个玩家
        joined_players = [p for p in game['players'] if p['joined']]
        if len(joined_players) < 2:
            emit('error', {'message': '至少需要2个玩家才能开始游戏'})
            return

        # 开始游戏
        game['game_started'] = True
        player_colors = [p['color'] for p in joined_players]
        
        socketio.emit('game_start', {
            'message': f'游戏开始！{len(joined_players)}人游戏，红方先手',
            'first_player': 1,
            'player_colors': player_colors,
            'board': game['board']
        }, to=room_id)
        
        print(f"Game started in room {room_id} by host {sid}")
        
    except Exception as e:
        print(f"Error in handle_start_game: {e}")
        emit('error', {'message': '开始游戏失败'})


@socketio.on('disconnect')
def handle_disconnect():
    """客户端断开连接"""
    try:
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]
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
                opponent_sids = chinese_chess.handle_chinese_chess_disconnect(game, sid)
                if opponent_sids:
                    is_connected = True
            elif game['game_type'] == 'go':
                opponent_sids = go.handle_go_disconnect(game, sid)
                if opponent_sids:
                    is_connected = True
            elif game['game_type'] == 'army_chess':
                opponent_sids = army_chess_module.handle_army_chess_disconnect(game, sid)
                if opponent_sids:
                    is_connected = True
            elif game['game_type'] == 'flip_army_chess':
                opponent_sids = flip_army_chess_module.handle_flip_army_chess_disconnect(game, sid)
                if opponent_sids:
                    is_connected = True
            elif game['game_type'] == 'othello':
                    opponent_sids = othello.handle_othello_disconnect(game, sid)
                    if opponent_sids:
                        is_connected = True
            elif game['game_type'] == 'international_chess':
                opponent_sids = international_chess.handle_international_chess_disconnect(game, sid)
                if opponent_sids:
                    is_connected = True
            else:  # gobang
                opponent_sids = gobang.handle_gobang_disconnect(game, sid)
                if opponent_sids:
                    is_connected = True

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
        
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

        # 根据游戏类型初始化游戏数据
        if game_type == 'chinese_chess':
            games[room_id] = chinese_chess.initialize_chinese_chess_game(sid)
            games[room_id]['red_player'] = sid
            player_color = 'red'
        elif game_type == 'go':
            games[room_id] = go.initialize_go_game(sid)
            games[room_id]['black_player'] = sid
            player_color = 'black'
        elif game_type == 'army_chess':
            games[room_id] = army_chess_module.initialize_army_chess_game(sid)
            games[room_id]['red_player'] = sid
            player_color = 'red'
        elif game_type == 'flip_army_chess':
            games[room_id] = flip_army_chess_module.initialize_flip_army_chess_game(sid)
            games[room_id]['red_player'] = sid
            player_color = 'red'
        elif game_type == 'othello':
            games[room_id] = othello.initialize_othello_game(sid)
            games[room_id]['black_player'] = sid
            player_color = 'black'
        elif game_type == 'chinese_checkers':
            games[room_id] = chinese_checkers.initialize_chinese_checkers_game(sid)
            player_color = 'red'
        elif game_type == 'doudizhu':
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
                'landlord_calls': {},
                'current_player': None,
                'last_played_cards': [],
                'last_played_player': None,
                'pass_count': 0,
                'game_over': False,
                'winner': None
            }
            games[room_id]['player1'] = sid
            player_number = 1
        elif game_type == 'international_chess':
            games[room_id] = international_chess.initialize_international_chess_game(sid)
            games[room_id]['white_player'] = sid
            player_color = 'white'
        else:  # gobang default
            games[room_id] = gobang.initialize_gobang_game(sid)
            games[room_id]['black_player'] = sid
            player_color = 'black'

        join_room(room_id)
        print(f"Room {room_id} created by {sid}, game type: {game_type}")

        emit('room_created', {
            'room_id': room_id,
            'game_type': game_type,
            'player_color': player_color if game_type != 'doudizhu' else None,
            'player_number': player_number if game_type == 'doudizhu' else None,
            'message': '房间创建成功，等待其他玩家加入...'
        })
    except Exception as e:
        print(f"Error in handle_create_room: {e}")
        emit('error', {'message': f'创建房间失败: {str(e)}'})


@socketio.on('join_room')
def handle_join_room(data):
    """加入游戏房间"""
    try:
        room_id = data.get('room_id')
        game_type = data.get('game_type')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

        if room_id not in games:
            emit('error', {'message': '房间不存在'})
            return

        game = games[room_id]

        # 检查游戏类型是否匹配
        if game_type and game['game_type'] != game_type:
            emit('error', {'message': '游戏类型不匹配'})
            return

        # 根据游戏类型分配玩家身份
        player_color = None
        player_number = None

        if game['game_type'] == 'doudizhu':
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
        elif game['game_type'] == 'army_chess':
            player_color = army_chess_module.assign_army_chess_player(game, sid)
            if player_color is None:
                emit('error', {'message': '房间已满'})
                return
            else:
                player_number = 1 if player_color == 'red' else 2
        elif game['game_type'] == 'flip_army_chess':
            player_color = flip_army_chess_module.assign_flip_army_chess_player(game, sid)
            if player_color is None:
                emit('error', {'message': '房间已满'})
                return
            else:
                player_number = 1 if player_color == 'red' else 2
        elif game['game_type'] == 'international_chess':
            if game['white_player'] is None:
                game['white_player'] = sid
                player_color = 'white'
            elif game['black_player'] is None:
                game['black_player'] = sid
                player_color = 'black'
            else:
                emit('error', {'message': '房间已满'})
                return
        elif game['game_type'] == 'chinese_chess':
            player_color = chinese_chess.assign_chinese_chess_player(game, sid)
            if player_color is None:
                emit('error', {'message': '房间已满'})
                return
        elif game['game_type'] == 'go':
            player_color = go.assign_go_player(game, sid)
            if player_color is None:
                emit('error', {'message': '房间已满'})
                return
        elif game['game_type'] == 'othello':
            player_color = othello.assign_othello_player(game, sid)
            if player_color is None:
                emit('error', {'message': '房间已满'})
                return
        elif game['game_type'] == 'international_chess':
            player_color = international_chess.assign_international_chess_player(game, sid)
            if player_color is None:
                emit('error', {'message': '房间已满'})
                return
        elif game['game_type'] == 'chinese_checkers':
            # 寻找空位加入
            # 对于双人游戏，第二人应分配到对面位置
            player_info = None
            player_index = -1
            
            # 检查是否是双人游戏模式（只有房主和一个对手）
            joined_count = sum(1 for p in game['players'] if p['joined'])
            
            if joined_count == 1:  # 只有房主加入了，现在是第二个人加入
                # 在双人模式中，让第二人坐在对面（蓝色位置）
                # 查找蓝色位置
                for i, player in enumerate(game['players']):
                    if player['color'] == 'blue' and not player['joined']:
                        player_info = player
                        player_index = i
                        break
                # 如果没找到蓝色位置（理论上不会发生），则使用第一个可用位置
                if player_info is None:
                    for i, player in enumerate(game['players']):
                        if not player['joined']:
                            player_info = player
                            player_index = i
                            break
            else:
                # 非双人模式或多人游戏，按顺序分配
                for i, player in enumerate(game['players']):
                    if not player['joined']:
                        player_info = player
                        player_index = i
                        break
            
            if player_info:
                print(f"设置玩家信息前: {player_info}")
                print(f"请求SID: {sid}")
                player_info['sid'] = sid
                player_info['joined'] = True
                player_color = player_info['color']
                player_number = player_index + 1
                print(f"玩家加入房间 {room_id}: 分配颜色 {player_color}, 索引 {player_index}")
                print(f"设置玩家信息后: {player_info}")
                print(f"当前房间玩家状态: {[{'color': p['color'], 'sid': p['sid'], 'joined': p['joined']} for p in game['players']]}")
            else:
                emit('error', {'message': '房间已满'})
                return
        else:  # gobang default
            player_color = gobang.assign_gobang_player(game, sid)
            if player_color is None:
                emit('error', {'message': '房间已满'})
                return

        # 先加入房间
        join_room(room_id)
        if game['game_type'] == 'doudizhu':
            emit('room_joined', {'room_id': room_id, 'player_number': player_number})
        elif game['game_type'] == 'chinese_checkers':
            # 计算已加入的玩家数量
            joined_count = sum(1 for p in game['players'] if p['joined'])
            emit('room_joined', {
                'room_id': room_id, 
                'player_color': player_color,
                'joined_count': joined_count
            })
            # 向房间内所有玩家广播最新的玩家状态
            socketio.emit('player_status_update', {
                'joined_count': joined_count,
                'players': [{'color': p['color'], 'joined': p['joined']} for p in game['players']]
            }, to=room_id)
        else:
            emit('room_joined', {'room_id': room_id, 'player_color': player_color})

        # 检查是否所有玩家都已加入
        if game['game_type'] == 'doudizhu':
            if game['player1'] and game['player2'] and game['player3']:
                _start_doudizhu_game(game, room_id)
        elif game['game_type'] == 'chinese_checkers':
            # 对于中国跳棋，不再自动开始游戏，由房主手动开始
            pass
        else:
            # 检查是否两个玩家都已加入
            if game['game_type'] == 'chinese_chess':
                if game['red_player'] and game['black_player']:
                    socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, to=room_id)
            elif game['game_type'] == 'go':
                if game['black_player'] and game['white_player']:
                    socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, to=room_id)
            elif game['game_type'] == 'army_chess':
                if game['red_player'] and game['blue_player']:
                    socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, to=room_id)
            elif game['game_type'] == 'flip_army_chess':
                if game['red_player'] and game['blue_player']:
                    socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, to=room_id)
            elif game['game_type'] == 'othello':
                if game['black_player'] and game['white_player']:
                    socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, to=room_id)
            elif game['game_type'] == 'international_chess':
                if game['white_player'] and game['black_player']:
                    socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, to=room_id)
            else:  # gobang
                if game['black_player'] and game['white_player']:
                    socketio.emit('waiting_for_choices', {'message': '双方已连接，请选择先后手'}, to=room_id)
    except Exception as e:
        print(f"Error in handle_join_room: {e}")
        emit('error', {'message': f'加入房间失败: {str(e)}'})


@socketio.on('choose_color')
def handle_choose_color(data):
    """玩家选择先手或后手"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]
        choice = data.get('choice')  # 'first' or 'second'

        if room_id not in games:
            return

        game = games[room_id]

        # 记录玩家的选择
        if game['game_type'] == 'chinese_chess':
            chinese_chess.record_chinese_chess_choice(game, sid, choice)
        elif game['game_type'] == 'go':
            go.record_go_choice(game, sid, choice)
        elif game['game_type'] == 'army_chess':
            army_chess_module.record_army_chess_choice(game, sid, choice)
        elif game['game_type'] == 'flip_army_chess':
            flip_army_chess_module.record_flip_army_chess_choice(game, sid, choice)
        elif game['game_type'] == 'othello':
            othello.record_othello_choice(game, sid, choice)
        elif game['game_type'] == 'international_chess':
            international_chess.record_international_chess_choice(game, sid, choice)
        elif game['game_type'] == 'chinese_checkers':
            if game['red_player'] == sid:
                game['red_choice'] = choice
            elif game['blue_player'] == sid:
                game['blue_choice'] = choice
        else:  # gobang
            if game['black_player'] == sid:
                game['black_choice'] = choice
            elif game['white_player'] == sid:
                game['white_choice'] = choice

        # 检查是否两人都已选择
        if game['game_type'] == 'chinese_chess':
            if chinese_chess.should_start_chinese_chess(game):
                chinese_chess.determine_chinese_chess_first_player(game)

                # 准备棋盘数据
                board_data = chinese_chess.prepare_chinese_chess_board_data(game)

                # 通知双方结果
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
            if go.should_start_go(game):
                # 确定先后手
                if game['black_choice'] == game['white_choice']:
                    first_player_sid = random.choice([game['black_player'], game['white_player']])
                    is_black_first = (first_player_sid == game['black_player'])
                else:
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
            if army_chess_module.should_start_army_chess(game):
                army_chess_module.determine_army_chess_first_player(game)
                # 通知双方开始布阵（红方总是先手）
                army_chess_module.notify_arrange_start(game)
        elif game['game_type'] == 'flip_army_chess':
            if flip_army_chess_module.should_start_flip_army_chess(game):
                flip_army_chess_module.determine_flip_army_chess_first_player(game)
                # 初始化并打乱棋子
                flip_army_chess_module.initialize_flip_army_chess_pieces(game)
                
                # 准备棋盘数据（所有棋子位置，但都是盖住的）
                all_piece_positions = []
                for key in game['pieces']:
                    row = int(key.split('_')[0])
                    col = int(key.split('_')[1])
                    all_piece_positions.append({
                        'row': row,
                        'col': col,
                        'flipped': False  # 初始都是盖住的
                    })
                
                # 通知双方游戏开始，包含所有棋子位置
                socketio.emit('game_start', {
                    'message': '游戏开始！',
                    'first_player': 'red',
                    'player_color': 'red',
                    'current_player': 1,
                    'pieces': all_piece_positions  # 发送所有棋子位置
                }, to=game['red_player'])
                socketio.emit('game_start', {
                    'message': '游戏开始！',
                    'first_player': 'red',
                    'player_color': 'blue',
                    'current_player': 1,
                    'pieces': all_piece_positions  # 发送所有棋子位置
                }, to=game['blue_player'])

        elif game['game_type'] == 'othello':
            if othello.should_start_othello(game):
                # 黑白棋总是黑棋先手
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
        elif game['game_type'] == 'international_chess':
            if international_chess.should_start_international_chess(game):
                # 确定先后手
                if game['white_choice'] == game['black_choice']:
                    # 选择相同，随机决定
                    first_player_sid = random.choice([game['white_player'], game['black_player']])
                    is_white_first = (first_player_sid == game['white_player'])
                else:
                    first_choice_sid = game['white_player'] if game['white_choice'] == 'first' else game['black_player']
                    is_white_first = (first_choice_sid == game['white_player'])

                # 确定先后手
                if is_white_first:
                    game['current_player'] = 1  # 白方先手
                    socketio.emit('game_start', {
                        'message': '游戏开始！白方先手',
                        'first_player': 'white',
                        'player': 1,
                        'player_color': 'white',
                        'board': game['board'],
                        'current_player': 1
                    }, to=game['white_player'])
                    socketio.emit('game_start', {
                        'message': '游戏开始！白方先手',
                        'first_player': 'white',
                        'player': 2,
                        'player_color': 'black',
                        'board': game['board'],
                        'current_player': 1
                    }, to=game['black_player'])
                else:
                    game['current_player'] = -1  # 黑方先手
                    socketio.emit('game_start', {
                        'message': '游戏开始！黑方先手',
                        'first_player': 'black',
                        'player': 2,
                        'player_color': 'white',
                        'board': game['board'],
                        'current_player': -1
                    }, to=game['white_player'])
                    socketio.emit('game_start', {
                        'message': '游戏开始！黑方先手',
                        'first_player': 'black',
                        'player': 1,
                        'player_color': 'black',
                        'board': game['board'],
                        'current_player': -1
                    }, to=game['black_player'])
        elif game['game_type'] == 'chinese_checkers':
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

                # 通知双方结果
                socketio.emit('game_start', {
                    'message': '游戏开始！红方先手',
                    'first_player': 'red',
                    'player_color': 'red',
                    'board': game['board']
                }, to=game['red_player'])
                socketio.emit('game_start', {
                    'message': '游戏开始！蓝方后手',
                    'first_player': 'red',
                    'player_color': 'blue',
                    'board': game['board']
                }, to=game['blue_player'])

        else:  # gobang
            if gobang.should_start_gobang(game):
                is_black_first = gobang.determine_gobang_first_player(game)

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
    except Exception as e:
        print(f"Error in handle_choose_color: {e}")


@socketio.on('arrange_complete')
def handle_arrange_complete(data):
    """玩家完成布阵"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]
        pieces = data.get('pieces')  # [{row, col, type}, ...]

        if room_id not in games:
            return

        game = games[room_id]

        if game['game_type'] != 'army_chess':
            return

        # 验证玩家身份并保存棋子位置
        if sid == game['red_player']:
            army_chess_module.handle_arrange_pieces(game, sid, pieces)
            socketio.emit('arrange_complete', {'message': '布阵完成，等待对方...'}, to=sid)
        elif sid == game['blue_player']:
            army_chess_module.handle_arrange_pieces(game, sid, pieces)
            socketio.emit('arrange_complete', {'message': '布阵完成，等待对方...'}, to=sid)

        # 检查双方是否都已完成布阵
        if game['red_arranged'] and game['blue_arranged']:
            army_chess_module.start_arranged_game(game, room_id)
    except Exception as e:
        print(f"Error in handle_arrange_complete: {e}")


@socketio.on('make_move')
def handle_make_move(data):
    """玩家移动棋子（路由函数）"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

        if room_id not in games:
            return

        game = games[room_id]

        # 根据游戏类型调用相应的处理函数
        if game['game_type'] == 'chinese_chess':
            chinese_chess.handle_chess_move(game, room_id, sid, data)
        elif game['game_type'] == 'go':
            go.handle_go_move(game, room_id, sid, data)
        elif game['game_type'] == 'army_chess':
            army_chess_module.handle_army_chess_move(game, room_id, sid, data)
        elif game['game_type'] == 'flip_army_chess':
            flip_army_chess_module.handle_flip_army_chess_move(game, room_id, sid, data)
        elif game['game_type'] == 'othello':
            othello.handle_othello_move(game, room_id, sid, data)
        elif game['game_type'] == 'chinese_checkers':
            chinese_checkers.handle_chinese_checkers_move(game, room_id, sid, data)
        elif game['game_type'] == 'international_chess':
            international_chess.handle_international_chess_move(game, room_id, sid, data)
        else:  # gobang
            gobang.handle_gobang_move(game, room_id, sid, data)
    except Exception as e:
        print(f"Error in handle_make_move: {e}")


@socketio.on('play_again')
def handle_play_again(data):
    """再玩一局"""
    try:
        room_id = data.get('room_id')

        if room_id not in games:
            return

        game = games[room_id]

        # 根据游戏类型重置游戏
        if game['game_type'] == 'chinese_chess':
            chinese_chess.reset_chess_game(game)
            socketio.emit('reset_game', {'message': '请重新选择先后手'}, to=room_id)
        elif game['game_type'] == 'go':
            go.reset_go_game(game)
            socketio.emit('reset_game', {'message': '请重新选择先后手'}, to=room_id)
        elif game['game_type'] == 'army_chess':
            army_chess_module.reset_army_chess_game(game)
            socketio.emit('reset_game', {'message': '请重新选择先后手'}, to=room_id)
        elif game['game_type'] == 'flip_army_chess':
            flip_army_chess_module.reset_flip_army_chess_game(game)
            socketio.emit('reset_game', {'message': '请重新选择先后手'}, to=room_id)
        elif game['game_type'] == 'othello':
            othello.reset_othello_game(game)
            socketio.emit('reset_game', {'message': '请重新选择先后手'}, to=room_id)
        elif game['game_type'] == 'chinese_checkers':
            chinese_checkers.reset_chinese_checkers_game(game)
            socketio.emit('reset_game', {'message': '游戏已重置'}, to=room_id)
        elif game['game_type'] == 'international_chess':
            international_chess.reset_international_chess_game(game)
            socketio.emit('reset_game', {'message': '请重新选择先后手'}, to=room_id)
        else:  # gobang
            gobang.reset_gobang_game(game)
            socketio.emit('reset_game', {'message': '请重新选择先后手'}, to=room_id)
    except Exception as e:
        print(f"Error in handle_play_again: {e}")


@socketio.on('surrender')
def handle_surrender(data):
    """认输"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

        if room_id not in games:
            return

        game = games[room_id]

        # 检查游戏是否结束
        if game['game_over']:
            emit('error', {'message': '游戏已结束'})
            return

        # 确定赢家（对方）和双方sid
        if game['game_type'] == 'chinese_chess':
            winner, winner_sid, loser_sid = chinese_chess.handle_chinese_chess_surrender(game, sid)
        elif game['game_type'] == 'gobang':
            winner, winner_sid, loser_sid = gobang.handle_gobang_surrender(game, sid)
        elif game['game_type'] == 'go':
            winner, winner_sid, loser_sid = go.handle_go_surrender(game, sid)
        elif game['game_type'] == 'othello':
            winner, winner_sid, loser_sid = othello.handle_othello_surrender(game, sid)
        elif game['game_type'] == 'international_chess':
            winner, winner_sid, loser_sid = international_chess.handle_international_chess_surrender(game, sid)
        elif game['game_type'] == 'chinese_checkers':
            # 中国跳棋认输逻辑
            winner = 1  # 简化处理，实际应该找出其他玩家
            winner_sid = None
            loser_sid = sid
        elif game['game_type'] == 'army_chess':
            winner, winner_sid, loser_sid = army_chess_module.handle_army_chess_surrender(game, sid)
        elif game['game_type'] == 'flip_army_chess':
            winner, winner_sid, loser_sid = flip_army_chess_module.handle_flip_army_chess_surrender(game, sid)
        else:  # doudizhu
            emit('error', {'message': '斗地主暂不支持认输'})
            return

        game['game_over'] = True
        game['winner'] = winner

        if game['game_type'] == 'chinese_chess':
            winner_name = chinese_chess.get_chinese_chess_winner_name(winner)
        elif game['game_type'] == 'gobang':
            winner_name = gobang.get_gobang_winner_name(winner)
        elif game['game_type'] == 'go':
            winner_name = go.get_go_winner_name(winner)
        elif game['game_type'] == 'othello':
            winner_name = othello.get_othello_winner_name(winner)
        elif game['game_type'] == 'international_chess':
            winner_name = international_chess.get_international_chess_winner_name(winner)
        elif game['game_type'] == 'chinese_checkers':
            winner_name = '某位玩家'
        elif game['game_type'] == 'army_chess':
            winner_name = army_chess_module.get_army_chess_winner_name(winner)
        elif game['game_type'] == 'flip_army_chess':
            winner_name = flip_army_chess_module.get_flip_army_chess_winner_name(winner)
        else:
            winner_name = '某方'

        # 分别给赢家和输家发送不同的消息
        if game['game_type'] in ['gobang', 'go', 'othello', 'international_chess', 'chinese_chess', 'army_chess']:
            # 给赢家发送：你赢了，对手认输
            socketio.emit('game_over', {
                'winner': winner,
                'message': f'{winner_name}获胜！对手认输。'
            }, to=winner_sid)
            # 给输家发送：你认输了
            socketio.emit('game_over', {
                'winner': winner,
                'message': '你认输了。'
            }, to=loser_sid)
        else:
            # 其他游戏类型，统一广播（如中国跳棋）
            socketio.emit('game_over', {
                'winner': winner,
                'message': f'{winner_name}获胜！对手认输。'
            }, to=room_id)
    except Exception as e:
        print(f"Error in handle_surrender: {e}")


@socketio.on('leave_room')
def handle_leave_room(data):
    """离开房间"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

        if room_id in games:
            leave_room(room_id)
            socketio.emit('player_left', {'sid': sid}, to=room_id)
            print(f"Player {sid} left room {room_id}")
    except Exception as e:
        print(f"Error in handle_leave_room: {e}")


# 斗地主相关事件处理
@socketio.on('choose_landlord')
def handle_choose_landlord_handler(data):
    """玩家选择是否叫地主"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]
        handle_choose_landlord(games, room_id, sid, data, socketio, emit)
    except Exception as e:
        print(f"Error in handle_choose_landlord: {e}")


@socketio.on('play_cards')
def handle_play_cards_handler(data):
    """玩家出牌"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]
        handle_play_cards(games, room_id, sid, data, socketio, emit)
    except Exception as e:
        print(f"Error in handle_play_cards: {e}")


@socketio.on('pass_turn')
def handle_pass_turn_handler(data):
    """玩家不出牌"""
    try:
        room_id = data.get('room_id')
        sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]
        handle_pass_turn(games, room_id, sid, data, socketio, emit)
    except Exception as e:
        print(f"Error in handle_pass_turn: {e}")


@socketio.on('undo_request')
def handle_undo_request(data):
    """悔棋请求"""
    print(f"=== 收到悔棋请求 ===")
    print(f"请求数据: {data}")
    
    room_id = data.get('room_id')
    sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]
    
    print(f"房间ID: {room_id}, 请求者SID: {sid}")
    
    if room_id not in games:
        print(f"房间 {room_id} 不存在")
        return
    
    game = games[room_id]
    print(f"游戏类型: {game['game_type']}")
    print(f"游戏状态: {'已结束' if game['game_over'] else '进行中'}")
    print(f"移动记录数: {len(game.get('moves', []))}")

    # 斗地主和军棋不支持悔棋
    if game['game_type'] in ['doudizhu', 'army_chess', 'flip_army_chess']:
        emit('error', {'message': '该游戏不支持悔棋'})
        return

    # 检查游戏是否结束
    if game['game_over']:
        emit('error', {'message': '游戏已结束'})
        return

    # 检查是否有走棋记录
    if not game.get('moves'):
        emit('error', {'message': '还没有走棋，无法悔棋'})
        return

    # 获取当前玩家编号
    current_player = game['current_player']
    print(f"当前玩家编号: {current_player}")
        
    # 根据游戏类型获取对手 sid
    if game['game_type'] == 'chinese_chess':
        player_sid = chinese_chess.get_chinese_chess_current_player_sid(game)
        print(f"象棋对手SID: {player_sid}")
    elif game['game_type'] == 'go':
        player_sid = go.get_go_current_player_sid(game)
        print(f"围棋对手SID: {player_sid}")
    elif game['game_type'] == 'othello':
        player_sid = othello.get_othello_current_player_sid(game)
    elif game['game_type'] == 'international_chess':
        player_sid = international_chess.get_international_chess_current_player_sid(game)
        print(f"国际象棋对手SID: {player_sid}")
    elif game['game_type'] == 'chinese_checkers':
        # 跳棋：向当前轮到的玩家发送悔棋请求
        # current_player是当前轮到的玩家，也就是需要同意悔棋的玩家
        current_player_info = game['players'][current_player - 1]
        player_sid = current_player_info['sid']
        print(f"跳棋当前轮到玩家SID: {player_sid}, 玩家信息: {current_player_info}")
    elif game['game_type'] == 'checkers':
        player_sid = game['red_player'] if current_player == 1 else game['blue_player']
        print(f"西洋跳棋对手SID: {player_sid}")
    else:  # gobang
        player_sid = gobang.get_gobang_current_player_sid(game)
        print(f"五子棋对手SID: {player_sid}")

    # 检查是否已经有待处理的悔棋请求
    if game.get('undo_requested', False):
        print(f"已经有待处理的悔棋请求")
        emit('error', {'message': '已经有待处理的悔棋请求'})
        return

    # 只能悔自己刚才走的那一步（轮到对方的时候请求）
    if sid == player_sid:
        print(f"请求者SID {sid} 与目标玩家SID {player_sid} 相同，不能请求悔棋自己的棋")
        emit('error', {'message': '只能请求悔棋自己的棋'})
        return

    # 检查是否连续悔棋（上次悔棋的玩家不能连续悔棋）
    last_undo_player = game.get('last_undo_player')
    if last_undo_player == sid:
        print(f"玩家 {sid} 不能连续悔棋")
        emit('error', {'message': '不能连续悔棋'})
        return

    # 标记有悔棋请求
    game['undo_requested'] = True
    game['undo_requester_sid'] = sid

    # 通知对方有悔棋请求
    print(f"发送悔棋请求给玩家: {player_sid}")
    print(f"发送数据: {{'player': {current_player}, 'room_id': '{room_id}'}}")
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
    sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

    if room_id not in games:
        return

    game = games[room_id]

    # 斗地主和军棋不支持悔棋
    if game['game_type'] in ['doudizhu', 'army_chess', 'flip_army_chess']:
        return

    # 检查游戏是否结束
    if game['game_over']:
        return

    # 获取当前玩家（轮到的那一方）
    current_player = game['current_player']
    if game['game_type'] == 'chinese_chess':
        current_sid = chinese_chess.get_chinese_chess_current_player_sid(game)
    elif game['game_type'] == 'go':
        current_sid = go.get_go_current_player_sid(game)
    elif game['game_type'] == 'othello':
        current_sid = othello.get_othello_current_player_sid(game)
    elif game['game_type'] == 'chinese_checkers':
        # 跳棋：根据当前玩家编号获取对应的玩家SID
        current_player_index = (current_player - 1) % len(game['players'])
        current_player_info = game['players'][current_player_index]
        current_sid = current_player_info['sid']
    elif game['game_type'] == 'checkers':
        current_sid = game['red_player'] if current_player == 1 else game['blue_player']
    elif game['game_type'] == 'gobang':
        current_sid = gobang.get_gobang_current_player_sid(game)

    # 只有轮到的一方才能响应
    if sid != current_sid:
        return

    requester_sid = game.get('undo_requester_sid')

    # 如果同意悔棋，执行悔棋
    if approved:
        # 撤销最后一步棋
        if not game.get('moves'):
            return

        last_move = game['moves'].pop()

        if game['game_type'] == 'chinese_chess':
            chinese_chess.execute_chinese_chess_undo(game, last_move)
        elif game['game_type'] == 'go':
            # 围棋悔棋：清除最后一子
            row = last_move['row']
            col = last_move['col']
            game['board'][row][col] = 0
        elif game['game_type'] == 'othello':
            othello.execute_othello_undo(game, last_move)
        elif game['game_type'] == 'chinese_checkers':
            # 跳棋悔棋
            from_row = last_move['from_row']
            from_col = last_move['from_col']
            to_row = last_move['to_row']
            to_col = last_move['to_col']
            
            # 恢复棋子到原位置
            piece = game['board'][to_row][to_col]
            game['board'][from_row][from_col] = piece
            game['board'][to_row][to_col] = None
            
            # 恢复上一步路径
            path = last_move.get('path', [])
            if path:
                game['last_move_path'] = path
            else:
                game['last_move_path'] = [[from_row, from_col], [to_row, to_col]]
        elif game['game_type'] == 'international_chess':
            # 国际象棋悔棋
            from_row = last_move['from']['row']
            from_col = last_move['from']['col']
            to_row = last_move['to']['row']
            to_col = last_move['to']['col']
            # 恢复棋子到原位置
            game['board'][from_row][from_col] = game['board'][to_row][to_col]
            # 恢复被吃的棋子
            if last_move.get('captured') != 0:
                game['board'][to_row][to_col] = last_move['captured']
            else:
                game['board'][to_row][to_col] = 0
        elif game['game_type'] == 'gobang':
            gobang.execute_gobang_undo(game, last_move)

        # 切换回之前的玩家
        game['current_player'] = last_move['player']

        # 记录悔棋玩家（申请者），防止连续悔棋
        if requester_sid:
            game['last_undo_player'] = requester_sid

        # 广播悔棋信息
        undo_data = {
            'from_row': last_move.get('from_row'),
            'from_col': last_move.get('from_col'),
            'to_row': last_move.get('to_row'),
            'to_col': last_move.get('to_col'),
            'row': last_move.get('row'),
            'col': last_move.get('col'),
            'current_player': game['current_player']
        }
        # 只有被吃的棋子才添加 captured 字段
        if last_move.get('captured') is not None:
            if game['game_type'] == 'chinese_chess':
                undo_data['captured_name'] = last_move['captured']['name']
                undo_data['captured_type'] = last_move['captured']['type']
                undo_data['captured_color'] = last_move['captured']['color']
        socketio.emit('undo_move', undo_data, to=room_id)

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
    sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

    if room_id not in games:
        return

    game = games[room_id]

    # 检查游戏是否结束
    if game['game_over']:
        socketio.emit('error', {'message': '游戏已结束'}, to=sid)
        return

    # 获取当前玩家编号
    current_player = game['current_player']

    # 根据游戏类型获取对手 sid
    if game['game_type'] == 'chinese_chess':
        opponent_sid = chinese_chess.get_chinese_chess_opponent_sid(game, sid)
    elif game['game_type'] == 'army_chess':
        opponent_sid = army_chess_module.get_army_chess_opponent_sid(game, sid)
    elif game['game_type'] == 'flip_army_chess':
        opponent_sid = flip_army_chess_module.get_flip_army_chess_opponent_sid(game, sid)
    elif game['game_type'] == 'checkers':
        opponent_sid = game['red_player'] if current_player == 1 else game['blue_player']
    elif game['game_type'] == 'gobang':
        opponent_sid = gobang.get_gobang_opponent_sid(game, sid)
    elif game['game_type'] == 'othello':
        opponent_sid = othello.get_othello_opponent_sid(game, sid)
    elif game['game_type'] == 'go':
        opponent_sid = go.get_go_opponent_sid(game, sid)
    else:  # chess
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
    sid = request.sid  # pyright: ignore[reportAttributeAccessIssue]

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
        }, to=room_id)

        print(f"Draw approved in room {room_id}")
    else:
        print(f"Draw rejected in room {room_id}")


def _start_doudizhu_game(game, room_id):
    """开始斗地主游戏"""
    try:
        from games.doudizhu import create_doudizhu_deck, shuffle_deck, deal_cards

        # 创建并洗牌
        deck = shuffle_deck(create_doudizhu_deck())

        # 发牌
        player1_cards, player2_cards, player3_cards, landlord_cards = deal_cards(deck)

        # 保存到游戏数据
        game['player1_cards'] = player1_cards
        game['player2_cards'] = player2_cards
        game['player3_cards'] = player3_cards
        game['landlord_cards'] = landlord_cards
        game['landlord'] = None
        game['landlord_calls'] = {}
        game['last_played_cards'] = []
        game['last_played_player'] = None
        game['pass_count'] = 0

        # 分别发送手牌给每个玩家
        for i, player_sid in enumerate([game['player1'], game['player2'], game['player3']], 1):
            cards_key = f'player{i}_cards'
            if game[cards_key]:
                socketio.emit('cards_dealt', {
                    'my_cards': game[cards_key],
                    'player_number': i
                }, to=player_sid)

        socketio.emit('game_start', {
            'message': '游戏开始！请选择是否叫地主'
        }, to=room_id)
    except Exception as e:
        print(f"Error in _start_doudizhu_game: {e}")


if __name__ == '__main__':
    print("="*50)
    print("Online Game Server Starting")
    print("Supported Games: Gobang, Chinese Chess, Go, Othello, Army Chess, Dou Dizhu, Checkers")
    print("="*50)
    print(f"Async mode: {ASYNC_MODE}")
    print(f"Host: 0.0.0.0")
    print(f"Port: 5000")
    print("="*50)

    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)
