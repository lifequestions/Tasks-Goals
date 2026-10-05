#!/usr/bin/env python3
"""Builds site/send-data.js from the two spreadsheets.

The send sheet needs the 52 questions and the list of people, and it needs
them without a fetch, so that the page works when it is opened straight off
the disk as well as off the web. So they are baked into a script file, and
this rebuilds that file when either spreadsheet changes.

   python3 edit/make-send-data.py

No phone number ever goes in here. The repository is public. Numbers are
typed into the page once and kept in the browser that typed them.
"""
import csv, json, os, re

HERE  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE  = os.path.join(HERE, "site")

def rows(name):
    with open(os.path.join(HERE, name), newline="", encoding="utf-8") as f:
        return [r for r in csv.DictReader(f)]

weeks = []
msgs  = {r["Week"]: r["The whole message, ready to paste"] for r in rows("weekly-messages.csv")}
for r in rows("life-questions-52.csv"):
    n = r["Week"]
    if not n: continue
    weeks.append({
        "n":      int(n),
        "season": r["Season"],
        "q":      r["Send exactly this"],
        "spare":  r["If they dry up"],
        "msg":    msgs.get(n, ""),
    })

people = []
for r in rows("tracker.csv"):
    name = (r["Person"] or "").strip()
    if not name: continue
    slug  = (r["Page slug"] or "").strip() or re.split(r"[ (]", name)[0].lower()
    page  = slug + ".html"
    p = {
        "name":    name,
        "channel": (r["Channel"] or "").strip(),
        "where":   (r["Where"]   or "").strip(),
        "week":    int(r["Week no."]) if (r["Week no."] or "").strip() else 1,
        "note":    (r["Notes"]   or "").strip(),
    }
    if os.path.exists(os.path.join(SITE, page)): p["page"] = page
    people.append(p)

out = os.path.join(SITE, "send-data.js")
with open(out, "w", encoding="utf-8") as f:
    f.write("/* Built by edit/make-send-data.py from life-questions-52.csv and\n")
    f.write("   tracker.csv. Do not edit by hand — edit the spreadsheets and rerun.\n")
    f.write("   No phone numbers here: the repository is public. */\n")
    f.write("var WEEKS = "  + json.dumps(weeks,  ensure_ascii=False, indent=0).replace("\n", "") + ";\n")
    f.write("var PEOPLE = " + json.dumps(people, ensure_ascii=False, indent=0).replace("\n", "") + ";\n")

print(len(weeks), "weeks,", len(people), "people ->", out)
