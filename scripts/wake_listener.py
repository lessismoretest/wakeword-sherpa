#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shlex
import subprocess
import time
from pathlib import Path

import numpy as np
import sherpa_onnx
import sounddevice as sd


def file_exists(path: str) -> str:
    p = Path(path)
    if not p.is_file():
        raise argparse.ArgumentTypeError(f"File not found: {path}")
    return str(p)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Always-on wake word listener with sherpa-onnx")
    parser.add_argument("--tokens", type=file_exists, required=True)
    parser.add_argument("--encoder", type=file_exists, required=True)
    parser.add_argument("--decoder", type=file_exists, required=True)
    parser.add_argument("--joiner", type=file_exists, required=True)
    parser.add_argument("--keywords-file", type=file_exists, required=True)
    parser.add_argument("--trigger-cmd", required=True, help="Shell command executed on wake detection")
    parser.add_argument("--provider", default="cpu", choices=["cpu", "coreml", "cuda"])
    parser.add_argument("--num-threads", type=int, default=1)
    parser.add_argument("--max-active-paths", type=int, default=4)
    parser.add_argument("--keywords-score", type=float, default=1.2)
    parser.add_argument("--keywords-threshold", type=float, default=0.35)
    parser.add_argument("--num-trailing-blanks", type=int, default=2)
    parser.add_argument("--cooldown-seconds", type=float, default=2.5)
    parser.add_argument(
        "--beep-cmd",
        default="",
        help="Optional shell command to play a sound when wake word is detected",
    )
    parser.add_argument(
        "--input-device",
        default="",
        help="Audio input device name/id passed to sounddevice.InputStream",
    )
    parser.add_argument(
        "--audio-log-interval",
        type=float,
        default=3.0,
        help="Seconds between microphone RMS/peak logs. Set 0 to disable.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    kws = sherpa_onnx.KeywordSpotter(
        tokens=args.tokens,
        encoder=args.encoder,
        decoder=args.decoder,
        joiner=args.joiner,
        num_threads=args.num_threads,
        max_active_paths=args.max_active_paths,
        keywords_file=args.keywords_file,
        keywords_score=args.keywords_score,
        keywords_threshold=args.keywords_threshold,
        num_trailing_blanks=args.num_trailing_blanks,
        provider=args.provider,
    )

    sample_rate = 16000
    samples_per_read = int(0.1 * sample_rate)
    stream = kws.create_stream()

    print("[wake-listener] started")
    print(f"[wake-listener] keywords_file={args.keywords_file}")
    print(f"[wake-listener] trigger_cmd={args.trigger_cmd}")
    if args.input_device:
        print(f"[wake-listener] input_device={args.input_device}")

    last_trigger_ts = 0.0

    stream_kwargs = {
        "channels": 1,
        "dtype": "float32",
        "samplerate": sample_rate,
    }
    current_device = args.input_device
    if current_device:
        stream_kwargs["device"] = current_device

    try:
        audio_in = sd.InputStream(**stream_kwargs)
    except Exception as e:
        if args.input_device:
            print(f"[wake-listener] warning: cannot open input_device={args.input_device}: {e}")
            print("[wake-listener] fallback to default input device")
            stream_kwargs.pop("device", None)
            current_device = ""
            audio_in = sd.InputStream(**stream_kwargs)
        else:
            raise

    next_audio_log_ts = time.time() + max(args.audio_log_interval, 0.0)
    silent_log_count = 0
    with audio_in:
        while True:
            samples, _ = audio_in.read(samples_per_read)
            samples = samples.reshape(-1)
            stream.accept_waveform(sample_rate, samples)

            if args.audio_log_interval > 0:
                now = time.time()
                if now >= next_audio_log_ts:
                    rms = float(np.sqrt(np.mean(np.square(samples))))
                    peak = float(np.max(np.abs(samples)))
                    print(f"[wake-listener] audio rms={rms:.6f} peak={peak:.6f}")
                    if peak < 1e-7:
                        silent_log_count += 1
                    else:
                        silent_log_count = 0

                    if silent_log_count >= 3 and current_device:
                        # Some macOS routes can return all-zero audio for specific device names.
                        # Fallback to default input device to keep wakeword usable.
                        print(
                            f"[wake-listener] warning: device={current_device} appears silent; "
                            "fallback to default input device"
                        )
                        audio_in.abort(ignore_errors=True)
                        audio_in.close(ignore_errors=True)
                        stream_kwargs.pop("device", None)
                        current_device = ""
                        audio_in = sd.InputStream(**stream_kwargs)
                        audio_in.start()
                        silent_log_count = 0
                    next_audio_log_ts = now + args.audio_log_interval

            while kws.is_ready(stream):
                kws.decode_stream(stream)
                result = kws.get_result(stream)
                if not result:
                    continue

                now = time.time()
                if now - last_trigger_ts < args.cooldown_seconds:
                    kws.reset_stream(stream)
                    continue

                last_trigger_ts = now
                print(f"[wake-listener] detected: {result}")
                if args.beep_cmd:
                    subprocess.Popen(args.beep_cmd, shell=True)
                subprocess.Popen(f"{args.trigger_cmd} {shlex.quote(result)}", shell=True)
                kws.reset_stream(stream)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[wake-listener] stopped")
