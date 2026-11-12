"""Small instrument kit for Sandfall Rescue's music and sound effects.

Everything here is synthesised from scratch (no samples), so the audio is fully
ours to ship. Instruments: oud / qanun (plucked strings), ney (breathy flute),
darbuka, riq / frame drum, big tabl drum, bells, marimba, string pad, brass stab,
metal anvil hit.
"""
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
rng = np.random.default_rng(7)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def env_adsr(n, a=0.005, d=0.1, s=0.6, r=0.1):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(1, a_n)),
        np.linspace(1, s, max(1, d_n)),
        np.full(s_n, s),
        np.linspace(s, 0, max(1, r_n)),
    ])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def bp(x, lo, hi, order=2):
    sos = butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], btype="band", output="sos")
    return sosfilt(sos, x)


def lp(x, f, order=2):
    sos = butter(order, min(f, SR / 2 - 100) / (SR / 2), btype="low", output="sos")
    return sosfilt(sos, x)


def hp(x, f, order=2):
    sos = butter(order, f / (SR / 2), btype="high", output="sos")
    return sosfilt(sos, x)


# ---------------- plucked strings ----------------
def pluck(freq, dur, bright=0.5, decay=0.996, body=True):
    """Karplus-Strong string, block-vectorised, pitch-corrected by resampling."""
    period = SR / freq
    N = max(2, int(period - 0.5))  # the averaging filter adds half a sample
    n = int(dur * SR * (N + 0.5) / period) + N
    buf = rng.uniform(-1, 1, N)
    # softer pick for a warmer tone
    k = max(1, int((1 - bright) * 6))
    if k > 1:
        buf = np.convolve(buf, np.ones(k) / k, mode="same")
    blocks = [buf]
    prev_last = buf[-1]
    while sum(len(b) for b in blocks) < n:
        cur = blocks[-1]
        shifted = np.concatenate([[prev_last], cur[:-1]])
        prev_last = cur[-1]
        blocks.append(decay * 0.5 * (cur + shifted))
    y = np.concatenate(blocks)[:n]
    # resample to the exact pitch
    t_out = np.arange(int(dur * SR)) * ((N + 0.5) / period)
    y = np.interp(t_out, np.arange(len(y)), y)
    if body:  # wooden body resonance
        y = 0.7 * y + 0.5 * bp(y, freq * 0.9, freq * 3.2) + 0.25 * bp(y, 900, 1600)
    fade = min(len(y), int(0.02 * SR))
    if fade:
        y[-fade:] *= np.linspace(1, 0, fade)
    return y


def oud(freq, dur, vel=1.0):
    y = pluck(freq, dur + 0.25, bright=0.45, decay=0.9965)
    return vel * 1.5 * y


def qanun(freq, dur, vel=1.0):
    y = pluck(freq, dur + 0.4, bright=0.85, decay=0.998, body=False)
    return vel * 0.55 * (y + 0.3 * hp(y, 2000))


# ---------------- ney flute ----------------
def ney(freq, dur, vel=1.0, vib=5.2, slide_from=None, breath=0.25):
    n = int((dur + 0.08) * SR)
    t = np.arange(n) / SR
    vib_amt = np.clip((t - 0.18) * 3, 0, 1) * 0.006
    f = np.full(n, freq)
    if slide_from:
        k = min(n, int(0.07 * SR))
        f[:k] = np.linspace(slide_from, freq, k)
    f = f * (1 + vib_amt * np.sin(2 * np.pi * vib * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph)
    noise = rng.normal(0, 1, n)
    air = bp(noise, freq * 0.8, freq * 2.6) * 1.4 + hp(noise, 3000) * 0.05
    e = env_adsr(n, a=0.07, d=0.1, s=0.85, r=0.12)
    chiff = np.exp(-t * 40) * bp(noise, 1500, 6000) * 0.25
    return vel * 0.32 * e * (tone * (1 - breath * 0.5) + air * breath) + vel * chiff * 0.4


# ---------------- percussion ----------------
def dum(vel=1.0, pitch=1.0):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = (95 + 80 * np.exp(-t * 30)) * pitch
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    slap = lp(rng.normal(0, 1, n), 900) * np.exp(-t * 60) * 0.5
    return vel * 0.9 * (body + slap)


def tek(vel=1.0, bright=1.0):
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0, 1, n)
    ring = np.sin(2 * np.pi * 720 * bright * t) * np.exp(-t * 55) * 0.6
    crack = bp(noise, 2500 * bright, 8000) * np.exp(-t * 90)
    return vel * 0.55 * (ring + crack * 1.3)


def ka(vel=1.0):
    return tek(vel * 0.5, bright=0.85)


def riq(vel=1.0):
    """Frame drum jingles."""
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0, 1, n)
    j = np.zeros(n)
    for fr in (5200, 6900, 8300, 9700):
        j += np.sin(2 * np.pi * fr * t + rng.uniform(0, 6)) * np.exp(-t * rng.uniform(14, 22))
    j *= 0.25
    shimmer = hp(noise, 6000) * np.exp(-t * 18) * 0.5
    skin = bp(noise, 300, 1200) * np.exp(-t * 50) * 0.4
    return vel * 0.32 * (j + shimmer + skin)


def tabl(vel=1.0):
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = 55 + 70 * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4)
    hit = lp(rng.normal(0, 1, n), 500) * np.exp(-t * 35)
    return vel * 1.1 * np.tanh(1.6 * (body + 0.6 * hit))


def anvil(vel=1.0, base=880):
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for r, a, d in ((1.0, 1, 5), (2.76, 0.6, 7), (5.4, 0.35, 9), (8.9, 0.2, 13)):
        y += a * np.sin(2 * np.pi * base * r * t) * np.exp(-t * d)
    clank = hp(rng.normal(0, 1, n), 3000) * np.exp(-t * 80)
    return vel * 0.22 * (y + clank)


# ---------------- melodic extras ----------------
def bell(freq, dur, vel=1.0):
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * 2.2 * np.exp(-t * 3)
    y = np.sin(2 * np.pi * freq * t + mod) * np.exp(-t * 2.2)
    y += 0.3 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 4)
    return vel * 0.28 * y * env_adsr(n, a=0.002, d=0.01, s=1, r=0.05)


def marimba(freq, dur, vel=1.0):
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t * 7) + 0.25 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 20)
    y += 0.1 * lp(rng.normal(0, 1, n), 2000) * np.exp(-t * 200)
    return vel * 0.5 * y


def pad(freqs, dur, vel=1.0, bright=1500):
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f in freqs:
        for det in (-0.006, 0.0, 0.007):
            ph = 2 * np.pi * f * (1 + det) * t + rng.uniform(0, 6)
            y += 2 * (((ph / (2 * np.pi)) % 1.0) - 0.5)  # saw
    y = lp(y, bright, 2)
    e = env_adsr(n, a=0.35, d=0.2, s=0.9, r=0.5)
    return vel * 0.05 * y * e


def brass(freqs, dur, vel=1.0):
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f in freqs:
        for det in (-0.004, 0.004):
            ph = f * (1 + det) * t
            y += 2 * ((ph % 1.0) - 0.5)
    cut = 600 + 2600 * np.exp(-t * 6)
    # time-varying lowpass by blending two filters
    lo, hi = lp(y, 700), lp(y, 3200)
    w = (cut - 600) / 2600
    y = lo * (1 - w) + hi * w
    e = env_adsr(n, a=0.02, d=0.15, s=0.7, r=0.15)
    return vel * 0.18 * np.tanh(1.5 * y) * e


# ---------------- mixing helpers ----------------
class Track:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.L = np.zeros(self.n + SR * 4)
        self.R = np.zeros(self.n + SR * 4)
        self.wetL = np.zeros_like(self.L)
        self.wetR = np.zeros_like(self.R)

    def add(self, sig, at, pan=0.0, gain=1.0, wet=0.25):
        i = int(at * SR)
        if i >= len(self.L):
            return
        sig = sig[: len(self.L) - i] * gain
        gl = np.cos((pan + 1) * np.pi / 4)
        gr = np.sin((pan + 1) * np.pi / 4)
        self.L[i:i + len(sig)] += sig * gl
        self.R[i:i + len(sig)] += sig * gr
        if wet:
            self.wetL[i:i + len(sig)] += sig * gl * wet
            self.wetR[i:i + len(sig)] += sig * gr * wet

    def render(self, room=1.6, tone=5000):
        n_ir = int(room * SR)
        t = np.arange(n_ir) / SR
        irs = []
        for _ in range(2):
            ir = rng.normal(0, 1, n_ir) * np.exp(-t * 6.9 / room)
            ir = lp(ir, tone)
            ir[: int(0.012 * SR)] = 0
            irs.append(ir / np.sqrt(np.sum(ir ** 2)) * 0.8)
        L = self.L + fftconvolve(self.wetL, irs[0])[: len(self.L)]
        R = self.R + fftconvolve(self.wetR, irs[1])[: len(self.R)]
        return np.stack([L, R], axis=1)


def master(st, drive=1.15, target=0.89):
    st = hp(st.T, 30).T
    st = np.tanh(st / np.max(np.abs(st)) * drive * 1.4)
    st = st / np.max(np.abs(st)) * target
    return st
