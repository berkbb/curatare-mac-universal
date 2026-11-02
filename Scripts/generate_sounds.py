#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
generate_sounds.py — Synthesize original, high-assurance audio effects for Curatare.

Generates:
  1. curatare_trash.aiff   - A silky modern UI swoosh with a warm acoustic bottom body.
  2. curatare_restore.aiff - An uplifting, crystalline three-note chime (A5 -> C#6 -> E6 + shimmer).

Zero external dependencies: uses Python standard library + macOS /usr/bin/afconvert.
"""

import argparse
import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

SAMPLE_RATE = 44100


def generate_trash_waveform(duration: float = 0.28) -> bytes:
    """Synthesizes a silky modern macOS UI swoosh with tactile bottom body."""
    num_samples = int(SAMPLE_RATE * duration)
    frames = bytearray()

    rng = random.Random(1337)
    raw_noise = [rng.uniform(-1.0, 1.0) for _ in range(num_samples)]

    lp_state = 0.0

    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples

        # 1. Subtle tactile click at onset (first 5ms)
        click = 0.0
        if t < 0.006:
            click = math.sin(2.0 * math.pi * 320.0 * t) * (1.0 - t / 0.006) * 0.35

        # 2. Silky descending swoosh
        cutoff = 1600.0 * (1.0 - progress) ** 2.2 + 180.0
        alpha = min(1.0, 2.0 * math.pi * cutoff / SAMPLE_RATE)
        lp_state += alpha * (raw_noise[i] - lp_state)

        if t < 0.006:
            swoosh_env = t / 0.006
        else:
            swoosh_env = math.exp(-((t - 0.006) / 0.12) ** 1.3)

        swoosh = lp_state * swoosh_env * 0.55

        # 3. Warm tactile low body (thump: 110 Hz -> 55 Hz)
        thump_env = math.exp(-t * 22.0)
        thump_freq = 110.0 * math.exp(-t * 12.0) + 55.0
        thump = math.sin(2.0 * math.pi * thump_freq * t) * thump_env * 0.45

        # 4. Subtle air whisper texture
        whisper = 0.0
        if 0.02 < t < 0.16:
            w_env = math.sin((t - 0.02) / 0.14 * math.pi)
            whisper = (raw_noise[i] - raw_noise[max(0, i - 1)]) * 0.18 * w_env

        mix = click + swoosh + thump + whisper
        mix = math.tanh(mix * 1.3) * 0.85

        # Spatial stereo staging: swoosh moves subtly left to right
        pan = 0.5 + 0.25 * (progress - 0.5)
        left = mix * math.cos(pan * math.pi / 2.0) * 1.4
        right = mix * math.sin(pan * math.pi / 2.0) * 1.4

        val_l = int(max(-32767, min(32767, left * 32767)))
        val_r = int(max(-32767, min(32767, right * 32767)))
        frames.extend(struct.pack('<hh', val_l, val_r))

    return bytes(frames)


def generate_restore_waveform(duration: float = 0.58) -> bytes:
    """Synthesizes an uplifting crystalline chime (A5 -> C#6 -> E6 + shimmer)."""
    num_samples = int(SAMPLE_RATE * duration)
    frames = bytearray()

    # Note tuples: (onset_time, freq, decay_rate, base_amp, pan)
    notes = [
        (0.00,  880.00, 7.5, 0.38, -0.28),   # A5
        (0.07, 1108.73, 6.5, 0.42,  0.00),   # C#6
        (0.14, 1318.51, 5.0, 0.50,  0.28),   # E6
        (0.14, 1760.00, 6.0, 0.22,  0.15),   # A6 octave sparkle
        (0.14, 2637.02, 9.0, 0.12,  0.30),   # E7 overtone shimmer
    ]

    for i in range(num_samples):
        t = i / SAMPLE_RATE
        left_mix = 0.0
        right_mix = 0.0

        for onset, freq, decay, amp, pan in notes:
            if t >= onset:
                dt = t - onset
                if dt < 0.003:
                    env = (dt / 0.003) * amp
                else:
                    env = math.exp(-dt * decay) * amp

                fundamental = math.sin(2.0 * math.pi * freq * dt)
                partial2 = math.sin(2.0 * math.pi * freq * 2.756 * dt) * 0.15
                partial3 = math.sin(2.0 * math.pi * freq * 4.0 * dt) * 0.06

                wave_val = (fundamental + partial2 + partial3) * env

                pan_angle = (pan + 1.0) * math.pi / 4.0
                left_mix += wave_val * math.cos(pan_angle)
                right_mix += wave_val * math.sin(pan_angle)

        left_mix = math.tanh(left_mix * 1.1) * 0.85
        right_mix = math.tanh(right_mix * 1.1) * 0.85

        val_l = int(max(-32767, min(32767, left_mix * 32767)))
        val_r = int(max(-32767, min(32767, right_mix * 32767)))
        frames.extend(struct.pack('<hh', val_l, val_r))

    return bytes(frames)


def write_wav(path: str, data: bytes):
    with wave.open(path, 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(data)


def wav_to_aiff(wav_path: str, aiff_path: str):
    cmd = ['/usr/bin/afconvert', '-f', 'AIFF', '-d', 'BEI16', wav_path, aiff_path]
    subprocess.check_call(cmd)


def main():
    parser = argparse.ArgumentParser(description="Generate Curatare sound effects.")
    parser.add_argument(
        '--output-dir',
        default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'Resources'),
        help='Target directory for AIFF sound files.',
    )
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmpdir:
        # 1. Trash Sound
        trash_wav = os.path.join(tmpdir, 'curatare_trash.wav')
        trash_aiff = os.path.join(args.output_dir, 'curatare_trash.aiff')
        write_wav(trash_wav, generate_trash_waveform())
        wav_to_aiff(trash_wav, trash_aiff)
        print(f"✓ Generated: {trash_aiff}")

        # 2. Restore Sound
        restore_wav = os.path.join(tmpdir, 'curatare_restore.wav')
        restore_aiff = os.path.join(args.output_dir, 'curatare_restore.aiff')
        write_wav(restore_wav, generate_restore_waveform())
        wav_to_aiff(restore_wav, restore_aiff)
        print(f"✓ Generated: {restore_aiff}")


if __name__ == '__main__':
    main()
