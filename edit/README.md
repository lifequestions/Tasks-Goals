# Life Questions — polishing an answer

Two small tools. They never touch the original file.

## Once, to set up

    brew install ffmpeg
    pip3 install pillow

## Every answer

**1. Make the title card**

    python3 make-card.py \
      --name "Luis James de Souza" \
      --question "Tell me about your mother and father — what were their names, and what did they do? Did you get along with them?" \
      --meta "Recorded 20 September 2026   ·   Question one of twelve" \
      --out card.png

**2. Put it on the front, even out the light, level the sound**

    ./polish.sh answer.mov card.png luis-01.mp4

That is the whole job. It looks at twelve frames from the film, works out what
the light needs, and grades it accordingly — no judgement call from you. It also
drops a `luis-01-contact.jpg` beside the film: twelve stills on one small sheet.
Send that to anybody who wants to see how it looked without sending a 100MB file.

To overrule it, put the grade on the end:

    ./polish.sh answer.mov card.png luis-01.mp4 backlit

| grade | for |
|---|---|
| `soft` | the usual — a sitting room in the afternoon |
| `bright` | a darker room |
| `backlit` | sat in front of a window, face in shadow |
| `none` | the light is already fine |

Then upload `luis-01.mp4` to YouTube as **unlisted** and paste the video ID into his page.

## Checking a recording before you do anything

    python3 look.py answer.mov

Pulls twelve stills from across the film and reports the light (measured on their
face, not the room), the focus, how steady it is, how far they are from the phone,
whether they drift out of shot, and whether it was filmed upright. It writes
`contact.jpg` — all twelve frames on one small sheet you can send to anybody — and
prints the grade to use. Most of what it says is worth passing back to the family:
"a lamp to one side", "prop the phone on something", "sit a bit closer".

## The transcript, written for you

    python3 transcribe.py answer.mov

Or double-click **TRANSCRIBE.command** and it finds the newest film in the folder
by itself. It writes three files next to it:

| file | what it is for |
|---|---|
| `…-transcript.txt` | the words, in paragraphs, with a timestamp on each |
| `….srt` | subtitles — upload this to YouTube and the film is captioned |
| `…-chapters.txt` | rough chapter marks to paste into the YouTube description |

It runs on your own machine. The recording is not uploaded anywhere, which matters
when the subject is somebody's family. The first run downloads a 150MB speech model;
after that it works with the wifi off. Fifteen minutes of talking takes two or three
minutes to transcribe.

If you would rather not install anything: upload the film to YouTube, wait an hour,
then **Subtitles → the three dots → Download → .srt**. YouTube transcribes every
upload for free. Same result, slower, and Google keeps a copy.

## What it actually does

- Holds the card for four seconds, then cross-fades into the film over 0.8s
- Lifts the shadows without blowing out the window behind him
- Levels the voice to broadcast loudness (-16 LUFS) and cuts the rumble below 80Hz —
  this does more for how it feels than anything done to the picture
- Leaves the original untouched. Keep it. It is the master.

## The one rule

Polish the front and the sound. **Don't cut what he said.** If fifteen minutes feels
long, that is what chapter markers in the YouTube description are for — not scissors.
