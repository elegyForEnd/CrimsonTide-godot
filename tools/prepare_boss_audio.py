"""Master boss cues from the project's existing CC0 recordings, without synthesis.

Source attribution and exact edit recipes are exported alongside the WAV files.
Requires the same source library and dependencies as prepare_library_audio.py.
"""
import json
from pathlib import Path
import prepare_library_audio as bank

OUT = bank.ROOT / 'assets/audio/bosses'
OUT.mkdir(parents=True, exist_ok=True)
bank.OUT = OUT
L = bank.layer


def make(key, layers, length, **kwargs):
    bank.cue(key, layers, length, **kwargs)


def build():
    # The long cues are only ritual accents; ordinary hits keep a short transient.
    themes = {
        'bell': ('foley1/bell_02.ogg', bank.druid('Wind', 3), 'foley1/gong_01.ogg'),
        'thorn': (bank.druid('Plant', 3), bank.sw(8), bank.druid('Earth', 2)),
        'queen': (bank.spell('Ice', 4), 'foley2/sfx100v2_glass_03.ogg', 'foley1/gong_02.ogg'),
        'knight': (bank.druid('Wind', 2), bank.sw(9), 'swords/sword_clash.4.ogg'),
    }
    for theme, (identity, air, weight) in themes.items():
        make(f'{theme}-charge', [L(identity, reverse=True, duration=.9, stretch=.7, gain=.75),
                                L(air, reverse=True, duration=.7, stretch=.65, gain=.2)],
             .75, rise=True, tail=.04, room=.5, rms=.12)
        make(f'{theme}-quick', [L(air, duration=.45, gain=.8), L(identity, duration=.6, gain=.5, speed=1.15)],
             .7, tail=.22, room=.3, rms=.15)
        make(f'{theme}-sweep', [L(air, duration=.65, speed=.7),
                               L(identity, duration=.8, speed=.85, gain=.5)],
             1.0, tail=.3, room=.65, rms=.16)
        make(f'{theme}-burst', [L(weight, duration=1.8, speed=.67, low=8500),
                               L(identity, duration=1.3, gain=.65), L(air, duration=.4, gain=.3)],
             2.1, tail=.7, room=1.1, rms=.17)
        make(f'{theme}-lance', [L(air, duration=.7, speed=.9),
                               L(identity, duration=.7, gain=.55, high=650),
                               L(weight, duration=.3, gain=.2)],
             .9, tail=.25, room=.45, rms=.15)
        make(f'{theme}-ritual', [L(identity, speed=.65, duration=2, gain=.8),
                                L(weight, speed=.55, duration=2, gain=.55, delay=.09)],
             3.2, tail=1.2, room=1.5, rms=.14)
        make(f'{theme}-fall', [L(weight, speed=.55, duration=1.8),
                              L(air, speed=.65, duration=1.5, gain=.5, delay=.2)],
             2.8, tail=1.0, room=1.3, rms=.14)
    for theme in ['thorn', 'knight']:
        identity = themes[theme][0]
        make(f'{theme}-guard', [L('swords/sword_clash.2.ogg', duration=.55),
                               L(identity, gain=.25, duration=.5)], .8, tail=.3, rms=.13)
        make(f'{theme}-break', [L('swords/sword_clash.8.ogg', speed=.75, duration=.65),
                               L('foley2/sfx100v2_glass_02.ogg', gain=.5, duration=.8),
                               L(themes[theme][2], gain=.45, duration=.5)],
             1.25, tail=.45, room=.8, rms=.16)
    manifest = {
        'license': 'CC0-1.0', 'sample_rate': bank.RATE,
        'method': 'Edited and layered existing CC0 recordings; no AI audio or synthesized waveforms.',
        'sources': {key: {'author': value[0], 'url': value[1]} for key, value in bank.SOURCES.items()
                    if key in {entry['source'] for entry in bank.USED.values()}},
        'files': bank.USED, 'cues': bank.CUES,
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    (OUT / 'CREDITS.txt').write_text('BOSS SOUND EFFECTS — CC0-1.0\nExisting recordings, edited and layered.\n\n' +
        '\n\n'.join(f"{v['author']}\n{v['url']}" for v in manifest['sources'].values()) +
        '\n\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\nExact source hashes and recipes: manifest.json\n', encoding='utf-8')
    print(f'Built {len(bank.CUES)} boss cues from {len(bank.USED)} existing recordings.')


if __name__ == '__main__':
    build()
