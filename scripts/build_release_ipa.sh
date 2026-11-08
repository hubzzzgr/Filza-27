#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "usage: $0 <base-unsigned.ipa> <output.ipa> [MCMIdentifiers.plist]" >&2
  exit 64
fi
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Resolve paths before changing directory.
args=()
for arg in "$@"; do
  args+=("$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$arg")")
done
[[ -s "${args[0]}" ]] || { echo "base IPA not found: ${args[0]}" >&2; exit 66; }
cd "$REPO_ROOT"
export THEOS="${THEOS:-$HOME/theos}"
# Stage generated sources before Theos expands the Swift input lists.
bash scripts/stage-mond-current.sh
bash scripts/stage-mond-22-overlay.sh
bash scripts/stage-3105-v1.sh
gmake clean
gmake -j"$(sysctl -n hw.logicalcpu)" all FINALPACKAGE=1
bash scripts/generate-appintents-metadata.sh .theos/byetunes-appintents
bash scripts/package-unsigned-ipa.sh "${args[@]}"
