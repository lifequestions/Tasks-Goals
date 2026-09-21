#!/usr/bin/env python3
"""
Life Questions — opening title card.

    python3 make-card.py --name "Luis James de Souza" \
        --question "Tell me about your mother and father ..." \
        --meta "Recorded 20 September 2026  ·  Question one" \
        --out card.png
"""
import argparse, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
BG, INK, INK2, ACC = "#FAF6EF", "#211F1C", "#6A645C", "#2C5F5A"
W, H = 1920, 1080

def face(file, size, weight=400, opsz=None):
    f = ImageFont.truetype(os.path.join(HERE, "fonts", file), size)
    try:
        axes = [a["name"] for a in f.get_variation_axes()]
        vals = []
        for a in axes:
            n = a.decode() if isinstance(a, bytes) else a
            vals.append(opsz if (n == "Optical Size" and opsz) else weight if n == "Weight" else None)
        f.set_variation_by_axes([v for v in vals if v is not None] or [weight])
    except Exception:
        pass
    return f

def wrap(draw, text, font, width):
    words, lines, line = text.split(), [], ""
    for w in words:
        t = (line + " " + w).strip()
        if draw.textlength(t, font=font) <= width:
            line = t
        else:
            if line: lines.append(line)
            line = w
    if line: lines.append(line)
    return lines

def build(name, question, meta, out, eyebrow="LIFE QUESTIONS"):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    M = 200                      # margin, generous — this is a title card, not a slide
    y = 300

    f_eye = face("Karla.ttf", 30, 700)
    d.text((M, y), " ".join(eyebrow), font=f_eye, fill=ACC)
    y += 82

    f_name = face("Newsreader.ttf", 132, 400, opsz=72)
    for ln in wrap(d, name, f_name, W - M*2):
        d.text((M, y), ln, font=f_name, fill=INK)
        y += 150
    y += 26

    d.line([(M, y), (M + 120, y)], fill=ACC, width=3)
    y += 62

    f_q = face("Newsreader.ttf", 58, 300, opsz=24)
    for ln in wrap(d, question, f_q, W - M*2 - 120)[:3]:
        d.text((M, y), ln, font=f_q, fill=INK2)
        y += 82

    f_meta = face("Karla.ttf", 30, 500)
    d.text((M, H - 190), meta, font=f_meta, fill="#9A9289")
    im.save(out, quality=95)
    print("wrote", out, im.size)

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True)
    p.add_argument("--question", default="")
    p.add_argument("--meta", default="")
    p.add_argument("--out", default="card.png")
    a = p.parse_args()
    build(a.name, a.question, a.meta, a.out)
