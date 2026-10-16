#!/usr/bin/env python3
"""Check the links inside a built workshop site.

    scripts/check-links.py SITE_DIR

Every relative link and image in the site's HTML must point to a file that was built,
and a link to a #section must point to a section that exists on that page.
Links to other sites aren't checked. 404.html is skipped: its links are absolute on
purpose, so it works at any address.
"""
import html
import os
import re
import sys
import urllib.parse

LINK = re.compile(r'\s(?:href|src)="([^"]*)"')
ID = re.compile(r'\s(?:id|name)="([^"]+)"')


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__.strip())
    root = os.path.abspath(sys.argv[1])
    pages, ids = [], {}
    for d, _, files in os.walk(root):
        for f in files:
            if f.endswith(".html"):
                path = os.path.join(d, f)
                with open(path, encoding="utf-8") as fh:
                    text = fh.read()
                pages.append((path, text))
                ids[path] = {html.unescape(i) for i in ID.findall(text)}

    annotate = os.environ.get("GITHUB_ACTIONS") == "true"
    checked, broken = 0, []
    for path, text in pages:
        if os.path.relpath(path, root) == "404.html":
            continue
        page_url = "/" + os.path.relpath(path, root).replace(os.sep, "/")
        for link in LINK.findall(text):
            link = html.unescape(link)
            if not link or re.match(r"^[a-z][a-z0-9+.-]*:", link, re.I) or link.startswith("//"):
                continue
            checked += 1
            url = urllib.parse.urljoin(page_url, link)
            target, _, fragment = url.partition("#")
            target = target.split("?")[0]
            file = os.path.join(root, urllib.parse.unquote(target).lstrip("/"))
            if target.endswith("/"):
                file = os.path.join(file, "index.html")
            if not os.path.isfile(file):
                broken.append((page_url, link, "no such file"))
            elif fragment and file.endswith(".html"):
                if urllib.parse.unquote(fragment) not in ids.get(file, set()):
                    broken.append((page_url, link, "no such section on that page"))

    for page, link, why in broken:
        if annotate:
            print(f"::error title=broken link::{page} links to {link}: {why}")
        else:
            print(f"{page}: {link}: {why}")
    print(f"Checked {checked} links in {len(pages)} pages: {len(broken)} broken.")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
