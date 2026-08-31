# Dig Game asset foundry part 2 — BUILDINGS (on/off states + work frames), FX, backdrop.
from gen_assets import P, img, px, rect, save, scatter
from PIL import Image, ImageDraw

# All buildings drawn with: brass/copper steampunk kit, warm upper-left light,
# windows that LIGHT UP when on, and a 2-frame "working" animation where it counts.

def frame_shell(d, w, h, base="brass"):
    """Riveted metal shell with roof."""
    b0, b1, b2, b3 = base+"0", base+"1", base+"2", base+"3"
    rect(d, 1, 3, w-2, h-1, b1)
    rect(d, 1, 3, 4, h-1, b2)                    # left light
    rect(d, w-4, 5, w-2, h-1, b0)                # right shade
    rect(d, 0, 2, w-1, 3, b2)                    # roof edge
    rect(d, 0, 1, w-2, 2, b3)                    # roof light
    # rivets
    for x in range(2, w-2, 5):
        px(d, x, 4, b3); px(d, x, h-3, b0)

def window(d, x, y, lit, w=3, h=3):
    rect(d, x-1, y-1, x+w, y+h, "brass0")
    rect(d, x, y, x+w-1, y+h-1, "lamp" if lit else "dirt1")
    if lit:
        px(d, x, y, "white")

def bld_living(on, frame=0):
    """Bunkhouse 48x32: rows of warm windows, chimney puff when on."""
    w, h = 48, 32
    im = img(w, h); d = ImageDraw.Draw(im)
    frame_shell(d, w, h, "brass")
    # copper roof ridge + chimney
    rect(d, 4, 0, 9, 2, "copper1"); rect(d, 4, 0, 6, 1, "copper2")
    # windows: two rows of bunks
    for yy in [8, 18]:
        for xx in range(6, 42, 9):
            window(d, xx, yy, on)
    # door
    rect(d, 21, 24, 26, 31, "leath0"); rect(d, 21, 24, 23, 31, "leath1")
    px(d, 25, 27, "brass3")
    # smoke puff (frame anim) when on
    if on:
        sy = 0 if frame == 0 else 1
        px(d, 6, 0-0, "rock3")
        if frame == 1:
            px(d, 7, 0, "rock2")
    return im

def bld_farm(on, frame=0):
    """Greenhouse 48x24 on water: glass arc, crops inside, teal glow."""
    w, h = 48, 24
    im = img(w, h); d = ImageDraw.Draw(im)
    # glass dome (light teal, readable)
    rect(d, 2, 6, w-3, h-1, "teal1")
    rect(d, 4, 3, w-5, 6, "teal1")
    rect(d, 8, 1, w-9, 3, "teal1")
    rect(d, w-14, 8, w-3, h-1, "teal0")   # right shade
    # glass shine
    rect(d, 4, 4, 18, 5, "teal2"); rect(d, 9, 1, 20, 2, "teal2")
    rect(d, 6, 8, 12, 9, "teal2")
    # frame ribs
    for x in range(2, w-2, 8):
        rect(d, x, 4 if 8 < x < w-10 else 7, x, h-2, "brass1")
    rect(d, 0, h-2, w-1, h-1, "brass2")
    # soil bed + crops (chunky, high contrast against glass)
    rect(d, 3, h-5, w-4, h-3, "dirt2")
    g = "grn2" if on else "grn1"
    for i, x in enumerate(range(5, w-6, 6)):
        ch = 4 + (i * 7 % 3)
        rect(d, x, h-5-ch, x+1, h-5, "grn0")     # stem cluster
        rect(d, x-1, h-5-ch, x+2, h-4-ch, g)      # leafy top
        px(d, x, h-6-ch, g)
        if on and frame == 1 and i % 2 == 0:
            px(d, x, h-7-ch, "white")  # grow sparkle
    return im

def bld_power(on, frame=0):
    """Geothermal power plant 32x40: boiler + big gauge + stack, sits over a vent."""
    w, h = 32, 40
    im = img(w, h); d = ImageDraw.Draw(im)
    # smokestack
    rect(d, 22, 0, 27, 12, "copper1"); rect(d, 22, 0, 23, 12, "copper2")
    rect(d, 21, 0, 28, 1, "copper0")
    # boiler body (round-ish)
    rect(d, 2, 12, 19, 34, "copper1")
    rect(d, 2, 12, 8, 24, "copper2")
    rect(d, 16, 14, 19, 34, "copper0")
    rect(d, 4, 10, 17, 12, "copper1"); rect(d, 5, 10, 10, 11, "copper2")
    # rivet seams
    for y in range(14, 34, 6):
        for x in range(4, 18, 4):
            px(d, x, y, "copper0")
    # big brass gauge (needle flips with frame)
    rect(d, 6, 16, 14, 24, "brass0"); rect(d, 7, 17, 13, 23, "brass3")
    rect(d, 8, 18, 12, 22, "white")
    if on:
        if frame == 0:
            px(d, 9, 19, "clothR0"); px(d, 10, 20, "clothR0")
        else:
            px(d, 11, 19, "clothR0"); px(d, 10, 20, "clothR0")
    else:
        px(d, 9, 21, "rock1"); px(d, 10, 20, "rock1")
    # pipes down into vent + right to base
    rect(d, 8, 34, 11, 39, "brass1"); rect(d, 8, 34, 9, 39, "brass2")
    rect(d, 19, 28, 31, 31, "brass1"); rect(d, 19, 28, 31, 29, "brass2")
    px(d, 21, 30, "brass0"); px(d, 27, 30, "brass0")
    # glow at vent contact + steam from stack when on
    if on:
        rect(d, 7, 37, 12, 39, "glow0")
        px(d, 9, 36, "glow1")
        if frame == 1:
            px(d, 24, 0, "rock3"); px(d, 25, 0, "rock3")
    return im

def bld_armory(on, frame=0):
    """Armory 32x24: rack of rifles, red banner."""
    w, h = 32, 24
    im = img(w, h); d = ImageDraw.Draw(im)
    frame_shell(d, w, h, "brass")
    # banner
    rect(d, 2, 4, 6, 12, "clothR0"); rect(d, 2, 4, 3, 9, "clothR1")
    px(d, 2, 12, "clothR0"); px(d, 5, 12, "clothR0")
    # weapon rack window
    rect(d, 9, 7, 27, 17, "dirt0")
    rect(d, 9, 7, 27, 8, "brass0")
    for x in range(11, 26, 4):
        rect(d, x, 9, x, 15, "leath1")  # rifle stocks
        px(d, x, 9, "rock3")            # barrels
        if on:
            px(d, x, 10, "brass3")      # brass fittings gleam
    # door lamp
    px(d, 28, 6, "lamp" if on else "dirt1")
    return im

def bld_lab(tier, on, frame=0):
    """Research lab 32x32. tier0 = brass scope; tier1 = pink-crystal reactor."""
    w, h = 32, 32
    im = img(w, h); d = ImageDraw.Draw(im)
    frame_shell(d, w, h, "brass")
    if tier == 0:
        # rooftop telescope/antenna
        rect(d, 24, 0, 25, 4, "brass1")
        rect(d, 22, 0, 27, 0, "brass3")
        # round porthole with bubbling flask
        rect(d, 8, 10, 20, 22, "brass0")
        rect(d, 9, 11, 19, 21, "dirt0")
        rect(d, 12, 14, 16, 20, "teal1")     # flask liquid
        rect(d, 12, 14, 13, 16, "teal2")
        if on and frame == 1:
            px(d, 14, 12, "teal2"); px(d, 15, 13, "teal1")  # bubbles
        window(d, 24, 12, on)
    else:
        # late lab: rare-metal crystal in containment
        rect(d, 10, 6, 22, 26, "rock0")
        rect(d, 11, 7, 21, 25, "dirt0")
        # crystal
        rect(d, 14, 10, 18, 22, "rare1")
        rect(d, 14, 10, 15, 16, "rare2")
        px(d, 16, 8, "rare2"); px(d, 16, 23, "rare0")
        if on:
            px(d, 13, 12, "rare2"); px(d, 19, 18, "rare2")  # energy motes
            if frame == 1:
                px(d, 12, 16, "rare1"); px(d, 20, 12, "rare1")
        window(d, 4, 12, on); window(d, 25, 12, on)
    return im

def bld_barricade():
    """Barricade wall chunk 16x24: spiked brass-wood wall."""
    im = img(16, 24); d = ImageDraw.Draw(im)
    rect(d, 1, 6, 14, 23, "leath0")
    rect(d, 1, 6, 4, 23, "leath1")
    # brass banding
    rect(d, 0, 10, 15, 12, "brass1"); rect(d, 0, 10, 15, 10, "brass2")
    rect(d, 0, 18, 15, 20, "brass1"); rect(d, 0, 18, 15, 18, "brass2")
    # spikes
    for x in range(2, 15, 4):
        rect(d, x, 3, x+1, 6, "rock2")
        px(d, x, 2, "rock3")
    return im

def bld_turret(frame):
    """Checkpoint gatling 24x20: tripod + rotary barrels, muzzle flash on frame 1."""
    im = img(24, 20); d = ImageDraw.Draw(im)
    # tripod
    rect(d, 8, 14, 9, 19, "rock1"); rect(d, 12, 14, 13, 19, "rock1")
    rect(d, 5, 17, 6, 19, "rock0"); rect(d, 15, 17, 16, 19, "rock0")
    # body drum
    rect(d, 5, 8, 15, 14, "brass1")
    rect(d, 5, 8, 9, 11, "brass2")
    rect(d, 6, 6, 12, 8, "brass3")   # top plate
    px(d, 7, 9, "brass0"); px(d, 11, 12, "brass0")
    # rotary barrels (offset per frame)
    o = 0 if frame == 0 else 1
    rect(d, 15, 9+o, 22, 9+o, "rock2")
    rect(d, 15, 11-o, 22, 11-o, "rock3")
    # steam valve
    px(d, 6, 5, "copper2")
    if frame == 1:
        rect(d, 22, 9, 23, 11, "glow2")
        px(d, 23, 10, "glow1")
    return im

def vent(frame):
    """Geothermal vent (in-ground feature) 16x16: cracked ground + rising steam."""
    im = img(16, 16); d = ImageDraw.Draw(im)
    rect(d, 2, 12, 13, 15, "rock0")
    rect(d, 4, 11, 11, 12, "rock1")
    rect(d, 6, 12, 9, 13, "glow0")       # magma crack
    px(d, 7, 12, "glow1")
    # steam plumes rise, alternate frames
    steam = [(7, 8), (6, 5), (8, 3), (7, 0)] if frame == 0 else [(8, 9), (7, 6), (6, 3), (8, 1)]
    for i, (x, y) in enumerate(steam):
        c = "rock3" if i < 2 else "rock2"
        rect(d, x, y, x+1, y+1, c)
    return im

def shaft_head():
    """Topside shaft entrance 32x24: brass headframe + wheel."""
    im = img(32, 24); d = ImageDraw.Draw(im)
    # A-frame legs
    rect(d, 6, 4, 8, 23, "leath1"); rect(d, 23, 4, 25, 23, "leath1")
    rect(d, 6, 4, 6, 23, "leath0"); rect(d, 23, 4, 23, 23, "leath0")
    # crossbar + wheel
    rect(d, 4, 2, 27, 4, "brass2"); rect(d, 4, 2, 27, 2, "brass3")
    rect(d, 13, 0, 18, 5, "brass1")
    rect(d, 14, 1, 17, 4, "brass0")
    px(d, 15, 2, "brass3"); px(d, 16, 3, "brass3")  # wheel spokes
    # cable down
    rect(d, 15, 5, 15, 23, "rock2")
    # dark shaft mouth
    rect(d, 10, 18, 21, 23, "dirt0")
    rect(d, 10, 18, 21, 18, "ink")
    return im

def meteor():
    im = img(12, 12); d = ImageDraw.Draw(im)
    rect(d, 4, 4, 9, 9, "sky3")
    rect(d, 4, 4, 6, 6, "sky4")
    px(d, 5, 5, "sky5")
    # trail
    px(d, 2, 2, "sky4"); px(d, 1, 1, "sky3"); px(d, 3, 3, "sky5")
    px(d, 0, 0, "sky2")
    return im

def dirt_chunk():
    im = img(6, 6); d = ImageDraw.Draw(im)
    rect(d, 1, 1, 4, 4, "dirt3")
    rect(d, 1, 1, 2, 2, "dirt4")
    px(d, 4, 4, "dirt1")
    return im

def queen_maw(frame):
    """The hive queen's glow at map bottom — big ominous maw 64x32 (mostly for the final shot)."""
    im = img(64, 32); d = ImageDraw.Draw(im)
    o = frame
    # mound
    rect(d, 4, 12, 59, 31, "trog0")
    rect(d, 10, 8, 52, 14, "trog1")
    rect(d, 20, 5, 42, 9, "trog1")
    # maw
    rect(d, 24, 12+o, 40, 24, "glow0")
    rect(d, 27, 14+o, 37, 22, "glow1")
    rect(d, 30, 16+o, 34, 19, "glow2")
    # teeth
    for x in range(24, 41, 4):
        rect(d, x, 11+o, x+1, 13+o, "trog2")
        rect(d, x+2, 23, x+3, 25, "trog2")
    # eye clusters
    for (x, y) in [(16, 10), (48, 10), (12, 16), (52, 16)]:
        px(d, x, y+o, "glow1"); px(d, x+1, y+o, "glow2")
    # crest spines
    for i, x in enumerate(range(14, 52, 7)):
        rect(d, x, 3 - (i % 2), x, 6, "trog2")
        px(d, x, 2 - (i % 2), "glow0")
    return im

# ---------- BACKDROP (topside sky, 640x140) ----------
def backdrop():
    w, h = 640, 140
    im = img(w, h); d = ImageDraw.Draw(im)
    # banded apocalypse gradient (chunky bands, not smooth — pixel look)
    bands = ["sky0", "sky0", "sky1", "sky1", "sky2", "sky2", "sky3", "sky3", "sky4"]
    bh = h // len(bands)
    for i, c in enumerate(bands):
        rect(d, 0, i*bh, w-1, (i+1)*bh + 2, c)
    # sun sliver low on horizon
    rect(d, 250, h-22, 310, h-1, "sky4")
    rect(d, 262, h-16, 298, h-1, "sky5")
    # far ruined skyline (silhouette, near-sky color)
    sky_sil = (74, 26, 44, 255)
    heights = [18, 30, 12, 40, 22, 34, 15, 44, 26, 20, 36, 14, 30, 42, 18, 24]
    x = 0
    for i, hh in enumerate(heights):
        bw = 40
        rect(d, x, h-hh, x+bw-6, h-1, sky_sil)
        # broken tops
        if i % 3 == 0:
            rect(d, x+4, h-hh-4, x+12, h-hh, sky_sil)
        if i % 4 == 1:
            rect(d, x+bw-14, h-hh+6, x+bw-6, h-hh+10, (24, 13, 34, 255))  # window holes
        x += bw
    # smoke columns
    for sx in [120, 420, 560]:
        for j in range(6):
            rect(d, sx + (j % 2)*3, h-50-j*12, sx+8 + (j % 2)*3, h-40-j*12, (52, 24, 44, 255))
    # drifting clouds (lit from below)
    for (cx, cy, cw) in [(60, 20, 90), (280, 34, 120), (480, 14, 100), (180, 52, 70)]:
        rect(d, cx, cy, cx+cw, cy+6, "sky2")
        rect(d, cx+8, cy+6, cx+cw-10, cy+9, "sky3")
        rect(d, cx+4, cy, cx+30, cy+2, "sky1")
    return im

def gen():
    for on in (0, 1):
        for f in (0, 1):
            save(bld_living(on, f), "sprites", f"bld_living_{on}_{f}.png")
            save(bld_farm(on, f), "sprites", f"bld_farm_{on}_{f}.png")
            save(bld_power(on, f), "sprites", f"bld_power_{on}_{f}.png")
            save(bld_armory(on, f), "sprites", f"bld_armory_{on}_{f}.png")
            save(bld_lab(0, on, f), "sprites", f"bld_lab1_{on}_{f}.png")
            save(bld_lab(1, on, f), "sprites", f"bld_lab2_{on}_{f}.png")
    save(bld_barricade(), "sprites", "bld_barricade.png")
    for f in (0, 1):
        save(bld_turret(f), "sprites", f"bld_turret_{f}.png")
        save(vent(f), "sprites", f"vent_{f}.png")
        save(queen_maw(f), "sprites", f"queen_{f}.png")
    save(shaft_head(), "sprites", "shaft_head.png")
    save(meteor(), "fx", "meteor.png")
    save(dirt_chunk(), "fx", "dirt_chunk.png")
    save(backdrop(), "tiles", "backdrop.png")
    print("PART 2 DONE")

if __name__ == "__main__":
    gen()
