#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Args
# ------------------------------------------------------------
MOD_VERSION="${1:-}"
MC_VERSION="${2:-}"
RAW_CHANNEL="${3:-}"

if [[ -z "$MOD_VERSION" || -z "$MC_VERSION" || -z "$RAW_CHANNEL" ]]; then
  echo "ERROR: Usage: generate_metadata.sh <mod_version> <minecraft_version> <release_channel_raw>" >&2
  exit 1
fi

CONFIG_FILE=".release-config.json"
OUTPUT_FILE="metadata.json"
MAPPER_SCRIPT="scripts/map_release_channel.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found" >&2
  exit 1
fi

if [[ ! -x "$MAPPER_SCRIPT" ]]; then
  echo "ERROR: $MAPPER_SCRIPT not found or not executable" >&2
  exit 1
fi

# ------------------------------------------------------------
# Map release channel
# ------------------------------------------------------------
MAPPED_CHANNEL="$("$MAPPER_SCRIPT" "$RAW_CHANNEL" 2>/dev/null || echo "release")"

if [[ -z "$MAPPED_CHANNEL" ]]; then
  MAPPED_CHANNEL="release"
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

  "release_channel_raw": "$RAW_CHANNEL",
  "release_channel": "$MAPPED_CHANNEL",

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

  JAR_PATH="$MODULE/build/libs/$JAR_NAME"

  if [[ ! -f "$JAR_PATH" ]]; then
    echo "ERROR: Jar not found: $JAR_PATH" >&2
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
