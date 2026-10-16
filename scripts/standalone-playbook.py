#!/usr/bin/env python3
"""Write a playbook that builds one workshop of a repo on its own.

    scripts/standalone-playbook.py PLAYBOOK NAME > OUT

It copies PLAYBOOK with only the workshops/NAME content source, so the workshop's own
antora.yml supplies the title, nav and attributes, and starts the site at its index
page. preview.sh --workshop and the Check content workflow use it.
"""
import re
import sys


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip())
    playbook, name = sys.argv[1], sys.argv[2]
    with open(playbook, encoding="utf-8") as fh:
        lines = fh.read().splitlines(keepends=True)

    out, entry, in_sources, found = [], None, False, False

    def flush():
        nonlocal entry, found
        if entry and any(re.match(rf"\s*start_path:\s*['\"]?workshops/{re.escape(name)}/?['\"]?\s*$", line)
                         for line in entry):
            out.extend(entry)
            found = True
        entry = None

    for line in lines:
        if re.match(r"site:\s*$", line) is None and re.match(r"  start_page:", line):
            line = f"  start_page: ROOT:{name}:index.adoc\n"
        if re.match(r"  sources:\s*$", line):
            in_sources = True
            out.append(line)
            continue
        if in_sources:
            if re.match(r"    - ", line):
                flush()
                entry = [line]
                continue
            if re.match(r"      \S", line) and entry is not None:
                entry.append(line)
                continue
            if re.match(r"\s*#", line) or not line.strip():
                continue
            flush()
            in_sources = False
        out.append(line)
    flush()
    if not found:
        sys.exit(f"{playbook} has no content source with start_path: workshops/{name}")
    sys.stdout.write("".join(out))


if __name__ == "__main__":
    main()
