#!/usr/bin/env python3
"""Print .claude/STRUCTURE.md for the repo this runs in: every tracked file,
then every function and class signature with its line number. Signatures
only, never bodies. Stdlib only.

Run from the repo root:

    python3 .claude/structure.py > .claude/STRUCTURE.md
"""
import ast
import re
import subprocess
from collections import defaultdict
from pathlib import PurePosixPath

SKIP_PARTS = {"node_modules", "dist", "build", "vendor", "__pycache__", ".dart_tool"}
NOT_MAPPED = {".claude", "AGENTS.md", "CLAUDE.md"}
MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".ico", ".icns", ".svg",
         ".ttf", ".otf", ".mp4", ".mov", ".wav", ".mp3"}
COLLAPSE = (".agent/skills/",)
ROUTE_METHODS = {"get", "post", "put", "patch", "delete"}


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def tracked_files():
    files = []
    for path in git("ls-files").splitlines():
        parts = PurePosixPath(path).parts
        if parts[0] in NOT_MAPPED or SKIP_PARTS.intersection(parts):
            continue
        files.append(path)
    return files


def render_tree(files):
    lines = []
    collapsed = defaultdict(int)
    media = defaultdict(int)
    shown = []
    for path in files:
        prefix = next((c for c in COLLAPSE if path.startswith(c)), None)
        if prefix:
            collapsed[prefix] += 1
        elif PurePosixPath(path).suffix.lower() in MEDIA:
            media[str(PurePosixPath(path).parent)] += 1
        else:
            shown.append(path)
    entries = {p: None for p in shown}
    for prefix, count in collapsed.items():
        entries[prefix.rstrip("/") + f"/ ({count} files, not listed)"] = None
    for folder, count in media.items():
        entries[f"{folder}/ ({count} image, font or media files)"] = None
    printed = set()
    for path in sorted(entries, key=lambda p: p.split("/")):
        parts = path.split("/")
        for depth in range(len(parts) - 1):
            folder = "/".join(parts[: depth + 1])
            if folder not in printed:
                printed.add(folder)
                lines.append("  " * depth + parts[depth] + "/")
        lines.append("  " * (len(parts) - 1) + parts[-1])
    return lines


def py_decorators(node):
    tags = []
    for dec in node.decorator_list:
        if (isinstance(dec, ast.Call) and isinstance(dec.func, ast.Attribute)
                and dec.func.attr in ROUTE_METHODS and dec.args
                and isinstance(dec.args[0], ast.Constant)):
            tags.append(f"{dec.func.attr.upper()} {dec.args[0].value}")
        else:
            target = dec.func if isinstance(dec, ast.Call) else dec
            tags.append("@" + ast.unparse(target))
    return f"[{', '.join(tags)}] " if tags else ""


def py_signatures(src):
    out = []

    def walk(body, indent):
        for node in body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                kind = "async def" if isinstance(node, ast.AsyncFunctionDef) else "def"
                ret = f" -> {ast.unparse(node.returns)}" if node.returns else ""
                out.append(f"{indent}- L{node.lineno} {py_decorators(node)}"
                           f"`{kind} {node.name}({ast.unparse(node.args)}){ret}`")
            elif isinstance(node, ast.ClassDef):
                bases = [ast.unparse(b) for b in node.bases + node.keywords]
                base_text = f"({', '.join(bases)})" if bases else ""
                out.append(f"{indent}- L{node.lineno} {py_decorators(node)}"
                           f"`class {node.name}{base_text}`")
                walk(node.body, indent + "  ")

    walk(ast.parse(src).body, "")
    return out


DART_TYPE_DECL = re.compile(
    r"^\s*(?:(?:abstract|sealed|base|final|interface)\s+)*(?:mixin\s+class|class|mixin|enum|"
    r"extension\s+type|extension|typedef)\b")
DART_TYPE_NAME = re.compile(
    r"(?:class|mixin|enum|type|extension|typedef)\s+([A-Za-z_$][\w$]*)")
DART_MEMBER = re.compile(
    r"""^\s*(?:@\w+(?:\([^)]*\))?\s+)*
    (?P<mods>(?:(?:static|external|factory|const|abstract|covariant)\s+)*)
    (?:(?P<type>[A-Za-z_$][\w$.]*(?:<.*?>)?\??(?:\s+Function\s*\(.*?\)\??)?)\s+)?
    (?:(?P<acc>(?:get|set)(?=\s)|operator)\s*)?
    (?P<name>[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)?|==|\[\]=?|[<>+\-*/%~^|&]+)
    \s*(?:<[^()]*?>)?\s*(?P<rest>.*)$""", re.X)
DART_TOP_VAR = re.compile(r"^(?:final|const)\s+(?:[\w<>?, ]+\s+)?([A-Za-z_$][\w$]*)\s*=\s*([^(;]*)")
DART_NOT_TYPES = {"if", "for", "while", "switch", "return", "catch", "await", "throw",
                  "assert", "super", "this", "new", "else", "do", "try", "yield",
                  "case", "on", "in", "is", "as", "late", "var", "final", "const",
                  "required", "print", "async", "sync"}
DART_BODY_START = ("{", "=>", "async", "sync", ";", ":")


def dart_code_only(line, state, strings):
    # String literals become \x00<n>\x00 placeholders so braces, parens and //
    # inside them are not read as code; dart_restore puts them back.
    if state["block"]:
        if "*/" not in line:
            return ""
        line = line.split("*/", 1)[1]
        state["block"] = False

    def hide(match):
        strings.append(match.group(0))
        return f"\x00{len(strings) - 1}\x00"

    line = re.sub(r"r?'''.*?'''|r?\"\"\".*?\"\"\"", hide, line)
    line = re.sub(r"r?'(?:\\.|[^'\\])*'|r?\"(?:\\.|[^\"\\])*\"", hide, line)
    line = re.sub(r"/\*.*?\*/", "", line)
    line = re.sub(r"//.*", "", line)
    if "/*" in line:
        line = line.split("/*", 1)[0]
        state["block"] = True
    return line


def dart_restore(text, strings):
    return re.sub(r"\x00(\d+)\x00", lambda m: strings[int(m.group(1))], text)


def dart_signatures(src):
    lines = src.splitlines()
    code = []
    state = {"block": False}
    strings = []
    for raw in lines:
        code.append(dart_code_only(raw, state, strings))
    out = []
    depth = 0
    stack = []
    skip_until = -1
    for i, line in enumerate(code):
        start_depth = depth
        depth += line.count("{") - line.count("}")
        for entry in stack:
            entry[2] = entry[2] or depth >= entry[0]
        while stack and stack[-1][2] and depth < stack[-1][0]:
            stack.pop()
        if i <= skip_until or not line.strip():
            continue
        in_type_body = bool(stack) and stack[-1][2] and start_depth == stack[-1][0]
        if start_depth != 0 and not in_type_body:
            continue
        indent = "  " if in_type_body else ""
        text = line.strip()
        if DART_TYPE_DECL.match(line):
            header, j = text, i
            while "{" not in header and ";" not in header and j + 1 < len(code):
                j += 1
                header += " " + code[j].strip()
            header = re.sub(r"\s+", " ", header.split("{")[0]).rstrip(" ;")
            match = DART_TYPE_NAME.search(header)
            span = "".join(code[i:j + 1])
            if "{" in span and span.count("{") > span.count("}"):
                stack.append([start_depth + 1, match.group(1) if match else "", depth > start_depth])
            out.append(f"{indent}- L{i + 1} `{dart_restore(header, strings)}`")
            skip_until = j
            continue
        if start_depth == 0:
            var = DART_TOP_VAR.match(text)
            if var:
                value = dart_restore(var.group(2).strip(), strings)
                out.append(f"- L{i + 1} `{text.split('=')[0].strip()} = {value}`")
                continue
        member = DART_MEMBER.match(text)
        if not member or not member.group("name"):
            continue
        name, kind, rtype = member.group("name"), member.group("acc"), member.group("type")
        if name in DART_NOT_TYPES or (rtype and rtype.split("<")[0] in DART_NOT_TYPES):
            continue
        rest = member.group("rest")
        if kind == "get":
            if not rest.startswith(DART_BODY_START):
                continue
            signature, j = text.split("=>")[0].split("{")[0], i
        else:
            if not rest.startswith("("):
                continue
            joined, j = text, i
            while joined.count("(") > joined.count(")") and j + 1 < len(code):
                j += 1
                joined += " " + code[j].strip()
            close, balance = -1, 0
            for pos, ch in enumerate(joined):
                balance += ch == "("
                balance -= ch == ")"
                if ch == ")" and balance == 0:
                    close = pos
                    break
            tail = joined[close + 1:].strip()
            if not tail and j + 1 < len(code):
                tail = code[j + 1].strip()
            if not tail.startswith(DART_BODY_START):
                continue
            if not rtype and stack and in_type_body:
                owner = stack[-1][1]
                if not (name == owner or name.startswith(owner + ".")
                        or "factory" in member.group("mods")):
                    continue
            elif not rtype:
                continue
            signature = joined[: close + 1]
        signature = re.sub(r"\s+", " ", dart_restore(signature, strings)).strip()
        out.append(f"{indent}- L{i + 1} `{signature}`")
        skip_until = j
    return out


def main():
    files = tracked_files()
    sha = git("rev-parse", "--short", "HEAD").strip()
    repo = PurePosixPath(git("rev-parse", "--show-toplevel").strip()).name
    remote = git("config", "--get", "remote.origin.url").strip()
    repo = PurePosixPath(remote).stem if remote else repo
    # Top-level dotfiles (.gitignore and friends) are left out of the stamp so a
    # config tweak does not mark this file stale; they add no files or symbols.
    paths = sorted({PurePosixPath(p).parts[0] + ("/" if len(PurePosixPath(p).parts) > 1 else "")
                    for p in files
                    if len(PurePosixPath(p).parts) > 1 or not p.startswith(".")})
    dirty = git("status", "--porcelain", "--", *paths).strip()

    print(f"# {repo} structure\n")
    print("Every tracked file, then every function and class signature with its line")
    print("number. Signatures only: open the file at that line for the body. Find a")
    print("symbol here before opening whole files.\n")
    print("Generated, never hand-written: `python3 .claude/structure.py > .claude/STRUCTURE.md`.")
    print("Python signatures come from `ast` (route decorators shown as `[GET /path]`).")
    print("Dart signatures come from a brace-aware regex scan of classes, members,")
    print("top-level functions and top-level `final`/`const` values such as providers,")
    print("so an unusual declaration can be missed; grep the code when unsure.\n")
    print("## Files\n")
    print("```")
    print("\n".join(render_tree(files)))
    print("```\n")
    print("## Signatures")
    for path in files:
        try:
            src = open(path, encoding="utf-8").read()
        except (OSError, UnicodeDecodeError):
            continue
        if path.endswith(".py"):
            try:
                sigs = py_signatures(src)
            except SyntaxError:
                sigs = ["- (could not parse)"]
        elif path.endswith(".dart") and not path.endswith((".g.dart", ".freezed.dart")):
            sigs = dart_signatures(src)
        else:
            continue
        if sigs:
            print(f"\n### {path}\n")
            print("\n".join(sigs))
    suffix = " plus uncommitted changes" if dirty else ""
    print(f"\n<!-- mapped: {repo}@{sha}{suffix} | paths: {', '.join(paths)} -->")


if __name__ == "__main__":
    main()
