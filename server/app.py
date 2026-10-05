"""Crimson Tide account/cloud API and isolated Godot room supervisor (Python 3.10+)."""
import argparse
import hashlib
import hmac
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import socket
import sqlite3
import struct
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class ApiError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


def atomic_json(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value), encoding='utf-8')
    tmp.replace(path)


STUN_COOKIE = 0x2112A442


class Service:
    def __init__(self, data, godot, project, public_host, port_start=24900, room_limit=16,
                 stun_port=0, stun_bind='0.0.0.0'):
        self.data = Path(data).resolve()
        self.data.mkdir(parents=True, exist_ok=True)
        self.godot, self.project, self.public_host = godot, str(Path(project).resolve()), public_host
        self.port_start, self.room_limit = port_start, room_limit
        self.lock = threading.RLock()
        self.rooms, self.rates, self.p2p_rooms, self.stun_ids = {}, {}, {}, {}
        self.stun_stop = threading.Event()
        self.stun_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.stun_socket.bind((stun_bind, stun_port))
        self.stun_socket.settimeout(.2)
        self.stun_port = self.stun_socket.getsockname()[1]
        self.stun_thread = threading.Thread(target=self.stun_loop, daemon=True)
        self.stun_thread.start()
        self.db = sqlite3.connect(self.data / 'accounts.sqlite3', check_same_thread=False)
        self.db.executescript('''
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, username TEXT UNIQUE, salt BLOB, password BLOB);
            CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, user TEXT, expires INTEGER, guest INTEGER);
            CREATE TABLE IF NOT EXISTS profiles(user TEXT PRIMARY KEY, revision INTEGER, data TEXT);
        ''')
        self.db.commit()

    def close(self):
        self.stun_stop.set()
        self.stun_socket.close()
        self.stun_thread.join(timeout=2)
        for room in self.rooms.values():
            room['process'].terminate()
        for room in self.rooms.values():
            try:
                room['process'].wait(timeout=5)
            except subprocess.TimeoutExpired:
                room['process'].kill()
                room['process'].wait()
        self.db.close()

    def stun_loop(self):
        while not self.stun_stop.is_set():
            try:
                packet, source = self.stun_socket.recvfrom(1200)
            except (socket.timeout, OSError):
                continue
            if (len(packet) < 20 or packet[:2] != b'\x00\x01'
                    or packet[4:8] != struct.pack('!I', STUN_COOKIE)):
                continue
            length = struct.unpack('!H', packet[2:4])[0]
            if length % 4 or length + 20 > len(packet):
                continue
            transaction = packet[8:20]
            with self.lock:
                identity = self.stun_ids.get(transaction)
                room = self.p2p_rooms.get(identity[0]) if identity else None
                member = room['members'].get(identity[1]) if room else None
                if not member or room['mode'] != 'p2p':
                    continue
                member['endpoint'] = {'host': source[0], 'port': source[1]}
                member['observed_at'] = time.time()
            # RFC 8489 Binding Success with XOR-MAPPED-ADDRESS (IPv4).
            xor_port = source[1] ^ (STUN_COOKIE >> 16)
            xor_ip = bytes(a ^ b for a, b in zip(socket.inet_aton(source[0]),
                                                 struct.pack('!I', STUN_COOKIE)))
            response = (struct.pack('!HHI', 0x0101, 12, STUN_COOKIE) + transaction
                        + struct.pack('!HHBBH', 0x0020, 8, 0, 1, xor_port) + xor_ip)
            try:
                self.stun_socket.sendto(response, source)
            except OSError:
                pass

    def limit(self, ip):
        now = time.time()
        self.rates = {key: value for key, value in self.rates.items() if value[0] > now - 60}
        start, count = self.rates.get(ip, (now, 0))
        if count >= 20:
            raise ApiError(429, '请求过于频繁，请一分钟后再试。')
        self.rates[ip] = (start, count + 1)

    def session(self, user, guest):
        token = secrets.token_urlsafe(32)
        self.db.execute('DELETE FROM sessions WHERE expires < ?', (time.time(),))
        self.db.execute('INSERT INTO sessions VALUES(?,?,?,?)',
                        (hashlib.sha256(token.encode()).hexdigest(), user, int(time.time()) + 86400, guest))
        self.db.commit()
        return token

    def identity(self, token):
        row = self.db.execute('SELECT user,guest FROM sessions WHERE hash=? AND expires>?',
                              (hashlib.sha256(token.encode()).hexdigest(), time.time())).fetchone()
        if not row:
            raise ApiError(401, '登录已过期，请重新登录。')
        return row

    def prune(self):
        for code, room in list(self.rooms.items()):
            if room['process'].poll() is not None:
                del self.rooms[code]
        now = time.time()
        for code, room in list(self.p2p_rooms.items()):
            owner = room['members'].get(room['owner'])
            if not owner or owner['last_seen'] < now - 120:
                self.remove_p2p_room(code)
                continue
            for user, member in list(room['members'].items()):
                if user != room['owner'] and member['last_seen'] < now - 120:
                    self.stun_ids.pop(member['transaction'], None)
                    del room['members'][user]

    def remove_p2p_room(self, code):
        room = self.p2p_rooms.pop(code, None)
        if room:
            for member in room['members'].values():
                self.stun_ids.pop(member['transaction'], None)

    def p2p_member(self, room, user):
        transaction = secrets.token_bytes(12)
        while transaction in self.stun_ids:
            transaction = secrets.token_bytes(12)
        member = {'id': secrets.token_hex(4), 'transaction': transaction,
                  'ticket': secrets.token_urlsafe(24), 'endpoint': None,
                  'observed_at': 0, 'local_ips': [], 'local_port': 0,
                  'last_seen': time.time(), 'host_ready': False}
        room['members'][user] = member
        self.stun_ids[transaction] = (room['code'], user)
        return member

    def p2p_public_member(self, member, include_ticket=False):
        endpoint = member['endpoint'] if member['observed_at'] > time.time() - 30 else None
        result = {'id': member['id'], 'endpoint': endpoint,
                  'local_ips': member['local_ips'], 'local_port': member['local_port']}
        if include_ticket:
            result['ticket_hash'] = hashlib.sha256(member['ticket'].encode()).hexdigest()
        return result

    def p2p_access(self, code, user):
        room = self.p2p_rooms.get(code)
        if not room:
            raise ApiError(404, 'P2P 房间不存在或已经关闭。')
        member = room['members'].get(user)
        if not member:
            raise ApiError(403, '你尚未加入该房间。')
        member['last_seen'] = time.time()
        return room, member

    def p2p_state(self, room, user):
        owner = room['members'][room['owner']]
        result = {'code': room['code'], 'mode': room['mode'],
                  'self_id': room['members'][user]['id'],
                  'owner': self.p2p_public_member(owner), 'started': room['started'],
                  'host_ready': room['members'][user]['host_ready']}
        if user == room['owner']:
            for peer, member in room['members'].items():
                if peer != user:
                    member['host_ready'] = True
            result['guests'] = [self.p2p_public_member(member, True)
                                for peer, member in room['members'].items() if peer != user]
        if room['mode'] == 'server':
            worker = self.rooms.get(room['code'])
            result['server_ready'] = bool(worker and self.room_state(worker).get('players', 0) > 0)
            result['server_failed'] = worker is None
        return result

    def dedicated_room(self, code, owner):
        used = {room['port'] for room in self.rooms.values()}
        port = next((p for p in range(self.port_start, self.port_start + self.room_limit) if p not in used), None)
        if port is None:
            raise ApiError(503, '服务器房间已满，请稍后再试。')
        path = self.data / ('room-' + code + '-' + secrets.token_hex(4))
        path.mkdir()
        atomic_json(path / 'tickets.json', {})
        command = [self.godot, '--headless', '--path', self.project, '--script',
                   'res://server/room.gd', '--log-file', str(path / 'godot.log'), '--',
                   '--port=' + str(port), '--room-dir=' + str(path)]
        try:
            with (path / 'worker.log').open('wb') as log:
                proc = subprocess.Popen(command, stdout=log, stderr=log,
                                        creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        except OSError:
            raise ApiError(503, '房间进程启动失败，请检查服务器 Godot 配置。')
        room = {'process': proc, 'path': path, 'port': port, 'owner': owner}
        for _ in range(100):
            if (path / 'state.json').exists() or proc.poll() is not None:
                break
            time.sleep(.05)
        if proc.poll() is not None or not (path / 'state.json').exists():
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=5)
            raise ApiError(503, '房间启动失败，请查看 worker.log。')
        self.rooms[code] = room
        return room

    def room_state(self, room):
        try:
            return json.loads((room['path'] / 'state.json').read_text(encoding='utf-8'))
        except (OSError, ValueError):
            return {'players': 0, 'running': False}

    def ticket(self, code, room, user):
        state = self.room_state(room)
        if state.get('running') or state.get('players', 0) >= 4:
            raise ApiError(409, '房间已满或已经出发。')
        token = secrets.token_urlsafe(32)
        path = room['path'] / 'tickets.json'
        tickets = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
        tickets = {key: value for key, value in tickets.items()
                   if value['expires'] > time.time() and value['user'] != user}
        tickets[hashlib.sha256(token.encode()).hexdigest()] = {
            'user': user, 'owner': user == room['owner'], 'expires': int(time.time()) + 45}
        atomic_json(path, tickets)
        return {'code': code, 'host': self.public_host, 'port': room['port'], 'ticket': token}

    def dispatch(self, method, route, body, token, ip):
        with self.lock:
            return self._dispatch(method, route, body, token, ip)

    def _dispatch(self, method, route, body, token, ip):
        if route == '/health' and method == 'GET':
            return {'status': 'ok'}
        if route in ('/v1/auth/register', '/v1/auth/login', '/v1/auth/guest') and method == 'POST':
            self.limit(ip)
            if route == '/v1/auth/guest':
                return {'token': self.session('guest-' + secrets.token_hex(16), True)}
            if route not in ('/v1/auth/register', '/v1/auth/login'):
                raise ApiError(404, '接口不存在。')
            username, password = body.get('username'), body.get('password')
            if not isinstance(username, str) or not re.fullmatch(r'[A-Za-z0-9_]{3,24}', username):
                raise ApiError(400, '账号需为 3–24 位英文字母、数字或下划线。')
            if not isinstance(password, str) or not 8 <= len(password) <= 128:
                raise ApiError(400, '密码需为 8–128 个字符。')
            username = username.lower()
            row = self.db.execute('SELECT id,salt,password FROM users WHERE username=?', (username,)).fetchone()
            if route.endswith('/register'):
                if row:
                    raise ApiError(409, '该账号已存在。')
                user, salt = secrets.token_hex(16), secrets.token_bytes(16)
                digest = hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1)
                self.db.execute('INSERT INTO users VALUES(?,?,?,?)', (user, username, salt, digest))
                self.db.commit()
            else:
                salt = row[1] if row else bytes(16)
                digest = hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1)
                if not row or not hmac.compare_digest(row[2], digest):
                    raise ApiError(401, '账号或密码错误。')
                user = row[0]
            return {'token': self.session(user, False), 'user': {'id': user, 'username': username}}
        user, guest = self.identity(token)
        if route == '/v1/auth/logout' and method == 'POST':
            self.db.execute('DELETE FROM sessions WHERE hash=?', (hashlib.sha256(token.encode()).hexdigest(),))
            self.db.commit()
            return {}
        if route == '/v1/profile':
            if guest:
                raise ApiError(403, '游客仅使用本地存档，注册登录后可同步云端。')
            row = self.db.execute('SELECT revision,data FROM profiles WHERE user=?', (user,)).fetchone()
            revision = row[0] if row else 0
            if method == 'GET':
                return {'revision': revision, 'data': json.loads(row[1]) if row else None}
            if method == 'PUT':
                if type(body.get('revision')) is not int or body['revision'] != revision:
                    raise ApiError(409, '云端已有其他设备的进度。请重新选择上传本地或使用云端。')
                data = body.get('data')
                validate_profile(data)
                self.db.execute('INSERT OR REPLACE INTO profiles VALUES(?,?,?)',
                                (user, revision + 1, json.dumps(data)))
                self.db.commit()
                return {'revision': revision + 1}
        self.prune()
        if route == '/v1/p2p/rooms' and method == 'POST':
            self.limit(ip)
            if any(room['owner'] == user for room in self.rooms.values()):
                raise ApiError(409, '你已有服务器房间。')
            for old_code, old_room in list(self.p2p_rooms.items()):
                if old_room['owner'] == user:
                    self.remove_p2p_room(old_code)
            code = secrets.token_hex(3).upper()
            while code in self.rooms or code in self.p2p_rooms:
                code = secrets.token_hex(3).upper()
            room = {'code': code, 'owner': user, 'members': {},
                    'mode': 'p2p', 'started': False}
            self.p2p_rooms[code] = room
            member = self.p2p_member(room, user)
            return {'code': code, 'stun_host': self.public_host, 'stun_port': self.stun_port,
                    'transaction': member['transaction'].hex(), 'ticket': member['ticket']}
        if route.startswith('/v1/p2p/rooms/'):
            parts = route.split('/')
            if len(parts) not in (5, 6):
                raise ApiError(404, '接口不存在。')
            code = parts[4].upper()
            action = parts[5] if len(parts) == 6 else ''
            if action == 'join' and method == 'POST':
                self.limit(ip)
                room = self.p2p_rooms.get(code)
                if not room:
                    raise ApiError(404, 'P2P 房间不存在或已经关闭。')
                if room['mode'] != 'p2p' or room['started']:
                    raise ApiError(409, '房间已切换服务器或已经出发。')
                member = room['members'].get(user)
                if not member:
                    if len(room['members']) >= 4:
                        raise ApiError(409, '房间已满。')
                    member = self.p2p_member(room, user)
                member['last_seen'] = time.time()
                return {'code': code, 'stun_host': self.public_host, 'stun_port': self.stun_port,
                        'transaction': member['transaction'].hex(), 'ticket': member['ticket']}
            room, member = self.p2p_access(code, user)
            if not action and method == 'GET':
                return self.p2p_state(room, user)
            if action == 'candidate' and method == 'PUT':
                port = body.get('local_port')
                addresses = body.get('local_ips')
                if (type(port) is not int or not 1 <= port <= 65535
                        or not isinstance(addresses, list) or len(addresses) > 8):
                    raise ApiError(400, '无效的本地 UDP 地址。')
                valid = []
                for address in addresses:
                    try:
                        parsed = ipaddress.ip_address(address)
                    except (ValueError, TypeError):
                        raise ApiError(400, '无效的本地 IP 地址。') from None
                    if not isinstance(parsed, ipaddress.IPv4Address) or not parsed.is_private:
                        raise ApiError(400, '只允许局域网 IPv4 地址。')
                    valid.append(str(parsed))
                member['local_port'] = port
                member['local_ips'] = list(dict.fromkeys(valid))
                return self.p2p_state(room, user)
            if action == 'started' and method == 'POST':
                if user != room['owner'] or room['mode'] != 'p2p':
                    raise ApiError(403, '只有 P2P 房主可以出发。')
                room['started'] = True
                return self.p2p_state(room, user)
            if action == 'fallback' and method == 'POST':
                self.limit(ip)
                if room['started']:
                    raise ApiError(409, '已出发的 P2P 对局不能迁移。')
                if room['mode'] == 'p2p':
                    self.dedicated_room(code, room['owner'])
                    room['mode'] = 'server'
                worker = self.rooms.get(code)
                if not worker:
                    raise ApiError(503, '服务器房间暂不可用。')
                return self.ticket(code, worker, user)
            if action == 'close' and method == 'POST':
                if user != room['owner']:
                    raise ApiError(403, '只有房主可以关闭房间。')
                self.remove_p2p_room(code)
                return {}
            if action == 'leave' and method == 'POST':
                if user == room['owner']:
                    raise ApiError(403, '房主应关闭房间。')
                self.stun_ids.pop(member['transaction'], None)
                del room['members'][user]
                return {}
            raise ApiError(404, '接口不存在。')
        if route == '/v1/rooms' and method == 'POST':
            self.limit(ip)
            if any(room['owner'] == user for room in self.rooms.values()):
                raise ApiError(409, '你已有房间，请加入原房间或等待空房间回收。')
            code = secrets.token_hex(3).upper()
            while code in self.rooms or code in self.p2p_rooms:
                code = secrets.token_hex(3).upper()
            room = self.dedicated_room(code, user)
            return self.ticket(code, room, user)
        if route.startswith('/v1/rooms/') and route.endswith('/join') and method == 'POST':
            self.limit(ip)
            code = route.split('/')[3].upper()
            room = self.rooms.get(code)
            if not room:
                raise ApiError(404, '房间不存在或已经关闭。')
            return self.ticket(code, room, user)
        raise ApiError(404, '接口不存在。')


def validate_profile(data):
    if not isinstance(data, dict) or data.get('version') != 1:
        raise ApiError(400, '存档格式错误。')
    for key in ('coins', 'xp', 'runs', 'extracts', 'hero', 'gear', 'best'):
        value = data.get(key)
        if type(value) not in (int, float) or not 0 <= value <= 2147483647 or int(value) != value:
            raise ApiError(400, '存档数值错误：' + key)
    if data['hero'] > 2 or data['gear'] > 2:
        raise ApiError(400, '角色或装备无效。')
    talents = data.get('talents')
    if not isinstance(talents, list) or len(talents) != 3 or any(type(x) not in (int, float) or not 0 <= x <= 5 or int(x) != x for x in talents):
        raise ApiError(400, '天赋格式错误。')
    attributes = data.get('attributes', {})
    keys = ('vigor', 'mind', 'endurance', 'strength', 'dexterity', 'intelligence', 'arcane')
    if not isinstance(attributes, dict) or any(key not in keys for key in attributes):
        raise ApiError(400, '属性格式错误。')
    spent = 0
    for key in keys:
        value = attributes.get(key, 10)
        if type(value) not in (int, float) or not 10 <= value <= 99 or int(value) != value:
            raise ApiError(400, '属性数值错误：' + key)
        spent += int(value) - 10
    if spent > 5 + int(data['xp']) // 180:
        raise ApiError(400, '属性点超出等级预算。')
    if not isinstance(data.get('pocket'), dict) or not isinstance(data.get('bags'), list):
        raise ApiError(400, '背包格式错误。')
    if not isinstance(data.get('name'), str) or len(data['name']) > 64:
        raise ApiError(400, '代号格式错误。')
    if len(data['bags']) > 100:
        raise ApiError(400, '背包数量超出限制。')
    for container in [data['pocket']] + data['bags']:
        if not isinstance(container, dict) or not isinstance(container.get('items', []), list):
            raise ApiError(400, '容器格式错误。')
        if len(container.get('items', [])) > 100:
            raise ApiError(400, '容器物品数量超出限制。')
        for item in container.get('items', []):
            if not isinstance(item, dict) or not isinstance(item.get('kind'), str):
                raise ApiError(400, '物品格式错误。')
            for key in ('x', 'y', 'count', 'weapon', 'gear', 'tier'):
                if key in item and (type(item[key]) not in (int, float) or not 0 <= item[key] <= 2147483647 or int(item[key]) != item[key]):
                    raise ApiError(400, '物品数值错误。')


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(15)

    def log_message(self, fmt, *args):
        # Never log request bodies or bearer tokens.
        pass

    def do_GET(self):
        self.handle_api()

    def do_POST(self):
        self.handle_api()

    def do_PUT(self):
        self.handle_api()

    def handle_api(self):
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 <= size <= 262144:
                raise ApiError(413, '请求内容过大。')
            body = json.loads(self.rfile.read(size)) if size else {}
            if not isinstance(body, dict):
                raise ApiError(400, '请求必须是 JSON 对象。')
            token = self.headers.get('Authorization', '').removeprefix('Bearer ')
            result = self.server.service.dispatch(self.command, self.path, body, token, self.client_address[0])
            status = 200
        except ApiError as exc:
            status, result = exc.status, {'error': exc.message}
        except (ValueError, UnicodeError):
            status, result = 400, {'error': '无效的 JSON 请求。'}
        except Exception:
            import traceback
            traceback.print_exc()
            status, result = 500, {'error': '服务器内部错误。'}
        payload = json.dumps(result, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(payload)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--data', default='server/data')
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument('--public-host', default='example.com')
    parser.add_argument('--room-port-start', type=int, default=24900)
    parser.add_argument('--max-rooms', type=int, default=16)
    parser.add_argument('--stun-port', type=int, default=3478)
    args = parser.parse_args()
    service = Service(args.data, args.godot, args.project, args.public_host,
                      args.room_port_start, args.max_rooms, args.stun_port)
    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    server.service = service
    print(f'Crimson Tide API listening on {args.bind}:{args.port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        service.close()


if __name__ == '__main__':
    main()
