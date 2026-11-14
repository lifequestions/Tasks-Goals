#!/usr/bin/env python3
"""Stamps every local stylesheet and script link with a fresh version.

Why this exists. The pages ask for base.css?v=… and yt.js?v=…; the token on
the end is the only thing that makes a browser fetch a new copy. The deploy
workflow used to write the commit's hash in — but this repository is also
published by GitHub's own branch builder, which runs no workflow, and
whichever finishes last wins. So half the time the token stayed the literal
word "dev" and browsers kept months-old JavaScript against a freshly updated
page, which looks exactly like the site is broken.

Committing the token fixes it for both builders. Run this before committing
any change to a .css or .js file:

    python3 edit/stamp.py

YouTube's own watch?v= links are left alone: only .css and .js are touched.
"""
import os, re, sys, time

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = {".git", ".github", "_pub", "photos-original", "edit", "ten"}
PAT  = re.compile(r'((?:href|src)="[^"]+\.(?:css|js))\?v=[A-Za-z0-9._-]*"')

stamp = sys.argv[1] if len(sys.argv) > 1 else time.strftime("%Y%m%d-%H%M", time.gmtime())
hit = 0

for root, dirs, files in os.walk(HERE):
    dirs[:] = [d for d in dirs if d not in SKIP and not d.startswith(".")]
    for name in files:
        if not name.endswith(".html"): continue
        path = os.path.join(root, name)
        with open(path, encoding="utf-8") as f: src = f.read()
        out, n = PAT.subn(r'\1?v=' + stamp + '"', src)
        if n:
            with open(path, "w", encoding="utf-8") as f: f.write(out)
            hit += n
            print("%-34s %d" % (os.path.relpath(path, HERE), n))

print("stamped %d links as ?v=%s" % (hit, stamp))
