"""Render every voice line with Kokoro TTS, then give each champion its own sound with ffmpeg.

Usage: python gen_voices.py manifest.json models_dir out_dir
The manifest comes from tools/voice_manifest.mjs.
"""
import json
import os
import subprocess
import sys
import tempfile

import soundfile as sf
from kokoro_onnx import Kokoro

FX = {
    'none': [],
    'forge': ['aecho=0.8:0.6:35|70:0.18|0.1', 'bass=g=3'],
    'imp': ['flanger=delay=1:depth=4:speed=1.5', 'aecho=0.8:0.6:25:0.2'],
    'ocean': ['chorus=0.6:0.9:40|55:0.3|0.25:0.3|0.4:1.2|0.9', 'aecho=0.8:0.8:70|140:0.28|0.18'],
    'ice': ['aecho=0.8:0.75:90|180:0.25|0.15', 'treble=g=3'],
    'robot': ["afftfilt=real='hypot(re,im)*cos(0)':imag='hypot(re,im)*sin(0)':win_size=512:overlap=0.75",
              'aecho=0.8:0.5:12:0.35', 'highpass=f=180'],
    'mech': ['flanger=delay=0.5:depth=1.5:speed=0.4', 'aecho=0.8:0.6:18:0.25'],
    'void': ['chorus=0.5:0.9:50|60|40:0.4|0.32|0.3:0.25|0.4|0.3:2|2.3|1.3', 'aecho=0.8:0.88:60|180:0.4|0.25'],
    'abyss': ['chorus=0.5:0.9:60|80:0.5|0.4:0.3|0.4:1.5|1.1', 'aecho=0.8:0.9:90|260|420:0.45|0.3|0.18', 'bass=g=6'],
    'giant': ['aecho=0.8:0.85:110|230:0.35|0.2', 'bass=g=5'],
    'beast': ['aecho=0.8:0.6:20:0.3', 'bass=g=4'],
    'cathedral': ['aecho=0.8:0.9:120|260|400:0.3|0.2|0.12'],
    'grove': ['chorus=0.7:0.9:30:0.25:0.3:1.0', 'aecho=0.8:0.7:80|160:0.2|0.12'],
    'herald': ['aecho=0.8:0.88:140|300:0.28|0.16', 'bass=g=2'],
}


def main():
    manifest, models, out_dir = sys.argv[1:4]
    os.makedirs(out_dir, exist_ok=True)
    k = Kokoro(os.path.join(models, 'kokoro-v1.0.onnx'), os.path.join(models, 'voices-v1.0.bin'))
    lines = json.load(open(manifest))
    lang = lambda v: 'en-gb' if v.startswith('b') else 'en-us'
    for i, ln in enumerate(lines):
        dst = os.path.join(out_dir, ln['file'] + '.mp3')
        if os.path.exists(dst):
            continue
        samples, sr = k.create(ln['text'], voice=ln['v'], speed=ln.get('speed', 1.0), lang=lang(ln['v']))
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            sf.write(tmp.name, samples, sr)
            src = tmp.name
        p = ln.get('pitch', 1.0)
        chain = []
        if abs(p - 1.0) > 0.001:
            chain += [f'asetrate={int(sr * p)}', f'aresample={sr}', f'atempo={1.0 / p:.4f}']
        chain += FX.get(ln.get('fx', 'none'), [])
        chain += ['silenceremove=start_periods=1:start_threshold=-50dB',
                  'areverse', 'silenceremove=start_periods=1:start_threshold=-55dB', 'areverse',
                  'apad=pad_dur=0.25', 'loudnorm=I=-16:TP=-1.5:LRA=9']
        cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-af', ','.join(chain),
               '-ar', '44100', '-ac', '1', '-c:a', 'libmp3lame', '-b:a', '64k', dst]
        subprocess.run(cmd, check=True)
        os.unlink(src)
        print(f'[{i + 1}/{len(lines)}] {ln["file"]}', flush=True)


if __name__ == '__main__':
    main()
