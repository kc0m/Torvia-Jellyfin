#!/usr/bin/env bash
# Push, then explicitly trigger the plugin build.
#
# WHY NOT JUST PUSH: on a fork of a public repo GitHub holds push-triggered workflows
# disabled until the owner clicks "Enable workflows" in the Actions tab. `workflow_dispatch`
# is not affected, so we dispatch after pushing. One command -> one new installable build.
#
#   ./deploy.sh "commit message"     # commits everything, pushes, builds, waits, prints version
#   ./deploy.sh                      # pushes what is already committed, then builds
set -euo pipefail
export PATH="$HOME/bin:$PATH"
REPO="kc0m/Torvia-Jellyfin"
cd "$(dirname "$0")"

if [ "${1:-}" != "" ]; then
  git add -A
  git -c user.name="kc0m" -c user.email="m0ckerz24@gmail.com" commit -m "$1"
fi

git push origin main

gh workflow run build.yml --repo "$REPO" --ref main
sleep 8
RUN=$(gh api "repos/$REPO/actions/runs?per_page=1" --jq '.workflow_runs[0].databaseId')
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
