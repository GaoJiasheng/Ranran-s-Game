#!/usr/bin/env python3
"""Generate and validate Ranran's Mandarin lesson narration.

Run from any directory: python3 tools/voice/generate_voice.py
Dependencies are isolated in /tmp/mandarin-tts-env; ffmpeg/ffprobe must be on PATH.
Only `speak` is synthesized. Intermediate audio stays in a temporary directory.
An unchanged file is skipped only after its settings, digest, and audio pass QA.
"""

import argparse
import asyncio
import errno
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
VENV = Path('/tmp/mandarin-tts-env')
MANIFEST = ROOT / 'tools/voice/manifest.json'
INDEX = ROOT / 'tools/voice/voice_index.json'
OUTPUT = ROOT / 'RanranGame/Voice'
EDGE_VERSION = '7.3.1'
SETTINGS = {
    'pipeline_version': 2,
    'engine': 'edge-tts',
    'edge_tts_version': EDGE_VERSION,
    'voice': 'zh-CN-XiaoxiaoNeural',
    'rate': '-8%',
    'pitch': '+0Hz',
    'volume': '+0%',
    'trim_threshold_db': -50,
    'trim_keep_seconds': 0.08,
    'trim_detection': 'peak',
    'trim_window_seconds': 0.005,
    'loudness_method': 'measured EBU R128 gain, oversampled peak limiting, encoded feedback',
    'integrated_lufs': -16,
    'true_peak_dbtp': -1.5,
    'loudness_range_lu': 7,
    'channels': 1,
    'sample_rate_hz': 24000,
    'codec': 'libmp3lame',
    'bitrate_bps': 64000,
    'encoder_quality': 0,
    'limiter_sample_rate_hz': 192000,
    'limiter_attack_ms': 5,
    'limiter_release_ms': 50,
    'encoded_loudness_tolerance_lu': 0.75,
}


def bootstrap():
    """Never install packages in the system Python, even on a fresh machine."""
    python = VENV / 'bin/python'
    if not python.exists():
        subprocess.run([sys.executable, '-m', 'venv', str(VENV)], check=True)
    check = subprocess.run(
        [str(python), '-c', 'import edge_tts; print(edge_tts.__version__)'],
        text=True, capture_output=True,
    )
    if check.returncode or check.stdout.strip() != EDGE_VERSION:
        subprocess.run(
            [str(python), '-m', 'pip', 'install', f'edge-tts=={EDGE_VERSION}'],
            check=True,
        )
    if Path(sys.prefix).resolve() != VENV.resolve():
        os.execv(str(python), [str(python), '-B', str(Path(__file__).resolve()), *sys.argv[1:]])


async def command(*args, timeout=90):
    proc = await asyncio.create_subprocess_exec(
        *map(str, args), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout)
    except BaseException:
        if proc.returncode is None:
            proc.kill()
        await proc.communicate()
        raise
    out, err = stdout.decode('utf-8', 'replace'), stderr.decode('utf-8', 'replace')
    if proc.returncode:
        raise RuntimeError(f'{args[0]} exited {proc.returncode}: {err[-1800:]}')
    return out, err


async def ffmpeg(*args):
    return await command('ffmpeg', '-hide_banner', '-nostdin', '-y', '-threads', '1', *args)


def loudness_json(log):
    matches = re.findall(r'\{\s*"input_i".*?\}', log, re.S)
    if not matches:
        raise ValueError('ffmpeg did not report loudness measurements')
    return json.loads(matches[-1])


def finite(value):
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f'Non-finite audio measurement: {value}')
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def install_file(source, destination):
    # Both paths normally reside on the same volume. EXDEV is possible if /tmp
    # is mounted elsewhere; no scratch files are created inside the project.
    try:
        os.replace(source, destination)
    except OSError as error:
        if error.errno != errno.EXDEV:
            raise
        shutil.copyfile(source, destination)
        source.unlink()


def save_index(index, temporary):
    checkpoint = temporary / 'voice_index.json'
    checkpoint.write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    install_file(checkpoint, INDEX)


def load_manifest():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if not isinstance(manifest, list) or not manifest:
        raise ValueError('Manifest must be a nonempty list')
    names = set()
    for item in manifest:
        if not isinstance(item, dict):
            raise ValueError('Each manifest item must be an object')
        name, speak = item.get('file'), item.get('speak')
        if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', name):
            raise ValueError(f'Unsafe or invalid file stem: {name!r}')
        if name in names:
            raise ValueError(f'Duplicate manifest file: {name}')
        if not isinstance(speak, str) or not speak.strip():
            raise ValueError(f'Missing speak string: {name}')
        names.add(name)
    return manifest


async def process_audio(raw, wav, mp3):
    # Reverse-and-trim touches only the two outer edges. A stop_periods filter
    # would risk cutting off later sentences at internal teaching pauses.
    trim = (
        'silenceremove=start_periods=1:start_duration=0.015:'
        'start_threshold=-50dB:start_silence=0.08:detection=peak:window=0.005'
    )
    await ffmpeg('-i', raw, '-af', f'{trim},areverse,{trim},areverse',
                 '-ac', '1', '-ar', '24000', '-c:a', 'pcm_s24le', wav)
    norm = 'loudnorm=I=-16:TP=-1.5:LRA=7'
    _, log = await ffmpeg('-i', wav, '-af', f'{norm}:print_format=json', '-f', 'null', '-')
    measured = loudness_json(log)
    # loudnorm falls back to peak-constrained linear gain on very short clips.
    # The equivalent below uses its EBU R128 measurement, then lookahead peak
    # limiting only where needed. Feedback measures the final encoded waveform.
    # Each adjustment encodes the original WAV, never a previous MP3.
    gain = SETTINGS['integrated_lufs'] - finite(measured['input_i'])
    ceiling = 10 ** (SETTINGS['true_peak_dbtp'] / 20)
    for _ in range(4):
        filters = (
            f'aresample=192000,volume={gain:.6f}dB,'
            f'alimiter=limit={ceiling:.8f}:level=false:latency=true:attack=5:release=50,'
            'aresample=24000'
        )
        await ffmpeg('-i', wav, '-af', filters, '-ac', '1', '-ar', '24000',
                     '-map_metadata', '-1', '-c:a', 'libmp3lame', '-b:a', '64k',
                     '-compression_level', '0', mp3)
        _, log = await ffmpeg('-i', mp3, '-af', f'{norm}:print_format=json', '-f', 'null', '-')
        encoded_lufs = finite(loudness_json(log)['input_i'])
        correction = SETTINGS['integrated_lufs'] - encoded_lufs
        if abs(correction) <= 0.3:
            break
        gain += correction


async def validate(path, speak):
    out, _ = await command('ffprobe', '-v', 'error', '-show_streams', '-show_format',
                           '-of', 'json', path)
    probe = json.loads(out)
    streams = probe.get('streams', [])
    if len(streams) != 1 or streams[0].get('codec_type') != 'audio':
        raise ValueError('Expected exactly one audio stream')
    stream = streams[0]
    if (stream.get('codec_name') != 'mp3' or stream.get('channels') != 1
            or int(stream.get('sample_rate', 0)) != 24000
            or int(stream.get('bit_rate', 0)) != 64000):
        raise ValueError('Output must be mono 24 kHz 64 kbps MP3')
    duration = finite(probe['format']['duration'])
    if not 0.4 <= duration <= 30:
        raise ValueError(f'Duration {duration:.3f}s outside 0.4–30s')
    han = len(re.findall(r'[\u3400-\u9fff\uf900-\ufaff\U00020000-\U0003134f]', speak))
    # A/B/C labels are spoken too. Ignore punctuation and whitespace.
    spoken = han + len(re.findall(r'[A-Za-z0-9]', speak))
    if not spoken:
        raise ValueError('No countable spoken characters')
    cps = spoken / duration
    if spoken >= 6:
        plausible = 2 <= cps <= 7
    else:
        # A one-syllable affirmation has proportionally more articulation,
        # punctuation and edge-padding time. Allow 450ms of fixed overhead.
        plausible = spoken / 7 <= duration <= spoken / 2 + 0.45
    if not plausible:
        raise ValueError(f'Implausible speaking rate: {spoken} characters / {duration:.3f}s = {cps:.2f}/s')
    _, log = await ffmpeg('-v', 'info', '-xerror', '-i', path, '-af',
                         'volumedetect,loudnorm=I=-16:TP=-1.5:LRA=7:print_format=json',
                         '-f', 'null', '-')
    match = re.search(r'mean_volume:\s*([-\w.]+) dB', log)
    if not match:
        raise ValueError('No volumedetect mean_volume')
    mean = finite(match.group(1))
    if mean <= -35:
        raise ValueError(f'Silent/too quiet: mean_volume {mean:.1f} dB')
    loudness = loudness_json(log)
    lufs = finite(loudness['input_i'])
    peak = finite(loudness['input_tp'])
    if abs(lufs - SETTINGS['integrated_lufs']) > SETTINGS['encoded_loudness_tolerance_lu']:
        raise ValueError(f'Encoded loudness {lufs:.2f} LUFS outside -16 ±0.75 LU')
    if peak > -0.5:
        raise ValueError(f'Encoded true peak too high: {peak:.2f} dBTP')
    return {
        'duration_seconds': round(duration, 6),
        'chinese_characters': han,
        'spoken_characters': spoken,
        'characters_per_second': round(cps, 4),
        'mean_volume_db': mean,
        'integrated_lufs': lufs,
        'true_peak_dbtp': peak,
        'size_bytes': path.stat().st_size,
    }


async def run(args):
    import edge_tts

    manifest = load_manifest()
    for executable in ('ffmpeg', 'ffprobe'):
        if not shutil.which(executable):
            raise RuntimeError(f'{executable} is required on PATH')
    if importlib.metadata.version('edge-tts') != EDGE_VERSION:
        raise RuntimeError('Unexpected edge-tts version')
    if INDEX.exists():
        index = json.loads(INDEX.read_text(encoding='utf-8'))
        if not isinstance(index, dict):
            raise ValueError('voice_index.json must contain a file → record object')
    else:
        index = {}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    wanted = {item['file'] for item in manifest}
    removed = 0
    for path in OUTPUT.glob('*.mp3'):
        if path.stem not in wanted:
            path.unlink()
            removed += 1
    index = {key: value for key, value in index.items() if key in wanted}
    semaphore = asyncio.Semaphore(args.concurrency)
    counts = {'generated': 0, 'skipped': 0, 'failed': 0}
    failures = {}
    metrics = {}
    completed = 0

    with tempfile.TemporaryDirectory(prefix='ranran-voice-', dir='/tmp') as temp:
        temporary = Path(temp)
        save_index(index, temporary)

        async def item_job(item):
            nonlocal completed
            async with semaphore:
                name, speak = item['file'], item['speak']
                destination = OUTPUT / f'{name}.mp3'
                cached = index.get(name, {})
                if (isinstance(cached, dict) and cached.get('speak') == speak
                        and cached.get('settings') == SETTINGS and destination.is_file()):
                    try:
                        if cached.get('sha256') != digest(destination):
                            raise ValueError('Stored audio digest differs')
                        measurement = await validate(destination, speak)
                        metrics[name] = measurement
                        cached['validation'] = measurement
                        counts['skipped'] += 1
                        completed += 1
                        print(f'[{completed}/{len(manifest)}] skipped {name}', flush=True)
                        save_index(index, temporary)
                        return
                    except (RuntimeError, ValueError, KeyError, OSError) as error:
                        print(f'Regenerating {name}: {error}', flush=True)
                # Remove invalid provenance before attempting a replacement.
                index.pop(name, None)
                save_index(index, temporary)
                for attempt in range(1, 4):
                    try:
                        with tempfile.TemporaryDirectory(prefix=f'{name}-', dir=temp) as work:
                            work = Path(work)
                            raw, wav, mp3 = work / 'raw.mp3', work / 'trimmed.wav', work / 'final.mp3'
                            communicator = edge_tts.Communicate(
                                speak, SETTINGS['voice'], rate=SETTINGS['rate'],
                                pitch=SETTINGS['pitch'], volume=SETTINGS['volume'],
                                connect_timeout=15, receive_timeout=60,
                            )
                            await asyncio.wait_for(communicator.save(str(raw)), timeout=100)
                            await process_audio(raw, wav, mp3)
                            measurement = await validate(mp3, speak)
                            checksum = digest(mp3)
                            install_file(mp3, destination)
                        index[name] = {
                            'speak': speak, 'settings': dict(SETTINGS),
                            'sha256': checksum, 'validation': measurement,
                        }
                        metrics[name] = measurement
                        counts['generated'] += 1
                        save_index(index, temporary)
                        break
                    except (Exception,) as error:
                        detail = f'{type(error).__name__}: {error}'
                        print(f'{name}: attempt {attempt}/3 failed: {detail}', flush=True)
                        if attempt == 3:
                            failures[name] = detail
                            counts['failed'] += 1
                        else:
                            await asyncio.sleep(2 ** attempt + random.uniform(0.2, 1.0))
                completed += 1
                print(f'[{completed}/{len(manifest)}] '
                      f'{"FAILED" if name in failures else "generated"} {name}', flush=True)

        await asyncio.gather(*(item_job(item) for item in manifest))
        save_index(dict(sorted(index.items())), temporary)

    actual = {path.stem for path in OUTPUT.glob('*.mp3')}
    if actual != wanted:
        missing, extra = sorted(wanted - actual), sorted(actual - wanted)
        print(f'File-set mismatch: missing={missing}; extra={extra}', flush=True)
    duration = sum(value['duration_seconds'] for value in metrics.values())
    size = sum(path.stat().st_size for path in OUTPUT.glob('*.mp3'))
    print(f'\nSummary: generated={counts["generated"]} skipped={counts["skipped"]} '
          f'failed={counts["failed"]}; validated={len(metrics)}/{len(manifest)}; '
          f'mp3_files={len(actual)}; removed_obsolete={removed}; '
          f'total_duration={duration:.3f}s ({duration / 60:.2f} min); '
          f'total_size={size} bytes ({size / 1024 / 1024:.2f} MiB)', flush=True)
    if failures:
        print('Failures:', flush=True)
        for name, detail in sorted(failures.items()):
            print(f'  {name}: {detail}', flush=True)
    if metrics:
        print('\nRandom spot-checks (fresh ffprobe/ffmpeg validation):', flush=True)
        sample = random.SystemRandom().sample(list(metrics), min(5, len(metrics)))
        by_name = {item['file']: item for item in manifest}
        for name in sample:
            item = by_name[name]
            value = await validate(OUTPUT / f'{name}.mp3', item['speak'])
            print(f'  {name}: {value["duration_seconds"]:.3f}s; '
                  f'{value["chinese_characters"]} Chinese chars; '
                  f'{value["characters_per_second"]:.2f} chars/s; '
                  f'{value["integrated_lufs"]:.2f} LUFS; {item["speak"]}', flush=True)
    return 1 if failures or actual != wanted or len(metrics) != len(manifest) else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--concurrency', type=int, default=3, choices=range(1, 5),
                        help='Maximum simultaneous synthesis/processing jobs (default: 3)')
    args = parser.parse_args()
    bootstrap()
    return asyncio.run(run(args))


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as error:
        print(f'Fatal: {type(error).__name__}: {error}', file=sys.stderr, flush=True)
        sys.exit(1)
