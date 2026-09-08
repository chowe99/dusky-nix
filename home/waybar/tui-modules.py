#!/usr/bin/env python3
"""Point every waybar theme's network/bluetooth/audio modules at a TUI, and
move them to the right-hand side of the bar.

Waybar reads JSONC; plain JSON is valid JSONC, so the round-trip is safe. The
comment stripper is string-aware — a naive `//` regex would eat the `//` inside
URLs and inside format strings like "{icon} //".

usage: tui-modules.py <themes-dir> <wifi-cmd> <bluetooth-cmd> <audio-cmd>
"""

import json
import pathlib
import re
import sys

TARGET = re.compile(r"^(network|bluetooth|pulseaudio|wireplumber)(#.*)?$")


def strip_jsonc(text):
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            out.append(text[i : j + 1])
            i = j + 1
        elif text.startswith("//", i):
            i = text.find("\n", i)
            if i == -1:
                break
        elif text.startswith("/*", i):
            i = text.find("*/", i)
            i = n if i == -1 else i + 2
        else:
            out.append(c)
            i += 1
    # trailing commas are legal in JSONC, not in JSON
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def patch(path, cmds):
    try:
        cfg = json.loads(strip_jsonc(path.read_text()))
    except (ValueError, UnicodeDecodeError) as e:
        print(f"skip {path}: {e}", file=sys.stderr)
        return
    if not isinstance(cfg, dict):
        return

    # Which top-level modules are ours, and which drawer groups contain one.
    named = {k for k in cfg if TARGET.match(k)}
    groups = {
        k
        for k, v in cfg.items()
        if k.startswith("group/")
        and isinstance(v, dict)
        and named.intersection(v.get("modules") or [])
    }
    # A group is moved as a unit; its members must not be moved separately.
    in_group = {m for g in groups for m in (cfg[g].get("modules") or [])}
    movable = (named - in_group) | groups

    for key in named:
        mod = cfg[key]
        if not isinstance(mod, dict):
            continue
        base = key.split("#")[0]
        mod["on-click"] = cmds["network" if base == "network" else base]

    moved = []
    for side in ("modules-left", "modules-center"):
        keep = []
        for m in cfg.get(side) or []:
            (moved if m in movable else keep).append(m)
        if side in cfg:
            cfg[side] = keep
    right = [m for m in (cfg.get("modules-right") or []) if m not in moved]
    cfg["modules-right"] = moved + right

    path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")


def main():
    root, wifi, bluetooth, audio = sys.argv[1:5]
    cmds = {
        "network": wifi,
        "bluetooth": bluetooth,
        "pulseaudio": audio,
        "wireplumber": audio,
    }
    for p in pathlib.Path(root).rglob("config.jsonc"):
        patch(p, cmds)


if __name__ == "__main__":
    main()
