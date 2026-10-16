#!/usr/bin/env python3
"""Add a workshop to a workshop repo, under workshops/NAME.

    ../workshop-common/scripts/add-workshop.py NAME "Workshop title"

Run it from the repo's folder. NAME is lowercase words joined by hyphens, such as
helm or running-applications; it becomes the folder, the Antora module and the URL
path (/NAME/). The new workshop starts from workshop-common's template-workshop/,
and the script lists it everywhere the site needs it: both playbooks, the home
part's nav (setup requirements under Workshop Instructor Guide, pages under Workshop
Content), and the home, instructor and attendee pages. Each of
those has a line saying "add-workshop.py adds workshops above this line".
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARKER = "add-workshop.py adds workshops above this line"

HOME = "content/modules/ROOT"
ADDITIONS = {
    # file: (text added above each marker in that file, in order)
    "default-site.yml": ["    - url: .\n      start_path: workshops/{name}\n"],
    "default-pdf.yml": ["    - url: .\n      start_path: workshops/{name}\n"],
    f"{HOME}/nav.adoc": [
        "** xref:{name}:setup-requirements.adoc[{title}]\n",
        "** xref:{name}:index.adoc[{title}]\ninclude::{name}:partial$nav-items.adoc[]\n",
    ],
    f"{HOME}/pages/index.adoc": ["* xref:{name}:index.adoc[{title}]\n"],
    f"{HOME}/pages/attendee.adoc": ["* xref:{name}:index.adoc[{title}]\n"],
    f"{HOME}/pages/instructor.adoc": [
        "\n|xref:{name}:index.adoc[{title}]\n|What it covers, in a sentence.\n|How long it takes\n",
        "* xref:{name}:setup-requirements.adoc[{title}]\n",
    ],
}


def insert(path, texts):
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    marks = [i for i, line in enumerate(lines) if MARKER in line]
    if len(marks) != len(texts):
        sys.exit(f"{path} should have {len(texts)} line(s) saying \"{MARKER}\".")
    for i, text in reversed(list(zip(marks, texts))):
        lines[i:i] = [text]
    with open(path, "w", encoding="utf-8") as fh:
        fh.writelines(lines)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip())
    name, title = sys.argv[1], sys.argv[2]
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
        sys.exit(f"{name}: use lowercase letters, digits and single hyphens.")
    if not os.path.isfile("content/antora.yml"):
        sys.exit("No content/antora.yml here: run this from a workshop repo's folder.")
    dest = os.path.join("workshops", name)
    if os.path.exists(dest):
        sys.exit(f"{dest} already exists.")

    values = {"name": name, "title": title}
    for path, texts in ADDITIONS.items():
        insert(path, [t.format(**values) for t in texts])

    src = os.path.join(ROOT, "template-workshop")
    for d, _, files in os.walk(src):
        for f in files:
            rel = os.path.relpath(os.path.join(d, f), src).replace("@@NAME@@", name)
            out = os.path.join(dest, rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with open(os.path.join(d, f), encoding="utf-8") as fh:
                text = fh.read()
            with open(out, "w", encoding="utf-8") as fh:
                fh.write(text.replace("@@NAME@@", name).replace("@@WTITLE@@", title))
    print(f"Added {dest}. Write its pages, then fill in its row on the instructor page "
          f"and its setup requirements.")


if __name__ == "__main__":
    main()
