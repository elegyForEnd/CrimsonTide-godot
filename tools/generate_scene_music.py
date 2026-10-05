"""Resumable Suno soundtrack: submit, collect, master. Credentials stay in env."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess

import numpy as np
import requests

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'build/scene-music-source'
OUT = ROOT / 'assets/audio/music'
PLAN = ROOT / 'resources/scene_music_plan.json'
BASE = 'https://api.apilio.ai/suno'
RATE = 44100


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)


def process(name, spec, command, remaster=False):
    receipt = SOURCE / f'{name}-request.json'
    status_file = SOURCE / f'{name}-status.json'
    source = SOURCE / f'{name}.mp3'
    if command == 'submit':
        if receipt.exists():
            return name, 'already submitted'
        payload = {k: spec[k] for k in ('title', 'tags', 'prompt')}
        payload.update(mv='chirp-v4', make_instrumental=True,
                       negative_tags='vocals, singing, speech, lyrics, choir, pop song, EDM drop')
        response = requests.post(f'{BASE}/submit/music', headers=headers(), json=payload, timeout=45)
        response.raise_for_status()
        result = response.json()
        if result.get('code') != 'success' or not result.get('data'):
            raise RuntimeError(str(result.get('message', 'submission failed')))
        write(receipt, {'request': payload, 'response': result})
        return name, 'submitted ' + str(result['data'])
    if command == 'collect':
        if source.exists():
            return name, 'downloaded'
        if not receipt.exists():
            return name, 'not submitted'
        task = read(receipt)['response']['data']
        response = requests.get(f'{BASE}/fetch/{task}', headers=headers(), timeout=45)
        response.raise_for_status()
        result = response.json()
        data = result.get('data') or {}
        write(status_file, result)
        if data.get('status') != 'SUCCESS' or not data.get('data'):
            return name, str(data.get('status', result.get('message', 'pending')))
        clip = next((c for c in data['data'] if float(c.get('duration',0)) >= 74), data['data'][0])
        write(SOURCE / f'{name}-selection.json', {'clip_id': clip['id']})
        with requests.get(clip['audio_url'], stream=True, timeout=120) as response:
            response.raise_for_status()
            temporary = source.with_suffix('.tmp')
            with temporary.open('wb') as target:
                for chunk in response.iter_content(1024 * 1024):
                    target.write(chunk)
            temporary.replace(source)
        return name, 'downloaded'
    if not source.exists():
        return name, 'source missing'
    target = OUT / f'{name}.ogg'
    if target.exists() and not remaster:
        return name, 'already mastered'
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-f', 'f32le',
                          '-ar', str(RATE), '-ac', '2', 'pipe:1'], check=True, capture_output=True).stdout
    audio = np.frombuffer(raw, dtype='<f4').reshape(-1, 2).copy()[2 * RATE:-5 * RATE]
    if len(audio) < 64 * RATE or not np.isfinite(audio).all():
        raise RuntimeError('Generated audio is too short or invalid')
    cross = 3 * RATE
    blend = np.linspace(0, 1, cross, dtype=np.float32)[:, None]
    audio[-cross:] = audio[-cross:] * (1 - blend) + audio[:cross] * blend
    audio = audio[cross:]
    # A 5 ms microfade removes codec edge clicks without an audible long fade.
    edge = int(.005 * RATE)
    audio[:edge] *= np.linspace(0, 1, edge, dtype=np.float32)[:, None]
    audio[-edge:] *= np.linspace(1, 0, edge, dtype=np.float32)[:, None]
    mastered = SOURCE / f'{name}-master.tmp.ogg'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE),
                    '-ac', '2', '-i', 'pipe:0', '-af', 'loudnorm=I=-20:TP=-2:LRA=9',
                    '-ar', str(RATE), '-c:a', 'libvorbis', '-q:a', '6', str(mastered)],
                   input=audio.tobytes(), check=True)
    mastered.replace(target)
    selection = SOURCE / f'{name}-selection.json'
    clips = read(status_file)['data']['data']
    clip = next(c for c in clips if c['id'] == read(selection)['clip_id']) if selection.exists() else clips[0]
    entry = {'title': spec['label'], 'file': target.name,
             'task_id': read(receipt)['response']['data'], 'clip_id': clip['id'],
             'requested_model': 'chirp-v4', 'returned_model': clip.get('model_name'),
             'request': read(receipt)['request'], 'source_file': source.name,
             'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
             'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
             'duration_seconds': len(audio) / RATE,
             'editing': {'trim_start_seconds': 2, 'trim_end_seconds': 5,
                         'loop_crossfade_seconds': 3, 'target_lufs': -20,
                         'true_peak_ceiling_db': -2, 'edge_microfade_seconds': .005}}
    return name, entry


def headers():
    key = os.environ.get('APILIO_API_KEY')
    if not key:
        raise RuntimeError('Set APILIO_API_KEY in the process environment')
    return {'Authorization': f'Bearer {key}'}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('command', choices=['submit', 'collect', 'master'])
    parser.add_argument('--cue')
    parser.add_argument('--remaster', action='store_true')
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    plan = read(PLAN)
    if args.cue:
        plan = {args.cue: plan[args.cue]}
    failed = False
    # Master sequentially: the manifest is shared, and PCM conversion is memory-heavy.
    workers = 1 if args.command == 'master' else 3
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(process, name, spec, args.command, args.remaster): name for name, spec in plan.items()}
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                name, result = future.result()
                if isinstance(result, dict):
                    path = OUT / 'music-manifest.json'
                    manifest = read(path)
                    manifest['tracks'][name] = result
                    write(path, manifest)
                    result = f"mastered {result['duration_seconds']:.1f}s"
                print(name, result, flush=True)
            except Exception as error:
                # Never print headers or environment variables.
                print(name, type(error).__name__, str(error), flush=True)
                failed = True
    raise SystemExit(1 if failed else 0)


if __name__ == '__main__':
    main()
