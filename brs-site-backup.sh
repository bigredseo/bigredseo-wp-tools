#!/bin/bash

# ---------------------------------------------------------
# Script Name: site-backup.sh
# Description: Creates a ZIP backup containing:
#              1. The complete wp-content directory
#              2. A WordPress database dump
#
#              Cache directories, backup archives, and
#              generated backup-plugin files are excluded.
#
# Author: www.BigRedSEO.com
# Date: 20260724
# ---------------------------------------------------------

set -Eeuo pipefail

# ---------------------------
# 1. Ask for Filename Prefix
# ---------------------------

read -r -p "Enter the domain shortname (e.g., bigredseo): " SHORTNAME

if [[ -z "$SHORTNAME" ]]; then
    echo "No shortname entered. Exiting."
    exit 1
fi

# ---------------------------
# 2. Define Variables
# ---------------------------

DATE=$(date +%Y%m%d)

SITE_ROOT="./public_html"
WP_CONFIG="${SITE_ROOT}/wp-config.php"

BACKUP_FILE="${SHORTNAME}_wpcontent_db_backup_${DATE}.zip"
BACKUP_PATH="$(pwd)/${BACKUP_FILE}"

DB_DUMP_FILE="db_backup_${DATE}.sql"
DB_DUMP_PATH="${SITE_ROOT}/${DB_DUMP_FILE}"

# All exclusion paths are relative to public_html because the
# ZIP command is run from inside the public_html directory.
EXCLUDE_PATHS=(
    # General WordPress cache directories
    "wp-content/cache/*"
    "wp-content/cache-compat/*"

    # SiteGround Optimizer cache
    "wp-content/uploads/siteground-optimizer-assets/*"

    # Common cache plugin directories
    "wp-content/litespeed/*"
    "wp-content/w3tc-config/*"
    "wp-content/wp-rocket-config/*"
    "wp-content/advanced-cache.php"

    # Common backup plugin output directories
    "wp-content/ai1wm-backups/*"
    "wp-content/backup-db/*"
    "wp-content/backups/*"
    "wp-content/backupwordpress-*/*"
    "wp-content/backupwordpress-*"
    "wp-content/duplicator/*"
    "wp-content/duplicator-backups/*"
    "wp-content/updraft/*"
    "wp-content/wpvividbackups/*"
    "wp-content/uploads/backup-guard/*"
    "wp-content/uploads/backupbuddy_backups/*"
    "wp-content/uploads/wp-clone/*"

    # Common generated backup archive files anywhere in wp-content
    "wp-content/*.zip"
    "wp-content/*.tar"
    "wp-content/*.tar.gz"
    "wp-content/*.tgz"
    "wp-content/*.gz"
    "wp-content/*.wpress"
)

# ---------------------------
# 3. Validate Required Files
# ---------------------------

if [[ ! -d "$SITE_ROOT" ]]; then
    echo "Site directory not found: $SITE_ROOT"
    exit 1
fi

if [[ ! -d "${SITE_ROOT}/wp-content" ]]; then
    echo "wp-content directory not found: ${SITE_ROOT}/wp-content"
    exit 1
fi

if [[ ! -f "$WP_CONFIG" ]]; then
    echo "wp-config.php not found: $WP_CONFIG"
    exit 1
fi

if ! command -v mysqldump >/dev/null 2>&1; then
    echo "mysqldump is not available."
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    echo "zip is not available."
    exit 1
fi

# ---------------------------
# 4. Cleanup on Exit
# ---------------------------

cleanup() {
    if [[ -f "$DB_DUMP_PATH" ]]; then
        rm -f "$DB_DUMP_PATH"
    fi
}

trap cleanup EXIT

# ---------------------------
# 5. Extract DB Credentials
# ---------------------------

DB_NAME=$(grep -E "define\([[:space:]]*['\"]DB_NAME['\"]" "$WP_CONFIG" |
    head -n 1 |
    sed -E "s/.*DB_NAME['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")

DB_USER=$(grep -E "define\([[:space:]]*['\"]DB_USER['\"]" "$WP_CONFIG" |
    head -n 1 |
    sed -E "s/.*DB_USER['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")

DB_PASSWORD=$(grep -E "define\([[:space:]]*['\"]DB_PASSWORD['\"]" "$WP_CONFIG" |
    head -n 1 |
    sed -E "s/.*DB_PASSWORD['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]*)['\"].*/\1/")

DB_HOST=$(grep -E "define\([[:space:]]*['\"]DB_HOST['\"]" "$WP_CONFIG" |
    head -n 1 |
    sed -E "s/.*DB_HOST['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_HOST" ]]; then
    echo "Unable to extract database credentials from wp-config.php."
    exit 1
fi

# ---------------------------
# 6. Dump the Database
# ---------------------------

echo "Dumping database: $DB_NAME"

mysqldump \
    --host="$DB_HOST" \
    --user="$DB_USER" \
    --password="$DB_PASSWORD" \
    --single-transaction \
    --quick \
    --skip-lock-tables \
    --default-character-set=utf8mb4 \
    "$DB_NAME" > "$DB_DUMP_PATH"

if [[ ! -s "$DB_DUMP_PATH" ]]; then
    echo "Database dump failed or produced an empty file."
    exit 1
fi

echo "Database dump created: $DB_DUMP_FILE"

# ---------------------------
# 7. Build ZIP Exclusions
# ---------------------------

ZIP_EXCLUDES=()

for EXCLUDE_PATH in "${EXCLUDE_PATHS[@]}"; do
    ZIP_EXCLUDES+=("-x" "$EXCLUDE_PATH")
done

# ---------------------------
# 8. Create the ZIP Archive
# ---------------------------

echo "Creating ZIP archive: $BACKUP_FILE"

# Remove an existing backup with the same filename so ZIP does
# not update an older archive and leave stale files inside it.
rm -f "$BACKUP_PATH"

(
    cd "$SITE_ROOT"

    zip -r "$BACKUP_PATH" \
        "wp-content" \
        "$DB_DUMP_FILE" \
        "${ZIP_EXCLUDES[@]}"
)

# ---------------------------
# 9. Verify the ZIP
# ---------------------------

if [[ ! -s "$BACKUP_PATH" ]]; then
    echo "Backup ZIP was not created successfully."
    exit 1
fi

if ! unzip -t "$BACKUP_PATH" >/dev/null; then
    echo "The backup ZIP failed its integrity test."
    exit 1
fi

# ---------------------------
# 10. Done
# ---------------------------

BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f 1)

echo
echo "Backup created successfully:"
echo "$BACKUP_PATH"
echo "Backup size: $BACKUP_SIZE"
echo
echo "ZIP contents:"
echo "  ${DB_DUMP_FILE}"
echo "  wp-content/"