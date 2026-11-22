# TEST ONLY. Lives on the branch test/flatpak-mpv-lua of the fork, not in the pull request.
# Runs INSIDE the Flatpak build sandbox and asks the packaged mpv about its on-screen controls.
# Prints KEY=value lines that the workflow reads.
set -u

echo "### which mpv"
command -v mpv
mpv --version | head -n 2

echo "### Lua library this mpv is linked against"
if command -v ldd > /dev/null 2>&1; then
  ldd "$(command -v mpv)" | grep -i lua || echo "(none)"
else
  echo "(ldd is not available in this sandbox)"
fi

echo "### does this mpv know the option --osc"
if mpv --list-options | grep -Eq '^[[:space:]]*--osc[[:space:]]'; then
  echo "OSC_OPTION=yes"
else
  echo "OSC_OPTION=no"
fi

# A one second clip of black frames, made here so that no file from outside is needed.
work="$(mktemp -d)"
head -c 307200 /dev/zero > "$work/clip.raw"
RAW="--demuxer=rawvideo --demuxer-rawvideo-w=64 --demuxer-rawvideo-h=64 --demuxer-rawvideo-mp-format=rgb24 --demuxer-rawvideo-fps=25"

echo "### play the clip without a screen and list the built-in scripts mpv loads"
mpv --no-config --vo=null --ao=null --msg-level=all=debug $RAW "$work/clip.raw" > "$work/play.log" 2>&1
echo "PLAY_EXIT=$?"
grep -E "Loading lua script" "$work/play.log" | sed 's/^/  /'
if grep -q "Loading lua script @osc.lua" "$work/play.log"; then
  echo "OSC_SCRIPT_LOADED=yes"
else
  echo "OSC_SCRIPT_LOADED=no"
fi

echo "### start it with --no-osc, the way Harbor's Multiview starts this mpv"
mpv --no-osc --no-config --vo=null --ao=null $RAW "$work/clip.raw" > "$work/noosc.log" 2>&1
echo "NO_OSC_EXIT=$?"
tail -n 4 "$work/noosc.log" | sed 's/^/  /'
