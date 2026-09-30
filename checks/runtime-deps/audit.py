#!/usr/bin/env python3
"""Runtime-dependency audit for packaged dusky scripts.

For every executable in a package's bin/ directory this finds the external
commands the script (and the upstream files it execs) invokes, and fails if a
command is not reachable from what the package itself puts on PATH, the NixOS
base system, or the allowlist.

Why: dusky's scripts were written for Arch, where "every tool is installed".
Under Nix each wrapper must carry its own runtime closure; a script that calls
notify-send, wl-copy or jq only works on a host that happens to install them.

What counts as "reachable" for a script:
  * store bin/ dirs named on a PATH line of the wrapper (writeShellApplication
    runtimeInputs, makeWrapper --prefix PATH, `export PATH=...`),
  * the NixOS baseline (coreutils, util-linux, systemd, ... -- see default.nix),
  * bash builtins/keywords, functions the script defines itself,
  * allowlist entries (`cmd` globally, or `bin-name:cmd` for one binary).

Shell is parsed with shfmt's JSON AST, so only words in command position
count. Python is parsed with `ast`: subprocess/os.system/asyncio/GLib spawn
calls with a literal argv, plus every import not guarded by try/except (checked
with the script's own interpreter, so withPackages gaps show up too).

It is a heuristic: commands built from variables are invisible to it. It is
meant to catch the "script calls a tool the host happens to have" class of bug,
not to prove a closure complete.
"""

from __future__ import annotations

import ast
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

STORE_RE = re.compile(r"/nix/store/[a-z0-9]{32}-[^\s\"'`;:|)(<>{}$\\,]+")
PY_RE = re.compile(r"(/nix/store/[a-z0-9]{32}-[^/\s\"']+)/bin/python3(?:\.\d+)?\b")

BASH_BUILTINS = set(
    """
    . : [ [[ ]] alias bg bind break builtin caller case cd command compgen complete
    compopt continue declare dirs disown echo enable eval exec exit export false fc fg
    for function getopts hash help history if jobs kill let local logout mapfile popd
    printf pushd pwd read readarray readonly return select set shift shopt source
    suspend test then time times trap true type typeset ulimit umask unalias unset
    until wait while coproc do done elif else esac fi in { } ! declare
    """.split()
)

# Words that run the *next* word as the real command. The prefix itself is
# still reported (it must exist too), then skipped with its options.
PREFIX_CMDS = {"exec", "nohup", "setsid", "builtin", "nice", "ionice", "stdbuf", "sudo", "pkexec", "doas", "chrt", "taskset", "unbuffer"}


def is_elf(path: Path) -> bool:
    try:
        with open(path, "rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return True


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(errors="replace")
    except (OSError, UnicodeDecodeError):
        return None


def path_dirs_of(text: str) -> list[Path]:
    """Store bin dirs on the script's PATH lines."""
    dirs: list[Path] = []
    for line in text.splitlines():
        if not re.search(r"(?<![A-Z_])PATH\b", line):
            continue
        for m in STORE_RE.finditer(line):
            p = Path(m.group(0))
            cand = p if p.name == "bin" else p / "bin"
            if cand.is_dir() and cand not in dirs:
                dirs.append(cand)
    return dirs


def commands_in(dirs: list[Path]) -> set[str]:
    out: set[str] = set()
    for d in dirs:
        try:
            out.update(e.name for e in d.iterdir())
        except OSError:
            pass
    return out


# --------------------------------------------------------------------------- shell


def word_lit(word: dict) -> str | None:
    """A shfmt Word as a literal string, or None if it has any expansion."""
    parts = word.get("Parts") or []
    out = ""
    for p in parts:
        t = p.get("Type")
        if t == "Lit":
            out += p.get("Value", "")
        elif t == "SglQuoted":
            out += p.get("Value", "")
        elif t == "DblQuoted":
            inner = word_lit({"Parts": p.get("Parts") or []})
            if inner is None:
                return None
            out += inner
        else:
            return None
    return out


def resolve_call(args: list[str | None], probes: set[str]) -> tuple[list[str], list[str]]:
    """(commands, nested shell snippets) for one CallExpr argv. Names that are
    only existence-probed (`command -v X`, `type X`, `hash X`, `which X`) go
    to `probes`."""
    cmds: list[str] = []
    snippets: list[str] = []
    i = 0
    while i < len(args):
        a = args[i]
        if a is None or a == "":
            break
        if "=" in a and i == 0 and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", a):
            i += 1
            continue
        if a in ("command",):
            if i + 1 < len(args) and args[i + 1] in ("-v", "-V"):
                probes.update(x for x in args[i + 2 :] if x)
                break  # existence probe, guards an optional tool
            i += 1
            while i < len(args) and args[i] and args[i].startswith("-"):
                i += 1
            continue
        if a in ("type", "hash", "which"):
            probes.update(x for x in args[i + 1 :] if x and not x.startswith("-"))
            break
        if a in PREFIX_CMDS:
            cmds.append(a)
            i += 1
            while i < len(args) and args[i] is not None and (args[i].startswith("-") or args[i].isdigit()):
                # `nice -n 10`, `sudo -u user`: skip an option's value too
                if args[i] in ("-n", "-u", "-g", "-c", "-p") and a != "exec":
                    i += 1
                i += 1
            continue
        if a == "env":
            cmds.append(a)
            i += 1
            while i < len(args) and args[i] is not None and (args[i].startswith("-") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", args[i])):
                i += 1
            continue
        if a == "timeout":
            cmds.append(a)
            i += 1
            while i < len(args) and args[i] is not None and args[i].startswith("-"):
                # `timeout -k 1s 5s cmd`, `-s KILL`: skip an option's value too
                if args[i] in ("-k", "--kill-after", "-s", "--signal"):
                    i += 1
                i += 1
            i += 1  # duration
            continue
        if a in ("uwsm-app", "uwsm"):
            cmds.append(a)
            rest = args[i + 1 :]
            if "--" in rest:
                i = i + 1 + rest.index("--") + 1
                continue
            break
        if a in ("bash", "sh", "zsh") and "-c" in args[i + 1 :]:
            cmds.append(a)
            j = args.index("-c", i + 1)
            if j + 1 < len(args) and args[j + 1]:
                snippets.append(args[j + 1])
            break
        cmds.append(a)
        break
    return cmds, snippets


def shell_commands(text: str, shfmt: str, origin: str, probes: set[str] | None = None) -> tuple[set[str], set[str], list[str]]:
    """(called commands, defined functions, parse errors). Probed names are
    added to `probes` when given."""
    if probes is None:
        probes = set()
    try:
        res = subprocess.run([shfmt, "--to-json", "-ln", "bash"], input=text, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return set(), set(), [f"{origin}: shfmt timed out"]
    if res.returncode != 0:
        # Self-extracting scripts (rofi/emoji.sh) carry a data blob after a
        # top-level `exit`; only the code before it is shell.
        m = re.search(r"^exit\b[^\n]*$", text, re.M)
        if m and m.end() < len(text.rstrip()):
            return shell_commands(text[: m.end()] + "\n", shfmt, origin, probes)
        return set(), set(), [f"{origin}: shfmt could not parse: {res.stderr.strip().splitlines()[0] if res.stderr.strip() else '?'}"]
    tree = json.loads(res.stdout)
    called: set[str] = set()
    funcs: set[str] = set()
    errors: list[str] = []
    stack = [tree]
    while stack:
        node = stack.pop()
        if isinstance(node, list):
            stack.extend(node)
            continue
        if not isinstance(node, dict):
            continue
        t = node.get("Type")
        if t == "FuncDecl":
            name = (node.get("Name") or {}).get("Value")
            if name:
                funcs.add(name)
        elif t == "CallExpr":
            args = [word_lit(w) for w in node.get("Args") or []]
            cmds, snippets = resolve_call(args, probes)
            called.update(cmds)
            for s in snippets:
                c, f, e = shell_commands(s, shfmt, origin + " (-c)", probes)
                called |= c
                funcs |= f
                errors += e
        for v in node.values():
            if isinstance(v, (dict, list)):
                stack.append(v)
    return called, funcs, errors


# --------------------------------------------------------------------------- python

SPAWN_FUNCS = {
    ("subprocess", "run"), ("subprocess", "Popen"), ("subprocess", "call"),
    ("subprocess", "check_call"), ("subprocess", "check_output"),
    ("subprocess", "getoutput"), ("subprocess", "getstatusoutput"),
    ("os", "system"), ("os", "popen"), ("os", "execvp"), ("os", "execlp"),
    ("os", "spawnlp"), ("os", "spawnvp"),
    ("asyncio", "create_subprocess_exec"), ("asyncio", "create_subprocess_shell"),
    ("GLib", "spawn_async"), ("GLib", "spawn_command_line_async"),
    ("GLib", "spawn_command_line_sync"), ("GLib", "spawn_sync"),
}
SHELL_STRING_FUNCS = {"system", "popen", "getoutput", "getstatusoutput", "create_subprocess_shell", "spawn_command_line_async", "spawn_command_line_sync"}


def _func_key(func: ast.expr) -> tuple[str, str] | None:
    if isinstance(func, ast.Attribute):
        base = func.value
        if isinstance(base, ast.Name):
            return (base.id, func.attr)
        if isinstance(base, ast.Attribute):
            return (base.attr, func.attr)
    if isinstance(func, ast.Name):
        # `from subprocess import run` style
        return ("subprocess", func.id) if func.id in {"run", "Popen", "check_output", "check_call", "call"} else None
    return None


def _first_str(node: ast.expr) -> str | None:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, (ast.List, ast.Tuple)) and node.elts:
        e = node.elts[0]
        if isinstance(e, ast.Constant) and isinstance(e.value, str):
            return e.value
    return None


def python_facts(text: str, origin: str) -> tuple[set[str], set[str], list[str], list[str], set[str]]:
    """(commands, shell snippets, unguarded imports, errors, probed names)."""
    try:
        tree = ast.parse(text)
    except SyntaxError as e:
        return set(), set(), [], [f"{origin}: python parse error: {e}"], set()
    cmds: set[str] = set()
    probes: set[str] = set()
    snippets: set[str] = set()
    imports: list[str] = []

    def visit(node: ast.AST, guarded: bool) -> None:
        if isinstance(node, ast.Try) or (hasattr(ast, "TryStar") and isinstance(node, ast.TryStar)):
            for child in node.body:
                visit(child, True)
            for h in node.handlers:
                visit(h, guarded)
            for child in node.orelse + node.finalbody:
                visit(child, guarded)
            return
        if isinstance(node, ast.If):
            # `if TYPE_CHECKING:` / version gates: treat as guarded
            visit(node.test, guarded)
            for child in node.body + node.orelse:
                visit(child, True)
            return
        if isinstance(node, ast.Import) and not guarded:
            imports.extend(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom) and not guarded and node.level == 0 and node.module:
            imports.append(node.module.split(".")[0])
        elif isinstance(node, ast.Call):
            key = _func_key(node.func)
            if key == ("shutil", "which") and node.args:
                w = _first_str(node.args[0])
                if w:
                    probes.add(w)
            if key in SPAWN_FUNCS and node.args:
                first = node.args[0]
                s = _first_str(first)
                if isinstance(first, ast.Constant) and isinstance(first.value, str) and (key[1] in SHELL_STRING_FUNCS or any(k.arg == "shell" and isinstance(k.value, ast.Constant) and k.value.value for k in node.keywords)):
                    snippets.add(first.value)
                elif s is not None:
                    if isinstance(first, ast.Constant):
                        try:
                            parts = shlex.split(s)
                        except ValueError:
                            parts = []
                        if parts:
                            cmds.add(parts[0])
                    else:
                        cmds.add(s)
        for child in ast.iter_child_nodes(node):
            visit(child, guarded)

    visit(tree, False)
    return cmds, snippets, sorted(set(imports)), [], probes


def missing_imports(python: str, script: Path, modules: list[str], pythonpath: list[str]) -> list[str]:
    if not modules:
        return []
    probe = (
        "import importlib.util, sys, json\n"
        f"sys.path[0:0] = {[str(script.parent)] + pythonpath!r}\n"
        f"mods = {modules!r}\n"
        "bad = []\n"
        "for m in mods:\n"
        "    try:\n"
        "        if importlib.util.find_spec(m) is None: bad.append(m)\n"
        "    except Exception: bad.append(m)\n"
        "print(json.dumps(bad))\n"
    )
    env = dict(os.environ)
    env.pop("PYTHONPATH", None)
    res = subprocess.run([python, "-c", probe], capture_output=True, text=True, env=env)
    if res.returncode != 0:
        return [f"<probe failed: {res.stderr.strip()[:200]}>"]
    return json.loads(res.stdout)


def local_modules(script: Path, modules: list[str]) -> list[Path]:
    out = []
    for m in modules:
        for cand in (script.parent / f"{m}.py", script.parent / m / "__init__.py"):
            if cand.is_file():
                out.append(cand)
    return out


# --------------------------------------------------------------------------- driver


class Audit:
    def __init__(self, shfmt: str, baseline: set[str], allow: set[str], siblings: set[str]):
        self.shfmt = shfmt
        self.baseline = baseline
        self.allow = allow
        # Every binary of the audited set: they are installed as one unit
        # (dusky-scripts-all / the profile's home.packages), so one script may
        # call another by name. A call to a sibling that does not exist is
        # still caught.
        self.siblings = siblings
        self.problems: list[str] = []
        self.warnings: list[str] = []
        self.seen: set[tuple[str, str]] = set()
        self.checked = 0

    def allowed(self, binname: str, cmd: str) -> bool:
        return cmd in self.allow or f"{binname}:{cmd}" in self.allow

    def report(self, binname: str, cmd: str, origin: str, avail: set[str], probes: set[str]) -> None:
        if cmd in avail or cmd in BASH_BUILTINS or cmd in self.baseline or cmd in self.siblings or self.allowed(binname, cmd):
            return
        if cmd.startswith("/nix/store/"):
            if not Path(cmd).exists():
                self.problems.append(f"{binname}: {cmd} does not exist ({origin})")
            return
        if cmd.startswith("/"):
            if cmd not in ("/bin/sh", "/usr/bin/env"):
                self.problems.append(f"{binname}: absolute FHS path {cmd} ({origin})")
            return
        if cmd.startswith(("./", "~", "../")) or "/" in cmd:
            return  # relative paths: not a PATH lookup
        if not re.match(r"^[A-Za-z0-9_.+-]+$", cmd):
            return
        if cmd in probes:
            # The script checks for it first (command -v / which / shutil.which):
            # optional, or an Arch auto-install path. Reported, not fatal.
            self.warnings.append(f"{binname}: optional `{cmd}` (probed before use) not in closure ({origin})")
            return
        self.problems.append(f"{binname}: `{cmd}` not in its runtime closure ({origin})")

    def analyze(self, binname: str, path: Path, dirs: list[Path], python: str | None, depth: int = 0, pythonpath: list[str] | None = None) -> None:
        key = (binname, str(path))
        if key in self.seen or depth > 4:
            return
        self.seen.add(key)
        if is_elf(path):
            return
        text = read_text(path)
        if text is None:
            return
        self.checked += 1
        own = path_dirs_of(text)
        pythonpath = list(pythonpath or [])
        for line in text.splitlines():
            if "PYTHONPATH" in line:
                pythonpath += [m.group(0) for m in STORE_RE.finditer(line) if m.group(0) not in pythonpath]
        dirs = dirs + [d for d in own if d not in dirs]
        avail = commands_in(dirs)
        first = text.split("\n", 1)[0]
        pym = PY_RE.search(text)
        if pym:
            python = pym.group(0)
        origin = path.name if depth else "wrapper"
        is_py = path.suffix == ".py" or (first.startswith("#!") and "python" in first)
        if is_py:
            if first.startswith("#!") and "python" in first and first[2:].split()[0].startswith("/nix/store"):
                python = first[2:].split()[0]
            cmds, snippets, imports, errors, probes = python_facts(text, origin)
            self.problems += [f"{binname}: {e}" for e in errors]
            for c in sorted(cmds):
                self.report(binname, c, origin, avail, probes)
            for s in sorted(snippets):
                c2, f2, e2 = shell_commands(s, self.shfmt, origin + " (shell string)", probes)
                for c in sorted(c2 - f2):
                    self.report(binname, c, origin + " (shell string)", avail, probes)
            interp = python or next((str(d / "python3") for d in dirs if (d / "python3").exists()), None)
            if interp is None:
                self.problems.append(f"{binname}: python script {origin} has no python on its closure")
            else:
                for m in missing_imports(interp, path, imports, pythonpath):
                    if not self.allowed(binname, f"py:{m}"):
                        self.problems.append(f"{binname}: python module `{m}` not importable by {Path(interp).parent.parent.name} ({origin})")
                for sib in local_modules(path, imports):
                    self.analyze(binname, sib, dirs, interp, depth + 1, pythonpath)
            return
        if not (first.startswith("#!") and ("sh" in first.split("/")[-1] or "bash" in first)) and path.suffix != ".sh" and depth:
            return
        probes: set[str] = set()
        called, funcs, errors = shell_commands(text, self.shfmt, origin, probes)
        self.problems += [f"{binname}: {e}" for e in errors]
        for c in sorted(called - funcs):
            self.report(binname, c, origin, avail, probes)
        # Follow upstream files the wrapper execs (store .sh/.py, or $out/lib entries).
        for m in STORE_RE.finditer(text):
            p = Path(m.group(0))
            if "/bin/" in str(p) or not p.is_file():
                continue
            if p.suffix in (".sh", ".py") or (p.suffix == "" and not is_elf(p) and (read_text(p) or "").startswith("#!")):
                self.analyze(binname, p, dirs, python, depth + 1, pythonpath)


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument("--shfmt", required=True)
    ap.add_argument("--baseline", required=True, help="file: one command name per line")
    ap.add_argument("--allow", required=True, help="allowlist file")
    ap.add_argument("bindirs", nargs="+")
    a = ap.parse_args()

    baseline = {l.strip() for l in Path(a.baseline).read_text().splitlines() if l.strip()}
    allow = set()
    for line in Path(a.allow).read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            allow.add(line)

    entries = []
    for bindir in a.bindirs:
        for entry in sorted(Path(bindir).iterdir()):
            real = entry.resolve()
            if real.is_file():
                entries.append((entry.name, real))

    audit = Audit(a.shfmt, baseline, allow, {n for n, _ in entries})
    for name, real in entries:
        audit.analyze(name, real, [], None)

    print(f"audited {len(entries)} binaries, {audit.checked} script files")
    if audit.warnings:
        print(f"\n{len(set(audit.warnings))} warning(s):")
        for w in sorted(set(audit.warnings)):
            print("  " + w)
    if audit.problems:
        print(f"\n{len(set(audit.problems))} runtime-dependency problem(s):")
        for p in sorted(set(audit.problems)):
            print("  " + p)
        print("\nFix: add the providing package to the script's runtimeInputs / wrapper PATH /"
              " python withPackages, or (if the host legitimately provides it) to checks/runtime-deps/allowlist.")
        return 1
    print("ok: every invoked command resolves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
