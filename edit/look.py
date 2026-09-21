#!/usr/bin/env python3
"""
Look at a recording and say what it needs.

    python3 look.py answer.mov

Pulls stills from across the film and checks the light, the focus, the framing,
how steady it is and how busy the background is. Writes contact.jpg — everything
it looked at, on one small sheet — and prints a grade for polish.sh plus a note
you could pass back to the family.
"""
import argparse, os, subprocess, sys, tempfile, warnings
warnings.filterwarnings('ignore')
from PIL import Image, ImageStat, ImageFilter

def ffmpeg():
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
        return "ffmpeg"
    except Exception:
        pass
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        sys.exit("ffmpeg not found — brew install ffmpeg")

def duration(path):
    r = subprocess.run([ffmpeg(), "-hide_banner", "-i", path], capture_output=True, text=True)
    for line in (r.stderr or "").splitlines():
        if "Duration:" in line:
            t = line.split("Duration:")[1].split(",")[0].strip()
            h, m, s = t.split(":")
            return int(h)*3600 + int(m)*60 + float(s)
    return 0.0

def frames(path, n, tmp):
    FF, d = ffmpeg(), duration(path) or 60.0
    out = []
    for i in range(n):
        t = d * (0.05 + 0.90 * (i / max(1, n - 1)))          # skip hellos and fumbling
        f = os.path.join(tmp, "f%03d.png" % i)
        subprocess.run([FF, "-y", "-ss", "%.2f" % t, "-i", path,
                        "-frames:v", "1", "-vf", "scale=854:-2", f], capture_output=True)
        if os.path.exists(f) and os.path.getsize(f) > 0:
            out.append(f)
    return out, d

def luma(im):  return ImageStat.Stat(im.convert("L")).mean[0]
def sharp(im): return ImageStat.Stat(im.convert("L").filter(ImageFilter.FIND_EDGES)).stddev[0]

def faces(im):
    """Largest face, as (x, y, w, h) in pixels. Needs opencv; skipped if absent."""
    try:
        import cv2, numpy as np
    except Exception:
        return None
    casc = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
    g = cv2.cvtColor(np.array(im), cv2.COLOR_RGB2GRAY)
    f = casc.detectMultiScale(g, 1.1, 5, minSize=(40, 40))
    if len(f) == 0:
        return None
    return max(f, key=lambda r: r[2]*r[3])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--sheet", default="contact.jpg")
    ap.add_argument("--still", default="still.jpg")
    ap.add_argument("--n", type=int, default=12)
    a = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        fs, dur = frames(a.video, a.n, tmp)
        if not fs:
            sys.exit("could not read any frames from " + a.video)
        ims = [Image.open(f).convert("RGB") for f in fs]
        W0, H0 = ims[0].size

        whole, middle, sharps, boxes, onface = [], [], [], [], []
        for im in ims:
            w, h = im.size
            whole.append(luma(im))
            middle.append(luma(im.crop((w//3, h//6, w*2//3, h*5//6))))
            sharps.append(sharp(im))
            b = faces(im)
            boxes.append(b)
            if b is not None:
                x, y, fw, fh = b
                onface.append(luma(im.crop((x, y, x+fw, y+fh))))

        # how much the picture moves between stills — a proxy for a wobbly hand
        move = []
        for i in range(1, len(ims)):
            a1 = ims[i-1].convert("L").resize((64, 36))
            a2 = ims[i].convert("L").resize((64, 36))
            move.append(sum(abs(p-q) for p, q in zip(a1.tobytes(), a2.tobytes()))/(64*36))

        B  = sum(whole)/len(whole)
        Mi = sum(middle)/len(middle)
        S  = sum(sharps)/len(sharps)
        seen = [b for b in boxes if b is not None]

        # contact sheet
        cols = 4
        rows = (len(ims)+cols-1)//cols
        tw = 400; th = int(tw * H0 / W0)
        sheet = Image.new("RGB", (cols*tw, rows*th), "black")
        for i, im in enumerate(ims):
            sheet.paste(im.resize((tw, th)), ((i % cols)*tw, (i//cols)*th))
        sheet.save(a.sheet, quality=82)

        # A still for the web page. The page needs one real frame of them, and
        # picking it by hand is one more thing to remember, so pick it here:
        # the sharpest frame that has a face in it, skipping the first one in
        # case they are still reaching for the phone.
        cand = [(i, im) for i, im in enumerate(ims) if boxes[i] is not None]
        if len(cand) > 1:
            cand = [c for c in cand if c[0] > 0]
        if cand:
            def score(c):
                i, im = c
                x, y, fw, fh = boxes[i]
                return sharps[i] * (fw * fh) ** 0.5
            bi, bim = max(cand, key=score)
            x, y, fw, fh = boxes[bi]
            w, h = bim.size
            # crop to the shape the page plays it in, with the face high in frame
            tw2 = min(w, int(round(h * 9 / 16)))
            th2 = min(h, int(round(tw2 * 16 / 9)))
            cx = x + fw // 2
            left = max(0, min(w - tw2, cx - tw2 // 2))
            top = max(0, min(h - th2, y - int(th2 * 0.22)))
            still = bim.crop((left, top, left + tw2, top + th2))
            if still.width > 720:
                still = still.resize((720, int(720 * still.height / still.width)), Image.LANCZOS)
            still.save(a.still, quality=84)

        # where a face was found, judge the light on the face rather than the room
        if onface:
            F = sum(onface)/len(onface)
            Mi = F

        notes = []
        if Mi < B - 20:
            grade = "backlit"; notes.append("They are sat against a window — the light is behind them. Next time, face the window.")
        elif Mi < 90:
            grade = "bright";  notes.append("Their face is in poor light. A lamp to one side would do more than any editing.")
        elif Mi < 115:
            grade = "soft"
        else:
            grade = "none"

        if S < 8:
            notes.append("Soft focus throughout — the lens may need a wipe, or the phone was too close.")
        if move and sum(move)/len(move) > 26:
            notes.append("The picture moves a lot. Prop the phone on something instead of holding it.")
        if H0 > W0:
            notes.append("Filmed upright. It will letterbox on the page — landscape fills the frame better.")
        if seen:
            fw = sum(b[2] for b in seen)/len(seen)
            fy = sum(b[1] for b in seen)/len(seen)
            fx = sum(b[0]+b[2]/2 for b in seen)/len(seen)
            pct = 100*fw/W0
            if pct < 12:
                notes.append("They are a long way from the phone — face fills only %.0f%% of the width. A little closer." % pct)
            elif pct > 45:
                notes.append("Very close to the lens. A step back would be kinder.")
            if fy < H0*0.04:
                notes.append("The top of their head is close to the edge of the frame — tilt the phone down a touch.")
            if abs(fx - W0/2) > W0*0.22:
                notes.append("They sit well off to one side of the frame.")
            if len(seen) < len(ims)*0.6:
                notes.append("They drift out of shot in some of the film.")
        else:
            notes.append("No face found in the stills — worth opening the contact sheet and looking.")

        print("%-18s %s" % ("film", os.path.basename(a.video)))
        print("%-18s %d:%02d" % ("length", int(dur//60), int(dur % 60)))
        print("%-18s %dx%d" % ("size", W0, H0))
        print("%-18s %d frames" % ("looked at", len(ims)))
        print()
        print("%-18s %.0f / 255   (%s %.0f)" % ("brightness", B, "on their face" if onface else "middle of frame", Mi))
        print("%-18s %.1f" % ("sharpness", S))
        if move: print("%-18s %.0f" % ("movement", sum(move)/len(move)))
        print("%-18s %d of %d frames" % ("face found in", len(seen), len(ims)))
        print()
        print("grade: %s" % grade)
        print("sheet: %s" % a.sheet)
        if os.path.exists(a.still):
            print("still: %s  (the page's thumbnail — send this too)" % a.still)
        if notes:
            print()
            print("worth knowing:")
            for n in notes:
                print("  - " + n)
        print()
        print("  ./polish.sh %s card.png out.mp4 %s" % (a.video, grade))

if __name__ == "__main__":
    main()
