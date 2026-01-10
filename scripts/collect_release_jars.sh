#!/usr/bin/env bash
set -e

MODULES="$1"

if [ -z "$MODULES" ]; then
  echo "ERROR: No modules provided"
  exit 1
fi

FILES=""

for M in $MODULES; do
  META_FILE="$M/build/release-jar.txt"

  if [ ! -f "$META_FILE" ]; then
    echo "ERROR: $META_FILE not found. Did you run exportReleaseJar in the build workflow?"
    exit 1
  fi

  JAR_PATH=$(cat "$META_FILE")
  BASENAME=$(basename "$JAR_PATH")

  if [ ! -f "artifacts/$BASENAME" ]; then
    echo "ERROR: Release asset $BASENAME not found in GitHub release assets."
    exit 1
  fi

  FILES="$FILES artifacts/$BASENAME"
done

echo "$FILES"
