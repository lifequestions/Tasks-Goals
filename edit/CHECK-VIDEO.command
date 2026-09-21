#!/bin/bash
# Life Questions — double-click me.
# Put a video in this folder first. Makes contact.jpg to send to Claude.
cd "$(dirname "$0")"
echo
echo "  Life Questions — checking your recording"
echo "  ----------------------------------------"
echo

for mod in "PIL:pillow" "imageio_ffmpeg:imageio-ffmpeg" "cv2:opencv-python-headless"; do
  m="${mod%%:*}"; p="${mod##*:}"
  if ! python3 -c "import $m" >/dev/null 2>&1; then
    echo "  installing $p (first time only)..."
    pip3 install --quiet --user "$p" >/dev/null 2>&1 || pip3 install --quiet "$p" >/dev/null 2>&1
  fi
done

VID=""
for f in *.mov *.MOV *.mp4 *.MP4 *.m4v *.M4V; do
  [ -e "$f" ] || continue
  if [ -z "$VID" ] || [ "$f" -nt "$VID" ]; then VID="$f"; fi
done

if [ -z "$VID" ]; then
  echo "  No video found in this folder."
  echo "  Put the film next to this file and double-click again."
  echo
  read -p "  Press return to close. "
  exit 1
fi

echo "  Looking at: $VID"
echo
python3 look.py "$VID" --sheet contact.jpg
echo
echo "  ----------------------------------------"
echo "  Made contact.jpg — drag it into the chat."
echo
command -v open >/dev/null && open . >/dev/null 2>&1
read -p "  Press return to close. "
