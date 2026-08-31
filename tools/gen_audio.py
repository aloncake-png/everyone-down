# Dig Game asset foundry part 4 — synthesized SFX (wav, 22050Hz mono 16-bit).
import math, os, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)

def rnd_stream(seed=1234):
    v = seed
    while True:
        v = (v * 1103515245 + 12345) % 2147483648
        yield (v / 2147483648.0) * 2 - 1

def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print("wrote", name + ".wav", len(samples) / SR, "s")

def env(i, n, a=0.01, r=0.5):
    t = i / n
    att = min(1.0, (i / SR) / a) if a > 0 else 1.0
    rel = (1 - t) ** r
    return att * rel

def sfx_dig():  # low thunk + dirt crunch
    n = int(SR * 0.16); r = rnd_stream(7); out = []
    for i in range(n):
        t = i / SR
        s = 0.6 * math.sin(2 * math.pi * (90 - 40 * t / 0.16) * t)
        s += 0.35 * next(r) * (1 - i / n) ** 2
        out.append(s * env(i, n, 0.002, 1.2))
    return out

def sfx_pop():  # building appears: rising boop
    n = int(SR * 0.22); out = []
    for i in range(n):
        t = i / SR
        f = 220 + 660 * (t / 0.22) ** 1.5
        s = 0.5 * math.sin(2 * math.pi * f * t) + 0.15 * math.sin(4 * math.pi * f * t)
        out.append(s * env(i, n, 0.004, 0.8))
    return out

def sfx_blip():  # counter tick
    n = int(SR * 0.05); out = []
    for i in range(n):
        t = i / SR
        out.append(0.3 * math.sin(2 * math.pi * 1320 * t) * env(i, n, 0.001, 1.5))
    return out

def sfx_gun():  # turret shot
    n = int(SR * 0.09); r = rnd_stream(21); out = []
    prev = 0.0
    for i in range(n):
        s = next(r)
        prev = 0.55 * prev + 0.45 * s  # lowpass-ish
        out.append((0.7 * prev + 0.2 * math.sin(2 * math.pi * 140 * i / SR)) * env(i, n, 0.001, 2.2))
    return out

def sfx_roar():  # swarm breach
    n = int(SR * 1.4); r = rnd_stream(99); out = []
    prev = 0.0
    for i in range(n):
        t = i / SR
        s = next(r)
        prev = 0.9 * prev + 0.1 * s
        growl = 0.5 * math.sin(2 * math.pi * (55 + 18 * math.sin(2 * math.pi * 3 * t)) * t)
        amp = min(1.0, t / 0.18) * (1 - t / 1.4) ** 0.7
        out.append((0.8 * prev + growl) * amp * 0.9)
    return out

def sfx_heart():  # seismograph heartbeat (two thumps)
    n = int(SR * 0.6); out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for t0 in (0.0, 0.22):
            if t >= t0:
                dt = t - t0
                s += 0.8 * math.sin(2 * math.pi * 52 * dt) * math.exp(-dt * 22)
        out.append(s)
    return out

def sfx_scream():  # tiny casualty squeak (cute, not grim)
    n = int(SR * 0.18); out = []
    for i in range(n):
        t = i / SR
        f = 900 - 500 * t / 0.18
        out.append(0.25 * math.sin(2 * math.pi * f * t) * env(i, n, 0.002, 1.0))
    return out

def sfx_meteor():  # whistle + boom
    n = int(SR * 0.7); r = rnd_stream(55); out = []
    prev = 0.0
    for i in range(n):
        t = i / SR
        s = 0.0
        if t < 0.35:
            f = 1600 - 1100 * t / 0.35
            s = 0.2 * math.sin(2 * math.pi * f * t)
        if t >= 0.33:
            dt = t - 0.33
            nz = next(r); prev = 0.8 * prev + 0.2 * nz
            s += (0.9 * prev + 0.4 * math.sin(2 * math.pi * 60 * dt)) * math.exp(-dt * 7)
        out.append(s)
    return out

def loop_drone():  # ambient underground drone, 6s loopable
    n = int(SR * 6.0); out = []
    for i in range(n):
        t = i / SR
        s = 0.10 * math.sin(2 * math.pi * 55 * t) + 0.07 * math.sin(2 * math.pi * 82.5 * t + 0.5)
        s += 0.05 * math.sin(2 * math.pi * 110.3 * t)   # slight detune shimmer
        s *= 1.0 + 0.15 * math.sin(2 * math.pi * t / 6.0)  # slow swell, loop-aligned
        out.append(s)
    return out

def loop_steam():  # soft hiss, 1s loopable
    n = int(SR * 1.0); r = rnd_stream(77); out = []
    prev = 0.0
    for i in range(n):
        s = next(r)
        prev = 0.7 * prev + 0.3 * s
        out.append(0.06 * prev)
    return out

if __name__ == "__main__":
    write_wav("dig", sfx_dig())
    write_wav("pop", sfx_pop())
    write_wav("blip", sfx_blip())
    write_wav("gun", sfx_gun())
    write_wav("roar", sfx_roar())
    write_wav("heart", sfx_heart())
    write_wav("squeak", sfx_scream())
    write_wav("meteor", sfx_meteor())
    write_wav("drone", loop_drone())
    write_wav("steam", loop_steam())
    print("PART 4 DONE")
