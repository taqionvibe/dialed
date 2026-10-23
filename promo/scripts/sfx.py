# Synthesizes the reel sound effects (no third-party audio): dial click, soft tick,
# whoosh, pop and a low "boom" for the logo hit. 44.1 kHz mono 16-bit WAV.
import math, random, struct, wave, sys
R = 44100
def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(f"{sys.argv[1]}/{name}.wav", "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes(b"".join(struct.pack("<h", int(32767 * 0.9 * s / peak)) for s in samples))
random.seed(7)
def env(i, n, attack=0.002, decay=6.0):
    t = i / R
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-decay * t / (n / R))
# Mechanical dial click: short resonant tick + noise transient.
n = int(R * 0.05)
write("click", [env(i, n, 0.0005, 9) * (0.6 * math.sin(2 * math.pi * 2600 * i / R) + 0.5 * (random.random() * 2 - 1)) for i in range(n)])
n = int(R * 0.035)
write("tick", [env(i, n, 0.0003, 10) * math.sin(2 * math.pi * 4200 * i / R) for i in range(n)])
# Whoosh: band-limited noise with rising-falling envelope and moving filter.
n = int(R * 0.45); y = 0.0; out = []
for i in range(n):
    t = i / n
    a = math.sin(math.pi * t) ** 2
    k = 0.02 + 0.25 * t
    y += k * ((random.random() * 2 - 1) - y)
    out.append(a * y)
write("whoosh", out)
# Pop: pitched blip falling.
n = int(R * 0.12)
write("pop", [env(i, n, 0.001, 5) * math.sin(2 * math.pi * (900 - 500 * i / n) * i / R) for i in range(n)])
# Boom: sub hit with a little click on top.
n = int(R * 0.9)
write("boom", [env(i, n, 0.002, 4) * (math.sin(2 * math.pi * (70 - 30 * i / n) * i / R) + 0.15 * math.sin(2 * math.pi * 140 * i / R)) for i in range(n)])
print("sfx ok")
