#!/usr/bin/env bash
# Assembles the directory that gets published: the whole repository, minus the
# parts that have no business being on the open web — the spreadsheets, the
# originals of Dad's photographs, and this editing kit.
#
# The site itself lives at the repository root, so that what you see in the
# repository is what the domain serves. /site/ is kept as a set of redirects
# because Dad has /site/luis.html in a WhatsApp message.
#
#   bash edit/build-pages.sh _pub
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-_pub}"
rm -rf "$out"; mkdir -p "$out"
tar -cf - \
  --exclude='./.git' --exclude='./.github' --exclude="./$out" \
  --exclude='./edit' --exclude='./photos-original' --exclude='./ten' \
  --exclude='*.csv' --exclude='.DS_Store' --exclude='./_config.yml' \
  . | ( cd "$out" && tar -xf - )
echo "built $out: $(find "$out" -type f | wc -l) files"
