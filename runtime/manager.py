#!/usr/bin/env python3
"""Deyra managed upstream installation. No compositor configs or upstream installers are copied."""
import fcntl
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
BASE = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "deyra-shell" / "managed"
SOURCES = CONFIG / "deyra-shell" / "upstream"
REPOS = {
    "TQQ Rice": "zadrotov7000/TQQ-Niri-rice",
    "Noctalia": "noctalia-dev/noctalia",
    "DankMaterialShell": "duxlabs-dev/dux-shell",
    "Caelestia": "caelestia-dots/shell",
    "Illogical Impulse": "end-4/dots-hyprland",
    "HyDE": "HyDE-Project/HyDE",
    "ML4W": "mylinuxforwork/dotfiles",
    "iNiR": "snowarch/iNiR",
    "DotFriedRice": "nickjj/dotfriedrice",
    "Ambxst": "Axenide/Ambxst",
    "DarkShadow": "shadowww-dev/DarkShadowShell",
    "Serpantinum": "ilyamiro/serpantinum",
}
RECIPES = {
    "Serpantinum": "git curl jq python3 file pciutils util-linux playerctl wireplumber wl-clipboard grim imagemagick ffmpeg bluez network-manager ddcutil tesseract-ocr zbar-tools qml6-module-qtquick-effects qml6-module-qtmultimedia qml6-module-qtquick-controls qml6-module-qtquick-layouts",
    "Noctalia": "git meson ninja-build pkg-config g++ libwayland-dev wayland-protocols libegl-dev libgles-dev libfreetype-dev libfontconfig-dev libcairo2-dev libpango1.0-dev libharfbuzz-dev libxkbcommon-dev libglib2.0-dev libsecret-1-dev libsodium-dev libsdbus-c++-dev libpipewire-0.3-dev libwireplumber-0.5-dev libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev libcurl4-openssl-dev libwebp-dev libjxl-dev libsndfile1-dev librsvg2-dev libqalculate-dev libxml2-dev libmd4c-dev libtomlplusplus-dev libical-dev nlohmann-json3-dev libstb-dev libjemalloc-dev",
}
def slug(name):
    if name not in REPOS:
        raise ValueError("Unknown project")
    return re.sub("[^a-z0-9]+", "-", name.lower()).strip("-")

def owned(name):
    return BASE / slug(name)

def say(msg):
    print(msg, flush=True)

def run(argv, cwd=None, **kw):
    say("+ " + " ".join(map(str, argv)))
    subprocess.run(list(map(str, argv)), cwd=cwd, check=True, **kw)

def capture(argv, cwd=None):
    return subprocess.check_output(list(map(str, argv)), cwd=cwd, text=True).strip()

def metadata(name):
    try:
        p = owned(name) / "current.json"
        data = json.loads(p.read_text())
        version = data["directory"]
        if not re.fullmatch(r"release-[0-9a-f]{12}-[0-9]+", version):
            return None
        root = owned(name) / version
        if not root.is_dir() or root.is_symlink():
            return None
        return data
    except (OSError, ValueError, KeyError, TypeError):
        return None

def release_dir(name):
    data = metadata(name)
    return owned(name) / data["directory"] if data else None

def runtime(name):
    root = release_dir(name)
    if root is None:
        return None
    env = dict(os.environ)
    if name == "Noctalia":
        exe = root / "bin/noctalia"
        return ([str(exe)], env) if exe.is_file() and os.access(exe, os.X_OK) else None
    if name == "Serpantinum":
        exe = root / "repo/bin/serpantinumd"
        if not exe.is_file() or not (root / "repo/src/quickshell/Shell.qml").is_file():
            return None
        for b in ("serpantinum-core", "serpantinum-audio", "serpantinum-gamma"):
            if not os.access(root / "bin" / b, os.X_OK):
                return None
        if not shutil.which("quickshell"):
            return None
        env["PATH"] = str(root / "bin") + ":" + str(root / "repo/bin") + ":" + env.get("PATH", "")
        env["SERPANTINUM_DIR"] = str(root / "repo/src")
        env["MAIN_QML"] = str(root / "repo/src/quickshell/Shell.qml")
        return (["bash", str(exe), "start"], env)
    return None

def distro():
    try:
        return dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)["ID"].strip('"')
    except (OSError, KeyError):
        return ""

def missing_packages(name):
    result = []
    for pkg in RECIPES[name].split():
        p = subprocess.run(["dpkg-query", "-W", "-f=${Status}", pkg], text=True, capture_output=True)
        if p.returncode or p.stdout.strip() != "install ok installed":
            result.append(pkg)
    return result

def ensure_deps(name):
    if distro() not in ("debian", "ubuntu"):
        raise RuntimeError("Managed installation currently supports Debian/Ubuntu only.")
    if platform.machine() != "x86_64":
        raise RuntimeError("Managed build is currently restricted to x86_64.")
    if name == "Serpantinum" and not shutil.which("quickshell"):
        raise RuntimeError("Original Serpantinum requires the quickshell executable; install a compatible build first.")
    minimum = (5 if name == "Noctalia" else 1) * 1024**3
    if shutil.disk_usage(BASE).free < minimum:
        raise RuntimeError("Not enough free disk space for a safe staged installation; no dependencies were changed.")
    missing = missing_packages(name)
    if missing:
        say("Missing packages: " + ", ".join(missing))
        # No repository changes, no removals, no autoremove, and authentication via the user's agent.
        run(["apt-get", "-s", "--no-remove", "install", *missing])
        if not shutil.which("pkexec"):
            raise RuntimeError("pkexec is unavailable. Install the listed dependencies with your package manager, then retry.")
        run(["pkexec", "/usr/bin/apt-get", "-y", "--no-remove", "install", *missing])
        if missing_packages(name):
            raise RuntimeError("Some dependencies are still missing.")

def clone(name, target):
    run(["git", "-c", "core.hooksPath=/dev/null", "-c", "protocol.file.allow=never",
         "clone", "--depth", "1", "--no-tags", "--", "https://github.com/" + REPOS[name] + ".git", target])
    return capture(["git", "-C", target, "rev-parse", "HEAD"])

def get(url, path, limit=150 * 1024 * 1024):
    req = urllib.request.Request(url, headers={"User-Agent": "Deyra-Shell-Manager"})
    with urllib.request.urlopen(req, timeout=60) as response, path.open("wb") as output:
        n = 0
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            n += len(block)
            if n > limit:
                raise RuntimeError("Download exceeded size limit")
            output.write(block)

def backend(repo, kind, dest, tmp):
    name = "serpantinum-" + kind
    # Versions are taken from the checked-out original shell's packaging manifest.
    version = re.search(r'version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"', (repo / "nix" / (kind + ".nix")).read_text())
    if not version:
        raise RuntimeError("Cannot find upstream pinned version for " + name)
    version = version.group(1)
    archive = name + "-" + version + "-x86_64-linux.tar.gz"
    url = "https://github.com/ilyamiro/" + name + "/releases/download/v" + version + "/"
    say("Downloading official " + name + " " + version)
    checksums = tmp / (name + ".sha256")
    tarpath = tmp / archive
    get(url + "SHA256SUMS", checksums, 1024 * 1024)
    get(url + archive, tarpath)
    expected = None
    for line in checksums.read_text().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].lstrip("*") == archive and re.fullmatch("[a-fA-F0-9]{64}", parts[0]):
            expected = parts[0].lower()
    with tarpath.open("rb") as f:
        digest = hashlib.file_digest(f, "sha256").hexdigest()
    if not expected or digest != expected:
        raise RuntimeError("Checksum mismatch for " + name)
    # Extract only the named regular executable; never unpack paths or symlinks.
    with tarfile.open(tarpath, "r:gz") as tar:
        item = next((m for m in tar if m.name.lstrip("./") == "usr/bin/" + name and m.isfile()), None)
        if item is None or item.size > 100 * 1024 * 1024:
            raise RuntimeError("Official archive does not contain expected executable")
        with tar.extractfile(item) as f, (dest / name).open("wb") as out:
            shutil.copyfileobj(f, out)
        (dest / name).chmod(0o755)
    tarpath.unlink()

def install(name):
    if name not in RECIPES:
        raise RuntimeError("No reviewed Debian installation recipe. Use the official guide; source download is not installation.")
    ensure_deps(name)
    parent = owned(name)
    if parent.is_symlink():
        raise RuntimeError("Refusing symlinked installation directory")
    parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(parent).free < (5 if name == "Noctalia" else 1) * 1024**3:
        raise RuntimeError("Not enough disk space for a safe staged installation")
    with tempfile.TemporaryDirectory(prefix=".stage-", dir=parent) as td:
        tmp = Path(td)
        repo = tmp / "repo"
        say("Fetching actual upstream source")
        commit = clone(name, repo)
        old = metadata(name)
        if old and commit.startswith(old.get("commit", "") or "invalid") and runtime(name):
            say("Already at the downloaded upstream commit " + commit[:12])
            return
        folder = "release-" + commit[:12] + "-" + str(time.time_ns())
        target = parent / folder
        target.mkdir()
        try:
            if name == "Serpantinum":
                repo.rename(target / "repo")
                repo = target / "repo"
                (target / "bin").mkdir()
                for kind in ("core", "audio", "gamma"):
                    backend(repo, kind, target / "bin", tmp)
                for p in (repo / "bin").iterdir():
                    if p.is_file() and not p.is_symlink():
                        p.chmod(p.stat().st_mode | 0o100)
                for p in (repo / "src").rglob("*"):
                    if p.is_file() and not p.is_symlink() and p.suffix in (".sh", ".py"):
                        p.chmod(p.stat().st_mode | 0o100)
                # Preserve upstream UI, skip only automatic migration of external configs.
                for script in ("migrate_niri_overview.sh", "migrate_easyeffects.sh"):
                    path = repo / "src/scripts" / script
                    if path.is_file():
                        shutil.copy2(path, path.with_suffix(".sh.upstream"))
                        path.write_text("#!/bin/sh\n# Deyra: do not migrate an existing desktop configuration.\nexit 0\n")
                        path.chmod(0o755)
                if not (repo / "src/quickshell/Shell.qml").is_file():
                    raise RuntimeError("Original root QML missing")
            else:
                # Real Noctalia Meson build, one job to limit peak RAM on low-end laptops.
                build = tmp / "build"
                run(["meson", "setup", build, repo, "--prefix", target, "--buildtype=release", "-Dtests=disabled"])
                run(["meson", "compile", "-C", build, "-j", "1"])
                run(["meson", "install", "-C", build, "--no-rebuild"])
                if not (target / "bin/noctalia").is_file():
                    raise RuntimeError("Original Noctalia binary missing")
            data = {"directory": folder, "commit": commit, "name": name, "previous": old["directory"] if old else ""}
            out = parent / ".current.tmp"
            out.write_text(json.dumps(data))
            os.replace(out, parent / "current.json")
            say("Installed original source " + name + " at " + commit[:12] + ". Runtime test still required.")
        except BaseException:
            shutil.rmtree(target, ignore_errors=True)
            raise

def rollback(name):
    parent = owned(name)
    if parent.is_symlink():
        raise RuntimeError("Refusing symlinked installation directory")
    data = metadata(name)
    old = (data or {}).get("previous", "")
    if not re.fullmatch(r"release-[0-9a-f]{12}-[0-9]+", old):
        raise RuntimeError("No previous managed version")
    target = parent / old
    if not target.is_dir() or target.is_symlink():
        raise RuntimeError("Previous version is missing")
    before = data["directory"]
    data["directory"], data["previous"] = old, before
    data["commit"] = old.split("-")[1]
    tmp = parent / ".current.tmp"
    tmp.write_text(json.dumps(data))
    os.replace(tmp, parent / "current.json")
    say("Previous managed version selected. Apply it to test.")

def remove(name):
    parent = owned(name)
    # Only remove manager-owned, versioned directories; keep user configs and APT dependencies.
    if parent.is_symlink():
        raise RuntimeError("Refusing symlinked installation directory")
    if parent.exists():
        for entry in parent.iterdir():
            if re.fullmatch(r"release-[0-9a-f]{12}-[0-9]+", entry.name) and entry.is_dir() and not entry.is_symlink():
                shutil.rmtree(entry)
        (parent / "current.json").unlink(missing_ok=True)
    say("Managed runtime removed; original settings and shared dependencies retained.")

def source_download(name, update=False):
    SOURCES.mkdir(parents=True, exist_ok=True)
    target = SOURCES / slug(name)
    if target.is_symlink():
        raise RuntimeError("Refusing symlinked source checkout")
    if target.exists():
        if not (target / ".git").is_dir():
            raise RuntimeError("Source directory exists but is not a Git checkout")
        if not update:
            say("Original sources already downloaded")
            return
        url = capture(["git", "-C", target, "remote", "get-url", "origin"])
        if url.rstrip("/").removesuffix(".git") != "https://github.com/" + REPOS[name]:
            raise RuntimeError("Unexpected source remote")
        run(["git", "-C", target, "-c", "core.hooksPath=/dev/null", "pull", "--ff-only"])
    else:
        with tempfile.TemporaryDirectory(prefix=".download-", dir=SOURCES) as td:
            checkout = Path(td) / "repo"
            clone(name, checkout)
            checkout.rename(target)
    say("Original source checkout ready (not a runtime installation)")

def catalog():
    return {name: {"recipe": name in RECIPES, "managed": metadata(name) is not None, "ready": runtime(name) is not None,
                   "rollback": bool((metadata(name) or {}).get("previous")),
                   "source": (SOURCES / slug(name) / ".git").is_dir(),
                   "commit": (metadata(name) or {}).get("commit", "")[:12]}
            for name in REPOS}

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action == "catalog":
        say(json.dumps(catalog()))
        return
    if len(sys.argv) != 3:
        raise RuntimeError("Usage: manager.py catalog|plan|install|update|remove|rollback|source|source-update NAME")
    name = sys.argv[2]
    slug(name)
    if action == "plan":
        if name not in RECIPES:
            raise RuntimeError("No managed recipe for this project")
        say("Install original " + name + ". APT may install missing dependencies (no package removal). "
            "The runtime is installed in Deyra's managed directory. "
            + ("Official backend archives are SHA-256 checked. " if name == "Serpantinum" else "Compile upstream C++ using one build job. ")
            + "Existing compositor configs are not replaced by this installer. Upstream runtime may make its own settings changes.")
        return
    BASE.mkdir(parents=True, exist_ok=True)
    with (BASE / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if action in ("install", "update"):
            install(name)
        elif action == "remove":
            remove(name)
        elif action == "rollback":
            rollback(name)
        elif action in ("source", "source-update"):
            source_download(name, action == "source-update")
        else:
            raise RuntimeError("Unknown operation")

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, KeyError, tarfile.TarError) as e:
        say("ERROR: " + str(e))
        sys.exit(1)
