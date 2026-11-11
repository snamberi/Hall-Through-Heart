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


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "sfx":
        # Only the short effects; leaves the music alone.
        for name, make in (("ui_hover", ui_hover), ("ui_click", ui_click), ("chop", chop), ("mine", mine), ("transform", transform)):
            write(name + ".wav", make())
        sys.exit(0)
    write("ui_hover.wav", ui_hover())
    write("ui_click.wav", ui_click())
    write("chop.wav", chop())
    write("mine.wav", mine())
    write("transform.wav", transform())
    write("level_up.wav", level_up())
    write("swing.wav", swing())
    write("hit.wav", hit())
    write("pickup.wav", pickup())
    # The music is large as a WAV; convert it and delete the WAV:
    #   ffmpeg -i assets/audio/music.wav -c:a libvorbis -q:a 3 assets/audio/music.ogg
    write("music.wav", music())
