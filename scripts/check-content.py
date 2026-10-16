#!/usr/bin/env python3
"""Check workshop pages against the formatting conventions.

    scripts/check-content.py [--base REF] [PATH ...]

With --base, only lines changed since REF are checked (what a pull request adds),
so older pages don't have to be cleaned up first. Without it, every line is checked.
PATH defaults to the current directory; README files are skipped.

Rules:
  long-line  A line in a code block is longer than the PDF fits (76 characters).
             Break long commands with a backslash, one flag per indented line.
  inline     A runnable command sits in a sentence. Put it in its own code block.
             A command is runnable when it pipes or chains, has five or more words,
             or follows "run", "enter", "type", "execute" or "paste".
             Commands in tables and plain mentions such as `oc login` are fine.

To allow an exception, put a comment line right above the block (or the line):
  // check: long-lines     no long-line errors in the next code block
  // check: inline-ok      no inline errors on the next line
"""
import argparse
import os
import re
import subprocess
import sys

MAX_LINE = 76

CLI = (r"(?:oc|kubectl|helm|rosa|az|aws|podman|docker|curl|wget|git|istioctl|jq|yq|"
       r"eksctl|skopeo|ssh|sudo|export|source|cd|mkdir|cat|watch|tkn|argocd|virtctl|"
       r"opm|ansible-playbook|make|npm|pip|python3?|chmod|cp|mv|rm|tar|ls|echo)")
INLINE = re.compile(r"`\+?(" + CLI + r" [^`]+?)\+?`")
RUN_VERB = re.compile(r"\b(run|running|enter|type|execute|paste)\b[^`]*$", re.I)
SHELL = re.compile(r"\||&&|;|\$\(|\s[<>]")

CODE_DELIM = re.compile(r"^(-{4,}|\.{4,})\s*$")
SKIP_DELIM = re.compile(r"^(\+{4,}|/{4,})\s*$")  # passthrough and comment blocks
TABLE_DELIM = re.compile(r"^[|!,:]===\s*$")


def runnable(cmd, before):
    return bool(SHELL.search(cmd) or len(cmd.split()) >= 5 or RUN_VERB.search(before))


def check_file(path, lines, wanted):
    """Yield (line, rule, message) for the lines in `wanted` (None means all)."""
    code = skip = None   # the delimiter of the open code or skipped block
    table = False
    allow_long = False   # the open code block has "// check: long-lines"
    pending = []         # comment lines since the last blank or content line
    for n, raw in enumerate(lines, 1):
        s = raw.rstrip("\n").rstrip("\r")
        check = wanted is None or n in wanted
        if skip:
            if s.rstrip() == skip:
                skip = None
            continue
        if code:
            if s.rstrip() == code:
                code = None
            elif check and len(s) > MAX_LINE and not allow_long:
                yield (n, "long-line",
                       f"This code line is {len(s)} characters; the PDF cuts lines over "
                       f"{MAX_LINE}. Break it with a backslash, one flag per indented line.")
            continue
        m = CODE_DELIM.match(s)
        if m:
            code = m.group(1)
            allow_long = any("check: long-lines" in c for c in pending)
            pending = []
            continue
        m = SKIP_DELIM.match(s)
        if m:
            skip = m.group(1)
            continue
        if s.startswith("//"):
            pending.append(s)
            continue
        if TABLE_DELIM.match(s):
            table = not table
            continue
        if not s.strip():
            pending = []
            continue
        if s.startswith("[") or re.match(r"\.[^.\s]", s):
            continue  # block attributes and titles keep the comments above them
        allow_inline = any("check: inline-ok" in c for c in pending)
        pending = []
        if table or not check or allow_inline:
            continue
        for m in INLINE.finditer(s):
            if runnable(m.group(1), s[:m.start()]):
                yield (n, "inline",
                       f"`{m.group(1)}` is a command in a sentence. "
                       "Put it in its own code block.")


def changed_lines(base, paths):
    """Map each changed .adoc file to the set of line numbers added since `base`."""
    out = subprocess.run(
        ["git", "diff", "--unified=0", "--no-color", "--no-ext-diff", "--diff-filter=AMR",
         f"{base}...HEAD", "--"] + paths,
        check=True, capture_output=True, text=True).stdout
    result, current = {}, None
    for line in out.splitlines():
        if line.startswith("+++ "):
            name = line[4:]
            current = name[2:] if name.startswith("b/") else None
            if current and current.endswith(".adoc"):
                result.setdefault(current, set())
            else:
                current = None
        elif line.startswith("@@") and current:
            m = re.match(r"@@ -\S+ \+(\d+)(?:,(\d+))? @@", line)
            start, count = int(m.group(1)), int(m.group(2) or 1)
            result[current].update(range(start, start + count))
    return result


def all_files(paths):
    for p in paths:
        if os.path.isfile(p):
            yield p
            continue
        for d, dirs, files in os.walk(p):
            dirs[:] = [x for x in dirs if not x.startswith(".") and x != "node_modules"]
            for f in sorted(files):
                if f.endswith(".adoc"):
                    yield os.path.normpath(os.path.join(d, f))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", help="check only lines changed since this git ref")
    ap.add_argument("paths", nargs="*", default=["."])
    args = ap.parse_args()

    if args.base:
        targets = changed_lines(args.base, args.paths)
    else:
        targets = {f: None for f in all_files(args.paths)}

    annotate = os.environ.get("GITHUB_ACTIONS") == "true"
    errors = 0
    for path, wanted in sorted(targets.items()):
        if os.path.basename(path).upper().startswith("README") or wanted == set():
            continue
        with open(path, encoding="utf-8") as fh:
            lines = fh.readlines()
        for n, rule, msg in check_file(path, lines, wanted):
            errors += 1
            if annotate:
                print(f"::error file={path},line={n},title={rule}::{path}:{n}: {msg}")
            else:
                print(f"{path}:{n}: {rule}: {msg}")

    scope = f"lines changed since {args.base}" if args.base else "all lines"
    print(f"Checked {len(targets)} file(s), {scope}: {errors} problem(s).")
    if errors:
        print("Fix them, or see the top of scripts/check-content.py in workshop-common "
              "for how to allow an exception.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
