#!/usr/bin/env python3
"""Turn a recording into a transcript, without anybody having to type it.

Runs entirely on this Mac. Nothing is uploaded. It writes three files beside
the video:

    <name>-transcript.txt   the words, in readable paragraphs with timestamps
    <name>.srt              subtitles, ready to upload to YouTube
    <name>-chapters.txt     rough chapter marks to paste into the YouTube description
"""
import os, sys, re, subprocess, tempfile, warnings
warnings.filterwarnings("ignore")

VID_EXT = (".mp4", ".mov", ".m4v", ".avi", ".mkv", ".mp3", ".m4a", ".wav")


def newest_video(folder):
    files = [os.path.join(folder, f) for f in os.listdir(folder)
             if f.lower().endswith(VID_EXT) and not f.startswith(".")
             and "-polished" not in f]
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def audio_of(path):
    wav = os.path.join(tempfile.gettempdir(), "lq-audio.wav")
    subprocess.run([ffmpeg(), "-y", "-i", path, "-vn", "-ac", "1", "-ar", "16000",
                    "-c:a", "pcm_s16le", wav],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    return wav


def clock(sec):
    sec = int(sec)
    return "%d:%02d" % (sec // 60, sec % 60)


def srt_clock(sec):
    ms = int(round(sec * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return "%02d:%02d:%02d,%03d" % (h, m, s, ms)


def main():
    folder = os.path.dirname(os.path.abspath(sys.argv[0]))
    path = sys.argv[1] if len(sys.argv) > 1 else newest_video(folder)
    if not path:
        print("No video in this folder. Drop the recording in here and run it again.")
        return 1
    print("Transcribing: %s" % os.path.basename(path))
    print("The first run downloads the speech model (about 150 MB). After that it is offline.\n")

    from faster_whisper import WhisperModel
    wav = audio_of(path)
    try:
        model = WhisperModel(os.environ.get("LQ_MODEL", "base"), device="cpu", compute_type="int8")
    except Exception as e:
        print("Could not fetch the speech model: %s" % e)
        print("\nThis machine cannot reach the model download. Two ways round it:")
        print("  1. Try again on a normal network (it only downloads once).")
        print("  2. Or let YouTube do it: upload the film, wait an hour, then")
        print("     Subtitles -> the three dots -> Download -> .srt")
        return 1
    segs, info = model.transcribe(wav, language="en", vad_filter=True,
                                  beam_size=1, condition_on_previous_text=False)

    stem = os.path.splitext(path)[0]
    segments = []
    total = info.duration or 0
    for s in segs:
        segments.append((s.start, s.end, s.text.strip()))
        if total:
            done = min(100, int(100 * s.end / total))
            sys.stdout.write("\r  %3d%%   %s" % (done, clock(s.end)))
            sys.stdout.flush()
    print("\r  100%%   %s      \n" % clock(total))

    # subtitles
    with open(stem + ".srt", "w", encoding="utf-8") as f:
        for i, (a, b, t) in enumerate(segments, 1):
            f.write("%d\n%s --> %s\n%s\n\n" % (i, srt_clock(a), srt_clock(b), t))

    # readable transcript, gathered into paragraphs of roughly half a minute
    paras, cur, start = [], [], None
    for a, b, t in segments:
        if start is None:
            start = a
        cur.append(t)
        if b - start > 45 and re.search(r"[.!?]$", t):
            paras.append((start, " ".join(cur)))
            cur, start = [], None
    if cur:
        paras.append((start or 0, " ".join(cur)))

    with open(stem + "-transcript.txt", "w", encoding="utf-8") as f:
        f.write("%s\n%s\n\n" % (os.path.basename(path), "-" * len(os.path.basename(path))))
        f.write("Length %s. Transcribed on this machine — nothing was uploaded.\n\n" % clock(total))
        for a, text in paras:
            f.write("[%s]  %s\n\n" % (clock(a), text))

    # rough chapters: a mark every few minutes, labelled with its first words
    with open(stem + "-chapters.txt", "w", encoding="utf-8") as f:
        f.write("0:00 Introduction\n")
        last = 0
        for a, text in paras:
            if a - last < 150:
                continue
            words = " ".join(text.split()[:7]).rstrip(",.")
            f.write("%s %s…\n" % (clock(a), words))
            last = a

    words = sum(len(t.split()) for _, _, t in segments)
    print("Done. %s of talking, about %d words.\n" % (clock(total), words))
    print("  %s" % os.path.basename(stem + "-transcript.txt"))
    print("  %s   (upload this to YouTube so the film has subtitles)" % os.path.basename(stem + ".srt"))
    print("  %s" % os.path.basename(stem + "-chapters.txt"))
    try:
        os.remove(wav)
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
