"""Composes Sandfall Rescue's music loops from hand-written maqam melodies.

Run:  python3 tools/audio/compose.py  -> writes assets/music/*.ogg
Each song is 16 bars (8 two-bar phrases). It is rendered three times in a row and
the middle copy is kept, so reverb tails wrap around and the loop is seamless.
"""
import os
import subprocess
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from synth import *  # noqa

SCALES = {
    "hijaz": [0, 1, 4, 5, 7, 8, 10],
    "kurd": [0, 1, 3, 5, 7, 8, 10],
    "nahawand": [0, 2, 3, 5, 7, 8, 11],
}

RHYTHMS = {
    "maqsum": "D.T.k.T.D.k.T.k.",
    "baladi": "D.D.k.T.D.k.T.k.",
    "saidi": "D.T.k.D.D.k.T.k.",
    "malfuf": "D.k.k.T.k.k.T.k.",
    "soft": "D...k...T...k...",
    "fill": "D.TkTkTkTkTkTkTk",
}

CHORDS = {"A1": [0, 0], "A2": [0, 4], "A3": [4, 0], "B1": [3, 3], "B2": [3, 4]}
FORM = ["A1", "A2", "A1", "A3", "B1", "B2", "B1", "A3"]


def parse(s):
    out = []
    for tok in s.split():
        d, b = tok.split(":")
        out.append((None if d == "_" else int(d), float(b)))
    return out


def semis(scale, deg):
    sc = SCALES[scale]
    o, i = divmod(deg, 7)
    return 12 * o + sc[i]


SONGS = {
    "map": dict(bpm=108, scale="hijaz", root=62, rhythm="maqsum", riq=True,
                leads=["oud", "oud", "ney", "both", "ney", "ney", "oud", "both"],
                m={"A1": "4:1 5:.5 4:.5 2:1 3:.5 2:.5 1:1 2:1 0:2",
                   "A2": "0:.5 1:.5 2:.5 3:.5 4:1 4:1 5:.5 4:.5 3:.5 2:.5 4:2",
                   "A3": "7:1 6:.5 5:.5 4:1 3:.5 2:.5 1:.5 2:.5 1:.5 0:.5 0:2",
                   "B1": "4:.5 4:.5 7:1 6:.5 5:.5 4:1 5:.5 6:.5 5:.5 4:.5 3:2",
                   "B2": "3:.5 4:.5 5:1 4:.5 3:.5 2:1 3:.5 2:.5 1:.5 2:.5 4:2"}),
    "level": dict(bpm=100, scale="hijaz", root=62, rhythm="baladi", riq=True, soft=True,
                  leads=["marimba", "oud", "marimba", "oud", "ney", "ney", "marimba", "oud"],
                  m={"A1": "0:.5 _:.5 2:.5 _:.5 4:.5 3:.5 2:1 1:.5 2:.5 1:.5 0:.5 _:2",
                     "A2": "4:.5 _:.5 5:.5 _:.5 4:.5 3:.5 4:1 2:.5 3:.5 2:.5 1:.5 2:2",
                     "A3": "3:.5 2:.5 1:.5 2:.5 3:1 4:1 2:.5 1:.5 0:1 _:2",
                     "B1": "7:.5 _:.5 6:.5 5:.5 4:1 5:1 6:.5 5:.5 4:.5 3:.5 4:2",
                     "B2": "4:.5 5:.5 6:.5 7:.5 6:1 5:1 4:.5 3:.5 2:.5 1:.5 2:2"}),
    "level_iron": dict(bpm=96, scale="kurd", root=62, rhythm="saidi", anvil=True,
                       leads=["qanun", "qanun", "oud", "qanun", "ney", "ney", "qanun", "both"],
                       m={"A1": "0:.5 0:.5 1:.5 2:.5 1:1 0:1 2:.5 3:.5 4:1 3:.5 2:.5 1:1",
                          "A2": "4:.5 4:.5 5:.5 4:.5 3:1 2:1 1:.5 2:.5 1:.5 0:.5 0:2",
                          "A3": "6:1 5:.5 4:.5 3:1 2:1 1:.5 0:.5 1:1 0:2",
                          "B1": "7:1 6:.5 5:.5 6:1 4:1 5:.5 4:.5 3:.5 2:.5 3:2",
                          "B2": "3:.5 4:.5 5:.5 6:.5 7:1 6:1 5:.5 4:.5 3:.5 2:.5 1:2"}),
    "level_crystal": dict(bpm=84, scale="nahawand", root=62, rhythm="soft", arp=True, room=2.6,
                          leads=["bell", "bell", "qanun", "bell", "ney", "ney", "bell", "both"],
                          m={"A1": "4:2 3:1 2:1 0:1 2:1 4:2",
                             "A2": "5:2 4:1 3:1 2:1 1:1 0:2",
                             "A3": "6:1 7:1 6:1 5:1 4:4",
                             "B1": "7:2 8:1 7:1 6:1 5:1 4:2",
                             "B2": "5:1 4:1 3:1 2:1 1:1 2:1 0:2"}),
    "level_emerald": dict(bpm=104, scale="hijaz", root=60, rhythm="maqsum", tabl=True, anvil=True,
                          leads=["oud", "oud", "oud", "both", "ney", "ney", "oud", "both"],
                          m={"A1": "0:.5 1:.5 2:.5 1:.5 0:.5 1:.5 2:1 3:.5 2:.5 1:.5 2:.5 0:2",
                             "A2": "4:.5 5:.5 4:.5 2:.5 4:.5 5:.5 6:1 5:.5 4:.5 2:.5 1:.5 2:2",
                             "A3": "7:.5 6:.5 5:.5 4:.5 5:.5 4:.5 2:1 1:1 2:.5 1:.5 0:2",
                             "B1": "4:1 4:.5 5:.5 6:1 5:1 4:.5 5:.5 4:.5 2:.5 1:2",
                             "B2": "2:.5 4:.5 5:.5 7:.5 6:1 5:1 4:1 2:1 4:2"}),
    "level_tomb": dict(bpm=92, scale="kurd", root=64, rhythm="soft", riq=True, room=2.2,
                       leads=["stacc", "stacc", "stacc", "stacc", "ney", "ney", "stacc", "both"],
                       m={"A1": "0:.5 _:.5 0:.5 _:.5 1:.5 _:.5 2:.5 _:.5 1:.5 _:.5 0:.5 _:.5 -1:1 _:1",
                          "A2": "2:.5 _:.5 2:.5 _:.5 3:.5 _:.5 4:.5 _:.5 3:.5 2:.5 1:.5 2:.5 0:2",
                          "A3": "4:.5 3:.5 2:.5 1:.5 2:1 _:1 1:.5 0:.5 -1:.5 0:.5 0:2",
                          "B1": "4:2 5:1 4:1 3:2 2:2",
                          "B2": "5:2 6:1 5:1 4:1 3:1 4:2"}),
    "level_temple": dict(bpm=132, scale="hijaz", root=62, rhythm="malfuf", riq=True,
                         leads=["ney", "ney", "both", "ney", "oud", "both", "ney", "both"],
                         m={"A1": "4:.5 5:.25 4:.25 2:.5 4:.5 5:.5 4:.5 2:1 1:.5 2:.5 4:.5 2:.5 1:.5 0:.5 0:1",
                            "A2": "7:.5 6:.25 5:.25 4:.5 5:.5 6:.5 5:.5 4:1 5:.5 4:.5 2:.5 1:.5 2:2",
                            "A3": "4:.25 5:.25 4:.25 2:.25 1:.5 2:.5 4:1 5:1 4:.5 2:.5 1:.5 2:.5 0:2",
                            "B1": "0:.5 1:.5 2:.5 4:.5 5:1 4:1 5:.5 7:.5 5:.5 4:.5 2:2",
                            "B2": "4:.5 5:.5 7:1 8:.5 7:.5 5:1 4:.5 5:.5 4:.5 2:.5 4:2"}),
    "boss": dict(bpm=140, scale="hijaz", root=62, rhythm="saidi", tabl=True, brass=True, riq=True,
                 leads=["both", "both", "ney", "both", "oud", "both", "ney", "both"],
                 m={"A1": "0:.5 1:.5 2:1 1:.5 0:.5 -1:1 0:.5 1:.5 2:.5 4:.5 2:2",
                    "A2": "4:.5 5:.5 4:1 2:.5 1:.5 2:1 4:.5 5:.5 7:.5 5:.5 4:2",
                    "A3": "7:1 5:.5 4:.5 2:1 1:1 2:.5 1:.5 0:1 0:2",
                    "B1": "4:1 4:1 5:.5 4:.5 2:1 1:1 2:1 4:2",
                    "B2": "7:1 7:1 8:.5 7:.5 5:1 4:.5 5:.5 4:.5 2:.5 1:2"}),
}


def compose(name, s, copies=3):
    beat = 60.0 / s["bpm"]
    bar = 4 * beat
    loop = 16 * bar
    tr = Track(loop * copies + 1)
    sc, root = s["scale"], s["root"]
    hz = lambda deg, octv=0: midi_hz(root + semis(sc, deg) + 12 * octv)
    for c in range(copies):
        t0 = c * loop
        for p, sec in enumerate(FORM):
            mel = parse(s["m"][sec])
            assert abs(sum(b for _, b in mel) - 8) < 1e-6, (name, sec)
            pt = t0 + p * 2 * bar
            lead = s["leads"][p]
            # ---- melody ----
            t = pt
            prev = None
            for deg, b in mel:
                if deg is not None:
                    d = b * beat
                    f = hz(deg)
                    if lead in ("oud", "both"):
                        if b >= 1.0:  # risha tremolo on long notes
                            k = int(b * 4)
                            for j in range(k):
                                tr.add(oud(f, beat * 0.3, 0.75 if j else 1.0), t + j * beat / 4, pan=-0.15)
                        else:
                            tr.add(oud(f, d), t, pan=-0.15)
                    if lead in ("ney", "both"):
                        tr.add(ney(f * (2 if lead == "both" else 1), d * 0.97, 0.9,
                                   slide_from=(prev * (2 if lead == "both" else 1)) if prev else None),
                               t, pan=0.15, wet=0.35)
                    if lead == "qanun":
                        tr.add(qanun(f * 2, d), t, pan=0.2)
                        if b >= 1:
                            tr.add(qanun(f * 2, d, 0.5), t + beat / 2, pan=0.2)
                    if lead == "marimba":
                        tr.add(marimba(f * 2, d), t, pan=0.1)
                    if lead == "bell":
                        tr.add(bell(f * 2, d), t, pan=0.1, wet=0.45)
                    if lead == "stacc":
                        tr.add(oud(f, min(d, beat * 0.35), 1.0), t, pan=-0.1)
                    prev = f
                t += b * beat
            # ---- harmony and rhythm per bar ----
            for bi in range(2):
                bt = pt + bi * bar
                bar_idx = p * 2 + bi
                ch = CHORDS[sec][bi]
                rf = midi_hz(root + semis(sc, ch) - 12)
                tr.add(pad([rf, rf * 1.5, rf * 2], bar, 0.8 if not s.get("soft") else 0.6), bt, wet=0.5)
                last = bar_idx in (7, 15)
                patt = RHYTHMS["fill" if last and s["rhythm"] != "soft" else s["rhythm"]]
                for st, ch_ in enumerate(patt):
                    at = bt + st * beat / 4
                    accent = 1.0 if st == 0 else 0.8
                    if ch_ == "D":
                        tr.add(dum(0.9 * accent), at, gain=0.75, wet=0.12)
                        tr.add(oud(rf, beat * 0.5, 0.8), at, pan=-0.25, gain=0.7)
                    elif ch_ == "T":
                        tr.add(tek(0.8 * accent), at, pan=0.2, gain=0.7, wet=0.12)
                    elif ch_ == "k":
                        tr.add(ka(0.8), at, pan=0.25, gain=0.6, wet=0.1)
                if s.get("riq"):
                    for st in range(1, 16, 2):
                        tr.add(riq(0.5 if st % 4 == 1 else 0.3), bt + st * beat / 4, pan=0.4, wet=0.1)
                if s.get("tabl") and bi == 0:
                    tr.add(tabl(1.0), bt, gain=0.8, wet=0.2)
                    tr.add(tabl(0.7), bt + 2 * beat, gain=0.8, wet=0.2)
                if s.get("anvil") and bar_idx % 2 == 1:
                    tr.add(anvil(0.6, 1320 if sc == "kurd" else 990), bt + 3 * beat, pan=0.35, wet=0.4)
                if s.get("arp"):
                    arp = [0, 2, 4, 7, 4, 2, 4, 7]
                    for k, a in enumerate(arp):
                        tr.add(bell(midi_hz(root + semis(sc, ch + a) + 12), beat * 0.5, 0.35),
                               bt + k * beat / 2, pan=-0.35 + 0.1 * (k % 4), wet=0.5)
                if s.get("brass"):
                    tr.add(brass([rf * 2, rf * 3, rf * 4], beat * 0.6), bt, gain=0.9)
                    tr.add(brass([rf * 2, rf * 3, rf * 4], beat * 0.3, 0.7), bt + 2.5 * beat, gain=0.9)
    st = tr.render(room=s.get("room", 1.6))
    a = int(loop * SR)
    st = st[a:2 * a]
    return master(st)


def write_ogg(path, st):
    raw = (np.clip(st, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2",
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "5", path], input=raw, check=True)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/music"
    only = sys.argv[2:] or list(SONGS)
    os.makedirs(out, exist_ok=True)
    for name in only:
        st = compose(name, SONGS[name])
        write_ogg(os.path.join(out, name + ".ogg"), st)
        print(name, round(len(st) / SR, 1), "s")
