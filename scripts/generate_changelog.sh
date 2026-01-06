#!/usr/bin/env bash
set -e

CATEGORIES_FILE="scripts/changelog_categories.json"
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
CURRENT_TAG=$1

echo "Generating changelog from '$LAST_TAG' to '$CURRENT_TAG'..."

# Load categories
CATEGORIES=$(jq -r 'keys[]' "$CATEGORIES_FILE")

echo "## Changelog for $CURRENT_TAG"
echo ""

for CATEGORY in $CATEGORIES; do
    DISPLAY=$(jq -r --arg c "$CATEGORY" '.[$c]' "$CATEGORIES_FILE")

    # Find PRs with matching prefix
    PRS=$(git log "$LAST_TAG"..HEAD --pretty=format:"%s" | grep -i "^

\[$CATEGORY\]

" || true)

    if [ -z "$PRS" ]; then
        continue
    fi

    # Print category header only if display string exists
    if [ "$DISPLAY" != "" ]; then
        echo "### $DISPLAY"
    fi

    while IFS= read -r LINE; do
        # Remove [category] prefix
        CLEANED=$(echo "$LINE" | sed -E "s/^

\[$CATEGORY\]

 ?//i")

        if [ "$DISPLAY" != "" ]; then
            echo "- $DISPLAY: $CLEANED"
        else
            echo "- $CLEANED"
        fi
    done <<< "$PRS"

    echo ""
done
