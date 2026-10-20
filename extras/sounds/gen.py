#!/usr/bin/env python3
# Собирает звуки событий extras/sounds/ochre/*.wav (services/Sounds.qml): синтез без зависимостей.
#   python3 extras/sounds/gen.py [каталог]
import math
import random
import struct
import sys
import wave
from pathlib import Path

rate = 22050


def note(name):
    names = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
    semi = names[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    return 440 * 2 ** ((semi + 12 * (octave - 4) - 9) / 12)


def wave_fn(kind):
    if kind == "sine":
        return lambda p: math.sin(p)
    if kind == "tri":
        return lambda p: 2 / math.pi * math.asin(math.sin(p))
    return lambda p: math.tanh(4 * math.sin(p)) / math.tanh(4)


def tone(freq, ms, kind, level=1.0, slide=None, decay=6.0):
    n = int(rate * ms / 1000)
    fn = wave_fn(kind)
    attack = int(rate * 0.004)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq if slide is None else freq * (slide / freq) ** t
        phase += 2 * math.pi * f / rate
        env = min(1.0, i / attack) * math.exp(-decay * t) * min(1.0, (n - i) / attack)
        out.append(fn(phase) * env * level)
    return out


def noise(ms, level=1.0, decay=18.0):
    n = int(rate * ms / 1000)
    rnd = random.Random(7)
    prev = 0.0
    out = []
    for i in range(n):
        prev = prev * 0.55 + rnd.uniform(-1, 1) * 0.45
        out.append(prev * math.exp(-decay * i / n) * level)
    return out


def rest(ms):
    return [0.0] * int(rate * ms / 1000)


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def sounds(kind):
    return {
        "notify": seq(tone(note("e5"), 70, kind), tone(note("b5"), 120, kind)),
        "critical": seq(*[seq(tone(note("a5"), 80, kind, decay=2), rest(60)) for _ in range(3)]),
        "lock": seq(tone(note("g5"), 70, kind), tone(note("c5"), 140, kind)),
        "unlock": seq(tone(note("c5"), 70, kind), tone(note("g5"), 140, kind)),
        "auth-fail": tone(note("c3"), 220, kind, decay=3, slide=note("a2")),
        "screenshot": seq(noise(35, 1.2), rest(25), noise(55, 0.9)),
        "plug": seq(tone(note("c5"), 60, kind), tone(note("e5"), 60, kind), tone(note("g5"), 130, kind)),
        "unplug": seq(tone(note("g5"), 60, kind), tone(note("e5"), 60, kind), tone(note("c5"), 130, kind)),
        "battery-low": seq(tone(note("e4"), 160, kind, decay=2), rest(140), tone(note("e4"), 160, kind, decay=2)),
        "volume": tone(note("a5"), 35, kind, 0.6, decay=10),
        "mute": tone(note("a4"), 90, kind, slide=note("e4")),
        "unmute": tone(note("e4"), 90, kind, slide=note("a4")),
        "rec-start": seq(tone(note("d5"), 60, kind), rest(50), tone(note("d5"), 60, kind), rest(50), tone(note("a5"), 150, kind)),
        "rec-stop": seq(tone(note("a5"), 60, kind), tone(note("d5"), 150, kind)),
        "timer": seq(*[seq(mix(tone(note("c6"), 90, kind, 0.7, decay=3), tone(note("g5"), 90, kind, 0.5, decay=3)), rest(70)) for _ in range(4)]),
        "login": seq(
            tone(note("a4"), 140, kind, decay=3), tone(note("c5"), 140, kind, decay=3), tone(note("e5"), 140, kind, decay=3),
            tone(note("d5"), 140, kind, decay=3), mix(tone(note("a5"), 700, kind, 0.6, decay=3), tone(note("e5"), 700, kind, 0.35, decay=3), tone(note("c5"), 700, kind, 0.3, decay=3))),
    }


def save(path, samples, gain):
    peak = max(abs(s) for s in samples) or 1.0
    data = b"".join(struct.pack("<h", int(s / peak * gain * 32767)) for s in samples + rest(30))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / "ochre"
    out.mkdir(parents=True, exist_ok=True)
    for name, samples in sounds("square").items():
        save(out / f"{name}.wav", samples, 0.32)


main()
