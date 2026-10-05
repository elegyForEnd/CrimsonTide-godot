"""No shell interpolation: container configuration becomes explicit API CLI args."""
import os
from pathlib import Path
import sys


def main():
    host = os.environ.get('PUBLIC_HOST', 'example.com').strip()
    if not host or any(char in host for char in '/: \t\r\n'):
        raise SystemExit('PUBLIC_HOST must be a DNS name or IPv4 address, without a scheme or port.')
    try:
        start = int(os.environ.get('ROOM_PORT_START', '24900'))
        rooms = int(os.environ.get('MAX_ROOMS', '16'))
        stun_port = int(os.environ.get('STUN_PORT', '3478'))
    except ValueError:
        raise SystemExit('ROOM_PORT_START, MAX_ROOMS and STUN_PORT must be integers.')
    if not (1024 <= start <= 65535 and 1 <= rooms <= 256 and start + rooms <= 65536
            and 1024 <= stun_port <= 65535 and stun_port not in range(start, start + rooms)):
        raise SystemExit('Invalid UDP port range or room count (1-256).')
    project = Path(__file__).resolve().parents[1]
    args = [sys.executable, str(project / 'server/app.py'),
            '--bind', '0.0.0.0', '--port', '8080', '--data', '/data',
            '--project', str(project), '--godot', '/usr/local/bin/godot',
            '--public-host', host, '--room-port-start', str(start), '--max-rooms', str(rooms),
            '--stun-port', str(stun_port)]
    os.execv(sys.executable, args + sys.argv[1:])


if __name__ == '__main__':
    main()
