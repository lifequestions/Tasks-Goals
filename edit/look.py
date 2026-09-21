#!/usr/bin/env python3
"""
Look at a recording and say what it needs.

    python3 look.py answer.mov

Writes contact.jpg — twelve frames on one sheet, small enough to send to
anybody — and prints which grade polish.sh should use.
"""
import argparse, os, subprocess, sys, tempfile
from PIL import Image, ImageStat

def ffmpeg():
    for c in ("ffmpeg",):
        try:
            subprocess.run([c, "-version"], capture_output=True, check=True)
            return c
        except Exception:
            pass
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        sys.exit("ffmpeg not found — brew install ffmpeg")

def duration(path):
    FF = ffmpeg()
    r = subprocess.run([FF, "-hide_banner", "-i", path], capture_output=True, text=True)
    for line in (r.stderr or "").splitlines():
        if "Duration:" in line:
            t = line.split("Duration:")[1].split(",")[0].strip()
            h, m, sec = t.split(":")
            return int(h)*3600 + int(m)*60 + float(sec)
    return 0.0

def frames(path, n, tmp):
    """n stills spread evenly through the film, whatever its length."""
    FF = ffmpeg()
    d = duration(path)
    if d <= 0:
        d = 60.0
    out = []
    for i in range(n):
        # skip the first and last twentieth — hellos and fumbling for stop
        t = d * (0.05 + 0.90 * (i / max(1, n - 1)))
        f = os.path.join(tmp, "f%03d.png" % i)
        subprocess.run([FF, "-y", "-ss", "%.2f" % t, "-i", path,
                        "-frames:v", "1", "-vf", "scale=640:-2", f],
                       capture_output=True)
        if os.path.exists(f) and os.path.getsize(f) > 0:
            out.append(f)
    return out

def luma(im):
    return ImageStat.Stat(im.convert("L")).mean[0]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--sheet", default="contact.jpg")
    ap.add_argument("--n", type=int, default=12)
    a = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        fs = frames(a.video, a.n, tmp)
        if not fs:
            sys.exit("could not read any frames from " + a.video)
        ims = [Image.open(f).convert("RGB") for f in fs]

        whole, middle = [], []
        for im in ims:
            w, h = im.size
            whole.append(luma(im))
            # the middle third, which is where a face usually sits
            middle.append(luma(im.crop((w//3, h//6, w*2//3, h*5//6))))
        W = sum(whole)/len(whole)
        M = sum(middle)/len(middle)

        cols = 4
        rows = (len(ims) + cols - 1)//cols
        tw, th = 400, int(400 * ims[0].size[1] / ims[0].size[0])
        sheet = Image.new("RGB", (cols*tw, rows*th), "black")
        for i, im in enumerate(ims):
            sheet.paste(im.resize((tw, th)), ((i % cols)*tw, (i//cols)*th))
        sheet.save(a.sheet, quality=82)

        if M < W - 18:
            grade, why = "backlit", "the middle of the frame is much darker than the rest — they are sat against a window"
        elif W < 85:
            grade, why = "bright", "the whole picture is dark"
        elif W < 115:
            grade, why = "soft", "a little dark, nothing serious"
        else:
            grade, why = "none", "the light is already fine"

        print("frames looked at : %d" % len(ims))
        print("overall bright.. : %.0f / 255" % W)
        print("middle bright... : %.0f / 255" % M)
        print("contact sheet... : %s" % a.sheet)
        print()
        print("use grade: %s   (%s)" % (grade, why))
        print()
        print("  ./polish.sh %s card.png out.mp4 %s" % (a.video, grade))

if __name__ == "__main__":
    main()
