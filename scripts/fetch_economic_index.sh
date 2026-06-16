#!/usr/bin/env bash
# Mirror the full Anthropic/EconomicIndex dataset into a scratch dir.
# Run this AFTER huggingface.co (+ cdn-lfs hosts) are added to the
# environment's network egress allowlist.
set -euo pipefail

DEST="${1:-/tmp/economic_index_data}"
REPO="Anthropic/EconomicIndex"

echo ">> Destination: $DEST"

# Preferred path: huggingface_hub snapshot (handles LFS + resume).
if python3 -c "import huggingface_hub" 2>/dev/null || pip install -q huggingface_hub; then
  python3 - "$REPO" "$DEST" <<'PY'
import sys
from huggingface_hub import snapshot_download
repo, dest = sys.argv[1], sys.argv[2]
path = snapshot_download(repo_id=repo, repo_type="dataset", local_dir=dest)
print(f">> Downloaded full dataset to: {path}")
PY
else
  # Fallback: git clone with LFS.
  echo ">> huggingface_hub unavailable; falling back to git clone"
  GIT_LFS_SKIP_SMUDGE=0 git clone "https://huggingface.co/datasets/$REPO" "$DEST"
fi

echo ">> Tree:"
find "$DEST" -maxdepth 2 -type f | head -50
echo ">> Total size:"
du -sh "$DEST"
