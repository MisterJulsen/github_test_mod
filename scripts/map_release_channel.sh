#!/usr/bin/env bash
set -e

CONFIG_FILE=".release-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found"
  exit 1
fi

RAW_CHANNEL="$1"
if [ -z "$RAW_CHANNEL" ]; then
  echo "ERROR: No release channel provided"
  exit 1
fi

RAW_CHANNEL_LOWER=$(echo "$RAW_CHANNEL" | tr '[:upper:]' '[:lower:]')

TYPE=""

# Iterate over categories in JSON
for CATEGORY in $(jq -r '.release_channels | keys[]' "$CONFIG_FILE"); do
  MATCHES=$(jq -r ".release_channels[\"$CATEGORY\"][]" "$CONFIG_FILE")

  for M in $MATCHES; do
    if [ "$RAW_CHANNEL_LOWER" = "$M" ]; then
      TYPE="$CATEGORY"
      break
    fi
  done

  if [ -n "$TYPE" ]; then
    break
  fi
done

# Fallback
if [ -z "$TYPE" ]; then
  echo "WARN: Unknown release channel '$RAW_CHANNEL', defaulting to 'release'" >&2
  TYPE="release"
fi

echo "$TYPE"
