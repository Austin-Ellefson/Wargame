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
    parser.add_argument("--report-capture", type=Path)
    parser.add_argument("--path-capture", type=Path)
    parser.add_argument("--logs-dir", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    logs = args.logs_dir or Path(tempfile.mkdtemp(prefix="wargame-checks-"))
    logs.mkdir(parents=True, exist_ok=True)
    checks = [("editor", ["--headless", "--editor", "--quit"])]
    for name in ["campaign_smoke", "campaign_save_smoke", "tactical_smoke",
                 "repeatable_loop_smoke", "suppression_smoke", "visibility_smoke", "contact_memory_smoke", "movement_orders_smoke", "fire_control_smoke", "target_orders_smoke", "timed_pause_smoke", "opponent_reaction_smoke", "cover_routing_smoke", "covered_goals_smoke", "fatigue_smoke", "morale_smoke", "posture_smoke", "weapon_roles_smoke", "acquisition_smoke", "command_response_smoke", "shared_reports_smoke", "observer_memory_smoke", "soldier_visual_smoke", "soldier_animation_smoke", "tactical_view_smoke"]:
        checks.append((name, ["--headless", "--script", f"res://tests/{name}.gd"]))
    if args.render_check:
        if args.capture:
            args.capture = args.capture.resolve()
            args.capture.parent.mkdir(parents=True, exist_ok=True)
        if args.report_capture:
            args.report_capture = args.report_capture.resolve()
            args.report_capture.parent.mkdir(parents=True, exist_ok=True)
        if args.path_capture:
            args.path_capture = args.path_capture.resolve()
            args.path_capture.parent.mkdir(parents=True, exist_ok=True)
        command = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                   "--script", "res://tests/tactical_view_smoke.gd"]
        if args.capture:
            command.extend(["--", f"--capture={args.capture}"])
        if args.report_capture:
            if "--" not in command:
                command.append("--")
            command.append(f"--report-capture={args.report_capture}")
        if args.path_capture:
            if "--" not in command:
                command.append("--")
            command.append(f"--path-capture={args.path_capture}")
        checks.append(("render", command))
        soldier_command = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "res://tests/soldier_visual_smoke.gd"]
        if args.capture:
            soldier_command.extend(["--", f"--capture={args.capture}"])
        checks.append(("soldier_render", soldier_command))
        animation_command = soldier_command.copy()
        animation_command[animation_command.index("res://tests/soldier_visual_smoke.gd")] = "res://tests/soldier_animation_smoke.gd"
        checks.append(("animation_render", animation_command))
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
    if args.render_check and args.report_capture and not args.report_capture.is_file():
        print("FAILED: rendered report screenshot was not created", file=sys.stderr)
        return 1
    if args.render_check and args.path_capture and not args.path_capture.is_file():
        print("FAILED: rendered path screenshot was not created", file=sys.stderr)
        return 1
    print(f"Godot checks complete; logs: {logs}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
