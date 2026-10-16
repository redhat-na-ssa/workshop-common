#!/usr/bin/env python3
"""Ship the files in a workshop's downloads/ folder with its release.

    scripts/list-downloads.py [--copy DIR]

Run it from the workshop repo's folder. It writes the Downloads page's list of those
files to content/modules/ROOT/partials/workshop-downloads.adoc (empty when there are
none), and with --copy also copies them to DIR, for the release to attach and bundle.
downloads/README.md and hidden files are left out. The Pages and Release workflows run
it; there is nothing to run by hand.
"""
import argparse
import os
import shutil
import sys
import urllib.parse

FOLDER = "downloads"
PARTIAL = "content/modules/ROOT/partials/workshop-downloads.adoc"
# files every release already ships under these names
RESERVED = {"DISCONNECTED.md", "TOOLS.md", "tools-deployment.yaml", "images-mirror.txt"}


def files():
    if not os.path.isdir(FOLDER):
        return []
    names = sorted(n for n in os.listdir(FOLDER)
                   if not n.startswith(".") and n != "README.md")
    problems = []
    for n in names:
        if os.path.isdir(os.path.join(FOLDER, n)):
            problems.append(f"{FOLDER}/{n} is a folder: put files directly in {FOLDER}/.")
        if n in RESERVED:
            problems.append(f"{FOLDER}/{n}: every release already has a file of that name.")
    if problems:
        sys.exit("\n".join(problems))
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("--copy", metavar="DIR", help="also copy the files to DIR")
    args = parser.parse_args()
    if not os.path.isfile("content/antora.yml"):
        sys.exit("No content/antora.yml here: run this from a workshop repo's folder.")

    names = files()
    lines = []
    if names:
        lines = ["== Workshop Files", "",
                 "Files this workshop ships with every release, also at the top of the "
                 "offline bundle:", ""]
        lines += [f"* link:{{downloads-base}}/{urllib.parse.quote(n)}[{n}]" for n in names]
    os.makedirs(os.path.dirname(PARTIAL), exist_ok=True)
    with open(PARTIAL, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + ("\n" if lines else ""))

    if args.copy:
        os.makedirs(args.copy, exist_ok=True)
        for n in names:
            shutil.copy2(os.path.join(FOLDER, n), args.copy)
    print(f"{len(names)} file(s) in {FOLDER}/: {', '.join(names) or 'none'}")


if __name__ == "__main__":
    main()
