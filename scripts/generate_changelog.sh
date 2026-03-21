#!/usr/bin/env bash
set -Eeuo pipefail

#######################################
# Configuration
#######################################
CONFIG_FILE=".mod-build-config.json"
OUTPUT_FILE="CHANGELOG.md"
VERSION="${1:-}"
MOD_NAME="${2:-}"

#######################################
# Error handling
#######################################
trap 'echo "Error: Script failed at line $LINENO" >&2' ERR

#######################################
# Dependency checks
#######################################
command -v git >/dev/null 2>&1 || { echo "Error: git is not installed or not in PATH" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "Error: jq is not installed or not in PATH"  >&2; exit 1; }

#######################################
# Validation
#######################################
if [[ -z "$VERSION" || -z "$MOD_NAME" ]]; then
  echo "Usage: $0 <VERSION> <MOD_NAME>" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

jq empty "$CONFIG_FILE" 2>/dev/null || { echo "Error: Invalid JSON in $CONFIG_FILE" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: Not inside a git repository" >&2
  exit 1
}

#######################################
# Git range
# Sucht nur nach Tags die zum aktuellen Branch passen,
# damit MC-Versions-Branches sich nicht gegenseitig stören.
#######################################
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
LAST_TAG=$(git tag --merged HEAD --sort=-creatordate | head -n1 || true)

if [[ -n "$LAST_TAG" ]]; then
  RANGE="$LAST_TAG..HEAD"
  echo "Info: Generating changelog from $LAST_TAG to HEAD (branch: $CURRENT_BRANCH)"
else
  RANGE="HEAD"
  echo "Info: No previous tag found – using full history (branch: $CURRENT_BRANCH)"
fi

mapfile -t COMMITS < <(git log "$RANGE" --pretty=format:%s 2>/dev/null || true)

if [[ ${#COMMITS[@]} -eq 0 ]]; then
  echo "Warning: No commits found in range '$RANGE'" >&2
fi

#######################################
# Output header
#######################################
DATE=$(date +"%Y-%m-%d")
{
  echo "## Changelog of $MOD_NAME v$VERSION"
  echo "*$DATE*"
  echo ""
} > "$OUTPUT_FILE"

#######################################
# Processing – Commits werden pro Kategorie gesammelt
# und dann als Sektion ausgegeben. Leere Sektionen
# werden komplett weggelassen.
#######################################
shopt -s nocasematch

jq -c '.changelog_categories[]' "$CONFIG_FILE" | while IFS= read -r entry; do
  OUTPUT_LABEL=$(jq -r '.output' <<< "$entry")
  mapfile -t INPUTS < <(jq -r '.inputs[]' <<< "$entry")

  # Sammle alle passenden Einträge für diese Kategorie
  declare -a SECTION_LINES=()

  for commit in "${COMMITS[@]}"; do
    [[ -z "$commit" ]] && continue

    for input in "${INPUTS[@]}"; do
      matched=false

      if [[ "$input" =~ ^[[:alnum:]]+$ ]]; then
        # Keyword-Syntax: [fixed] some text
        if [[ "$commit" =~ ^\[$input\][[:space:]]*(.+)$ ]]; then
          TEXT="${BASH_REMATCH[1]}"
          matched=true
        fi
      else
        # Emoji-Syntax: 🐛 some text
        if [[ "$commit" =~ ^${input}[[:space:]]*(.+)$ ]]; then
          TEXT="${BASH_REMATCH[1]}"
          matched=true
        fi
      fi

      if [[ "$matched" == true ]]; then
        SECTION_LINES+=("- $TEXT")
        break  # Nächsten Commit prüfen, nicht weitere inputs
      fi
    done
  done

  # Sektion nur ausgeben wenn es Einträge gibt
  if [[ ${#SECTION_LINES[@]} -gt 0 ]]; then
    echo "### $OUTPUT_LABEL" >> "$OUTPUT_FILE"
    for line in "${SECTION_LINES[@]}"; do
      echo "$line" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  fi

  unset SECTION_LINES
done

shopt -u nocasematch

echo "Changelog successfully written to $OUTPUT_FILE"
cat "$OUTPUT_FILE"