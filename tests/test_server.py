"""Run with: python -m unittest tests/test_server.py -v (or this file directly)."""
import importlib.util
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tide_server', ROOT / 'server/app.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
GODOT = os.environ.get('GODOT', str(ROOT / 'Godot_v4.7.2-stable_win64_console.exe'))


class ServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.service = module.Service(cls.temp.name, GODOT, ROOT, '127.0.0.1', 25120, 4)
        cls.http = module.ThreadingHTTPServer(('127.0.0.1', 0), module.Handler)
        cls.http.service = cls.service
        cls.thread = threading.Thread(target=cls.http.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = 'http://127.0.0.1:' + str(cls.http.server_port)

    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown()
        cls.http.server_close()
        cls.thread.join()
        cls.service.close()
        cls.temp.cleanup()

    def call(self, route, method='GET', body=None, token='', expected=200):
        data = json.dumps(body or {}).encode() if method != 'GET' else None
        request = Request(self.base + route, data=data, method=method,
                          headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token})
        try:
            response = urlopen(request, timeout=15)
        except HTTPError as error:
            response = error
        with response:
            self.assertEqual(response.status, expected, response.read() if response.status != expected else '')
            return json.load(response)

    def test_01_accounts_and_cloud(self):
        self.call('/v1/profile', expected=401)
        account = self.call('/v1/auth/register', 'POST', {'username': 'watcher', 'password': 'password123'})
        token = account['token']
        self.call('/v1/auth/register', 'POST', {'username': 'WATCHER', 'password': 'password123'}, expected=409)
        self.call('/v1/auth/login', 'POST', {'username': 'watcher', 'password': 'wrong-password'}, expected=401)
        login = self.call('/v1/auth/login', 'POST', {'username': 'WATCHER', 'password': 'password123'})
        self.assertEqual(account['user'], login['user'])
        profile = {'version': 1, 'name': '守夜人', 'coins': 987, 'xp': 44, 'runs': 3,
                   'extracts': 2, 'hero': 0, 'gear': 0, 'best': 9, 'talents': [0, 1, 2],
                   'pocket': {'items': []}, 'bags': []}
        self.assertIsNone(self.call('/v1/profile', token=token)['data'])
        self.call('/v1/profile', 'PUT', {'revision': 0, 'data': profile}, token)
        self.assertEqual(self.call('/v1/profile', token=login['token'])['data'], profile)
        self.call('/v1/profile', 'PUT', {'revision': 0, 'data': profile}, token, expected=409)
        self.call('/v1/profile', 'PUT', {'revision': 1, 'data': {}}, token, expected=400)
        self.call('/v1/profile', 'PUT', {'revision': 1, 'data': dict(profile, coins=-1)}, token, expected=400)
        guest = self.call('/v1/auth/guest', 'POST')['token']
        self.call('/v1/profile', token=guest, expected=403)
        other = self.call('/v1/auth/register', 'POST', {'username': 'another', 'password': 'password123'})
        self.assertIsNone(self.call('/v1/profile', token=other['token'])['data'])
        self.call('/v1/auth/logout', 'POST', token=token)
        self.call('/v1/profile', token=token, expected=401)
        self.assertEqual(self.call('/v1/profile', token=login['token'])['revision'], 1)
        stored = self.service.db.execute('SELECT password FROM users WHERE username="watcher"').fetchone()[0]
        self.assertNotEqual(stored, b'password123')

    @unittest.skipUnless(Path(GODOT).exists(), 'Set GODOT to the Godot executable for real room integration')
    def test_02_real_four_player_room(self):
        self.service.rates.clear()
        tokens = [self.call('/v1/auth/guest', 'POST')['token'] for _ in range(4)]
        room = self.call('/v1/rooms', 'POST', token=tokens[0])
        self.assertEqual(len(room['code']), 6)
        processes = []
        def client(descriptor, role):
            path = Path(self.temp.name) / f'client-{len(processes)}.json'
            path.write_text(json.dumps(descriptor), encoding='utf-8')
            proc = subprocess.Popen([GODOT, '--headless', '--path', str(ROOT), '--script',
                                     'tests/server_client.gd', '--log-file', str(path.with_suffix('.log')), '--', str(path), role],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8')
            processes.append(proc)
            return proc
        try:
            invalid = client(dict(room, ticket='invalid'), 'invalid')
            output, _ = invalid.communicate(timeout=15)
            self.assertEqual(invalid.returncode, 0, output)
            self.assertIn('INVALID TICKET: PASS', output)
            client(room, 'owner')
            time.sleep(1)
            for token in tokens[1:]:
                descriptor = self.call('/v1/rooms/' + room['code'] + '/join', 'POST', token=token)
                client(descriptor, 'member')
            def collect(proc):
                output, _ = proc.communicate(timeout=30)
                return proc.returncode, output
            with ThreadPoolExecutor(max_workers=4) as pool:
                outcomes = list(pool.map(collect, processes[1:]))
            for exit_code, output in outcomes:
                self.assertEqual(exit_code, 0, output + (self.service.rooms[room['code']]['path'] / 'worker.log').read_text(encoding='utf-8'))
                self.assertIn('PASS', output)
                self.assertNotIn('SCRIPT ERROR', output)
                print(output.strip())
            log = (self.service.rooms[room['code']]['path'] / 'worker.log').read_text(encoding='utf-8')
            self.assertNotIn('SCRIPT ERROR', log)
            self.call('/v1/rooms/FFFFFF/join', 'POST', token=tokens[0], expected=404)
        finally:
            for proc in processes:
                if proc.poll() is None:
                    proc.kill()
                    proc.communicate()

    @unittest.skipUnless(Path(GODOT).exists(), 'Godot required')
    def test_03_client_ui_cloud(self):
        self.service.rates.clear()
        result = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--script',
                                 'tests/online_ui.gd', '--log-file', str(Path(self.temp.name) / 'ui.log'), '--', self.base],
                                capture_output=True, text=True, encoding='utf-8', timeout=35)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('ONLINE UI + CLOUD: PASS', result.stdout)
        self.assertNotIn('SCRIPT ERROR', result.stderr)
        print(result.stdout.strip())


if __name__ == '__main__':
    unittest.main(verbosity=2)
