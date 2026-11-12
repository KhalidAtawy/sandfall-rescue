"""Sound effects for Sandfall Rescue, synthesised from scratch.

Run:  python3 tools/audio/sfx.py  -> writes assets/sfx/*.wav
"""
import os
import sys
import wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from synth import *  # noqa

D4 = 62


def T(sec):
    return np.arange(int(sec * SR)) / SR


def fade(y, a=0.002, r=0.02):
    n = len(y)
    ai, ri = int(a * SR), int(r * SR)
    if ai:
        y[:ai] *= np.linspace(0, 1, ai)
    if ri:
        y[-ri:] *= np.linspace(1, 0, ri)
    return y


def mix(n, *parts):
    out = np.zeros(n)
    for at, sig in parts:
        i = int(at * SR)
        if i < n:
            s = sig[: n - i]
            out[i:i + len(s)] += s
    return out


def norm(y, peak):
    return y / (np.max(np.abs(y)) + 1e-9) * peak


def verb(y, room=0.6, wet=0.2):
    n = int(room * SR)
    t = np.arange(n) / SR
    ir = lp(rng.normal(0, 1, n) * np.exp(-t * 6.9 / room), 6000)
    ir /= np.sqrt(np.sum(ir ** 2))
    w = np.convolve(y, ir)[: len(y)] if len(y) < 20000 else __import__("scipy.signal").signal.fftconvolve(y, ir)[: len(y)]
    return y + wet * w


def pop(i):
    deg = [0, 4, 7, 8, 12][i]  # D F# A Bb D'
    f = midi_hz(D4 + 12 + deg)
    t = T(0.32)
    pitch = f * (1 + 0.5 * np.exp(-t * 60))
    ph = 2 * np.pi * np.cumsum(pitch) / SR
    y = np.sin(ph) * np.exp(-t * 14) + 0.35 * np.sin(2.76 * ph) * np.exp(-t * 26) + 0.15 * np.sin(5.4 * ph) * np.exp(-t * 40)
    click = hp(rng.normal(0, 1, len(t)), 4000) * np.exp(-t * 400) * 0.4
    return norm(verb(fade(y + click), 0.5, 0.25), 0.6)


def swap():
    t = T(0.22)
    n = rng.normal(0, 1, len(t))
    # sweep by blending bands
    lo, mid, hi = bp(n, 400, 900), bp(n, 900, 2000), bp(n, 2000, 4500)
    x = t / t[-1]
    y = lo * (1 - x) ** 2 + mid * 2 * x * (1 - x) + hi * x ** 2
    e = np.sin(np.pi * x) ** 1.5
    return norm(fade(y * e), 0.4)


def bad():
    t = T(0.3)
    y = np.sin(2 * np.pi * 170 * t) * np.exp(-t * 22) + 0.5 * np.sin(2 * np.pi * 455 * t) * np.exp(-t * 35)
    y += lp(rng.normal(0, 1, len(t)), 2500) * np.exp(-t * 200) * 0.6
    y2 = np.sin(2 * np.pi * 140 * t) * np.exp(-t * 22) * 0.7
    return norm(fade(mix(len(t) + int(0.12 * SR), (0, y), (0.11, y2))), 0.55)


def rocket():
    t = T(0.85)
    n = rng.normal(0, 1, len(t))
    x = t / t[-1]
    y = bp(n, 300, 900) * (1 - x) + bp(n, 900, 3000) * np.sin(np.pi * x) + bp(n, 3000, 8000) * x
    y *= np.sin(np.pi * np.clip(x * 1.2, 0, 1)) ** 0.7
    sparks = [(0.15 + k * 0.07, bell(midi_hz(D4 + 24 + [0, 4, 7, 12, 16, 19][k % 6]), 0.1, 0.5)) for k in range(8)]
    y = mix(len(t) + SR, (0, y * 0.9), *sparks)
    return norm(fade(verb(y, 0.8, 0.25), r=0.1), 0.7)


def boom():
    t = T(1.1)
    f = 40 + 90 * np.exp(-t * 14)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    burst = lp(rng.normal(0, 1, len(t)), 1800) * np.exp(-t * 7)
    crack_ = hp(rng.normal(0, 1, len(t)), 2000) * np.exp(-t * 60) * 0.5
    debris = [(0.05 + rng.uniform(0, 0.5), tek(rng.uniform(0.2, 0.5), bright=rng.uniform(0.6, 1.2))) for _ in range(9)]
    y = mix(len(t), (0, sub * 1.2 + burst + crack_), *debris)
    return norm(fade(np.tanh(verb(y, 1.0, 0.2) * 1.6), r=0.15), 0.9)


def zap():
    t = T(0.7)
    f = 250 * (8 ** (t / 0.45))
    f = np.minimum(f, 2200)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph + 2.0 * np.sin(ph * 2.01)) * np.exp(-t * 3) * 0.6
    chimes = [(0.25 + k * 0.06, bell(midi_hz(D4 + 24 + d), 0.2, 0.7)) for k, d in enumerate([0, 4, 7, 12, 16])]
    y = mix(len(t) + SR, (0, y), *chimes)
    return norm(fade(verb(y, 0.9, 0.3), r=0.2), 0.65)


def sand():
    t = T(0.6)
    n = rng.normal(0, 1, len(t))
    y = bp(n, 1500, 7000) + 0.5 * bp(n, 600, 1500)
    grains = (rng.uniform(0, 1, len(t)) > 0.985) * rng.uniform(0.5, 1.5, len(t))
    y += hp(np.convolve(grains, np.exp(-np.arange(60) / 8), mode="same"), 2500) * 0.8
    x = t / t[-1]
    y *= np.sin(np.pi * x) ** 0.8
    return norm(fade(y), 0.35)


def shine():
    t = T(0.9)
    notes = [(k * 0.055, bell(midi_hz(D4 + 19 + d), 0.25, 0.8)) for k, d in enumerate([0, 5, 9, 12])]
    sh = hp(rng.normal(0, 1, len(t)), 7000) * np.exp(-t * 6) * 0.08
    y = mix(len(t) + SR, (0, sh), *notes)
    return norm(fade(verb(y, 1.0, 0.35), r=0.25), 0.6)


def crack():
    t = T(0.65)
    y = np.zeros(len(t))
    for k in range(6):
        at = rng.uniform(0, 0.12)
        i = int(at * SR)
        tt = t[: len(t) - i]
        y[i:] += hp(rng.normal(0, 1, len(tt)), 1800) * np.exp(-tt * rng.uniform(150, 300)) * rng.uniform(0.5, 1)
    thud = np.sin(2 * np.pi * (70 + 60 * np.exp(-t * 30)) * t) * np.exp(-t * 14) * 0.8
    crumble = bp(rng.normal(0, 1, len(t)), 500, 3000) * np.exp(-t * 6) * 0.35
    crumble *= (rng.uniform(0, 1, len(t)) > 0.6)
    crumble = lp(crumble, 3000)
    return norm(fade(verb(y + thud + crumble, 0.5, 0.15), r=0.08), 0.75)


def click():
    t = T(0.09)
    y = np.sin(2 * np.pi * 1100 * t) * np.exp(-t * 90) + 0.4 * np.sin(2 * np.pi * 2600 * t) * np.exp(-t * 150)
    y += hp(rng.normal(0, 1, len(t)), 3000) * np.exp(-t * 600) * 0.3
    return norm(fade(y, r=0.01), 0.45)


def win():
    n = int(2.4 * SR)
    beat = 0.16
    parts = []
    arp = [0, 4, 7, 12, 16]
    for k, d in enumerate(arp):
        parts.append((k * beat, oud(midi_hz(D4 + d), 0.4, 1.0)))
    for j in range(10):  # tremolo on the top note
        parts.append((5 * beat + j * 0.06, oud(midi_hz(D4 + 19), 0.12, 0.7)))
    parts.append((5 * beat, ney(midi_hz(D4 + 24), 1.2, 1.1, slide_from=midi_hz(D4 + 21))))
    parts.append((5 * beat, pad([midi_hz(D4 - 12), midi_hz(D4 - 5), midi_hz(D4 + 4)], 1.3, 2.0)))
    for k, at in enumerate([0, 2 * beat, 4 * beat, 5 * beat]):
        parts.append((at, dum(0.9) if k % 2 == 0 else tek(0.8)))
    for k in range(6):
        parts.append((5 * beat + k * 0.08, riq(0.6)))
    parts.append((5 * beat, bell(midi_hz(D4 + 31), 0.5, 0.6)))
    y = mix(n, *parts)
    return norm(fade(verb(y, 1.4, 0.3), r=0.4), 0.85)


def lose():
    n = int(2.4 * SR)
    seq = [(7, 0.35), (5, 0.35), (4, 0.35), (1, 0.45), (0, 0.9)]  # A G F# Eb D, hijaz going down
    parts, t, prev = [], 0.0, None
    for d, dur in seq:
        f = midi_hz(D4 + 12 + [0, 1, 4, 5, 7, 8, 10, 12][d])
        parts.append((t, ney(f, dur * 0.95, 0.9, vib=4.0, slide_from=prev)))
        prev = f
        t += dur
    parts.append((0, dum(0.5, pitch=0.8)))
    parts.append((t - 0.9, dum(0.7, pitch=0.7)))
    parts.append((t - 0.9, pad([midi_hz(D4 - 12), midi_hz(D4 - 5)], 1.0, 1.5, bright=900)))
    y = mix(n, *parts)
    return norm(fade(verb(y, 1.4, 0.3), r=0.4), 0.75)


def trim(y, floor=0.003):
    idx = np.where(np.abs(y) > floor)[0]
    if len(idx):
        y = y[: idx[-1] + int(0.03 * SR)]
        k = min(len(y), int(0.03 * SR))
        y[-k:] *= np.linspace(1, 0, k)
    return y


def write_wav(path, y):
    y = trim(y)
    data = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/sfx"
    os.makedirs(out, exist_ok=True)
    sounds = {f"pop{i}": (lambda i=i: pop(i)) for i in range(5)}
    sounds.update(swap=swap, bad=bad, rocket=rocket, boom=boom, zap=zap, sand=sand, shine=shine,
                  crack=crack, click=click, win=win, lose=lose)
    for name, fn in sounds.items():
        y = fn()
        write_wav(os.path.join(out, name + ".wav"), y)
        print(name, round(len(y) / SR, 2))
