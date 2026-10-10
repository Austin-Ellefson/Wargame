"""Run Godot checks and reject script errors even when Godot exits with status 0."""

import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--render-check", action="store_true")
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--logs-dir", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    logs = args.logs_dir or Path(tempfile.mkdtemp(prefix="wargame-checks-"))
    logs.mkdir(parents=True, exist_ok=True)
    checks = [("editor", ["--headless", "--editor", "--quit"])]
    for name in ["campaign_smoke", "campaign_save_smoke", "tactical_smoke",
                 "repeatable_loop_smoke", "tactical_view_smoke"]:
        checks.append((name, ["--headless", "--script", f"res://tests/{name}.gd"]))
    if args.render_check:
        if args.capture:
            args.capture = args.capture.resolve()
            args.capture.parent.mkdir(parents=True, exist_ok=True)
        command = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                   "--script", "res://tests/tactical_view_smoke.gd"]
        if args.capture:
            command.extend(["--", f"--capture={args.capture}"])
        checks.append(("render", command))
    for name, flags in checks:
        result = subprocess.run([args.godot, "--path", str(root), *flags], cwd=root,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=90)
        (logs / f"{name}.log").write_text(result.stdout)
        error = re.search(r"(?:SCRIPT ERROR:|^ERROR:)", result.stdout, re.MULTILINE)
        if result.returncode or error or (name != "editor" and "PASS:" not in result.stdout):
            print(result.stdout)
            print(f"FAILED: {name}; exit={result.returncode}; logs={logs}", file=sys.stderr)
            return 1
        print(f"PASS: {name}")
    if args.render_check and args.capture and not args.capture.is_file():
        print("FAILED: rendered screenshot was not created", file=sys.stderr)
        return 1
    print(f"Godot checks complete; logs: {logs}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
