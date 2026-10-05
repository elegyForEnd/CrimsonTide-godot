"""STUN binding, authenticated signalling and dedicated fallback."""
import importlib.util
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import threading
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tide_server', ROOT / 'server/app.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
GODOT = Path(os.environ.get('GODOT', str(ROOT / 'Godot_v4.7.2-stable_win64_console.exe')))


class P2PTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.service = module.Service(self.temp.name, str(GODOT), ROOT,
                                      '127.0.0.1', 25140, 2)
        self.owner = self.service.session('owner', True)
        self.guest = self.service.session('guest', True)
        self.other = self.service.session('other', True)

    def tearDown(self):
        self.service.close()
        self.temp.cleanup()

    def call(self, method, route, token, body=None):
        return self.service.dispatch(method, route, body or {}, token, '127.0.0.1')

    def binding(self, transaction):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as peer:
            peer.bind(('127.0.0.1', 0))
            peer.settimeout(2)
            packet = struct.pack('!HHI', 1, 0, module.STUN_COOKIE) + bytes.fromhex(transaction)
            peer.sendto(packet, ('127.0.0.1', self.service.stun_port))
            response, _ = peer.recvfrom(1200)
            self.assertEqual(response[:4], struct.pack('!HH', 0x0101, 12))
            self.assertEqual(response[8:20], bytes.fromhex(transaction))
            self.assertEqual(response[20:24], struct.pack('!HH', 0x0020, 8))
            self.assertEqual(response[25], 1)
            mapped_port = struct.unpack('!H', response[26:28])[0] ^ 0x2112
            self.assertEqual(mapped_port, peer.getsockname()[1])
            endpoint = bytes(a ^ b for a, b in zip(response[28:32],
                                                    struct.pack('!I', module.STUN_COOKIE)))
            self.assertEqual(socket.inet_ntoa(endpoint), '127.0.0.1')
            return mapped_port

    def test_binding_and_signalling(self):
        created = self.call('POST', '/v1/p2p/rooms', self.owner)
        code = created['code']
        self.assertEqual(len(code), 6)
        self.assertEqual(created['stun_port'], self.service.stun_port)
        owner_port = self.binding(created['transaction'])
        self.call('PUT', f'/v1/p2p/rooms/{code}/candidate', self.owner,
                  {'local_port': 24872, 'local_ips': ['127.0.0.1', '192.168.1.2']})
        joined = self.call('POST', f'/v1/p2p/rooms/{code}/join', self.guest)
        guest_port = self.binding(joined['transaction'])
        self.call('PUT', f'/v1/p2p/rooms/{code}/candidate', self.guest,
                  {'local_port': guest_port, 'local_ips': ['127.0.0.1']})
        owner = self.call('GET', f'/v1/p2p/rooms/{code}', self.owner)
        guest = self.call('GET', f'/v1/p2p/rooms/{code}', self.guest)
        self.assertEqual(guest['owner']['endpoint']['port'], owner_port)
        self.assertEqual(owner['guests'][0]['endpoint']['port'], guest_port)
        self.assertEqual(owner['guests'][0]['ticket_hash'],
                         __import__('hashlib').sha256(joined['ticket'].encode()).hexdigest())
        with self.assertRaises(module.ApiError):
            self.call('GET', f'/v1/p2p/rooms/{code}', self.other)
        with self.assertRaises(module.ApiError):
            self.call('PUT', f'/v1/p2p/rooms/{code}/candidate', self.guest,
                      {'local_port': 9999, 'local_ips': ['8.8.8.8']})
        self.call('POST', f'/v1/p2p/rooms/{code}/leave', self.guest)
        self.assertEqual(self.call('GET', f'/v1/p2p/rooms/{code}', self.owner)['guests'], [])

    @unittest.skipUnless(GODOT.exists(), 'Godot required for dedicated fallback')
    def test_fallback_keeps_room_code(self):
        created = self.call('POST', '/v1/p2p/rooms', self.owner)
        code = created['code']
        self.call('POST', f'/v1/p2p/rooms/{code}/join', self.guest)
        guest_room = self.call('POST', f'/v1/p2p/rooms/{code}/fallback', self.guest)
        owner_room = self.call('POST', f'/v1/p2p/rooms/{code}/fallback', self.owner)
        self.assertEqual(guest_room['code'], code)
        self.assertEqual(owner_room['code'], code)
        self.assertEqual(guest_room['port'], owner_room['port'])
        self.assertEqual(self.call('GET', f'/v1/p2p/rooms/{code}', self.owner)['mode'], 'server')

    def test_started_room_cannot_migrate(self):
        created = self.call('POST', '/v1/p2p/rooms', self.owner)
        code = created['code']
        self.call('POST', f'/v1/p2p/rooms/{code}/join', self.guest)
        self.call('POST', f'/v1/p2p/rooms/{code}/started', self.owner)
        with self.assertRaises(module.ApiError) as raised:
            self.call('POST', f'/v1/p2p/rooms/{code}/fallback', self.guest)
        self.assertEqual(raised.exception.status, 409)

    def run_local_party(self, count=2, force_fallback=False, force_public=False,
                        fallback_after_connect=False, stun_hostname=False):
        if stun_hostname:
            self.service.public_host = 'localhost'
        http = module.ThreadingHTTPServer(('127.0.0.1', 0), module.Handler)
        http.service = self.service
        thread = threading.Thread(target=http.serve_forever, daemon=True)
        thread.start()
        code_file = Path(self.temp.name) / 'p2p-code.txt'
        host_log_path = Path(self.temp.name) / 'p2p-host.log'
        common = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
                  'tests/p2p_client.gd', '--']
        api = f'http://127.0.0.1:{http.server_port}'
        host_log = host_log_path.open('w', encoding='utf-8')
        guest_logs = []
        host = subprocess.Popen(common + ['--role=host', '--api=' + api,
                                         '--code_file=' + str(code_file),
                                         '--expected=' + str(count),
                                         '--expected_mode=' + ('SERVER' if force_fallback or fallback_after_connect else 'DIRECT')],
                                stdout=host_log, stderr=subprocess.STDOUT)
        guests = []
        try:
            deadline = time.monotonic() + 12
            while not code_file.exists() and host.poll() is None and time.monotonic() < deadline:
                time.sleep(.05)
            if not code_file.exists():
                self.fail('P2P host did not publish a code:\n' + host_log_path.read_text(encoding='utf-8'))
            code = code_file.read_text()
            for index in range(count - 1):
                log_path = Path(self.temp.name) / f'p2p-guest-{index}.log'
                log = log_path.open('w', encoding='utf-8')
                guest_logs.append((log, log_path))
                guest = subprocess.Popen(common + ['--role=guest', '--api=' + api,
                                                   '--code=' + code, '--expected=' + str(count),
                                                   '--expected_mode=' + ('SERVER' if force_fallback or fallback_after_connect else 'DIRECT'),
                                                   '--force_fallback=' + ('1' if force_fallback and index == 0 else '0'),
                                                   '--fallback_after_connect=' + ('1' if fallback_after_connect and index == 0 else '0'),
                                                   '--force_public=' + ('1' if force_public else '0')],
                                         stdout=log, stderr=subprocess.STDOUT)
                guests.append(guest)
            for guest in guests:
                guest.wait(timeout=35)
            host.wait(timeout=35)
            host_log.flush()
            host_output = host_log_path.read_text(encoding='utf-8')
            self.assertEqual(host.returncode, 0, host_output)
            mode = 'SERVER' if force_fallback or fallback_after_connect else 'DIRECT'
            self.assertIn(f'P2P HOST MODE {mode} PASS', host_output)
            for guest, (log, log_path) in zip(guests, guest_logs):
                log.flush()
                output = log_path.read_text(encoding='utf-8')
                self.assertEqual(guest.returncode, 0, output)
                self.assertIn(f'P2P GUEST MODE {mode} PASS', output)
        finally:
            for proc in [host] + guests:
                if proc and proc.poll() is None:
                    proc.kill()
                    proc.wait()
            host_log.close()
            for log, _ in guest_logs: log.close()
            http.shutdown()
            http.server_close()
            thread.join()

    @unittest.skipUnless(GODOT.exists(), 'Godot required for P2P integration')
    def test_local_two_process_direct(self):
        self.run_local_party()

    @unittest.skipUnless(GODOT.exists(), 'Godot required for STUN public candidate integration')
    def test_local_public_candidate(self):
        self.run_local_party(force_public=True)

    @unittest.skipUnless(GODOT.exists(), 'Godot required for STUN hostname integration')
    def test_stun_hostname(self):
        self.run_local_party(stun_hostname=True)

    @unittest.skipUnless(GODOT.exists(), 'Godot required for dedicated fallback')
    def test_local_two_process_fallback(self):
        self.run_local_party(force_fallback=True)

    @unittest.skipUnless(GODOT.exists(), 'Godot required for four-player P2P integration')
    def test_local_four_player_direct(self):
        self.run_local_party(count=4)

    @unittest.skipUnless(GODOT.exists(), 'Godot required for migration integration')
    def test_connected_party_fallback(self):
        self.run_local_party(count=3, fallback_after_connect=True)


if __name__ == '__main__':
    unittest.main()
