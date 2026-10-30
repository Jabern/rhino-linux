#!/bin/bash
# Adds a flatpak-builder build to the signed Flatpak repository that GitHub
# Pages serves, and exports a bundle of the same commit. Installing either the
# bundle, rhino-on-linux.flatpakref or rhino-on-linux.flatpakrepo subscribes
# Flatpak to the repository, so the app then updates like any other Flatpak.
#
#   publish-repo.sh BUILD_REPO SITE_DIR BUNDLE
#
# BUILD_REPO  flatpak-builder's --repo
# SITE_DIR    the site's folder (the gh-pages branch); the repository is SITE_DIR/repo
# BUNDLE      the bundle to write
#
# GPG_KEY_ID signs with the key in GPG_HOMEDIR (default: gpg's own).
# REPO_URL is where SITE_DIR/repo is served.
set -euo pipefail

BUILD_REPO="$1"
SITE_DIR="$2"
BUNDLE="$3"
: "${GPG_KEY_ID:?GPG_KEY_ID is not set}"
REPO_URL="${REPO_URL:-https://jabern.github.io/rhino-linux/repo/}"
APP_ID=io.github.jabern.RhinoOnLinux
REF="app/$APP_ID/x86_64/master"
HERE="$(cd "$(dirname "$0")" && pwd)"
KEY="$HERE/rhino-on-linux.gpg"
RUNTIME_REPO=https://dl.flathub.org/repo/flathub.flatpakrepo

sign=(--gpg-sign="$GPG_KEY_ID")
[ -n "${GPG_HOMEDIR:-}" ] && sign+=(--gpg-homedir="$GPG_HOMEDIR")

REPO="$SITE_DIR/repo"
if [ ! -f "$REPO/config" ]; then
    mkdir -p "$REPO"
    ostree init --mode=archive --repo="$REPO"
fi

# A new commit on top of the published one, so the repository keeps history.
flatpak build-commit-from --src-repo="$BUILD_REPO" "${sign[@]}" "$REPO" "$REF"
flatpak build-update-repo "${sign[@]}" --title="Rhino on Linux" --default-branch=master \
    --generate-static-deltas --prune --prune-depth=5 "$REPO"

key_b64="$(base64 -w0 "$KEY")"
cat > "$SITE_DIR/rhino-on-linux.flatpakrepo" << EOF
[Flatpak Repo]
Title=Rhino on Linux
Url=$REPO_URL
Homepage=https://github.com/Jabern/rhino-linux
Comment=Rhino 3D on Linux, with a patched Wine
GPGKey=$key_b64
EOF
cat > "$SITE_DIR/rhino-on-linux.flatpakref" << EOF
[Flatpak Ref]
Name=$APP_ID
Branch=master
Title=Rhino on Linux
Url=$REPO_URL
SuggestRemoteName=rhino-on-linux
RuntimeRepo=$RUNTIME_REPO
IsRuntime=false
GPGKey=$key_b64
EOF
# GitHub Pages would otherwise run the site through Jekyll; ostree's lock and
# scratch space stay out of the branch.
touch "$SITE_DIR/.nojekyll"
printf 'repo/.lock\nrepo/tmp/\n' > "$SITE_DIR/.gitignore"

# --repo-url and --gpg-keys: installing the bundle sets up the repository as
# the app's remote. --runtime-repo: the GNOME runtime comes from Flathub.
flatpak build-bundle --repo-url="$REPO_URL" --gpg-keys="$KEY" --runtime-repo="$RUNTIME_REPO" \
    "$REPO" "$BUNDLE" "$APP_ID" master
