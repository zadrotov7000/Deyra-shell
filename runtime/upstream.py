#!/usr/bin/env python3
"""Launch the installed upstream runtime, not Deyra lookalikes."""
import os
import sys
import shutil
from pathlib import Path

home = Path.home()
config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
# Upstream foreground entrypoints, verified against their documentation.
entries = {
    "Serpantinum": (["serpantinumd", "start"], ("niri", "hyprland"), ["quickshell", "serpantinum-core"], None),
    "Noctalia": (["noctalia"], ("niri", "hyprland"), [], None),
    "DankMaterialShell": (["dms", "run"], ("niri", "hyprland"), [], None),
    "Caelestia": (["qs", "-c", "caelestia"], ("hyprland",), ["caelestia"], config / "quickshell/caelestia/shell.qml"),
    "Illogical Impulse": (["qs", "-c", "ii"], ("hyprland",), [], config / "quickshell/ii/shell.qml"),
    "iNiR": (["inir", "run", "--foreground"], ("niri",), [], None),
    "Ambxst": (["ambxst"], ("niri", "hyprland"), [], None),
}
blocked = {
    "TQQ Rice": "Multi-process Niri rice; needs a separate session integration.",
    "HyDE": "Hyprland dotfiles; needs a separate installed session.",
    "ML4W": "Hyprland dotfiles; needs a separate installed session.",
    "DotFriedRice": "Niri dotfiles; needs a separate installed session.",
    "DarkShadow": "Its launcher starts detached helpers; safe full-session switching is not implemented yet.",
}

def check(name):
    if name in blocked:
        raise RuntimeError(blocked[name])
    if name not in entries:
        raise RuntimeError("Unknown shell")
    cmd, compositors, extra, required = entries[name]
    compositor = "niri" if os.environ.get("NIRI_SOCKET") else "hyprland" if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") else ""
    if compositor not in compositors:
        raise RuntimeError("Requires " + " or ".join(compositors) + "; current compositor: " + (compositor or "unknown"))
    missing = [item for item in [cmd[0], *extra] if not shutil.which(item)]
    if missing:
        raise RuntimeError("Install the original shell first. Missing: " + ", ".join(missing))
    if required and not required.is_file():
        raise RuntimeError("Original installed configuration not found: " + str(required))
    return cmd

def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("check", "run"):
        raise RuntimeError("Usage: upstream.py check|run NAME")
    cmd = check(sys.argv[2])
    if sys.argv[1] == "check":
        print("Original runtime found: " + " ".join(cmd), flush=True)
    else:
        print("Starting original runtime: " + " ".join(cmd), flush=True)
        os.execvp(cmd[0], cmd)

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as exc:
        print(str(exc), flush=True)
        sys.exit(2)
