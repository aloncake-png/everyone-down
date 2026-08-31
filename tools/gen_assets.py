# Dig Game asset foundry — draws all pixel sprites with PIL.
# Craft rules: hue-shifted ramps, warm upper-left light, chunky clusters, no pure black.
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")

# ---------- PALETTE (hue-shifted ramps, dark->light) ----------
P = {
    # dirt: purple shadows -> warm tan light
    "dirt0": (26, 15, 28), "dirt1": (46, 28, 46), "dirt2": (74, 45, 52),
    "dirt3": (107, 66, 52), "dirt4": (143, 95, 62), "dirt5": (181, 129, 82), "dirt6": (219, 164, 99),
    # rock: cool blue-greys
    "rock0": (34, 32, 48), "rock1": (58, 60, 82), "rock2": (91, 96, 122), "rock3": (133, 140, 165),
    # brass / steampunk metal
    "brass0": (61, 38, 20), "brass1": (122, 82, 34), "brass2": (168, 117, 44), "brass3": (217, 164, 65), "brass4": (242, 207, 110),
    "copper0": (96, 42, 34), "copper1": (176, 92, 56), "copper2": (224, 138, 82),
    # verdigris / teal accents
    "teal0": (24, 66, 66), "teal1": (47, 140, 116), "teal2": (94, 205, 168),
    # water
    "wat0": (22, 50, 76), "wat1": (30, 86, 124), "wat2": (46, 134, 171), "wat3": (85, 193, 224), "wat4": (190, 240, 248),
    # trogs (dark maroon bodies, hot glow)
    "trog0": (56, 20, 36), "trog1": (94, 32, 48), "trog2": (140, 46, 54), "glow0": (224, 82, 48), "glow1": (255, 143, 77), "glow2": (255, 206, 121),
    # ore
    "iron0": (74, 52, 104), "iron1": (122, 88, 158), "iron2": (168, 130, 205),
    "rare0": (168, 44, 106), "rare1": (222, 90, 154), "rare2": (255, 154, 201),
    # people
    "skin0": (176, 116, 82), "skin1": (233, 178, 128),
    "cloth0": (36, 84, 90), "cloth1": (62, 138, 142),
    "clothR0": (128, 46, 40), "clothR1": (190, 84, 62),
    "leath0": (66, 44, 34), "leath1": (110, 76, 52),
    # greens (dead-ish topside + farm crops)
    "grn0": (46, 62, 30), "grn1": (78, 100, 44), "grn2": (122, 148, 62),
    # sky (apocalypse)
    "sky0": (24, 13, 34), "sky1": (66, 22, 48), "sky2": (118, 35, 52), "sky3": (179, 64, 47), "sky4": (232, 118, 58), "sky5": (255, 196, 94),
    # misc
    "ink": (26, 18, 28), "white": (242, 230, 208), "lamp": (255, 214, 140),
}

def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def px(d, x, y, c):
    d.point((x, y), fill=P[c] if isinstance(c, str) else c)

def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=P[c] if isinstance(c, str) else c)

def save(im, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)
    print("wrote", os.path.relpath(p, ROOT))

# deterministic scatter (no random module — stable builds)
def scatter(seed, n, w, h):
    pts = []
    v = seed * 2654435761 % 4294967296
    for _ in range(n):
        v = (v * 1103515245 + 12345) % 2147483648
        x = v % w
        v = (v * 1103515245 + 12345) % 2147483648
        y = v % h
        pts.append((x, y))
    return pts

T = 16  # tile size

# ---------- TILES ----------
def tile_dirt(variant):
    im = img(T, T); d = ImageDraw.Draw(im)
    rect(d, 0, 0, T-1, T-1, "dirt3")
    # big soft clusters of light (upper-left) and shadow (lower-right)
    for (x, y) in scatter(variant+1, 14, T, T):
        c = "dirt4" if (x + y) < 16 else "dirt2"
        rect(d, x, y, min(x+2, T-1), min(y+1, T-1), c)
    for (x, y) in scatter(variant+7, 5, T, T):
        px(d, x, y, "dirt1")
    # subtle top edge light
    for x in range(0, T, 3):
        px(d, x, 0, "dirt4")
    return im

def tile_cave(variant):
    # dug-out tunnel background: readable warm-dark stone, lamp-friendly
    im = img(T, T); d = ImageDraw.Draw(im)
    rect(d, 0, 0, T-1, T-1, (64, 44, 56, 255))
    for (x, y) in scatter(variant+3, 10, T, T):
        rect(d, x, y, min(x+1, T-1), y, (84, 58, 66, 255))
    for (x, y) in scatter(variant+11, 6, T, T):
        px(d, x, y, "dirt1")
    for (x, y) in scatter(variant+17, 3, T, T):
        px(d, x, y, (100, 72, 74, 255))
    return im

def tile_rock(variant):
    im = img(T, T); d = ImageDraw.Draw(im)
    rect(d, 0, 0, T-1, T-1, "rock1")
    # chunky facets
    rect(d, 1, 1, 7, 6, "rock2"); rect(d, 9, 8, 14, 13, "rock2")
    rect(d, 2, 2, 4, 3, "rock3"); rect(d, 10, 9, 11, 10, "rock3")
    rect(d, 8, 1, 14, 5, "rock1"); rect(d, 0, 9, 6, 15, "rock0")
    rect(d, 1, 10, 3, 12, "rock1")
    for (x, y) in scatter(variant+5, 4, T, T):
        px(d, x, y, "rock0")
    return im

def tile_ore(kind, variant):
    # ore VEIN tile: rock base with a bold glowing seam across the middle (reads like water does)
    base = tile_rock(variant + 20)
    d = ImageDraw.Draw(base)
    c0, c1, c2 = (kind+"0", kind+"1", kind+"2")
    # continuous seam band (edge-to-edge so neighboring vein tiles connect)
    rect(d, 0, 6, 15, 10, c0)
    # chunky nuggets in the band
    spots = [(1, 6), (6, 7), (11, 6)] if variant % 2 == 0 else [(2, 7), (8, 6), (13, 7)]
    for (x, y) in spots:
        rect(d, x, y, min(x+3, 15), min(y+3, 10), c1)
        rect(d, x, y, min(x+1, 15), y+1, c2)
    # seam sparkle + soft top edge
    for x in range(0, 16, 5):
        px(d, (x + variant * 2) % 16, 5, c1)
        px(d, (x + variant * 3) % 16, 11, c0)
    return base

def tile_water(frame):
    im = img(T, T); d = ImageDraw.Draw(im)
    rect(d, 0, 0, T-1, T-1, "wat1")
    rect(d, 0, 0, T-1, 2, "wat2")
    # ripple highlights, shift by frame
    off = frame * 2
    for i, y in enumerate([1, 5, 9, 13]):
        x0 = (i * 5 + off) % T
        for dx in range(4):
            px(d, (x0+dx) % T, y, "wat3" if dx < 3 else "wat4")
    for (x, y) in scatter(4, 5, T, T):
        px(d, x, min(y+4, 15), "wat0")
    return im

def tile_trog_tunnel(variant):
    im = img(T, T); d = ImageDraw.Draw(im)
    rect(d, 0, 0, T-1, T-1, (38, 12, 24, 255))
    for (x, y) in scatter(variant+9, 7, T, T):
        px(d, x, y, "trog0")
    for (x, y) in scatter(variant+13, 3, T, T):
        px(d, x, y, "glow0")  # ember flecks
    return im

def tile_surface(variant):
    # topside ground strip: dead grass over dirt
    im = tile_dirt(variant + 40)
    d = ImageDraw.Draw(im)
    rect(d, 0, 0, T-1, 2, "grn0")
    for x in range(T):
        if (x * 7 + variant) % 3 != 0:
            px(d, x, 0, "grn1")
        if (x * 5 + variant) % 4 == 0:
            px(d, x, 3, "grn0")
    for x in range(0, T, 4):
        px(d, (x + variant) % T, 1, "grn2")
    return im

def gen_tiles():
    for v in range(4):
        save(tile_dirt(v), "tiles", f"dirt_{v}.png")
        save(tile_cave(v), "tiles", f"cave_{v}.png")
        save(tile_rock(v), "tiles", f"rock_{v}.png")
        save(tile_surface(v), "tiles", f"surface_{v}.png")
        save(tile_trog_tunnel(v), "tiles", f"trog_{v}.png")
    for v in range(2):
        save(tile_ore("iron", v), "tiles", f"iron_{v}.png")
        save(tile_ore("rare", v), "tiles", f"rare_{v}.png")
    for f in range(3):
        save(tile_water(f), "tiles", f"water_{f}.png")

# ---------- DUDES (16x16 canvas, ~13px tall, feet at y=15) ----------
def dude_base(d, body="cloth", flip=False):
    """Chunky little worker: cap, face, jacket, legs. Light upper-left."""
    B0, B1 = body+"0", body+"1"
    X = (lambda x: 15 - x) if flip else (lambda x: x)
    # legs
    rect(d, X(5), 12, X(6), 14, "leath0"); rect(d, X(9), 12, X(10), 14, "leath0")
    px(d, X(5), 12, "leath1")
    # boots
    rect(d, X(4), 15, X(6), 15, "ink"); rect(d, X(9), 15, X(11), 15, "ink")
    # torso (jacket)
    rect(d, X(4), 7, X(11), 11, B0)
    rect(d, X(4), 7, X(7), 9, B1)  # upper-left light
    # arms
    rect(d, X(3), 8, X(4), 10, B0); rect(d, X(11), 8, X(12), 10, B0)
    # head
    rect(d, X(5), 2, X(10), 6, "skin1")
    rect(d, X(9), 4, X(10), 6, "skin0")  # right shade
    # cap (brass miner cap with lamp)
    rect(d, X(4), 1, X(11), 2, "brass2")
    rect(d, X(4), 0, X(10), 0, "brass3")
    px(d, X(11) if not flip else X(11), 1, "brass1")
    px(d, X(7), 0, "lamp"); px(d, X(8), 0, "lamp")  # headlamp
    # eyes
    px(d, X(6), 4, "ink"); px(d, X(9), 4, "ink")

def dude_walk(frame, body="cloth"):
    im = img(16, 16); d = ImageDraw.Draw(im)
    dude_base(d, body)
    # legs swap per frame
    if frame == 1:
        rect(d, 5, 12, 6, 15, (0, 0, 0, 0)); rect(d, 9, 12, 10, 15, (0, 0, 0, 0))
        rect(d, 4, 12, 5, 14, "leath0"); rect(d, 10, 12, 11, 14, "leath0")
        rect(d, 3, 15, 5, 15, "ink"); rect(d, 10, 15, 12, 15, "ink")
    return im

def dude_dig(frame):
    """Pickaxe swing right. frame0 = raised, frame1 = struck."""
    im = img(20, 18); d = ImageDraw.Draw(im)
    # body shifted left, feet y=17
    B0, B1 = "cloth0", "cloth1"
    rect(d, 3, 14, 4, 16, "leath0"); rect(d, 7, 14, 8, 16, "leath0")
    rect(d, 2, 17, 4, 17, "ink"); rect(d, 7, 17, 9, 17, "ink")
    rect(d, 2, 9, 9, 13, B0); rect(d, 2, 9, 5, 11, B1)
    rect(d, 3, 4, 8, 8, "skin1"); rect(d, 7, 6, 8, 8, "skin0")
    rect(d, 2, 3, 9, 4, "brass2"); rect(d, 2, 2, 8, 2, "brass3")
    px(d, 5, 2, "lamp"); px(d, 6, 2, "lamp")
    px(d, 4, 6, "ink"); px(d, 7, 6, "ink")
    if frame == 0:  # raised overhead
        rect(d, 9, 6, 10, 9, "skin1")           # arms up
        rect(d, 11, 1, 12, 7, "leath1")          # handle
        rect(d, 9, 0, 15, 1, "rock3")            # pick head
        px(d, 9, 1, "rock2"); px(d, 15, 1, "rock2")
    else:  # struck forward-down
        rect(d, 9, 10, 11, 11, "skin1")
        rect(d, 12, 8, 16, 12, "leath1")         # handle diagonal
        rect(d, 12, 8, 13, 9, "leath1")
        rect(d, 16, 11, 18, 15, "rock3")         # pick head biting ground
        px(d, 17, 15, "rock2")
    return im

def dude_soldier(frame):
    """Armed dude: red coat, brass helm, rifle."""
    im = img(18, 16); d = ImageDraw.Draw(im)
    dude_base(d, "clothR")
    # brass helmet over cap
    rect(d, 4, 0, 11, 2, "brass2"); rect(d, 4, 0, 8, 1, "brass3")
    px(d, 3, 1, "brass1"); px(d, 12, 1, "brass1")
    # rifle held right
    rect(d, 12, 8, 17, 8, "leath1"); rect(d, 12, 9, 13, 9, "leath0")
    px(d, 17, 8, "rock3")
    if frame == 1:  # muzzle flash frame
        px(d, 18-1, 7, "glow2")
    return im

def gen_dudes():
    for f in range(2):
        save(dude_walk(f, "cloth"), "sprites", f"worker_walk_{f}.png")
        save(dude_walk(f, "leath"), "sprites", f"free_walk_{f}.png")
        save(dude_dig(f), "sprites", f"worker_dig_{f}.png")
        save(dude_soldier(f), "sprites", f"soldier_{f}.png")

# ---------- TROGS ----------
def trog(frame):
    """Crawly maroon gremlin, glowing eyes + back crest. 16x12, belly-low."""
    im = img(16, 12); d = ImageDraw.Draw(im)
    o = frame  # scuttle bob
    # body blob
    rect(d, 2, 5+o, 12, 9, "trog1")
    rect(d, 2, 5+o, 7, 7, "trog2")
    rect(d, 3, 4+o, 10, 5+o, "trog1")
    # head
    rect(d, 10, 3+o, 14, 8, "trog2")
    rect(d, 10, 3+o, 12, 5+o, "trog2")
    # jaw
    rect(d, 13, 7, 15, 8, "trog1")
    # glowing eyes
    px(d, 12, 4+o, "glow1"); px(d, 13, 4+o, "glow2")
    # crest spines (ember-lit)
    for i, x in enumerate([3, 6, 9]):
        px(d, x, 3+o - (i % 2), "glow0")
        px(d, x, 4+o - (i % 2), "trog0")
    # legs
    legs = [(3, 10), (7, 10), (11, 10)] if frame == 0 else [(4, 10), (8, 10), (12, 10)]
    for (x, y) in legs:
        rect(d, x, y, x+1, 11, "trog0")
    return im

def trog_big(frame):
    """Brute variant for the swarm: 24x18."""
    im = img(24, 18); d = ImageDraw.Draw(im)
    o = frame
    rect(d, 2, 7+o, 18, 14, "trog1")
    rect(d, 2, 7+o, 10, 10, "trog2")
    rect(d, 4, 5+o, 15, 7+o, "trog1")
    rect(d, 15, 4+o, 21, 12, "trog2")
    rect(d, 20, 10, 23, 12, "trog1")  # jaw
    px(d, 18, 6+o, "glow1"); rect(d, 19, 6+o, 20, 6+o, "glow2")
    for i, x in enumerate([4, 8, 12]):
        rect(d, x, 3+o-(i % 2), x, 5+o, "glow0")
        px(d, x, 5+o, "trog0")
    legs = [(4, 15), (9, 15), (14, 15)] if frame == 0 else [(5, 15), (10, 15), (15, 15)]
    for (x, y) in legs:
        rect(d, x, y, x+2, 17, "trog0")
    return im

def gen_trogs():
    for f in range(2):
        save(trog(f), "sprites", f"trog_{f}.png")
        save(trog_big(f), "sprites", f"trog_big_{f}.png")

if __name__ == "__main__":
    gen_tiles()
    gen_dudes()
    gen_trogs()
    print("PART 1 DONE")
