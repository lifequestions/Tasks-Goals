#!/usr/bin/env bash
# Life Questions — put a title card on the front of an answer, even out the
# light, and level the sound. Leaves the original file untouched.
#
#   ./polish.sh answer.mov card.png out.mp4 [soft|bright|backlit|none]
#
set -euo pipefail

IN="$1"; CARD="$2"; OUT="$3"; GRADE="${4:-soft}"
FF="${FFMPEG:-ffmpeg}"
FP="${FFPROBE:-ffprobe}"

CARD_SECS=4          # how long the card holds before the cross-fade
FADE=0.8             # length of the cross-fade into the film

# Work out the size, the frame rate and whether there is sound. Uses ffprobe
# when it is installed, and reads ffmpeg's own report when it isn't.
PROBE=$("$FF" -hide_banner -i "$IN" 2>&1 || true)
if command -v "$FP" >/dev/null 2>&1 && "$FP" -version >/dev/null 2>&1; then
  read -r W H < <("$FP" -v error -select_streams v:0 -show_entries stream=width,height \
                        -of csv=p=0:s=' ' "$IN")
  FPS=$("$FP" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$IN")
else
  DIM=$(printf '%s' "$PROBE" | grep -m1 'Stream.*Video' | grep -oE '[0-9]{2,5}x[0-9]{2,5}' | head -1)
  W="${DIM%x*}"; H="${DIM#*x}"
  FPS=$(printf '%s' "$PROBE" | grep -m1 'Stream.*Video' | grep -oE '[0-9]+(\.[0-9]+)? fps' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
fi
[ -z "${W:-}" ] && { echo "could not read the video size from $IN"; exit 1; }
[ -z "${FPS:-}" ] && FPS=30
HAS_AUDIO=$(printf '%s' "$PROBE" | grep -c 'Stream.*Audio' || true)
[ "$HAS_AUDIO" = "0" ] && HAS_AUDIO=""

case "$GRADE" in
  # a gentle lift — the usual fix for a sitting room in the afternoon
  soft)    LOOK="curves=all='0/0.04 0.25/0.30 0.75/0.78 1/1',eq=saturation=1.04" ;;
  # a darker room
  bright)  LOOK="curves=all='0/0.08 0.25/0.36 0.75/0.82 1/1',eq=contrast=1.04:saturation=1.05" ;;
  # sat in front of a window, face in shadow
  backlit) LOOK="curves=all='0/0.10 0.30/0.46 0.70/0.80 1/0.98',eq=saturation=1.03" ;;
  none)    LOOK="null" ;;
  *) echo "grade must be soft, bright, backlit or none"; exit 1 ;;
esac

OFFSET=$(awk "BEGIN{print $CARD_SECS - $FADE}")
DELAY_MS=$(awk "BEGIN{printf \"%d\", ($CARD_SECS - $FADE) * 1000}")

VF="[1:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,\
pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0xFAF6EF,setsar=1,format=yuv420p,fps=${FPS}[card];\
[0:v]${LOOK},scale=${W}:${H},setsar=1,format=yuv420p,fps=${FPS}[film];\
[card][film]xfade=transition=fade:duration=${FADE}:offset=${OFFSET}[v]"

if [ -n "$HAS_AUDIO" ]; then
  # level the voice, lose the room rumble, and hold silence under the card
  AF="[0:a]highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11,adelay=${DELAY_MS}|${DELAY_MS}[a]"
  "$FF" -y -i "$IN" -framerate "$FPS" -loop 1 -t "$CARD_SECS" -i "$CARD" \
     -filter_complex "${VF};${AF}" -map "[v]" -map "[a]" \
     -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
     -c:a aac -b:a 192k -movflags +faststart "$OUT"
else
  "$FF" -y -i "$IN" -framerate "$FPS" -loop 1 -t "$CARD_SECS" -i "$CARD" \
     -filter_complex "$VF" -map "[v]" \
     -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -movflags +faststart "$OUT"
fi

echo "wrote $OUT"
