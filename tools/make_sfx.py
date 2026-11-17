"""Synthesize a cozy clay-game sound family; run with ./out/ present.

Only math, random, struct and wave are used. No reference files are written.
Every voice has a short rounded attack and release; the final mix also fades
to exact zero before peak normalization. Randomness is reproducible.
"""

import math
import random
import struct
import wave


SR = 44100
TAU = 2.0 * math.pi
PEAK = 0.89
random.seed(7)  # Same seed as reference_make_sounds.py.

C4, E4, G4 = 261.625565, 329.627557, 391.995436
C5, D5, E5, G5, A5 = 523.251131, 587.329536, 659.255114, 783.990872, 880.0
C6, D6, E6, G6, A6, C7 = (1046.502261, 1174.659072, 1318.510228,
                          1567.981744, 1760.0, 2093.004522)


def blank(duration):
    return [0.0] * round(SR * duration)


def add(destination, voice, offset=0.0, gain=1.0):
    start = round(offset * SR)
    for i in range(min(len(voice), len(destination) - start)):
        destination[start + i] += voice[i] * gain


def envelope(t, duration, attack, decay, release):
    # Raised-cosine edges have zero slope, avoiding both clicks and hard cuts.
    onset = 0.5 - 0.5 * math.cos(math.pi * min(1.0, t / attack))
    remaining = max(0.0, duration - t)
    tail = 0.5 - 0.5 * math.cos(math.pi * min(1.0, remaining / release))
    return onset * math.exp(-decay * t) * tail


def tone(freq, duration, amp=1.0, decay=6.0,
         harmonics=((1, 1.0), (2, 0.25), (4, 0.08)), attack=0.003):
    """Reference-style sine bell, with faster decay of upper harmonics."""
    voice = blank(duration)
    for i in range(len(voice)):
        t = i / SR
        value = sum(a * math.exp(-t * decay * 0.20 * (h - 1))
                    * math.sin(TAU * freq * h * t)
                    for h, a in harmonics if freq * h <= 5400)
        voice[i] = amp * envelope(t, duration, attack, decay,
                                 min(0.045, duration * 0.30)) * value
    return voice


def wood(freq, duration, amp=1.0, decay=30.0, noise=0.15):
    """Harmonic clay/wood resonances with a tiny low-passed noise attack."""
    voice = blank(duration)
    lp1 = lp2 = 0.0
    alpha = 1.0 - math.exp(-TAU * 2000 / SR)
    modes = ((1, 1.0, decay), (2, 0.24, decay * 1.8),
             (3, 0.09, decay * 2.5), (0.5, 0.16, decay * 1.1))
    for i in range(len(voice)):
        t = i / SR
        lp1 += alpha * (random.uniform(-1, 1) - lp1)
        lp2 += alpha * (lp1 - lp2)
        value = sum(a * math.exp(-d * t) * math.sin(TAU * freq * h * t)
                    for h, a, d in modes if freq * h <= 5400)
        value += noise * lp2 * math.exp(-t * 450)
        voice[i] = amp * envelope(t, duration, 0.0015, 0,
                                 min(0.025, duration * 0.3)) * value
    return voice


def glide(f0, f1, duration, amp=1.0, travel=0.05, decay=20,
          wobble=0.0):
    """Rounded, phase-continuous sine blip, settling on a consonant note."""
    voice = blank(duration)
    phase = 0.0
    for i in range(len(voice)):
        t = i / SR
        u = min(1.0, t / travel)
        curve = 1.0 - (1.0 - u) ** 2
        freq = f0 + (f1 - f0) * curve
        freq *= 1.0 + wobble * math.sin(TAU * 17 * t) * math.exp(-12 * t)
        phase += TAU * freq / SR
        value = math.sin(phase) + 0.12 * math.sin(2 * phase) * math.exp(-25 * t)
        voice[i] = amp * envelope(t, duration, 0.002, decay, 0.03) * value
    return voice


def marimba(freq, duration, amp=1.0, decay=10):
    voice = tone(freq, duration, amp, decay,
                 ((1, 1.0), (2, 0.20), (4, 0.055)), 0.0025)
    add(voice, wood(freq, min(duration, 0.065), 0.075, 70, 0.10))
    return voice


def bell(freq, duration, amp=1.0, decay=6):
    return tone(freq, duration, amp, decay,
                ((1, 1.0), (2, 0.23), (3, 0.045), (4, 0.045)), 0.003)


def dust(destination, start, span, amp=0.10):
    """Quiet upward pentatonic grains; high partials remain below 5.4 kHz."""
    pitches = (C6, D6, E6, G6, A6, C7)
    for i in range(18):
        position = i / 17
        offset = start + span * position
        # Small local overlaps give a soft, rising fairy-dust cascade.
        index = min(5, int(position * 5.9))
        freq = pitches[index]
        available = len(destination) / SR - offset
        duration = min(0.22, available)
        if duration > 0.012:
            gain = amp * random.uniform(0.60, 1.0) * (1.0 - 0.40 * position)
            add(destination, tone(freq, duration, gain, 18,
                                  ((1, 1.0), (2, 0.09)), 0.0035), offset)


def finish(samples):
    """Gently darken the mix, then apply a smooth zero-ending master fade."""
    lp1 = lp2 = 0.0
    alpha = 1.0 - math.exp(-TAU * 4200 / SR)
    output = []
    for value in samples:
        lp1 += alpha * (value - lp1)
        lp2 += alpha * (lp1 - lp2)
        output.append(lp2)
    fade = min(round(0.080 * SR), max(2, len(output) // 4))
    for i in range(fade):
        output[-fade + i] *= 0.5 * (1.0 + math.cos(math.pi * i / (fade - 1)))
    output[-1] = 0.0
    scale = PEAK / max(abs(value) for value in output)
    return [round(value * scale * 32767) for value in output]


def write(name, samples):
    pcm = finish(samples)
    with wave.open('./out/' + name + '.wav', 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SR)
        output.writeframes(struct.pack('<' + 'h' * len(pcm), *pcm))


def synthesize():
    sounds = {}

    s = blank(0.15)
    add(s, glide(C5, G5, 0.15, travel=0.044, decay=23))
    add(s, tone(C5 / 2, 0.15, 0.24, 27, ((1, 1.0),), 0.002))
    sounds['pop'] = s

    s = blank(0.12)
    add(s, glide(E6, G6, 0.12, travel=0.025, decay=55), gain=0.70)
    add(s, wood(C6, 0.055, 0.07, 95, 0.12))
    sounds['pick'] = s

    s = blank(0.18)
    add(s, wood(E4, 0.18, 1.0, 27, 0.23))
    add(s, tone(C4, 0.18, 0.30, 33, ((1, 1.0),), 0.002))
    add(s, wood(C6, 0.045, 0.12, 90, 0.10), 0.001)
    sounds['drop'] = s

    s = blank(0.25)
    add(s, glide(G5, C5, 0.25, travel=0.115, decay=13, wobble=0.018))
    add(s, marimba(C5, 0.13, 0.12, 24), 0.10)
    sounds['nope'] = s

    s = blank(0.45)
    add(s, bell(G5, 0.36, 0.8, 10))
    add(s, bell(C6, 0.325, 1.0, 8), 0.125)
    dust(s, 0.18, 0.16, 0.035)
    sounds['done'] = s

    s = blank(0.07)
    add(s, wood(E6, 0.07, 1.0, 85, 0.24))
    sounds['key'] = s

    s = blank(0.7)
    for offset, freq, gain in ((0.0, C6, 0.82), (0.115, E6, 0.86),
                               (0.23, G6, 1.0)):
        add(s, bell(freq, 0.7 - offset, gain, 6.5), offset)
    dust(s, 0.29, 0.23, 0.055)
    sounds['correct'] = s

    s = blank(0.45)
    add(s, marimba(E5, 0.30, 0.85, 12))
    add(s, marimba(C5, 0.30, 0.92, 11), 0.15)
    sounds['oops'] = s

    s = blank(0.6)
    dust(s, 0.0, 0.40, 0.22)
    # A soft longer anchor avoids a brittle collection of isolated ticks.
    add(s, tone(C6, 0.6, 0.055, 8, ((1, 1.0),), 0.004))
    sounds['sparkle'] = s

    s = blank(0.5)
    for i, freq in enumerate((C5, E5, G5, C6)):
        offset = i * 0.085
        add(s, marimba(freq, 0.5 - offset, 0.85 + 0.05 * i, 11), offset)
    sounds['start'] = s

    s = blank(2.0)
    # Clear melody first, then a soft C-major bloom under the held G.
    for offset, freq, duration, gain in ((0.0, G5, 0.38, 0.8),
                                        (0.18, C6, 0.42, 0.9),
                                        (0.36, E6, 0.46, 0.95),
                                        (0.57, G6, 1.18, 1.0)):
        add(s, marimba(freq, duration, gain, 8), offset)
        add(s, bell(freq, duration, gain * 0.36, 4.0), offset)
    for freq, gain in ((C5, 0.35), (E5, 0.26), (G5, 0.24), (C6, 0.36)):
        add(s, tone(freq, 1.15, gain, 3.2, attack=0.018), 0.85)
    dust(s, 1.10, 0.60, 0.07)
    sounds['fanfare'] = s

    s = blank(1.2)
    # Pentatonic bell glissando resolves into a held high C-major chord.
    for i, freq in enumerate((C5, D5, E5, G5, A5, C6, D6, E6, G6, C7)):
        offset = i * 0.037
        add(s, bell(freq, 0.34, 0.48 + 0.035 * i, 10), offset)
    for freq, gain in ((C6, 0.54), (E6, 0.38), (G6, 0.40), (C7, 0.28)):
        add(s, tone(freq, 0.80, gain, 3.5,
                    ((1, 1.0), (2, 0.13)), 0.008), 0.40)
    dust(s, 0.52, 0.42, 0.07)
    sounds['record'] = s
    return sounds


def verify(sounds):
    print('{:<15} {:>12} {:>10} {:>10}  {}'.format(
        'File', 'Duration (s)', 'Peak', 'RMS', 'Check'))
    print('-' * 62)
    failures = []
    for name, original in sounds.items():
        with wave.open('./out/' + name + '.wav', 'rb') as audio:
            channels = audio.getnchannels()
            width = audio.getsampwidth()
            rate = audio.getframerate()
            frames = audio.getnframes()
            compression = audio.getcomptype()
            raw = audio.readframes(frames)
        pcm = struct.unpack('<' + 'h' * (len(raw) // 2), raw)
        peak = max(abs(x) for x in pcm) / 32767
        rms = math.sqrt(sum((x / 32767) ** 2 for x in pcm) / len(pcm))
        onset = next((i for i, x in enumerate(pcm) if abs(x) > 1), frames) / SR
        # Inspect a whole tail window as well as the exact last sample.
        tail_peak = max(abs(x) for x in pcm[-round(0.002 * SR):]) / 32767
        checks = {
            '44100 Hz': rate == SR,
            'mono': channels == 1,
            '16-bit PCM': width == 2 and compression == 'NONE',
            'duration': frames == len(original),
            'peak 0.85-0.90': 0.85 <= peak <= 0.90,
            'onset within 5 ms': onset < 0.005,
            'exact zero endpoint': pcm[-1] == 0,
            'smooth quiet tail': tail_peak < 0.001,
        }
        failed = [label for label, passed in checks.items() if not passed]
        failures.extend(name + ': ' + label for label in failed)
        print('{:<15} {:12.3f} {:10.5f} {:10.5f}  {}'.format(
            name + '.wav', frames / rate, peak, rms, 'FAIL' if failed else 'PASS'))
    if failures:
        raise RuntimeError('\n'.join(failures))
    print('\nAll 12 files pass: 44100 Hz, mono, 16-bit PCM, peak 0.85-0.90,')
    print('audible onset within 5 ms, smooth fade, and exact zero final sample.')
    print('Peak and RMS are fractions of full scale (1.0).')


if __name__ == '__main__':
    sounds = synthesize()
    for name, samples in sounds.items():
        write(name, samples)
    verify(sounds)
