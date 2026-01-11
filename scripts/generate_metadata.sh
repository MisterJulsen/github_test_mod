#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Args
# ------------------------------------------------------------
MOD_VERSION="${1:-}"
MC_VERSION="${2:-}"

if [[ -z "$MOD_VERSION" || -z "$MC_VERSION" ]]; then
  echo "ERROR: Usage: generate_metadata.sh <mod_version> <minecraft_version>" >&2
  exit 1
fi

CONFIG_FILE=".release-config.json"
OUTPUT_FILE="metadata.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found" >&2
  exit 1
fi

# ------------------------------------------------------------
# Timestamp
# ------------------------------------------------------------
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# ------------------------------------------------------------
# Begin JSON
# ------------------------------------------------------------
cat > "$OUTPUT_FILE" <<EOF
{
  "version": "$MOD_VERSION",
  "minecraft_version": "$MC_VERSION",
  "generated_at": "$GENERATED_AT",
  "artifacts": {
EOF

FIRST=true

# ------------------------------------------------------------
# Iterate modules
# ------------------------------------------------------------
for MODULE in $(jq -r '.modules[]' "$CONFIG_FILE"); do
  META_FILE="$MODULE/release-jar.txt"

  if [[ ! -f "$META_FILE" ]]; then
    echo "ERROR: $META_FILE not found" >&2
    exit 1
  fi

  JAR_NAME="$(tr -d '\r\n' < "$META_FILE")"

  if [[ -z "$JAR_NAME" ]]; then
    echo "ERROR: $META_FILE is empty" >&2
    exit 1
  fi

  # Validate jar exists
  if [[ ! -f "$MODULE/build/libs/$JAR_NAME" ]]; then
    echo "ERROR: Jar not found: $MODULE/build/libs/$JAR_NAME" >&2
    exit 1
  fi

  if [[ "$FIRST" = false ]]; then
    echo "," >> "$OUTPUT_FILE"
  fi
  FIRST=false

  cat >> "$OUTPUT_FILE" <<EOF
    "$MODULE": {
      "filename": "$JAR_NAME",
      "platform": "$MODULE"
    }
EOF
done

# ------------------------------------------------------------
# End JSON
# ------------------------------------------------------------
cat >> "$OUTPUT_FILE" <<EOF

  }
}
EOF

echo "Generated metadata.json:"
cat "$OUTPUT_FILE"
