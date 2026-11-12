#!/usr/bin/env python3
"""Synthesises the game's placeholder sound effects into assets/audio/.

Run from the project folder:  python3 tools/generate_audio.py
"""
import math
import os
import struct
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RATE = 22050


def write(name, samples):
    os.makedirs(ROOT, exist_ok=True)
    with wave.open(os.path.join(ROOT, name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def level_up():
    notes = [523.25, 659.25, 783.99, 1046.5]  # rising C major arpeggio
    step, tail = 0.09, 0.6
    total = int((step * len(notes) + tail) * RATE)
    out = [0.0] * total
    for i, freq in enumerate(notes):
        start = int(i * step * RATE)
        for n in range(total - start):
            t = n / RATE
            envelope = min(t / 0.005, 1.0) * math.exp(-t * 5.0)
            tone = math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(4 * math.pi * freq * t)
            out[start + n] += 0.28 * envelope * tone
    return out


def noise(seed):
    """Deterministic white noise in -1..1."""
    import random
    r = random.Random(seed)
    return lambda: r.uniform(-1.0, 1.0)


def swing():
    """A short airy whoosh: filtered noise that rises then falls."""
    n = int(0.16 * RATE)
    rnd, low, out = noise(1), 0.0, []
    for i in range(n):
        t = i / n
        low += (rnd() - low) * (0.25 + 0.5 * t)
        out.append(0.5 * low * math.sin(math.pi * t) ** 1.5)
    return out


def hit():
    """A dull thump with a click on top."""
    n = int(0.14 * RATE)
    rnd, out = noise(2), []
    for i in range(n):
        t = i / RATE
        thump = math.sin(2 * math.pi * (150 - 500 * t) * t) * math.exp(-t * 34)
        click = rnd() * math.exp(-t * 160)
        out.append(0.6 * thump + 0.3 * click)
    return out


def pickup():
    """Two quick rising blips."""
    out = [0.0] * int(0.16 * RATE)
    for start, freq in ((0.0, 880.0), (0.06, 1318.5)):
        for i in range(int(0.09 * RATE)):
            t = i / RATE
            out[int(start * RATE) + i] += 0.3 * math.sin(2 * math.pi * freq * t) * math.exp(-t * 30)
    return out


def music():
    """A slow, dark loop: a low drone under a sparse minor-key melody.

    Every part repeats a whole number of times in LENGTH seconds, so the
    file loops without a click.
    """
    LENGTH = 32.0
    n = int(LENGTH * RATE)
    out = [0.0] * n
    two_pi = 2 * math.pi
    for i in range(n):
        t = i / RATE
        swell = 0.6 + 0.4 * math.sin(two_pi * t / 16.0)
        drone = math.sin(two_pi * 55.0 * t) + 0.5 * math.sin(two_pi * 82.5 * t) + 0.35 * math.sin(two_pi * 110.0 * t + math.sin(two_pi * t / 8.0))
        out[i] = 0.11 * drone * swell
    # A minor: one note every two seconds, each ringing for a while.
    notes = [220.0, 261.63, 329.63, 293.66, 220.0, 196.0, 261.63, 246.94, 220.0, 329.63, 392.0, 329.63, 293.66, 261.63, 246.94, 196.0]
    ring = int(3.6 * RATE)
    for k, freq in enumerate(notes):
        start = int(k * 2.0 * RATE)
        for j in range(ring):
            t = j / RATE
            env = min(t / 0.04, 1.0) * math.exp(-t * 1.3)
            tone = math.sin(two_pi * freq * t) + 0.4 * math.sin(two_pi * freq * 2 * t) * math.exp(-t * 3.0)
            out[(start + j) % n] += 0.085 * env * tone
    return out


def ui_hover():
    """A tiny soft tick for moving over a button."""
    n = int(0.035 * RATE)
    return [0.22 * math.sin(2 * math.pi * 1500 * i / RATE) * math.exp(-i / RATE * 110.0) for i in range(n)]


def ui_click():
    """A short woody click for pressing a button."""
    n = int(0.07 * RATE)
    rnd, out = noise(5), []
    for i in range(n):
        t = i / RATE
        out.append(0.4 * math.sin(2 * math.pi * 620 * t) * math.exp(-t * 60.0) + 0.18 * rnd() * math.exp(-t * 240.0))
    return out


def chop():
    """An axe biting into wood: a knock and a crack."""
    n = int(0.16 * RATE)
    rnd, out = noise(6), []
    for i in range(n):
        t = i / RATE
        out.append(0.55 * math.sin(2 * math.pi * (240 - 500 * t) * t) * math.exp(-t * 32.0) + 0.35 * rnd() * math.exp(-t * 90.0))
    return out


def mine():
    """A pick ringing on stone: a bright ping over a clack."""
    n = int(0.2 * RATE)
    rnd, out = noise(7), []
    for i in range(n):
        t = i / RATE
        ring = 0.3 * math.sin(2 * math.pi * 2100 * t) * math.exp(-t * 26.0) + 0.16 * math.sin(2 * math.pi * 3150 * t) * math.exp(-t * 34.0)
        out.append(ring + 0.4 * rnd() * math.exp(-t * 130.0))
    return out


def transform():
    """A rising, growling swell for changing shape."""
    n = int(1.1 * RATE)
    rnd, low, out = noise(8), 0.0, []
    for i in range(n):
        t = i / RATE
        low += (rnd() - low) * 0.08
        growl = math.sin(2 * math.pi * (70 + 90 * t) * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 23 * t))
        out.append((0.5 * growl + 0.9 * low) * min(t / 0.5, 1.0) * min((1.1 - t) / 0.15, 1.0) * 0.8)
    return out


def heartbeat():
    """Lub-dub: two soft, low thumps."""
    n = int(0.42 * RATE)
    out = [0.0] * n
    for start, strength, pitch in ((0.0, 1.0, 58.0), (0.17, 0.72, 72.0)):
        for i in range(int(0.2 * RATE)):
            t = i / RATE
            j = int(start * RATE) + i
            if j < n:
                out[j] += 0.9 * strength * math.sin(2 * math.pi * (pitch - 60 * t) * t) * math.exp(-t * 26.0) * min(t / 0.006, 1.0)
    return out


def _filtered(seed, seconds, colour, level=1.0):
    """Noise smoothed by a one-pole filter: colour near 0 is a low rumble, near 1 a hiss."""
    rnd, low, out = noise(seed), 0.0, []
    for _ in range(int(seconds * RATE)):
        low += (rnd() - low) * colour
        out.append(low * level)
    return out


def _loop(samples, overlap=0.25):
    """Blends the tail into the head so the sound repeats without a click."""
    k = int(overlap * RATE)
    body = samples[:-k]
    for i in range(k):
        t = i / k
        body[i] = body[i] * t + samples[len(samples) - k + i] * (1.0 - t)
    return body


def step(kind):
    """One footfall: soft on grass, a click on stone, a crunch in snow, a plop in water, a hush on sand."""
    n = int(0.11 * RATE)
    rnd, low, out = noise({"grass": 11, "stone": 12, "snow": 13, "water": 14, "sand": 15}[kind]), 0.0, []
    for i in range(n):
        t = i / RATE
        if kind == "stone":
            low += (rnd() - low) * 0.6
            out.append(0.5 * low * math.exp(-t * 70.0) + 0.3 * math.sin(2 * math.pi * 320 * t) * math.exp(-t * 90.0))
        elif kind == "snow":
            low += (rnd() - low) * 0.8
            out.append(0.42 * low * math.sin(math.pi * min(t / 0.09, 1.0)) * (0.6 + 0.4 * math.sin(2 * math.pi * 55 * t)))
        elif kind == "water":
            low += (rnd() - low) * 0.35
            out.append(0.5 * low * math.exp(-t * 28.0) + 0.25 * math.sin(2 * math.pi * (500 - 2400 * t) * t) * math.exp(-t * 40.0))
        elif kind == "sand":
            low += (rnd() - low) * 0.5
            out.append(0.3 * low * math.sin(math.pi * min(t / 0.1, 1.0)))
        else:
            low += (rnd() - low) * 0.22
            out.append(0.55 * low * math.exp(-t * 34.0))
    return out


def amb_wind():
    """A slow sighing wind that loops."""
    n = int(6.0 * RATE)
    base = _filtered(21, 6.25, 0.035, 2.4)
    return _loop([base[i] * (0.55 + 0.45 * math.sin(2 * math.pi * i / n) * math.sin(2 * math.pi * 2 * i / n + 1.0)) for i in range(len(base))])


def amb_rain():
    """Steady rain on leaves and ground, looping."""
    hiss = _filtered(22, 4.25, 0.75, 0.33)
    patter = _filtered(23, 4.25, 0.2, 0.9)
    return _loop([hiss[i] + patter[i] * 0.5 for i in range(len(hiss))])


def amb_night():
    """Crickets: bursts of a high trill over a quiet bed, looping."""
    n = int(5.25 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        chirp = 1.0 if (t * 2.2) % 1.0 < 0.34 else 0.0
        trill = 0.5 + 0.5 * math.sin(2 * math.pi * 38 * t)
        second = 1.0 if ((t + 0.37) * 1.3) % 1.0 < 0.2 else 0.0
        out.append(0.11 * chirp * trill * math.sin(2 * math.pi * 4300 * t) + 0.07 * second * trill * math.sin(2 * math.pi * 3600 * t))
    return _loop(out)


def amb_cave():
    """The hollow breath of a cave: a low drone that swells and sinks, looping."""
    n = int(6.25 * RATE)
    rumble = _filtered(24, 6.25, 0.012, 5.0)
    return _loop([rumble[i] * 0.7 + 0.05 * math.sin(2 * math.pi * 61 * i / RATE) * (0.5 + 0.5 * math.sin(2 * math.pi * i / n)) for i in range(n)])


def amb_fire():
    """A fire: a soft roar with pops and cracks, looping."""
    n = int(3.25 * RATE)
    roar = _filtered(25, 3.25, 0.06, 1.6)
    rnd = noise(26)
    out = [roar[i] * 0.5 for i in range(n)]
    i = 0
    while i < n - 400:
        if rnd() > 0.9993:
            strength = 0.3 + 0.5 * abs(rnd())
            for k in range(300):
                out[i + k] += strength * rnd() * math.exp(-k / 40.0)
            i += 300
        i += 1
    return _loop(out)


def bird():
    """Two quick falling chirps."""
    out = []
    for start, pitch in ((0.0, 3200.0), (0.14, 2800.0)):
        for i in range(int(0.14 * RATE)):
            t = i / RATE
            if t < 0.09:
                out.append(0.28 * math.sin(2 * math.pi * (pitch + 900 * math.sin(t * 60.0)) * t) * math.sin(math.pi * t / 0.09))
            else:
                out.append(0.0)
    return out


def drip():
    """A drop of water falling into a pool, with an echo."""
    n = int(0.5 * RATE)
    out = [0.0] * n
    for start, strength in ((0.0, 1.0), (0.16, 0.3), (0.3, 0.12)):
        for i in range(int(0.12 * RATE)):
            t = i / RATE
            j = int(start * RATE) + i
            if j < n:
                out[j] += 0.4 * strength * math.sin(2 * math.pi * (900 + 1400 * t) * t) * math.exp(-t * 34.0)
    return out


def thunder():
    """A crack, then a long rolling rumble."""
    n = int(2.4 * RATE)
    rumble = _filtered(27, 2.4, 0.02, 6.0)
    rnd = noise(28)
    out = []
    for i in range(n):
        t = i / RATE
        crack = 0.7 * rnd() * math.exp(-t * 22.0)
        out.append((crack + rumble[i] * (0.9 * math.exp(-t * 1.5) * (0.6 + 0.4 * math.sin(t * 9.0)))) * min(t / 0.004, 1.0))
    return out


SFX = (("ui_hover", lambda: ui_hover()), ("ui_click", lambda: ui_click()), ("chop", lambda: chop()), ("mine", lambda: mine()), ("transform", lambda: transform()),
       ("heartbeat", lambda: heartbeat()), ("step_grass", lambda: step("grass")), ("step_stone", lambda: step("stone")), ("step_snow", lambda: step("snow")),
       ("step_water", lambda: step("water")), ("step_sand", lambda: step("sand")), ("amb_wind", lambda: amb_wind()), ("amb_rain", lambda: amb_rain()),
       ("amb_night", lambda: amb_night()), ("amb_cave", lambda: amb_cave()), ("amb_fire", lambda: amb_fire()), ("bird", lambda: bird()), ("drip", lambda: drip()),
       ("thunder", lambda: thunder()))


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "sfx":
        # Only the effects and ambience; leaves the music alone.
        for name, make in SFX:
            write(name + ".wav", make())
        sys.exit(0)
    for name, make in SFX:
        write(name + ".wav", make())
    write("level_up.wav", level_up())
    write("swing.wav", swing())
    write("hit.wav", hit())
    write("pickup.wav", pickup())
    # The music is large as a WAV; convert it and delete the WAV:
    #   ffmpeg -i assets/audio/music.wav -c:a libvorbis -q:a 3 assets/audio/music.ogg
    write("music.wav", music())
