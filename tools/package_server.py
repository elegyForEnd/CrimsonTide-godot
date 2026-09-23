"""Build/export a self-contained Linux Docker deployment bundle, without publishing."""
import argparse
import gzip
import hashlib
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ['crimson-tide-server:1.0.1', 'caddy:2.10-alpine']


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--skip-pull', action='store_true')
    args = parser.parse_args()
    if not args.skip_build:
        run('docker', 'build', '--platform', 'linux/amd64', '--target', 'runtime', '-t', IMAGES[0], '.')
    if not args.skip_pull:
        run('docker', 'pull', '--platform', 'linux/amd64', IMAGES[1])
    folder = ROOT / 'build' / 'crimson-tide-docker'
    (folder / 'server').mkdir(parents=True, exist_ok=True)
    compose = (ROOT / 'compose.yaml').read_text(encoding='utf-8')
    # The deployment bundle contains images, not a build context.
    compose = compose.replace('    build:\n      context: .\n      target: runtime\n', '')
    (folder / 'compose.yaml').write_text(compose, encoding='utf-8', newline='\n')
    shutil.copyfile(ROOT / '.env.example', folder / '.env.example')
    shutil.copyfile(ROOT / 'server/Caddyfile.docker', folder / 'server/Caddyfile.docker')
    shutil.copyfile(ROOT / 'server/DOCKER.md', folder / 'README.md')
    archive = folder / 'images-linux-amd64.tar.gz'
    print('Exporting both Linux/amd64 images...', flush=True)
    with gzip.open(archive, 'wb', compresslevel=3) as target:
        with subprocess.Popen(['docker', 'image', 'save', '--platform', 'linux/amd64', *IMAGES], stdout=subprocess.PIPE) as proc:
            shutil.copyfileobj(proc.stdout, target, 1024 * 1024)
            if proc.wait() != 0:
                raise SystemExit('docker save failed')
    names = ['images-linux-amd64.tar.gz', 'compose.yaml', '.env.example', 'server/Caddyfile.docker', 'README.md']
    checksums = []
    for name in names:
        digest = hashlib.sha256()
        with (folder / name).open('rb') as file:
            for block in iter(lambda: file.read(1024 * 1024), b''):
                digest.update(block)
        checksums.append(digest.hexdigest() + '  ' + name)
    (folder / 'SHA256SUMS').write_text('\n'.join(checksums) + '\n', encoding='utf-8', newline='\n')
    bundle = ROOT / 'build' / 'crimson-tide-docker-linux-amd64.zip'
    with zipfile.ZipFile(bundle, 'w', compression=zipfile.ZIP_STORED) as zip_file:
        for name in names + ['SHA256SUMS']:
            zip_file.write(folder / name, name)
    print(f'Ready: {bundle} ({bundle.stat().st_size / 1024**2:.1f} MiB)', flush=True)


if __name__ == '__main__':
    main()
