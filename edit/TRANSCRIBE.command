#!/bin/bash
# Life Questions — double-click me.
# Put a video in this folder first. Writes the transcript, the subtitles
# and rough chapter marks beside it. Nothing leaves this machine.
cd "$(dirname "$0")"
echo
echo "  Life Questions — writing out the transcript"
echo "  -------------------------------------------"
echo

for mod in "imageio_ffmpeg:imageio-ffmpeg" "faster_whisper:faster-whisper"; do
  m="${mod%%:*}"; p="${mod##*:}"
  if ! python3 -c "import $m" >/dev/null 2>&1; then
    echo "  installing $p (first time only, a minute or two)..."
    pip3 install --quiet --user "$p" >/dev/null 2>&1 || pip3 install --quiet "$p" >/dev/null 2>&1
  fi
done

VID=""
for f in *.mov *.MOV *.mp4 *.MP4 *.m4v *.M4V *.m4a *.mp3; do
  [ -e "$f" ] || continue
  case "$f" in *-polished*) continue;; esac
  if [ -z "$VID" ] || [ "$f" -nt "$VID" ]; then VID="$f"; fi
done

if [ -z "$VID" ]; then
  echo "  No video found in this folder."
  echo "  Put the film next to this file and double-click again."
  echo
  read -p "  Press return to close. "
  exit 1
fi

echo
python3 transcribe.py "$VID"
echo
echo "  -------------------------------------------"
echo "  Drag the -transcript.txt file into the chat."
echo
command -v open >/dev/null && open . >/dev/null 2>&1
read -p "  Press return to close. "
