#!/usr/bin/env bash
# Mirror the full Anthropic/EconomicIndex dataset into a scratch dir.
#
# Run this AFTER the environment's Network access is set to Full (or huggingface.co
# is on a Custom allowlist), in a fresh session.
#
# Usage:   scripts/fetch_economic_index.sh [DEST_DIR]
#   DEST_DIR defaults to /tmp/economic_index_data
#   Set FORCE=1 to download even if it may exceed available disk.
set -euo pipefail

DEST="${1:-/tmp/economic_index_data}"
REPO="Anthropic/EconomicIndex"
FORCE="${FORCE:-0}"

echo ">> Repo:        $REPO"
echo ">> Destination: $DEST"

# Ensure huggingface_hub is available (needed for both sizing and download).
if ! python3 -c "import huggingface_hub" 2>/dev/null; then
  echo ">> Installing huggingface_hub..."
  pip install -q huggingface_hub
fi

# ---- Pre-flight: total dataset size vs. available disk -------------------
mkdir -p "$DEST"
echo ">> Checking dataset size and available disk before downloading..."
python3 - "$REPO" "$DEST" "$FORCE" <<'PY'
import shutil, sys
from huggingface_hub import HfApi

repo, dest, force = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

api = HfApi()
info = api.repo_info(repo_id=repo, repo_type="dataset", files_metadata=True)

total = 0
for s in info.siblings:
    sz = getattr(s.lfs, "size", None) if getattr(s, "lfs", None) else None
    sz = sz if sz is not None else (s.size or 0)
    total += sz

avail = shutil.disk_usage(dest).free
gb = 1024 ** 3
print(f">> Dataset total size : {total/gb:6.2f} GB ({len(info.siblings)} files)")
print(f">> Disk free at dest  : {avail/gb:6.2f} GB")

# Require a 2 GB safety margin for temp/index files.
margin = 2 * gb
if total + margin > avail and not force:
    print("")
    print("!! ABORT: dataset may not fit on the available disk (need total + 2GB margin).")
    print("!! Options:")
    print("!!   - Re-run with FORCE=1 to download anyway, or")
    print("!!   - Download specific release subfolders instead of everything.")
    sys.exit(3)
print(">> Size check passed; proceeding with download.")
PY

# ---- Download ------------------------------------------------------------
echo ">> Downloading full dataset (this may take a while)..."
python3 - "$REPO" "$DEST" <<'PY'
import sys
from huggingface_hub import snapshot_download
repo, dest = sys.argv[1], sys.argv[2]
path = snapshot_download(repo_id=repo, repo_type="dataset", local_dir=dest)
print(f">> Downloaded full dataset to: {path}")
PY

# ---- Verify --------------------------------------------------------------
echo ">> File tree (top levels):"
find "$DEST" -maxdepth 2 -type f | head -50
echo ">> File count:"; find "$DEST" -type f | wc -l
echo ">> Total size on disk:"; du -sh "$DEST"
