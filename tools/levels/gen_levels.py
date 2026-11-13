"""Generates the 100-level journey for Sandfall Rescue and writes scripts/levels_data.gd.

Every layout is checked:
- the debris starts in the shaft at the top and is one connected piece
- the bottom row is always free and all gems form ONE connected area
- no gem cell is dead (each can be part of a line of 3)
- no cross / plus shapes (a bar sticking out both sides of a vertical stem)
- the hero's room beside the shaft is wide enough (wider still on boss levels)
"""
import json, random
from collections import deque

COLS, ROWS = 8, 9
CELL = 7
WORLDS = [
    # name, map colour key, new mode, boss
    ("Sand Pit", "sand", "drain", "scorpion"),
    ("Iron Vault", "iron", "iron", "golem"),
    ("Crystal Cave", "crystal", "chain", "spider"),
    ("Lava Forge", "emerald", "crust", "salamander"),
    ("Mummy's Tomb", "tomb", "wrap", "mummy"),
    ("Cobra Temple", "temple", "race", "cobra"),
    ("Valley of Kings", "tomb", "jars", "anubis"),
    ("Obsidian Mines", "emerald", "glass", "beetle"),
    ("Temple of Ra", "sand", "runes", "sphinx"),
    ("Pharaoh's Vault", "crystal", "curse", "pharaoh"),
]
MODE_THEME = {"drain": "sand", "iron": "iron", "chain": "crystal", "crust": "emerald", "wrap": "tomb", "race": "temple",
              "jars": "tomb", "glass": "emerald", "runes": "sand", "curse": "crystal"}
GOAL_BONUS = {"wrap": 2, "jars": 4, "glass": 4, "runes": 5, "curse": 4}   # extra moves for the mode's own goal
INFLOW = 1.5   # extra moves for the debris the source keeps pouring in
PER_MOVE = {"drain": 104.0, "iron": 116.0, "chain": 110.0, "crust": 92.0, "wrap": 118.0}   # grains cleared per move, from play tests


def cells_of(rows):
    return {(c, r) for r, (a, b) in rows.items() for c in range(a, b + 1)}


def check(rows, shaft, boss):
    R = cells_of(rows)
    if any(r >= ROWS - 1 for _, r in R):
        return None
    gems = {(c, r) for c in range(COLS) for r in range(ROWS)} - R
    # one gem area
    start = next(iter(gems)); seen = {start}; q = deque([start])
    while q:
        c, r = q.popleft()
        for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c + dc, r + dr)
            if n in gems and n not in seen:
                seen.add(n); q.append(n)
    if len(seen) != len(gems):
        return None

    def run(c, r, dx, dy):
        n = 1; x, y = c + dx, r + dy
        while (x, y) in gems: n += 1; x += dx; y += dy
        x, y = c - dx, r - dy
        while (x, y) in gems: n += 1; x -= dx; y -= dy
        return n
    if any(run(c, r, 1, 0) < 3 and run(c, r, 0, 1) < 3 for c, r in gems):
        return None
    # no crosses: a row wider on BOTH sides than the rows above and below it
    rs = sorted(rows)
    for r in rs:
        if r - 1 in rows and r + 1 in rows:
            a, b = rows[r]; au, bu = rows[r - 1]; ad, bd = rows[r + 1]
            if a < min(au, ad) and b > max(bu, bd):
                return None
    n = len(R)
    if not (14 <= n <= 30):
        return None
    s, w = shaft
    left_w = s * CELL - 1
    right_w = COLS * CELL - (s + w) * CELL - 1
    need = 30 if boss else 20
    side = "left" if left_w >= right_w else "right"
    if max(left_w, right_w) < need:
        return None
    return side


def walk(rng, boss):
    w = 2 if rng.random() < 0.8 else 3
    s = rng.randint(0, COLS - w)
    rows = {}
    top = rng.randint(2, 3)
    for r in range(top):
        rows[r] = (s, s + w - 1)
    a, b = s, s + w - 1
    r = top
    bottom = rng.randint(5, 7)
    while r <= bottom:
        h = rng.randint(1, 2)
        width = rng.choice([1, 2, 2, 2, 3, 3, 4])
        shift = rng.choice([-2, -1, -1, 0, 1, 1, 2])
        na = max(0, min(COLS - width, a + shift))
        nb = na + width - 1
        if nb < a or na > b:          # keep the segment touching the one above
            na = max(0, min(COLS - width, a)); nb = na + width - 1
        for k in range(h):
            if r + k <= bottom:
                rows[r + k] = (na, nb)
        a, b = na, nb
        r += h
    return rows, (s, w)


def to_rects(rows):
    rects = []
    for r in sorted(rows):
        a, b = rows[r]
        if rects and rects[-1][0] == a and rects[-1][1] == b and rects[-1][3] == r - 1:
            rects[-1][3] = r
        else:
            rects.append([a, b, r, r])
    return rects


def make_layouts(seed, n_normal, n_boss):
    rng = random.Random(seed)
    normal, boss, keys = [], [], set()
    tries = 0
    while (len(normal) < n_normal or len(boss) < n_boss) and tries < 400000:
        tries += 1
        want_boss = len(boss) < n_boss and rng.random() < 0.35
        rows, shaft = walk(rng, want_boss)
        side = check(rows, shaft, want_boss)
        if side is None:
            continue
        key = tuple(sorted(rows.items()))
        if key in keys:
            continue
        keys.add(key)
        item = {"rows": rows, "shaft": shaft, "side": side, "n": len(cells_of(rows))}
        (boss if want_boss else normal).append(item)
    assert len(normal) >= n_normal and len(boss) >= n_boss, (len(normal), len(boss))
    return normal, boss


# the hand-made shapes from the first six levels open the game
CLASSIC = [
    ({0: (3, 5), 1: (3, 5), 2: (3, 5), 3: (4, 4), 4: (4, 4), 5: (3, 5), 6: (3, 5), 7: (2, 6)}, (3, 3)),   # hourglass
    ({0: (3, 4), 1: (3, 4), 2: (3, 4), 3: (3, 4), 4: (2, 5), 5: (2, 5), 6: (2, 5)}, (3, 2)),              # teardrop
    ({0: (5, 6), 1: (5, 6), 2: (5, 6), 3: (4, 5), 4: (4, 5), 5: (3, 4), 6: (3, 4), 7: (2, 3)}, (5, 2)),   # staircase
    ({0: (1, 2), 1: (1, 2), 2: (1, 2), 3: (2, 4), 4: (2, 4), 5: (4, 5), 6: (4, 5), 7: (5, 6)}, (1, 2)),   # zigzag
    ({0: (2, 3), 1: (2, 3), 2: (2, 3), 3: (1, 4), 4: (1, 4), 5: (1, 6), 6: (1, 6)}, (2, 2)),              # pyramid
]


def main(out_path):
    normal, boss = make_layouts(20261111, 120, 14)
    rng = random.Random(77)
    rng.shuffle(normal)
    normal.sort(key=lambda it: it["n"] + rng.random() * 8)   # smaller shapes first, with some mixing
    classic = []
    for rows, shaft in CLASSIC:
        side = check(rows, shaft, False)
        assert side, rows
        classic.append({"rows": rows, "shaft": shaft, "side": side, "n": len(cells_of(rows))})
    levels = []
    modes_open = []
    ni = 0
    bi = 0
    for wi, (wname, wkey, new_mode, boss_kind) in enumerate(WORLDS):
        if new_mode:
            modes_open.append(new_mode)
        for li in range(10):
            idx = wi * 10 + li
            is_boss = li == 9
            # which rule this level plays by
            if new_mode and li in (0, 1, 2, 4, 6, 9):
                mode = new_mode
            else:
                pool = [m for m in modes_open if m != "race"] or ["drain"]
                if "race" in modes_open and rng.random() < 0.15:
                    pool = ["race"]
                mode = rng.choice(pool)
            if is_boss:
                lay = boss[bi % len(boss)]; bi += 1
            elif idx < len(classic) and wi == 0 and li < 5:
                lay = classic[li]
            else:
                lay = normal[ni % len(normal)]; ni += 1
            rows, (s, w), side = lay["rows"], lay["shaft"], lay["side"]
            n = lay["n"]
            # difficulty: generous at the start of a world, tighter towards the boss
            grains = n * 49 + w * 7 * 38
            curve = 1.18 - 0.03 * li
            if li in (3, 7):
                curve += 0.15                    # breather levels
            if is_boss:
                curve = 1.05
            curve *= max(0.86, 1.0 - 0.016 * wi)
            if idx < 3:
                curve *= 1.3                    # first levels teach the game
            moves = max(10, round(grains / PER_MOVE.get(mode, 104.0) * curve * INFLOW))
            moves += GOAL_BONUS.get(mode, 0)
            time = round(grains / 26.0 * curve) if mode == "race" else 70 + moves * 7
            theme = MODE_THEME[mode] if wi < 6 else (wkey if mode != "iron" else "iron")
            if mode == "race":
                theme = "temple"
            levels.append({
                "n": idx + 1, "world": wi, "name": wname, "mode": mode, "theme": theme,
                "moves": moves, "time": time, "shaft": [s, s + w - 1], "room": side, "fill_top": 6,
                "rubble": to_rects(rows), "hazard": boss_kind if is_boss else "spikes", "boss": is_boss,
            })
    worlds = [{"name": w[0], "theme": w[1], "boss": w[3], "mode": w[2] or ""} for w in WORLDS]
    with open(out_path, "w") as f:
        f.write("## Generated by art/levels/gen_levels.py - do not edit by hand.\nextends RefCounted\n\n")
        f.write("const WORLDS := " + json.dumps(worlds) + "\n\n")
        f.write("const LEVELS := [\n")
        for lv in levels:
            f.write("\t" + json.dumps(lv).replace("true", "true").replace("false", "false") + ",\n")
        f.write("]\n")
    # print a summary
    for lv in levels:
        if lv["n"] <= 12 or lv["boss"] or lv["n"] % 10 == 5:
            print(lv["n"], lv["name"], lv["mode"], lv["theme"], "moves", lv["moves"], "boss" if lv["boss"] else "", lv["hazard"], lv["room"])
    print(len(levels), "levels")


if __name__ == "__main__":
    import sys
    main(sys.argv[1])
