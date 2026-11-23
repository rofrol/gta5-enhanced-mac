#!/bin/bash
# Tests of gta5-enhanced-mac's game-argument rules, which run without Wine: which folders get
# commandline.txt, how it is merged, and that the watch writes it while a session runs. Needs clang
# (Xcode's command line tools) to build tools/fsevents-wake.
#
#   tests/test.sh

set -euo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=SCRIPTDIR/../gta5-enhanced-mac
. "$root/gta5-enhanced-mac"

work=$(mktemp -d "${TMPDIR:-/tmp}/gta5-enhanced-mac-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
GTA5_ENHANCED_MAC_DATA=$work
set_paths

failures=0
check() {
	local name=$1 expected=$2 actual=$3
	if [ "$expected" = "$actual" ]; then
		echo "ok: $name"
	else
		echo "FAIL: $name"
		echo "  expected: $(printf '%s' "$expected" | od -c | head -5)"
		echo "  actual:   $(printf '%s' "$actual" | od -c | head -5)"
		failures=$((failures + 1))
	fi
}

# A prefix as Wine lays it out: drive C: as a link to drive_c, and no drive Z:.
game="$drive/Program Files/Rockstar Games/Grand Theft Auto V Enhanced"
mkdir -p "$prefix/dosdevices" "$game" "$logs"
ln -s ../drive_c "$prefix/dosdevices/c:"
touch "$game/$game_executable"
both=$'-disableSpatialAudioClient\n-nobattleye'

# Merging.
write_game_arguments
check "a missing commandline.txt gets both arguments" "$both" "$(cat "$game/commandline.txt")"

printf '  -windowed \r\n\n-NOBATTLEYE -width 1920\n' >"$game/commandline.txt"
write_game_arguments
check "the user's arguments stay, trimmed; each argument once, whatever its case" \
	$'-windowed\n-NOBATTLEYE -width 1920\n-disableSpatialAudioClient' "$(cat "$game/commandline.txt")"

before=$(ls -i "$game/commandline.txt")
write_game_arguments
check "a file that already has both is not rewritten" "$before" "$(ls -i "$game/commandline.txt")"
check "no temporary file is left" "" "$(find "$game" -name '.commandline.*')"

printf '%s' '-windowed' | iconv -f UTF-8 -t UTF-16LE >"$game/commandline.txt"
cp "$game/commandline.txt" "$work/utf16"
write_game_arguments
check "a UTF-16 file is left as it is" "" "$(cmp "$work/utf16" "$game/commandline.txt" 2>&1)"

printf '\377\376x\n' >"$game/commandline.txt"
write_game_arguments
check "a file that is not UTF-8 is left as it is" $'\377\376x' "$(cat "$game/commandline.txt")"

rm "$game/commandline.txt"
mkfifo "$game/commandline.txt"
write_game_arguments
check "a commandline.txt that is not a regular file is left as it is" "fifo" "$([ -p "$game/commandline.txt" ] && echo fifo)"

rm "$game/commandline.txt"
echo '-windowed' >"$work/elsewhere.txt"
ln -s "$work/elsewhere.txt" "$game/commandline.txt"
write_game_arguments
check "a commandline.txt that is a link is left as it is" "-windowed" "$(cat "$work/elsewhere.txt")"
rm "$game/commandline.txt"

# A custom install folder gets the arguments too; one outside the prefix does not.
mkdir -p "$drive/Games/GTA"
touch "$drive/Games/GTA/$game_executable"
write_game_arguments
check "a folder the user chose gets the arguments" "$both" "$(cat "$drive/Games/GTA/commandline.txt" 2>&1)"
check "and the default folder" "$both" "$(cat "$game/commandline.txt" 2>&1)"

mkdir -p "$work/outside"
touch "$work/outside/$game_executable"
ln -s "$work/outside" "$prefix/dosdevices/d:"
ln -s "$work/outside" "$drive/linked-out"
write_game_arguments
check "a folder linked out of the prefix gets nothing" "" "$(find "$work/outside" -name commandline.txt)"

rm "$game/$game_executable" "$game/commandline.txt"
write_game_arguments
check "a folder without the game gets nothing" "" "$(ls "$game")"

# The watch: a launcher that installs the game during a session (here: moves a tree holding it into
# the prefix) gets the arguments while the session runs, before stop_watch's final pass. A second
# fsevents-wake over the prefix tells the test when something there changes, commandline.txt included.
mkdir -p "$profile/tools"
clang -O2 -framework CoreServices -o "$profile/tools/fsevents-wake" "$root/tools/fsevents-wake.c"
staged="$work/staged/Rockstar Games/GTA Elsewhere"
mkdir -p "$staged"
touch "$staged/$game_executable"
start_watch
mkdir -p "$work/observe"
mkfifo "$work/observe/wake" "$work/observe/ack"
"$profile/tools/fsevents-wake" "$prefix" >"$work/observe/wake" <"$work/observe/ack" &
observer=$!
exec 5<"$work/observe/wake" 6>"$work/observe/ack"
read -r line <&5
check "the observer watches" ready "$line"
mv "$work/staged/Rockstar Games" "$drive/Rockstar Games"
installed="$drive/Rockstar Games/GTA Elsewhere"
# Checked after each change the observer reports, until the arguments are in or the observer has
# nothing more to report (at most 1000 reports: a watch that never writes fails, whatever else changes).
seen=""
for _ in $(seq 1000); do
	if [ "$(cat "$installed/commandline.txt" 2>/dev/null)" = "$both" ]; then
		seen=yes
		break
	fi
	echo >&6
	# A watch that never writes leaves the observer silent: then the case fails instead of hanging.
	read -t 30 -r line <&5 || break # delay: test deadline: bounds the wait for the watch's write; expiry fails the case
done
check "a game moved into the prefix during a session gets the arguments before the session ends" yes "$seen"
exec 5<&- 6>&-
wait "$observer" || true
watched_by=$watch_pid
stop_watch
check "the watch's files are gone once it stops" "" "$(find "$data" -maxdepth 1 -name '.watch.*')"
check "the watch's process has ended" "" "$(kill -0 "$watched_by" 2>/dev/null && echo running)"

if [ "$failures" -ne 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
