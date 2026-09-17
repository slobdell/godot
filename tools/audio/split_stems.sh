#!/usr/bin/env bash
# Splits one Suno track into drums / bass / other with demucs, on builder0 (it needs PyTorch, ~2 GB, and the laptop
# has no room for it), and brings the stems back ready for `make music-import LAYERS=...`.
#
#   tools/audio/split_stems.sh ~/Downloads/grinding_treadmill.mp3 [out-folder]
#
# demucs's htdemucs model splits into drums, bass, other and vocals. An instrumental Suno track leaves "vocals"
# nearly empty (any vocal-like synth lead lands there), so all four come back and the import decides what to use.
# The venv lives in builder0's shared toolchain folder and is made on first use (~2 minutes).
set -euo pipefail
IN="${1:?usage: split_stems.sh <track.mp3|wav> [out-folder]}"
[ -f "$IN" ] || { echo "no such file: $IN"; exit 2; }
NAME="$(basename "${IN%.*}")"
OUT="${2:-build/audio/stems/$NAME}"
HOST="${REMOTE_HOST:-slobdell@builder0}"
TOOLS="tank_squad/.tools"
WORK="tank_squad/stems-work/$NAME"

ssh "$HOST" "mkdir -p $WORK && cd $TOOLS && if ! demucs-venv/bin/python -c 'import demucs' 2>/dev/null; then
  echo '>> split_stems: installing demucs on builder0 (first use, ~2 minutes)';
  python3 -m venv demucs-venv && demucs-venv/bin/pip install -q --index-url https://download.pytorch.org/whl/cpu torch torchaudio \
    && demucs-venv/bin/pip install -q demucs soundfile; fi"
scp -q "$IN" "$HOST:$WORK/source.${IN##*.}"
echo ">> split_stems: separating $NAME on builder0 (a few minutes for a 2-minute track)"
ssh "$HOST" "cd $WORK && ~/$TOOLS/demucs-venv/bin/python -m demucs -n htdemucs -o sep source.${IN##*.} >demucs.log 2>&1 \
  || { tail -20 demucs.log; exit 1; }"
mkdir -p "$OUT"
scp -q "$HOST:$WORK/sep/htdemucs/source/*.wav" "$OUT/"
ssh "$HOST" "rm -rf $WORK"
echo ">> split_stems: $(ls "$OUT" | tr '\n' ' ')in $OUT"
echo "   next: make music-import IN=$OUT STATE=fight BPM=<tempo> LAYERS=\"other=0 drums=0.3 bass=0.55\" FROM=<m:ss> TO=<m:ss>"
