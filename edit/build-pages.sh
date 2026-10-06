#!/usr/bin/env bash
# Assembles the directory that gets published, so that Life Questions sits at
# the root of the domain rather than down a /site/ corridor:
#
#   /                 Life Questions
#   /luis.html        a person's page
#   /send.html        the send sheet
#   /goals.html       the Goal Tracker, which used to be at /
#   /expenses.html    the Expense Tracker, where it has always been
#   /site/…           every old address, redirecting to its new one, because
#                     Dad has /site/luis.html in a WhatsApp message
#
# Run it the same way the workflow does:  bash edit/build-pages.sh _pub
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-_pub}"
rm -rf "$out"; mkdir -p "$out"

# The pages that were already at the root. index.html is the Goal Tracker and
# has to step aside; the rest are design studies nothing links to.
for f in *.html; do
  [ "$f" = "index.html" ] && cp "$f" "$out/goals.html" || cp "$f" "$out/$f"
done
# Those studies load their photographs from site/, which is where the files
# live in the repository — but in the published tree they are at the root.
sed -i -E 's#(["(])site/([a-z0-9-]+\.jpg)#\1\2#g' "$out"/*.html
# The Expense Tracker's way back used to be index.html.
sed -i 's#href="index\.html"#href="goals.html"#g' "$out/expenses.html"

# Life Questions takes the root.
cp -a site/. "$out"/

# Every old /site/… address, kept alive as a redirect to its new home.
( cd site && find . -name '*.html' ) | sed 's#^\./##' | while read -r rel; do
  dest="$out/site/$rel"
  mkdir -p "$(dirname "$dest")"
  # ../ for /site/x.html, ../../ for /site/options/x.html, and so on.
  up=$(printf '../%.0s' $(seq 1 $(( $(grep -o / <<<"$rel" | wc -l) + 1 ))))
  target="$up$rel"
  cat > "$dest" <<HTML
<!DOCTYPE html>
<meta charset="utf-8">
<title>This page has moved</title>
<link rel="canonical" href="$target">
<meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0; url=$target">
<p style="font:16px/1.6 Helvetica,Arial,sans-serif;padding:2rem">
  This page has moved. <a href="$target">Carry on here.</a></p>
HTML
done

# Not published: the spreadsheets, the originals of Dad's photographs, and the
# editing kit. They were going out with everything else and had no business
# being on the open web.
echo "built $out:"; ls "$out" | head -40
