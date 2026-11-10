#!/usr/bin/env bash
# Push and wait for the resulting plugin build.
#
# Push-triggered workflows work on this fork, so pushing is enough. The dispatch is kept only as a
# fallback: forks of public repos start with push triggers disabled until workflows are enabled
# once (PUT /actions/permissions with enabled=true clears it). If that ever regresses, this script
# still produces a build instead of silently doing nothing.
#
#   ./deploy.sh "commit message"     # commit everything, push, wait for the build
#   ./deploy.sh                      # push what is already committed, wait for the build
set -euo pipefail
export PATH="$HOME/bin:$PATH"
REPO="kc0m/Torvia-Jellyfin"
cd "$(dirname "$0")"

if [ "${1:-}" != "" ]; then
  git add -A
  git -c user.name="kc0m" -c user.email="m0ckerz24@gmail.com" commit -m "$1"
fi

git push origin main
HEAD_SHA=$(git rev-parse HEAD)

find_run() {
  gh api "repos/$REPO/actions/runs?per_page=8" \
    --jq ".workflow_runs[] | select(.head_sha==\"$HEAD_SHA\") | .databaseId" | head -1
}

RUN=""
for _ in $(seq 1 48); do
  sleep 5
  RUN=$(find_run)
  [ -n "$RUN" ] && break
done

if [ -z "$RUN" ]; then
  echo "no push-triggered run after 240s - dispatching manually" >&2
  gh workflow run build.yml --repo "$REPO" --ref main
  for _ in $(seq 1 12); do
    sleep 5
    RUN=$(find_run)
    [ -n "$RUN" ] && break
  done
fi
[ -n "$RUN" ] || { echo "build never appeared - check the Actions tab" >&2; exit 1; }
echo "watching run $RUN ..."
gh run watch "$RUN" --repo "$REPO" --exit-status >/dev/null
echo "build finished:"
gh release list --repo "$REPO" --limit 1
echo
echo "install with:"
echo "  sudo rm -rf /opt/torvia-test/config/plugins/PhoenicxTorBox_*"
echo "  sudo mkdir -p /opt/torvia-test/config/plugins/PhoenicxTorBox_<ver>"
echo "  sudo cp PhoenicxTorBox.dll /opt/torvia-test/config/plugins/PhoenicxTorBox_<ver>/"
echo "  sudo chown -R 1000:1000 /opt/torvia-test/config && sudo docker restart jellyfin-torvia"
