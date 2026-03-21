#!/usr/bin/env bash
# scripts/publish-maven.sh
#
# Veröffentlicht die gebauten JARs in einem separaten GitHub-Repo,
# das über GitHub Pages als Maven-Repository served wird.
#
# Erwartet folgende Umgebungsvariablen (werden von publish.yml gesetzt):
#   MAVEN_DEPLOY_KEY  – SSH Private Key (als String, nicht Pfad)
#   MAVEN_REPO        – GitHub Repo: "user/maven"
#   GROUP             – Maven Group ID, z.B. "com.example"
#   ARTIFACT          – Artifact Base Name, z.B. "mymod"
#   VERSION           – Mod-Version, z.B. "1.2.0"
#   MC_VERSION        – Minecraft-Version, z.B. "1.21.1"
set -Eeuo pipefail

trap 'echo "Error in publish-maven.sh at line $LINENO" >&2' ERR

#######################################
# Validation
#######################################
for var in MAVEN_DEPLOY_KEY MAVEN_REPO GROUP ARTIFACT VERSION MC_VERSION; do
  [[ -z "${!var:-}" ]] && { echo "Error: $var is not set" >&2; exit 1; }
done

#######################################
# SSH-Key einrichten
#######################################
mkdir -p ~/.ssh
echo "$MAVEN_DEPLOY_KEY" > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
export GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no"

#######################################
# Maven-Repo clonen
#######################################
echo "Cloning maven repo: $MAVEN_REPO"
git clone "git@github.com:${MAVEN_REPO}.git" /tmp/maven-repo
cd /tmp/maven-repo

git config user.email "github-actions[bot]@users.noreply.github.com"
git config user.name  "github-actions[bot]"

#######################################
# Verzeichnisstruktur aufbauen
# Layout: releases/{group_path}/{artifact}-{loader}/{version}/
# z.B.:   releases/com/example/mymod-fabric/1.2.0/
#######################################
GROUP_PATH="${GROUP//.//}"  # com.example → com/example

# Loader-Liste – passe an wenn du andere/mehr Loader hast
LOADERS=("fabric" "forge" "neoforge")

SOURCE_DIR="${GITHUB_WORKSPACE}/release-jars"

for loader in "${LOADERS[@]}"; do
  # JAR suchen
  JAR_PATTERN="${SOURCE_DIR}/*-${loader}.jar"
  JAR_FILE=$(ls ${JAR_PATTERN} 2>/dev/null | head -n1 || true)

  if [[ -z "$JAR_FILE" ]]; then
    echo "Warning: No JAR found for loader '$loader', skipping" >&2
    continue
  fi

  JAR_FILENAME=$(basename "$JAR_FILE")
  ARTIFACT_LOADER="${ARTIFACT}-${loader}"
  DEPLOY_DIR="releases/${GROUP_PATH}/${ARTIFACT_LOADER}/${VERSION}-mc${MC_VERSION}"

  mkdir -p "$DEPLOY_DIR"

  # JAR kopieren (mit versioniertem Namen)
  DEPLOY_JAR="${DEPLOY_DIR}/${ARTIFACT_LOADER}-${VERSION}-mc${MC_VERSION}.jar"
  cp "$JAR_FILE" "$DEPLOY_JAR"

  # MD5 und SHA1 Checksums (Maven-Standard)
  md5sum  "$DEPLOY_JAR" | awk '{print $1}' > "${DEPLOY_JAR}.md5"
  sha1sum "$DEPLOY_JAR" | awk '{print $1}' > "${DEPLOY_JAR}.sha1"

  # Minimales POM generieren
  POM_FILE="${DEPLOY_DIR}/${ARTIFACT_LOADER}-${VERSION}-mc${MC_VERSION}.pom"
  cat > "$POM_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${GROUP}</groupId>
  <artifactId>${ARTIFACT_LOADER}</artifactId>
  <version>${VERSION}-mc${MC_VERSION}</version>
  <packaging>jar</packaging>
</project>
EOF
  md5sum  "$POM_FILE" | awk '{print $1}' > "${POM_FILE}.md5"
  sha1sum "$POM_FILE" | awk '{print $1}' > "${POM_FILE}.sha1"

  # maven-metadata.xml aktualisieren (wird von Gradle zum Versionen-Listing benutzt)
  METADATA_DIR="releases/${GROUP_PATH}/${ARTIFACT_LOADER}"
  METADATA_FILE="${METADATA_DIR}/maven-metadata.xml"

  # Bestehende Versionen einlesen oder leere Liste starten
  if [[ -f "$METADATA_FILE" ]]; then
    mapfile -t EXISTING_VERSIONS < <(grep -oP '(?<=<version>)[^<]+' "$METADATA_FILE" || true)
  else
    EXISTING_VERSIONS=()
  fi

  FULL_VERSION="${VERSION}-mc${MC_VERSION}"
  # Version nur einmal eintragen
  if [[ ! " ${EXISTING_VERSIONS[*]} " =~ " ${FULL_VERSION} " ]]; then
    EXISTING_VERSIONS+=("$FULL_VERSION")
  fi

  LATEST_VERSION="${EXISTING_VERSIONS[-1]}"
  UPDATED=$(date -u +"%Y%m%d%H%M%S")

  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<metadata>'
    echo "  <groupId>${GROUP}</groupId>"
    echo "  <artifactId>${ARTIFACT_LOADER}</artifactId>"
    echo "  <versioning>"
    echo "    <latest>${LATEST_VERSION}</latest>"
    echo "    <release>${LATEST_VERSION}</release>"
    echo "    <versions>"
    for v in "${EXISTING_VERSIONS[@]}"; do
      echo "      <version>${v}</version>"
    done
    echo "    </versions>"
    echo "    <lastUpdated>${UPDATED}</lastUpdated>"
    echo "  </versioning>"
    echo '</metadata>'
  } > "$METADATA_FILE"

  md5sum  "$METADATA_FILE" | awk '{print $1}' > "${METADATA_FILE}.md5"
  sha1sum "$METADATA_FILE" | awk '{print $1}' > "${METADATA_FILE}.sha1"

  echo "Published: ${GROUP}:${ARTIFACT_LOADER}:${FULL_VERSION}"
done

#######################################
# Commit & Push
#######################################
git add -A

if git diff --cached --quiet; then
  echo "Nothing to commit – versions already published?"
  exit 0
fi

git commit -m "publish: ${GROUP}:${ARTIFACT}:${VERSION}-mc${MC_VERSION}"
git push origin HEAD

echo ""
echo "Maven repository updated successfully."
echo "Users can add this to their build.gradle:"
echo ""
echo "  repositories {"
echo "      maven { url = 'https://$(echo $MAVEN_REPO | cut -d'/' -f1).github.io/$(echo $MAVEN_REPO | cut -d'/' -f2)' }"
echo "  }"