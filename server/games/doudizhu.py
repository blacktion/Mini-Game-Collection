"""
斗地主游戏逻辑 - 完整版
包含所有高级牌型验证（飞机、连对等）
"""

# 全局变量，由主程序设置
socketio = None
games = None


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

    # 连对(至少3对,不能有2和王)
    if n >= 6 and n % 2 == 0:
        if max(ranks) <= 14:  # 不能有2和王
            # 检查是否每相邻两张都相等，且连续
            pairs = n // 2
            is_consecutive_pairs = True
            for i in range(pairs):
                idx = i * 2
                if ranks[idx] != ranks[idx + 1]:
                    is_consecutive_pairs = False
                    break
                if i > 0 and ranks[idx] != ranks[idx - 2] + 1:
                    is_consecutive_pairs = False
                    break
            if is_consecutive_pairs:
                return 'consecutive_pairs', ranks[-1]

    # 飞机不带(至少2个三张,不能有2和王)
    if n >= 6 and n % 3 == 0:
        if max(ranks) <= 14:  # 不能有2和王
            triples = n // 3
            # 检查是否都是三张且连续
            triple_ranks = []
            i = 0
            while i < n:
                if ranks[i] == ranks[i + 1] == ranks[i + 2]:
                    triple_ranks.append(ranks[i])
                    i += 3
                else:
                    break
            if len(triple_ranks) == triples and all(triple_ranks[i] == triple_ranks[i - 1] + 1 for i in range(1, triples)):
                return 'airplane', triple_ranks[-1]

    # 飞机带单(至少2个三张带2单,不能有2和王)
    if n >= 8 and n % 4 == 0:
        if max(ranks) <= 14:  # 不能有2和王
            triples = n // 4
            # 检查是否都是三张且连续，剩下的是单张
            # 统计每个rank的数量
            rank_counts = {}
            for r in ranks:
                rank_counts[r] = rank_counts.get(r, 0) + 1
            # 找出有三张的rank
            triple_ranks = sorted([r for r, cnt in rank_counts.items() if cnt == 3])
            if len(triple_ranks) == triples and all(triple_ranks[i] == triple_ranks[i - 1] + 1 for i in range(1, triples)):
                return 'airplane_single', triple_ranks[-1]

    # 飞机带对(至少2个三张带2对,不能有2和王)
    if n >= 10 and n % 5 == 0:
        if max(ranks) <= 14:  # 不能有2和王
            triples = n // 5
            # 检查是否都是三张且连续，剩下的是对子
            rank_counts = {}
            for r in ranks:
                rank_counts[r] = rank_counts.get(r, 0) + 1
            # 找出有三张的rank
            triple_ranks = sorted([r for r, cnt in rank_counts.items() if cnt == 3])
            # 找出有对子的rank
            pair_ranks = [r for r, cnt in rank_counts.items() if cnt == 2]
            if len(triple_ranks) == triples and len(pair_ranks) == triples:
                if all(triple_ranks[i] == triple_ranks[i - 1] + 1 for i in range(1, triples)):
                    return 'airplane_pair', triple_ranks[-1]

    # 四带二单
    if n == 6:
        # 找出四张的rank
        for r in set(ranks):
            if ranks.count(r) == 4:
                return 'four_two_single', r

    # 四带二对
    if n == 8:
        # 找出四张的rank
        for r in set(ranks):
            if ranks.count(r) == 4:
                # 检查剩下两张是否是对子
                remaining = [x for x in ranks if x != r]
                if len(remaining) == 2 and remaining[0] == remaining[1]:
                    return 'four_two_pair', r

    return None, 0


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

    # 炸弹可以炸任何牌（除王炸）
    if current_type == 'bomb' and last_type != 'bomb' and last_type != 'rocket':
        return True, current_type

    # 王炸最大
    if current_type == 'rocket':
        return True, current_type

    # 同类型比较
    if current_type == last_type and len(cards) == len(last_cards):
        # 四带二需要比较四张的rank
        if current_type in ['four_two_single', 'four_two_pair']:
            if current_rank > last_rank:
                return True, current_type
        # 其他牌型直接比较rank
        elif current_rank > last_rank:
            return True, current_type

    return False, "上家的牌更大或牌型不匹配"


def check_game_over(cards):
    """判断游戏是否结束(牌出完)"""
    return len(cards) == 0


def handle_choose_landlord(games, room_id, sid, data, socketio, emit):
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
            import random
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


def handle_play_cards(games, room_id, sid, data, socketio, emit):
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


def handle_pass_turn(games, room_id, sid, data, socketio, emit):
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
