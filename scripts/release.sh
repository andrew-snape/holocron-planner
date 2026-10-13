#!/bin/bash
# Builds a release of Holocron and publishes it on GitHub.
#
#   scripts/release.sh 1.2
#
# Before running it: add a "## 1.2" section to CHANGELOG.md (it becomes the release notes) and commit
# your code changes. The script then sets the version, builds, zips the app, writes a checksum,
# commits, tags, pushes, and creates the GitHub release. Holocron's built-in updater picks it up.
#
# With the GitHub CLI (brew install gh, then gh auth login) it does everything. Without it, it builds the
# files and prints the few steps to publish them from GitHub Desktop and github.com.

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Usage: scripts/release.sh 1.2   (the version is numbers and dots, like 1.2 or 1.2.1)"
  exit 1
fi

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "You have uncommitted changes. Commit them first (git add -A && git commit -m \"...\"), then run this again."
  exit 1
fi

if ! grep -q "^## $VERSION\$" CHANGELOG.md; then
  echo "Add a section headed exactly \"## $VERSION\" to CHANGELOG.md first. It becomes the release notes."
  exit 1
fi

# Student and planner data must never be published.
if git ls-files | grep -qiE '\.csv$|(^|/)photos/'; then
  echo "A CSV file or a photos folder is tracked by git. Remove it before publishing:"
  git ls-files | grep -iE '\.csv$|(^|/)photos/'
  exit 1
fi

PBX="Holocron.xcodeproj/project.pbxproj"
BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBX" | sed 's/[^0-9]//g')"
BUILD=$((BUILD + 1))
sed -i '' -E "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = $VERSION;/; s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $BUILD;/" "$PBX"

echo "Building Holocron $VERSION (build $BUILD)..."
rm -rf build dist
mkdir -p dist
xcodebuild -project Holocron.xcodeproj -target Holocron -configuration Release \
  SYMROOT="$PWD/build" CODE_SIGN_IDENTITY=- clean build > dist/build.log 2>&1 || {
    echo "The build failed. The end of the log:"; tail -25 dist/build.log; exit 1; }

APP="build/Release/Holocron.app"
[ -d "$APP" ] || { echo "Build finished but $APP was not found. See dist/build.log"; exit 1; }
BUILT="$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)"
[ "$BUILT" = "$VERSION" ] || { echo "The built app says $BUILT, not $VERSION."; exit 1; }
codesign --verify --deep --strict "$APP"

ZIP="Holocron-$VERSION-mac.zip"
ditto -c -k --keepParent "$APP" "dist/$ZIP"
( cd dist && shasum -a 256 "$ZIP" > "$ZIP.sha256" )
awk -v v="## $VERSION" '$0==v{f=1;next} /^## /{f=0} f' CHANGELOG.md > dist/notes.md

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  git add -A
  git commit -m "Holocron $VERSION"
  git tag "v$VERSION"
  git push
  git push origin "v$VERSION"
  gh release create "v$VERSION" "dist/$ZIP" "dist/$ZIP.sha256" --title "Holocron $VERSION" --notes-file dist/notes.md
  echo "Published Holocron $VERSION. Running copies will offer it as an update."
else
  echo ""
  echo "Built Holocron $VERSION. The files are in the dist folder:"
  echo "  $ZIP"
  echo "  $ZIP.sha256"
  echo "  notes.md (the release notes)"
  echo ""
  echo "To publish without the GitHub CLI:"
  echo "  1. In GitHub Desktop, commit the changes (the new version number) and click Push origin."
  echo "  2. On github.com open your repository, then Releases, then Draft a new release."
  echo "  3. Choose Create new tag: v$VERSION (on main). Title it Holocron $VERSION."
  echo "  4. Paste in dist/notes.md, drag in the .zip and the .sha256 files, and click Publish release."
fi
