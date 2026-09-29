#!/usr/bin/env python3
"""Session-level dependency audit for a whole dusky desktop configuration.

runtime-deps checks that each packaged script carries its own tools. This
checks the other half: the commands the *deployed configs* launch by name —
Hyprland keybinds/autostart (exec_cmd), desktop entries, waybar modules,
wlogout, hypridle and matugen's post_hooks — resolve on the evaluated
system (system profile + home profile + setuid wrappers).

Hyprland's Lua is evaluated just far enough to join string concatenations
over the globals the configs define (terminal, browser, dusky_scripts, …),
so `dusky_scripts .. "rofi/emoji.sh"` is checked as the real shim path.

Failures: a bare command that is not installed. Warnings (non-fatal):
references into upstream's script tree that dusky-nix does not package, and
leftover Arch paths (~/user_scripts/...), both of which are upstream-port
gaps rather than missing dependencies.
"""

from __future__ import annotations

import json
import re
import sys
import tomllib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit import BASH_BUILTINS, shell_commands  # noqa: E402

LUA_STR = re.compile(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'|\[\[(.*?)\]\]', re.S)


def strip_lua_comments(text: str) -> str:
    """Drop -- line comments and --[[ ]] blocks, leaving strings intact
    (`gdbus call --dest ...` inside a [[string]] is not a comment)."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            out.append(text[i : j + 1])
            i = j + 1
        elif text.startswith("[[", i):
            j = text.find("]]", i + 2)
            j = n if j == -1 else j + 2
            out.append(text[i:j])
            i = j
        elif text.startswith("--[[", i):
            j = text.find("]]", i + 4)
            i = n if j == -1 else j + 2
        elif text.startswith("--", i):
            j = text.find("\n", i)
            i = n if j == -1 else j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def lua_strings_assignments(text: str) -> dict[str, str]:
    out = {}
    for m in re.finditer(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')\s*(?:--.*)?$', text, re.M):
        out[m.group(1)] = m.group(2)[1:-1]
    return out


def lua_call_args(text: str, fname: str):
    """Yield the raw argument text of every fname(...) call."""
    for m in re.finditer(re.escape(fname) + r"\s*\(", text):
        i = m.end()
        depth = 1
        j = i
        while j < len(text) and depth:
            c = text[j]
            if c in "\"'":
                q = c
                j += 1
                while j < len(text) and text[j] != q:
                    j += 2 if text[j] == "\\" else 1
            elif text.startswith("[[", j):
                j = text.find("]]", j) + 1 or len(text)
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            j += 1
        yield text[i : j - 1]


def lua_eval_concat(expr: str, env: dict[str, str]) -> str | None:
    """Evaluate `"a" .. var .. [[b]]`; None if anything else is in there."""
    parts = []
    rest = expr.strip()
    # only the first argument
    while rest:
        m = LUA_STR.match(rest)
        if m:
            s = next(g for g in m.groups() if g is not None)
            if m.group(3) is None:
                s = s.replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\")
            parts.append(s)
            rest = rest[m.end() :].lstrip()
        else:
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", rest)
            if not m or m.group(0) not in env:
                return None
            parts.append(env[m.group(0)])
            rest = rest[m.end() :].lstrip()
        if rest.startswith(".."):
            rest = rest[2:].lstrip()
            continue
        if rest == "" or rest.startswith(","):
            break
        return None
    return "".join(parts)


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument("--shfmt", required=True)
    ap.add_argument("--home-files", required=True)
    ap.add_argument("--bin", action="append", default=[], help="bin dir on the session PATH")
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--allow", required=True)
    a = ap.parse_args()

    avail: set[str] = set(BASH_BUILTINS)
    avail |= {l.strip() for l in Path(a.baseline).read_text().splitlines() if l.strip()}
    for b in a.bin:
        p = Path(b)
        if p.is_dir():
            avail |= {e.name for e in p.iterdir()}
    allow = set()
    for line in Path(a.allow).read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            allow.add(line)

    hf = Path(a.home_files)
    sources: list[tuple[str, str]] = []  # (origin, command string)
    warnings: list[str] = []
    problems: list[str] = []

    # --- Hyprland Lua -------------------------------------------------------
    hypr = hf / ".config" / "hypr"
    env: dict[str, str] = {"HOME": "$HOME"}
    lua_files = sorted(p for p in hypr.rglob("*.lua") if p.is_file()) if hypr.exists() else []
    # globals first: default_apps + hyprland.lua (dusky_scripts)
    for p in lua_files:
        if p.name in ("default_apps.lua", "hyprland.lua"):
            env.update(lua_strings_assignments(p.read_text(errors="replace")))
    for p in lua_files:
        text = p.read_text(errors="replace")
        text = strip_lua_comments(text)
        for arg in lua_call_args(text, "exec_cmd"):
            s = lua_eval_concat(arg, env)
            if s is not None:
                sources.append((str(p.relative_to(hf)), s))

    # --- desktop entries ----------------------------------------------------
    apps = hf / ".local" / "share" / "applications"
    if apps.exists():
        for p in sorted(apps.glob("*.desktop")):
            for line in p.read_text(errors="replace").splitlines():
                if line.startswith("Exec="):
                    cmd = re.sub(r"%[a-zA-Z]", "", line[5:]).strip()
                    sources.append((str(p.relative_to(hf)), cmd))

    # --- waybar -------------------------------------------------------------
    wb = hf / ".config" / "waybar"
    if wb.exists():
        for p in sorted(wb.rglob("*.jsonc")):
            text = p.read_text(errors="replace")
            for m in re.finditer(r'"(exec|exec-if|on-click[-a-z]*|on-scroll-[a-z]+|on-double-click[-a-z]*)"\s*:\s*"((?:[^"\\]|\\.)*)"', text):
                try:
                    cmd = json.loads('"' + m.group(2) + '"')
                except ValueError:
                    continue
                sources.append((f"{p.relative_to(hf)} {m.group(1)}", cmd))

    # --- wlogout ------------------------------------------------------------
    wl = hf / ".config" / "wlogout" / "layout"
    if wl.exists():
        for m in re.finditer(r'"action"\s*:\s*"((?:[^"\\]|\\.)*)"', wl.read_text()):
            sources.append((".config/wlogout/layout", json.loads('"' + m.group(1) + '"')))

    # --- hypridle -----------------------------------------------------------
    hi = hf / ".config" / "hypr" / "hypridle.conf"
    if hi.exists():
        for m in re.finditer(r"^\s*(lock_cmd|unlock_cmd|before_sleep_cmd|after_sleep_cmd|on-timeout|on-resume)\s*=\s*(.+)$", hi.read_text(), re.M):
            sources.append((f".config/hypr/hypridle.conf {m.group(1)}", m.group(2)))

    # --- matugen post_hooks -------------------------------------------------
    mt = hf / ".config" / "matugen" / "config.toml"
    if mt.exists():
        try:
            cfg = tomllib.loads(mt.read_text())
            for name, t in (cfg.get("templates") or {}).items():
                for k in ("post_hook", "pre_hook"):
                    if isinstance(t.get(k), str):
                        sources.append((f".config/matugen/config.toml {name}.{k}", t[k]))
        except tomllib.TOMLDecodeError as e:
            problems.append(f"matugen config.toml does not parse: {e}")

    # --- check ---------------------------------------------------------------
    checked = 0
    for origin, cmd in sources:
        checked += 1
        for m in re.finditer(r"(?:~|\$HOME|\$\{HOME\})/user_scripts/[^\s\"';|&)]+", cmd):
            warnings.append(f"{origin}: Arch path {m.group(0)} (not on NixOS)")
        probes: set[str] = set()
        called, funcs, errors = shell_commands(cmd, a.shfmt, origin, probes)
        problems += errors
        for c in sorted(called - funcs):
            if c in avail or c in allow or f"{origin.split()[0]}:{c}" in allow:
                continue
            if c.startswith("/nix/store/"):
                if not Path(c).exists():
                    warnings.append(f"{origin}: {c.split('/user_scripts/', 1)[-1] if '/user_scripts/' in c else c} is not packaged (dead reference)")
                continue
            if c.startswith("/"):
                problems.append(f"{origin}: absolute FHS path {c}")
                continue
            if "/" in c or not re.match(r"^[A-Za-z0-9_.+-]+$", c):
                continue
            if c in probes:
                warnings.append(f"{origin}: optional `{c}` (probed) not installed")
                continue
            problems.append(f"{origin}: `{c}` is not installed")

    print(f"checked {checked} launch commands from {len(lua_files)} lua files, desktop entries, waybar, wlogout, hypridle, matugen")
    if warnings:
        print(f"\n{len(set(warnings))} warning(s) (upstream-port gaps, not fatal):")
        for w in sorted(set(warnings)):
            print("  " + w)
    if problems:
        print(f"\n{len(set(problems))} problem(s):")
        for p in sorted(set(problems)):
            print("  " + p)
        print("\nFix: install the providing package from the dusky-nix module that deploys the config,"
              " or allowlist it in checks/session-deps/allowlist.")
        return 1
    print("ok: every launched command is installed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
