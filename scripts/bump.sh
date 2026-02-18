#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# bump.sh — smart version bumping with Claude
#
# Usage:
#   devbox run bump                 # Claude decides bump level
#   devbox run bump -- --patch      # force patch
#   devbox run bump -- --minor      # force minor
#   devbox run bump -- --major      # force major
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Plugin registry: dir:version_file:jq_path
PLUGINS=(
  "plugins/android:plugins/android/plugin.json:.version"
  "plugins/ios:plugins/ios/plugin.json:.version"
  "plugins/react-native:plugins/react-native/plugin.json:.version"
  "plugins/devbox-mcp:plugins/devbox-mcp/package.json:.version"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

bump_version() {
  local version="$1" level="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"
  case "$level" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
    *) echo "ERROR: unknown bump level: $level" >&2; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

EXPLICIT_LEVEL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --major) EXPLICIT_LEVEL="major"; shift ;;
    --minor) EXPLICIT_LEVEL="minor"; shift ;;
    --patch) EXPLICIT_LEVEL="patch"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Step 1: Auto-commit dirty worktree
# ---------------------------------------------------------------------------

if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "Uncommitted changes detected, creating commit first..."
  claude -p --model sonnet --allowedTools "Bash(git:*)" <<'PROMPT'
There are uncommitted changes in this repo. Stage all changes and create a descriptive commit. Use conventional commit format {type}({scope}): {description}. Types: feat, fix, docs, test, refactor, perf, chore. Scopes: android, ios, react-native, ci, docs, tests.
PROMPT
  echo ""
fi

# ---------------------------------------------------------------------------
# Step 2: Find last release tag
# ---------------------------------------------------------------------------

LAST_TAG=$(git tag -l 'v*' --sort=-v:refname | head -1 || true)
if [ -z "$LAST_TAG" ]; then
  LAST_TAG=$(git rev-list --max-parents=0 HEAD)
  echo "No release tags found, using initial commit: ${LAST_TAG:0:8}"
else
  echo "Last release tag: $LAST_TAG"
fi

# ---------------------------------------------------------------------------
# Step 3: Detect changed plugins
# ---------------------------------------------------------------------------

declare -a CHANGED_PLUGINS=()
declare -a CHANGED_DIRS=()

for entry in "${PLUGINS[@]}"; do
  IFS=':' read -r plugin_dir version_file jq_path <<< "$entry"
  if [ -n "$(git diff --name-only "$LAST_TAG"..HEAD -- "$plugin_dir")" ]; then
    CHANGED_PLUGINS+=("$entry")
    CHANGED_DIRS+=("$plugin_dir")
  fi
done

if [ ${#CHANGED_PLUGINS[@]} -eq 0 ]; then
  echo "No plugins changed since $LAST_TAG. Nothing to bump."
  exit 0
fi

echo ""
echo "Changed plugins:"
for entry in "${CHANGED_PLUGINS[@]}"; do
  IFS=':' read -r plugin_dir _ _ <<< "$entry"
  echo "  - $plugin_dir"
done
echo ""

# ---------------------------------------------------------------------------
# Step 4: Determine bump level
# ---------------------------------------------------------------------------

if [ -n "$EXPLICIT_LEVEL" ]; then
  BUMP_LEVEL="$EXPLICIT_LEVEL"
  echo "Bump level (explicit): $BUMP_LEVEL"
else
  echo "Asking Claude to analyze changes..."
  log_output=$(git log --oneline "$LAST_TAG"..HEAD -- "${CHANGED_DIRS[@]}")

  BUMP_LEVEL=$(claude -p --model sonnet <<PROMPT | tr -d '[:space:]'
Given these changes to devbox plugins since the last release:

Git log:
$log_output

Determine the semver bump level: major, minor, or patch.
- major: breaking changes to plugin API, env var renames, removed features
- minor: new features, new commands, new env vars
- patch: bug fixes, docs, refactoring, dependency updates

Reply with ONLY one word: major, minor, or patch
PROMPT
  )

  # Validate response
  if [[ "$BUMP_LEVEL" != "major" && "$BUMP_LEVEL" != "minor" && "$BUMP_LEVEL" != "patch" ]]; then
    echo "Claude returned unexpected bump level: '$BUMP_LEVEL'. Defaulting to patch."
    BUMP_LEVEL="patch"
  fi
  echo "Bump level (Claude): $BUMP_LEVEL"
fi

echo ""

# ---------------------------------------------------------------------------
# Step 5: Bump versions
# ---------------------------------------------------------------------------

declare -a BUMPED_SUMMARY=()
declare -a CHANGED_FILES=()

for entry in "${CHANGED_PLUGINS[@]}"; do
  IFS=':' read -r plugin_dir version_file jq_path <<< "$entry"

  current_version=$(jq -r "$jq_path" "$version_file")
  new_version=$(bump_version "$current_version" "$BUMP_LEVEL")

  echo "  $plugin_dir: $current_version -> $new_version"

  # Update version in-place
  jq --arg v "$new_version" "$jq_path = \$v" "$version_file" > "${version_file}.tmp"
  mv "${version_file}.tmp" "$version_file"

  BUMPED_SUMMARY+=("$plugin_dir ($current_version -> $new_version)")
  CHANGED_FILES+=("$version_file")
done

echo ""

# ---------------------------------------------------------------------------
# Step 6: Generate release summary and commit
# ---------------------------------------------------------------------------

BUMPED_LIST=$(printf '%s\n' "${BUMPED_SUMMARY[@]}")
LOG_OUTPUT=$(git log --oneline "$LAST_TAG"..HEAD -- "${CHANGED_DIRS[@]}")
TEMPLATE=$(cat "$REPO_ROOT/scripts/bump-template.md")

# Determine the representative new version (use the first bumped plugin's new version)
IFS=':' read -r _ first_file first_path <<< "${CHANGED_PLUGINS[0]}"
NEW_VERSION=$(jq -r "$first_path" "$first_file")

echo "Generating release summary with Claude..."

RELEASE_SUMMARY=$(claude -p --model sonnet <<PROMPT
Generate a release summary following this template exactly:

$TEMPLATE

Plugins bumped ($BUMP_LEVEL):
$BUMPED_LIST

Git log since $LAST_TAG:
$LOG_OUTPUT

Fill in the template. Omit any sections marked 'Omit section if none' that have no entries.
Output ONLY the filled template, no preamble.
PROMPT
)

echo ""
echo "--- Release Summary ---"
echo "$RELEASE_SUMMARY"
echo "--- End Summary ---"
echo ""

# ---------------------------------------------------------------------------
# Step 7: Stage, commit, and tag
# ---------------------------------------------------------------------------

# Build plugin name list for commit message
PLUGIN_NAMES=""
for entry in "${CHANGED_PLUGINS[@]}"; do
  IFS=':' read -r plugin_dir _ _ <<< "$entry"
  name=$(basename "$plugin_dir")
  if [ -z "$PLUGIN_NAMES" ]; then
    PLUGIN_NAMES="$name"
  else
    PLUGIN_NAMES="$PLUGIN_NAMES, $name"
  fi
done

git add "${CHANGED_FILES[@]}"

git commit -m "$(cat <<EOF
chore(release): bump ${PLUGIN_NAMES} to v${NEW_VERSION}

${RELEASE_SUMMARY}
EOF
)"

TAG="v${NEW_VERSION}"

echo "Committed: $TAG"
echo ""
echo "To publish this release:"
echo "  1. Push your branch and open a PR:"
echo "     git push -u origin HEAD"
echo "     gh pr create --title 'chore(release): bump ${PLUGIN_NAMES} to ${TAG}'"
echo "  2. After CI passes and the PR is merged, release.yml will create the tag and GitHub Release."
