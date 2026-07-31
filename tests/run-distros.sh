#!/usr/bin/env bash
# Run tests/smoke.sh inside a container for each supported distro.
#
# The claim on the tin is "works on any reasonably modern system", and the only
# honest way to keep that true is to actually run it on those systems. Each
# container gets ONE security tool (nmap) installed, so the index is expected to
# come out small -- the point is that indexing, the CLI surface and the row
# rendering all behave, not how many tools happen to be present.
#
# Alpine is deliberately left on busybox awk (no gawk): it is the strictest awk
# in the support matrix and the one that caught sprintf("%-*s", ...).
#
#   ./tests/run-distros.sh            # every distro
#   ./tests/run-distros.sh alpine     # just one
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${ENGINE:-docker}"
command -v "$ENGINE" >/dev/null 2>&1 || { echo "need $ENGINE"; exit 1; }

# image | shell | command that installs bash + one tool to index
TARGETS=(
  "archlinux:latest|bash|pacman -Sy --noconfirm --quiet nmap"
  "debian:12|bash|apt-get update -qq && apt-get install -y -qq nmap"
  "ubuntu:24.04|bash|apt-get update -qq && apt-get install -y -qq nmap"
  "fedora:41|bash|dnf install -y -q nmap"
  "alpine:3.20|sh|apk add --no-cache bash nmap"
)

want="${1:-}"
fails=0
for t in "${TARGETS[@]}"; do
    IFS='|' read -r image shell setup <<< "$t"
    [[ -n "$want" && "$image" != *"$want"* ]] && continue
    printf '\n==================== %s ====================\n' "$image"
    "$ENGINE" run --rm \
        -v "$REPO:/repo:ro" \
        "$image" "$shell" -c "$setup >/dev/null 2>&1; cp -r /repo /work && cd /work && bash tests/smoke.sh" \
        || { fails=$((fails+1)); echo "  !! $image FAILED"; }
done

printf '\n%s\n' "----------------------------------------"
if ((fails)); then echo "$fails distro(s) failed"; exit 1; fi
echo "all distros passed"
