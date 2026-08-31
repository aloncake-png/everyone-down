# Dig Game asset foundry part 3 — UI: 3x5 digit font, icons, captions, title, light halo.
import os
from gen_assets import P, img, px, rect, save
from PIL import Image, ImageDraw, ImageFont

# ---------- 3x5 pixel digits (strip of 10, each 4px wide incl. 1px gap) ----------
DIGITS = {
    "0": ["111","101","101","101","111"], "1": ["010","110","010","010","111"],
    "2": ["111","001","111","100","111"], "3": ["111","001","111","001","111"],
    "4": ["101","101","111","001","001"], "5": ["111","100","111","001","111"],
    "6": ["111","100","111","101","111"], "7": ["111","001","010","010","010"],
    "8": ["111","101","111","101","111"], "9": ["111","101","111","001","111"],
    "/": ["001","001","010","100","100"], ":": ["000","010","000","010","000"],
}
def gen_digits():
    keys = "0123456789/:"
    im = img(4*len(keys), 7)
    d = ImageDraw.Draw(im)
    for i, k in enumerate(keys):
        rows = DIGITS[k]
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                if c == "1":
                    px(d, i*4+x, y+1, "white")
                    # drop shadow
    # shadow pass (offset +1,+1 in ink where empty)
    im2 = img(4*len(keys), 7); d2 = ImageDraw.Draw(im2)
    pix = im.load()
    for y in range(7):
        for x in range(im.width):
            if pix[x, y][3] > 0:
                d2.point((x+1, y+1), fill=P["ink"])
    im2.paste(im, (0, 0), im)
    save(im2, "ui", "digits.png")

# ---------- HUD icons 9x9 ----------
def icon_person():
    im = img(9, 9); d = ImageDraw.Draw(im)
    rect(d, 3, 1, 5, 3, "skin1")
    rect(d, 2, 4, 6, 6, "cloth1")
    rect(d, 3, 7, 3, 8, "leath0"); rect(d, 5, 7, 5, 8, "leath0")
    return im

def icon_person_down():
    im = icon_person(); d = ImageDraw.Draw(im)
    # little down arrow badge
    rect(d, 7, 3, 7, 5, "glow2"); px(d, 6, 5, "glow2"); px(d, 8, 5, "glow2"); px(d, 7, 6, "glow2")
    return im

def icon_food():
    im = img(9, 9); d = ImageDraw.Draw(im)
    rect(d, 2, 3, 6, 6, "grn2")
    rect(d, 2, 3, 3, 4, "grn1")
    px(d, 4, 2, "grn0"); px(d, 5, 1, "grn0")
    px(d, 3, 7, "grn1"); px(d, 5, 7, "grn1")
    return im

def icon_power():
    im = img(9, 9); d = ImageDraw.Draw(im)
    # lightning bolt
    for (x, y) in [(5,0),(4,1),(4,2),(3,3),(4,4),(3,5),(3,6),(2,7)]:
        px(d, x, y, "lamp")
        px(d, x+1, y, "brass3")
    px(d, 5, 4, "lamp")
    return im

def icon_ore(kind):
    im = img(9, 9); d = ImageDraw.Draw(im)
    rect(d, 2, 3, 6, 7, kind+"1")
    rect(d, 2, 3, 4, 5, kind+"2")
    px(d, 6, 7, kind+"0"); px(d, 4, 1, kind+"2")
    return im

def gen_icons():
    save(icon_person(), "ui", "ic_pop.png")
    save(icon_person_down(), "ui", "ic_below.png")
    save(icon_food(), "ui", "ic_food.png")
    save(icon_power(), "ui", "ic_power.png")
    save(icon_ore("iron"), "ui", "ic_iron.png")
    save(icon_ore("rare"), "ui", "ic_rare.png")

# ---------- HUD panel chips ----------
def chip(w=46, h=13):
    im = img(w, h); d = ImageDraw.Draw(im)
    rect(d, 1, 1, w-2, h-2, (26, 18, 28, 210))
    rect(d, 1, 1, w-2, 1, "brass1")
    rect(d, 1, h-2, w-2, h-2, (12, 8, 14, 220))
    px(d, 0, 0, (0,0,0,0)); px(d, w-1, 0, (0,0,0,0))
    px(d, 0, h-1, (0,0,0,0)); px(d, w-1, h-1, (0,0,0,0))
    rect(d, 0, 1, 0, h-2, "brass0"); rect(d, w-1, 1, w-1, h-2, "brass0")
    return im

# ---------- Seismograph panel (the Big Swarm countdown) ----------
def seismo():
    w, h = 92, 30
    im = img(w, h); d = ImageDraw.Draw(im)
    rect(d, 1, 1, w-2, h-2, (26, 18, 28, 220))
    rect(d, 0, 1, 0, h-2, "brass1"); rect(d, w-1, 1, w-1, h-2, "brass1")
    rect(d, 1, 0, w-2, 0, "brass2"); rect(d, 1, h-1, w-2, h-1, "brass0")
    # brass corners
    for (x, y) in [(1,1),(w-2,1),(1,h-2),(w-2,h-2)]:
        px(d, x, y, "brass3")
    # scope area
    rect(d, 4, 4, w-5, 18, (16, 10, 20, 255))
    rect(d, 4, 4, w-5, 4, "trog0")
    return im

def gen_panels():
    save(chip(), "ui", "chip.png")
    save(chip(60, 13), "ui", "chip_wide.png")
    save(seismo(), "ui", "seismo.png")

# ---------- captions & title (crisp TTF, no AA) ----------
def text_img(s, size=11, color="white", font_path="C:/Windows/Fonts/consolab.ttf", outline=True):
    font = ImageFont.truetype(font_path, size)
    tmp = Image.new("RGBA", (1000, 200), (0, 0, 0, 0))
    td = ImageDraw.Draw(tmp); td.fontmode = "1"
    td.text((10, 10), s, font=font, fill=P[color] if isinstance(color, str) else color)
    box = tmp.getbbox()
    tmp = tmp.crop(box)
    if not outline:
        return tmp
    w, h = tmp.size
    out = Image.new("RGBA", (w+2, h+2), (0, 0, 0, 0))
    mask = tmp.split()[3]
    ink = Image.new("RGBA", tmp.size, P["ink"] + (255,) if len(P["ink"]) == 3 else P["ink"])
    for (ox, oy) in [(0,1),(2,1),(1,0),(1,2),(2,2)]:
        out.paste(ink, (ox, oy), mask)
    out.paste(tmp, (1, 1), tmp)
    return out

CAPTIONS = {
    "cap_1": "The surface is done for.",
    "cap_2": "Dig. It's the only way.",
    "cap_3": "Build a life below.",
    "cap_4": "They can hear you.",
    "cap_5": "HOLD THE LINE.",
    "cap_6": "Survive the Big Swarm.",
    "cap_hint": "SPACE - next    ESC - quit",
}

def gen_captions():
    for name, s in CAPTIONS.items():
        col = "glow1" if name in ("cap_4", "cap_5") else "white"
        save(text_img(s, 11, col), "ui", name + ".png")
    # small labels
    save(text_img("SURVIVORS TOPSIDE", 11), "ui", "lbl_top.png")
    save(text_img("BELOW", 11), "ui", "lbl_below.png")
    save(text_img("THE SWARM", 11, "glow1"), "ui", "lbl_swarm.png")

def gen_title():
    # big chunky title: render at 28px, upscale x2 nearest for chunk
    t = text_img("EVERYONE DOWN!", 28, "brass3")
    t = t.resize((t.width*2, t.height*2), Image.NEAREST)
    save(t, "ui", "title.png")
    sub = text_img("a small game from Upstairs  -  demo mock", 11, "white")
    save(sub, "ui", "title_sub.png")

# ---------- light halo ----------
def gen_light():
    n = 128
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    pix = im.load()
    c = n // 2
    for y in range(n):
        for x in range(n):
            dx, dy = x - c, y - c
            dist = (dx*dx + dy*dy) ** 0.5 / c
            if dist < 1.0:
                a = int(255 * (1 - dist) ** 2)
                pix[x, y] = (255, 230, 180, a)
    save(im, "fx", "light_halo.png")

if __name__ == "__main__":
    gen_digits(); gen_icons(); gen_panels(); gen_captions(); gen_title(); gen_light()
    print("PART 3 DONE")
