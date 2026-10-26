# LEMMINGS APOCALYPSE (the sign-economy pivot) — asset foundry.
# Every sprite for the "signs" mode is drawn here with PIL. Edit + rerun to change anything.
# Output: assets/signs/
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "signs")
os.makedirs(ROOT, exist_ok=True)

P = {
    "dirt0": (38, 24, 22), "dirt1": (62, 40, 32), "dirt2": (92, 60, 42), "dirt3": (122, 84, 54), "dirt4": (150, 108, 66),
    "rock0": (40, 42, 56), "rock1": (66, 70, 90), "rock2": (98, 104, 128), "rock3": (138, 146, 170),
    "dug0": (22, 16, 18), "dug1": (34, 26, 26), "dug2": (48, 36, 34),
    "plank0": (70, 46, 26), "plank1": (118, 80, 42), "plank2": (168, 120, 62),
    "sand0": (110, 96, 60), "sand1": (160, 142, 90), "sand2": (200, 182, 122),
    "bug0": (44, 14, 30), "bug1": (84, 24, 46), "bug2": (132, 36, 58), "bug3": (190, 60, 70),
    "slime0": (54, 22, 40), "slime1": (92, 34, 64), "slime2": (140, 52, 92),
    "gas": (120, 200, 60),
    "sky0": (36, 30, 44), "sky1": (74, 54, 62), "sky2": (120, 84, 70), "sky3": (170, 122, 84),
    "grass0": (56, 62, 34), "grass1": (92, 100, 48),
    "skin": (232, 180, 130), "skin0": (178, 120, 84),
    "hair": (72, 190, 80), "hair0": (40, 120, 50),
    "robe0": (36, 60, 130), "robe1": (62, 96, 190),
    "khaki0": (86, 82, 44), "khaki1": (134, 128, 70), "khaki2": (172, 164, 98),
    "over0": (84, 52, 30), "over1": (134, 84, 44),
    "helm0": (60, 66, 50), "helm1": (104, 112, 84),
    "red0": (150, 34, 34), "red1": (214, 64, 54),
    "brass0": (120, 82, 34), "brass1": (200, 150, 64), "brass2": (240, 206, 110),
    "steel0": (70, 72, 84), "steel1": (130, 134, 150), "steel2": (196, 200, 214),
    "ink": (22, 16, 20), "white": (246, 238, 220), "paper": (232, 214, 170), "paper0": (184, 160, 110),
    "green": (90, 200, 90), "yellow": (250, 210, 70), "orange": (240, 140, 50), "blue": (90, 150, 240), "cyan": (110, 220, 230), "pink": (240, 110, 180),
}

def C(c): return P[c] if isinstance(c, str) else c
def img(w, h): return Image.new("RGBA", (w, h), (0, 0, 0, 0))
def px(d, x, y, c): d.point((x, y), fill=C(c))
def rect(d, x0, y0, x1, y1, c): d.rectangle([x0, y0, x1, y1], fill=C(c))
def line(d, pts, c, w=1): d.line(pts, fill=C(c), width=w)
def ell(d, x0, y0, x1, y1, c): d.ellipse([x0, y0, x1, y1], fill=C(c))
def save(im, name):
    im.save(os.path.join(ROOT, name)); print("wrote", name)

def hash2(x, y, s=0):
    v = (x * 374761393 + y * 668265263 + s * 982451653) & 0xFFFFFFFF
    v = (v ^ (v >> 13)) * 1274126177 & 0xFFFFFFFF
    return (v ^ (v >> 16)) & 0xFFFF

# ---------------- TILES (16x16) ----------------
T = 16
def tile_dirt(seed):
    im = img(T, T); d = ImageDraw.Draw(im)
    for y in range(T):
        for x in range(T):
            h = hash2(x, y, seed) % 100
            c = "dirt2" if h < 62 else ("dirt1" if h < 80 else ("dirt3" if h < 94 else "dirt4"))
            px(d, x, y, c)
    for i in range(3):
        h = hash2(i, seed, 7); px(d, h % T, (h >> 4) % T, "rock1")
    return im

def tile_rock(seed):
    im = img(T, T); d = ImageDraw.Draw(im)
    for y in range(T):
        for x in range(T):
            h = hash2(x, y, seed + 50) % 100
            c = "rock1" if h < 60 else ("rock0" if h < 78 else ("rock2" if h < 94 else "rock3"))
            px(d, x, y, c)
    line(d, [(2, 3), (7, 9), (13, 11)], "rock0")
    return im

def tile_dug(seed):
    im = img(T, T); d = ImageDraw.Draw(im)
    for y in range(T):
        for x in range(T):
            h = hash2(x, y, seed + 90) % 100
            px(d, x, y, "dug1" if h < 70 else ("dug0" if h < 90 else "dug2"))
    return im

def tile_bugdug(seed):
    im = img(T, T); d = ImageDraw.Draw(im)
    for y in range(T):
        for x in range(T):
            h = hash2(x, y, seed + 130) % 100
            px(d, x, y, "slime0" if h < 66 else ("bug0" if h < 86 else "slime1"))
    for i in range(2):
        h = hash2(i, seed, 11); ell(d, h % 12, (h >> 4) % 12, h % 12 + 3, (h >> 4) % 12 + 2, "slime2")
    return im

def tile_sky(seed):
    im = img(T, T); d = ImageDraw.Draw(im)
    rect(d, 0, 0, T, T, "sky0")
    for i in range(2):
        h = hash2(i, seed, 3); px(d, h % T, (h >> 4) % T, "sky1")
    return im

def tile_surface(seed):
    im = tile_dirt(seed); d = ImageDraw.Draw(im)
    rect(d, 0, 0, T, 2, "grass0")
    for x in range(T):
        if hash2(x, seed, 5) % 3 == 0: px(d, x, 2, "grass1")
        if hash2(x, seed, 6) % 4 == 0: px(d, x, 0, "grass1")
    # barbed wire posts
    if seed % 2 == 0:
        line(d, [(4, -1), (4, 2)], "plank1"); line(d, [(12, -1), (12, 2)], "plank1")
    return im

for s in range(4):
    save(tile_dirt(s), "t_dirt_%d.png" % s)
    save(tile_rock(s), "t_rock_%d.png" % s)
    save(tile_dug(s), "t_dug_%d.png" % s)
    save(tile_bugdug(s), "t_bugdug_%d.png" % s)
    save(tile_sky(s), "t_sky_%d.png" % s)
    save(tile_surface(s), "t_surf_%d.png" % s)

# edge overlays for lemming-dug cells (straight-edged trench look)
im = img(T, T); d = ImageDraw.Draw(im)
rect(d, 0, 0, T, 2, "plank1"); rect(d, 0, 0, T, 0, "plank2"); rect(d, 0, 2, T, 2, "plank0")
for x in (3, 9, 14): px(d, x, 1, "ink")
save(im, "e_top.png")
im = img(T, T); d = ImageDraw.Draw(im)
rect(d, 0, 13, T, 15, "plank0"); rect(d, 0, 13, T, 13, "plank1")
for x in range(0, T, 4): rect(d, x, 14, x + 1, 15, "plank1")
save(im, "e_floor.png")
im = img(T, T); d = ImageDraw.Draw(im)
rect(d, 0, 0, 2, T, "sand1"); rect(d, 0, 0, 0, T, "sand2")
for y in range(0, T, 4): line(d, [(0, y), (2, y)], "sand0")
save(im, "e_left.png")
save(im.transpose(Image.FLIP_LEFT_RIGHT), "e_right.png")
# bug tunnel soft edge (rounded blob feel)
im = img(T, T); d = ImageDraw.Draw(im)
for y in range(T):
    for x in range(T):
        if hash2(x, y, 999) % 100 < 50 - y * 3: px(d, x, y, "bug0")
save(im, "e_bug_top.png")
save(im.transpose(Image.FLIP_TOP_BOTTOM), "e_bug_bot.png")
save(im.transpose(Image.ROTATE_90), "e_bug_left.png")
save(im.transpose(Image.ROTATE_270), "e_bug_right.png")

# special spots
im = img(T, T); d = ImageDraw.Draw(im)
rect(d, 2, 10, 13, 15, "steel0"); rect(d, 4, 7, 11, 10, "steel1"); rect(d, 7, 2, 8, 7, "steel2"); px(d, 7, 1, "yellow")
save(im, "spot_flag.png")
im = img(T, T); d = ImageDraw.Draw(im)
rect(d, 1, 9, 14, 15, "paper0"); rect(d, 3, 4, 12, 9, "paper"); rect(d, 5, 6, 6, 8, "ink"); rect(d, 9, 6, 10, 8, "ink"); rect(d, 2, 3, 13, 3, "plank1")
save(im, "spot_inst.png")

# ---------------- LEMMINGS (12x16, 2 walk frames) ----------------
def lemming(kind, frame):
    im = img(12, 16); d = ImageDraw.Draw(im)
    # feet
    fy = 14
    if frame == 0:
        rect(d, 2, fy, 4, 15, "ink"); rect(d, 7, fy, 9, 15, "ink")
    else:
        rect(d, 3, fy, 5, 15, "ink"); rect(d, 6, fy, 8, 15, "ink")
    # body
    if kind == "civ":
        rect(d, 3, 7, 8, 13, "robe0"); rect(d, 4, 7, 7, 11, "robe1")
    elif kind == "sol":
        rect(d, 3, 7, 8, 13, "khaki0"); rect(d, 4, 7, 7, 11, "khaki1"); rect(d, 3, 9, 8, 9, "over0")
        rect(d, 9, 6, 10, 12, "steel0"); px(d, 9, 5, "steel1")  # rifle
    else:  # engineer
        rect(d, 3, 7, 8, 13, "over0"); rect(d, 4, 7, 7, 11, "over1"); rect(d, 4, 7, 4, 10, "khaki2"); rect(d, 7, 7, 7, 10, "khaki2")
        rect(d, 0, 9, 2, 10, "steel1")  # wrench
    # head
    rect(d, 3, 2, 8, 6, "skin"); rect(d, 3, 5, 8, 6, "skin0")
    px(d, 4, 4, "ink"); px(d, 7, 4, "ink")
    # hair / hat
    if kind == "civ":
        rect(d, 2, 0, 9, 2, "hair"); px(d, 3, 2, "hair0"); px(d, 8, 2, "hair0"); px(d, 5, -1, "hair")
    elif kind == "sol":
        rect(d, 2, 1, 9, 2, "helm1"); rect(d, 3, 0, 8, 0, "helm1"); rect(d, 1, 2, 10, 2, "helm0")
    else:
        rect(d, 3, 0, 8, 1, "over1"); rect(d, 2, 2, 10, 2, "over0")
    return im

for k in ("civ", "sol", "eng"):
    for f in (0, 1):
        save(lemming(k, f), "lem_%s_%d.png" % (k, f))

# ---------------- POSED LEMMINGS (zone choreography) ----------------
def lemming_pose(kind, pose, frame):
    im = lemming(kind, frame if pose in ("walk", "stab", "hammer") else 0)
    d = ImageDraw.Draw(im)
    f = frame
    if pose == "stab":      # bayonet lunge: stick thrust forward
        rect(d, 9, 8 + (0 if f else 1), 11, 8 + (0 if f else 1), "plank1"); px(d, 11, 8 + (0 if f else 1), "steel2")
        rect(d, 8, 9, 9, 10, "skin")
    elif pose == "hammer":  # builder swinging a hammer
        if f == 0:
            rect(d, 9, 3, 10, 7, "plank1"); rect(d, 8, 2, 11, 3, "steel1")
        else:
            rect(d, 9, 8, 11, 9, "plank1"); rect(d, 11, 7, 12, 9, "steel1")
        rect(d, 8, 8, 9, 9, "skin")
    elif pose == "wrench":  # crouched at the engine
        im = img(12, 16); d = ImageDraw.Draw(im)
        rect(d, 2, 13, 4, 15, "ink"); rect(d, 7, 13, 9, 15, "ink")
        rect(d, 3, 9, 8, 13, "over0" if kind == "eng" else "robe0"); rect(d, 3, 5, 8, 9, "skin"); px(d, 4, 7, "ink"); px(d, 7, 7, "ink")
        if kind == "civ":
            rect(d, 2, 3, 9, 5, "hair")
        else:
            rect(d, 3, 3, 8, 4, "over1"); rect(d, 2, 5, 10, 5, "over0")
        rect(d, 9, 9 + f, 11, 10 + f, "steel1"); px(d, 11, 8 + f, "steel2")
    elif pose == "sit":     # watching TV
        im = img(12, 16); d = ImageDraw.Draw(im)
        rect(d, 3, 11, 9, 15, "robe0" if kind == "civ" else ("khaki0" if kind == "sol" else "over0")); rect(d, 2, 13, 10, 15, "ink")
        rect(d, 3, 6, 8, 10, "skin"); px(d, 4, 8, "ink"); px(d, 7, 8, "ink"); px(d, 5, 9 + (f if kind == "civ" else 0), "ink")
        if kind == "civ":
            rect(d, 2, 4, 9, 6, "hair")
        elif kind == "sol":
            rect(d, 2, 5, 9, 6, "helm1"); rect(d, 1, 6, 10, 6, "helm0")
        else:
            rect(d, 3, 4, 8, 5, "over1"); rect(d, 2, 6, 10, 6, "over0")
    elif pose == "boss":    # operator: chest out, arm up (sergeant/master/prof)
        rect(d, 9, 2, 10, 7, "skin"); px(d, 10, 1, "skin")
        rect(d, 3, 8, 8, 9, "yellow" if kind == "sol" else ("brass1" if kind == "eng" else "white"))
        if f:
            rect(d, 0, 5, 1, 5, "white"); px(d, 0, 4, "white")   # a bark / shout
    elif pose == "crouch":  # MG crew
        im = img(12, 16); d = ImageDraw.Draw(im)
        rect(d, 2, 13, 4, 15, "ink"); rect(d, 7, 13, 9, 15, "ink")
        rect(d, 3, 9, 8, 13, "khaki0"); rect(d, 3, 5, 8, 9, "skin"); px(d, 4, 7, "ink"); px(d, 7, 7, "ink")
        rect(d, 2, 4, 9, 5, "helm1"); rect(d, 1, 5, 10, 5, "helm0")
        rect(d, 9, 8, 11, 9, "steel0")
    elif pose == "dig":     # pick swing
        if f == 0:
            rect(d, 9, 1, 10, 6, "plank1"); rect(d, 7, 0, 12, 1, "steel1")
        else:
            rect(d, 9, 7, 12, 8, "plank1"); rect(d, 12, 6, 13, 9, "steel1")
    elif pose == "cheer":   # arms up, hopping
        rect(d, 1, 2 - f, 2, 6, "skin"); rect(d, 9, 2 - f, 10, 6, "skin")
    return im

for k in ("civ", "sol", "eng"):
    for pose in ("stab", "hammer", "wrench", "sit", "boss", "crouch", "dig", "cheer"):
        for f in (0, 1):
            save(lemming_pose(k, pose, f), "lem_%s_%s_%d.png" % (k, pose, f))

# construction site (scaffold) 32x16 + sandbag pile stages
im = img(32, 16); d = ImageDraw.Draw(im)
for x in (2, 15, 28):
    rect(d, x, 2, x + 1, 15, "plank1")
rect(d, 1, 2, 30, 3, "plank2"); rect(d, 1, 9, 30, 9, "plank0")
for x in range(4, 28, 6):
    px(d, x, 12, "plank2"); px(d, x + 1, 13, "plank2")
save(im, "prop_site.png")
for stage in range(3):
    im = img(32, 16); d = ImageDraw.Draw(im)
    for i in range(stage + 2):
        x = i * 7
        d.ellipse([x, 10, x + 8, 15], fill=C("sand1")); d.ellipse([x + 1, 11, x + 5, 13], fill=C("sand2"))
    save(im, "prop_bags_%d.png" % stage)
im = img(8, 8); d = ImageDraw.Draw(im)   # spark
px(d, 3, 3, "yellow"); px(d, 4, 3, "white"); px(d, 3, 4, "white"); px(d, 4, 4, "yellow"); px(d, 2, 2, "orange"); px(d, 5, 5, "orange")
save(im, "fx_spark.png")

# scared civilian (arms up) & kidnapped (flailing)
im = lemming("civ", 0); d = ImageDraw.Draw(im)
rect(d, 1, 3, 2, 7, "skin"); rect(d, 9, 3, 10, 7, "skin"); rect(d, 5, 5, 6, 6, "ink")
save(im, "lem_civ_scream.png")
# Iwo Jima flag raisers (group sprite 32x24)
im = img(32, 24); d = ImageDraw.Draw(im)
for i, (x, y) in enumerate([(2, 8), (9, 6), (16, 5), (22, 7)]):
    im.paste(lemming(["civ", "sol", "civ", "eng"][i], 0), (x, y), lemming(["civ", "sol", "civ", "eng"][i], 0))
d = ImageDraw.Draw(im)
line(d, [(14, 22), (26, 1)], "plank2", 1)
rect(d, 22, 0, 31, 6, "red1"); rect(d, 22, 0, 31, 1, "red0"); rect(d, 25, 2, 28, 4, "white")
save(im, "iwo_jima.png")

# hats (operator markers) 10x6
def hat(c0, c1, kind):
    im = img(10, 6); d = ImageDraw.Draw(im)
    if kind == "sergeant":
        rect(d, 1, 3, 8, 4, c0); rect(d, 2, 0, 7, 3, c1); rect(d, 4, 1, 5, 2, "yellow")
    elif kind == "master":
        rect(d, 0, 4, 9, 5, c0); rect(d, 2, 1, 7, 4, c1); px(d, 4, 2, "brass2")
    elif kind == "prof":
        rect(d, 0, 2, 9, 3, "ink"); rect(d, 3, 0, 6, 2, "ink"); px(d, 8, 3, "yellow"); px(d, 8, 4, "yellow")
    return im
save(hat("red0", "red1", "sergeant"), "hat_sergeant.png")
save(hat("brass0", "brass1", "master"), "hat_master.png")
save(hat("ink", "ink", "prof"), "hat_prof.png")

# ---------------- BUGS ----------------
def raider(frame):
    im = img(16, 12); d = ImageDraw.Draw(im)
    ell(d, 2, 3, 13, 10, "bug1"); ell(d, 4, 4, 11, 8, "bug2"); ell(d, 10, 2, 15, 7, "bug2")
    px(d, 13, 4, "yellow"); px(d, 14, 4, "yellow")
    o = 0 if frame == 0 else 1
    for i, x in enumerate((3, 6, 9)):
        line(d, [(x, 9), (x - 2 + (o if i % 2 else -o), 11)], "bug0")
        line(d, [(x + 1, 9), (x + 3 - (o if i % 2 else -o), 11)], "bug0")
    line(d, [(1, 5), (0, 2)], "bug3"); line(d, [(3, 4), (2, 1)], "bug3")
    return im
save(raider(0), "bug_raider_0.png"); save(raider(1), "bug_raider_1.png")

im = img(24, 20); d = ImageDraw.Draw(im)
ell(d, 2, 6, 21, 19, "slime1"); ell(d, 5, 9, 18, 17, "slime0"); ell(d, 8, 11, 15, 16, "bug0")
ell(d, 4, 2, 11, 9, "bug2"); ell(d, 12, 0, 20, 8, "bug2"); px(d, 7, 5, "yellow"); px(d, 16, 3, "yellow")
save(im, "bug_nest.png")

im = img(48, 40); d = ImageDraw.Draw(im)
ell(d, 4, 12, 44, 39, "bug1"); ell(d, 10, 16, 38, 34, "bug2"); ell(d, 16, 20, 32, 30, "bug3")
ell(d, 18, 2, 34, 18, "bug2"); rect(d, 22, 8, 24, 10, "yellow"); rect(d, 28, 8, 30, 10, "yellow")
for x in (6, 14, 34, 42):
    line(d, [(x, 30), (x - 4, 39)], "bug0", 2); line(d, [(x, 30), (x + 4, 39)], "bug0", 2)
line(d, [(16, 4), (10, 0)], "bug3", 2); line(d, [(36, 4), (42, 0)], "bug3", 2)
save(im, "bug_queen.png")
im2 = im.resize((72, 60), Image.NEAREST); d = ImageDraw.Draw(im2)
for i in range(5):
    px(d, 20 + i * 8, 2, "red1")
save(im2, "bug_megaqueen.png")

# ---------------- SIGNS (board 20x26, icon 16x16 on it) ----------------
def board():
    im = img(20, 26); d = ImageDraw.Draw(im)
    rect(d, 9, 18, 10, 25, "plank0"); rect(d, 9, 18, 9, 25, "plank1")
    rect(d, 0, 0, 19, 18, "plank1"); rect(d, 1, 1, 18, 17, "paper"); rect(d, 1, 1, 18, 1, "white"); rect(d, 1, 17, 18, 17, "paper0")
    px(d, 2, 2, "ink"); px(d, 17, 2, "ink"); px(d, 2, 16, "ink"); px(d, 17, 16, "ink")
    return im

def icon(name):
    im = img(16, 16); d = ImageDraw.Draw(im)
    if name == "excavate":   # shovel
        line(d, [(3, 13), (10, 6)], "plank1", 2); rect(d, 9, 1, 14, 6, "steel1"); rect(d, 10, 2, 13, 5, "steel2"); rect(d, 2, 12, 4, 14, "plank0")
    elif name == "nogo":     # red circle slash
        d.ellipse([1, 1, 14, 14], outline=C("red1"), width=3); line(d, [(3, 12), (12, 3)], "red1", 3)
    elif name == "training": # target
        d.ellipse([1, 1, 14, 14], fill=C("red1")); d.ellipse([4, 4, 11, 11], fill=C("white")); d.ellipse([6, 6, 9, 9], fill=C("red1"))
    elif name == "engschool":  # gear
        d.ellipse([2, 2, 13, 13], fill=C("steel0")); d.ellipse([5, 5, 10, 10], fill=C("paper"))
        for (x0, y0, x1, y1) in [(7, 0, 8, 2), (7, 13, 8, 15), (0, 7, 2, 8), (13, 7, 15, 8), (1, 1, 3, 3), (12, 12, 14, 14), (12, 1, 14, 3), (1, 12, 3, 14)]:
            rect(d, x0, y0, x1, y1, "steel0")
    elif name == "idiot":    # TV
        rect(d, 1, 3, 14, 12, "ink"); rect(d, 3, 5, 12, 10, "cyan"); rect(d, 5, 13, 10, 14, "ink"); line(d, [(5, 3), (3, 0)], "ink"); line(d, [(10, 3), (12, 0)], "ink"); rect(d, 6, 6, 8, 9, "white")
    elif name == "mg":       # machine gun
        rect(d, 1, 7, 14, 9, "steel0"); rect(d, 10, 6, 15, 7, "steel1"); rect(d, 3, 10, 5, 14, "steel0"); rect(d, 8, 10, 10, 14, "steel0"); rect(d, 4, 4, 8, 6, "steel1")
    elif name == "patrol":   # crossed rifles
        line(d, [(2, 13), (13, 2)], "steel0", 2); line(d, [(2, 2), (13, 13)], "steel0", 2); rect(d, 1, 12, 3, 14, "plank1"); rect(d, 12, 12, 14, 14, "plank1")
    elif name == "shaft":    # bomb with fuse, arrow down
        d.ellipse([3, 5, 12, 14], fill=C("ink")); rect(d, 7, 2, 8, 5, "steel1"); px(d, 9, 1, "orange"); px(d, 10, 0, "yellow"); px(d, 6, 7, "steel2")
    elif name == "flag":     # red flag
        rect(d, 3, 1, 4, 14, "plank1"); rect(d, 5, 1, 14, 7, "red1"); rect(d, 5, 1, 14, 2, "red0"); rect(d, 8, 3, 11, 5, "white")
    elif name == "workshop": # wrench + hammer
        line(d, [(2, 13), (10, 5)], "steel1", 2); d.ellipse([8, 2, 14, 8], fill=C("steel1")); d.ellipse([10, 4, 12, 6], fill=C("paper")); line(d, [(13, 13), (6, 6)], "plank1", 2); rect(d, 2, 2, 6, 5, "steel0")
    elif name == "seismic":  # antenna with waves
        rect(d, 7, 5, 8, 14, "steel0"); rect(d, 4, 13, 11, 15, "steel1"); d.arc([2, 0, 13, 11], 200, 340, fill=C("green"), width=2); d.arc([5, 3, 10, 8], 200, 340, fill=C("green"), width=1)
    elif name == "pump":     # fan
        d.ellipse([1, 1, 14, 14], fill=C("steel0")); d.ellipse([3, 3, 12, 12], fill=C("paper")); rect(d, 7, 2, 8, 13, "cyan"); rect(d, 2, 7, 13, 8, "cyan"); d.ellipse([6, 6, 9, 9], fill=C("steel0"))
    elif name == "institute":  # grad cap
        d.polygon([(7, 1), (15, 6), (7, 11), (0, 6)], fill=C("ink")); rect(d, 3, 7, 11, 12, "ink"); rect(d, 13, 6, 13, 12, "yellow"); px(d, 13, 13, "yellow")
    elif name == "base":     # house / tent
        d.polygon([(7, 1), (14, 8), (0, 8)], fill=C("khaki1")); rect(d, 2, 8, 12, 14, "khaki0"); rect(d, 6, 10, 8, 14, "ink")
    elif name == "point":    # plus
        rect(d, 6, 1, 9, 14, "green"); rect(d, 1, 6, 14, 9, "green")
    return im

# category icons
im = img(16, 16); d = ImageDraw.Draw(im)   # movement: boot + arrow
rect(d, 1, 9, 9, 14, "plank0"); rect(d, 1, 5, 5, 9, "plank1"); rect(d, 7, 12, 11, 14, "plank0")
line(d, [(9, 5), (15, 5)], "yellow", 2); line(d, [(12, 2), (15, 5), (12, 8)], "yellow", 2)
save(im, "icon_cat_move.png")
im = img(16, 16); d = ImageDraw.Draw(im)   # civic: open book
rect(d, 1, 3, 7, 13, "paper"); rect(d, 8, 3, 14, 13, "paper"); rect(d, 7, 2, 8, 14, "plank1")
for y in (5, 7, 9, 11):
    line(d, [(2, y), (6, y)], "paper0"); line(d, [(9, y), (13, y)], "paper0")
save(im, "icon_cat_civic.png")
SIGNS = ["excavate", "nogo", "training", "engschool", "idiot", "mg", "patrol", "shaft", "flag", "workshop", "seismic", "pump", "institute", "base", "point"]
for s in SIGNS:
    ic = icon(s)
    save(ic, "icon_%s.png" % s)
    b = board(); b.paste(ic, (2, 1), ic)
    save(b, "sign_%s.png" % s)

# ---------------- PROPS ----------------
im = img(16, 16); d = ImageDraw.Draw(im)   # straw target
rect(d, 7, 8, 8, 15, "plank1"); d.ellipse([2, 0, 13, 11], fill=C("sand2")); d.ellipse([5, 3, 10, 8], fill=C("red1")); d.ellipse([7, 5, 8, 6], fill=C("white"))
save(im, "prop_target.png")
im = img(16, 16); d = ImageDraw.Draw(im)   # podium
rect(d, 2, 8, 13, 15, "plank1"); rect(d, 2, 8, 13, 9, "plank2"); rect(d, 5, 2, 10, 8, "plank0")
save(im, "prop_podium.png")
im = img(24, 16); d = ImageDraw.Draw(im)   # big engine
rect(d, 2, 4, 21, 15, "steel0"); rect(d, 4, 6, 19, 13, "steel1"); d.ellipse([6, 7, 12, 13], fill=C("brass1")); rect(d, 15, 1, 18, 5, "brass0"); rect(d, 14, 8, 18, 11, "red1")
save(im, "prop_engine.png")
im = img(16, 16); d = ImageDraw.Draw(im)   # TV set
rect(d, 1, 3, 14, 13, "ink"); rect(d, 3, 5, 12, 11, "cyan"); rect(d, 5, 7, 10, 9, "pink"); rect(d, 4, 14, 11, 15, "ink")
save(im, "prop_tv.png")
im = img(32, 16); d = ImageDraw.Draw(im)   # sandbag MG nest
for x in range(0, 32, 8):
    d.ellipse([x, 9, x + 8, 15], fill=C("sand1")); d.ellipse([x + 4, 5, x + 12, 11], fill=C("sand2"))
rect(d, 10, 2, 26, 4, "steel0"); rect(d, 22, 1, 30, 2, "steel1"); rect(d, 14, 4, 16, 7, "steel0")
save(im, "prop_mg.png")
im = img(32, 24); d = ImageDraw.Draw(im)   # workshop bench
rect(d, 2, 10, 29, 22, "plank1"); rect(d, 2, 10, 29, 11, "plank2"); rect(d, 4, 4, 12, 10, "steel1"); rect(d, 16, 2, 26, 10, "brass0"); rect(d, 18, 4, 24, 8, "brass1"); px(d, 20, 1, "yellow")
save(im, "prop_workshop.png")
im = img(16, 24); d = ImageDraw.Draw(im)   # seismic thumper
rect(d, 6, 10, 9, 23, "steel0"); rect(d, 2, 20, 13, 23, "steel1"); rect(d, 4, 2, 11, 10, "brass1"); rect(d, 6, 4, 9, 8, "ink"); px(d, 7, 0, "green"); px(d, 7, 1, "green")
save(im, "prop_thumper.png")
im = img(24, 32); d = ImageDraw.Draw(im)   # gas pump + stack
rect(d, 4, 18, 19, 31, "steel0"); rect(d, 6, 20, 17, 29, "steel1"); d.ellipse([8, 21, 15, 28], fill=C("cyan")); rect(d, 10, 0, 13, 18, "steel1"); rect(d, 9, 0, 14, 2, "steel2")
save(im, "prop_pump.png")
im = img(32, 24); d = ImageDraw.Draw(im)   # institute
rect(d, 2, 10, 29, 23, "paper0"); rect(d, 4, 12, 27, 21, "paper"); rect(d, 0, 8, 31, 10, "plank1"); d.polygon([(16, 0), (31, 8), (0, 8)], fill=C("plank0"))
for x in (6, 13, 20):
    rect(d, x, 13, x + 3, 21, "paper0")
save(im, "prop_institute.png")
im = img(32, 20); d = ImageDraw.Draw(im)   # base tent
d.polygon([(16, 1), (31, 18), (0, 18)], fill=C("khaki1")); d.polygon([(16, 1), (24, 18), (8, 18)], fill=C("khaki0")); rect(d, 13, 10, 18, 18, "ink"); rect(d, 0, 18, 31, 19, "plank0")
save(im, "prop_tent.png")
im = img(16, 16); d = ImageDraw.Draw(im)   # flag planted
rect(d, 7, 2, 8, 15, "plank2"); rect(d, 9, 2, 15, 7, "red1"); rect(d, 11, 4, 13, 5, "white")
save(im, "prop_flag.png")
im = img(16, 16); d = ImageDraw.Draw(im)   # ladder (shaft cell)
rect(d, 4, 0, 5, 15, "plank1"); rect(d, 10, 0, 11, 15, "plank1")
for y in (2, 6, 10, 14):
    rect(d, 4, y, 11, y, "plank2")
save(im, "prop_ladder.png")
im = img(16, 8); d = ImageDraw.Draw(im)    # bullet / tracer
rect(d, 0, 3, 5, 4, "yellow"); px(d, 6, 3, "orange")
save(im, "fx_tracer.png")
im = img(24, 24); d = ImageDraw.Draw(im)   # fire blast
d.ellipse([0, 0, 23, 23], fill=C("orange")); d.ellipse([5, 5, 18, 18], fill=C("yellow")); d.ellipse([9, 9, 14, 14], fill=C("white"))
save(im, "fx_fire.png")
im = img(8, 8); d = ImageDraw.Draw(im)     # soft glow dot (fog reveal / seismic ping)
d.ellipse([0, 0, 7, 7], fill=(255, 255, 255, 140)); d.ellipse([2, 2, 5, 5], fill=(255, 255, 255, 255))
save(im, "fx_dot.png")
im = img(64, 64); d = ImageDraw.Draw(im)   # light halo
for r in range(32, 0, -1):
    a = int(140 * (1 - r / 32.0) ** 1.5)
    d.ellipse([32 - r, 32 - r, 32 + r, 32 + r], fill=(255, 220, 160, a))
save(im, "fx_halo.png")
print("done")
