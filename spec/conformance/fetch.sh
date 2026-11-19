#!/bin/sh
# Fetch the HTML parser tree-construction tests (.dat files) from
# web-platform-tests, at the commit pinned in wpt-commit, into cases/
# (both next to this script).
#
# usage: spec/conformance/fetch.sh [-u] [-c commit]
#   -u         update the pin to WPT's latest commit first
#   -c commit  fetch this commit instead of the pinned one (doesn't change the pin)
#
# WPT is huge, so this makes a throwaway partial clone: only the one commit,
# only the tree, and only the blobs of the test directory. cases/ is replaced
# completely, so tests added upstream appear and tests removed upstream
# disappear.
set -eu

: "${WPT_URL:=https://github.com/web-platform-tests/wpt.git}"
: "${WPT_DIR:=html/syntax/parsing/resources}"
: "${PIN_FILE:=wpt-commit}"
: "${DEST:=cases}"

update=false
commit=""
while getopts uc: opt; do
	case "$opt" in
	u) update=true ;;
	c) commit="$OPTARG" ;;
	*) echo "usage: $0 [-u] [-c commit]" >&2; exit 2 ;;
	esac
done

cd "$(dirname "$0")"

if $update; then
	# the commit of the default branch (ls-remote also lists other refs ending in HEAD)
	git ls-remote "$WPT_URL" HEAD | awk '$2 == "HEAD" { print $1 }' > "$PIN_FILE"
	echo "pinned $PIN_FILE to $(cat "$PIN_FILE")"
fi

if [ -z "$commit" ]; then
	commit=$(cat "$PIN_FILE")
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

clone="$tmp/wpt"
git init -q "$clone"
git -C "$clone" remote add origin "$WPT_URL"
# one commit, without any file contents yet...
git -C "$clone" fetch -q --depth=1 --filter=blob:none origin "$commit"
# ...then check out just the test directory, which fetches only its contents
# (and those of the files in the directories above it)
git -C "$clone" sparse-checkout set "$WPT_DIR"
git -C "$clone" -c advice.detachedHead=false checkout -q FETCH_HEAD

mkdir "$tmp/tests"
count=0
for file in "$clone/$WPT_DIR"/*.dat; do
	[ -e "$file" ] || continue
	cp "$file" "$tmp/tests/"
	count=$((count + 1))
done
if [ "$count" -eq 0 ]; then
	echo "no .dat files found in $WPT_DIR at $commit" >&2
	exit 1
fi
echo "$commit" > "$tmp/tests/COMMIT"

rm -rf "$DEST"
mv "$tmp/tests" "$DEST"
echo "fetched $count test files from $WPT_URL at $commit into $DEST/"
