#!/bin/bash

# ---------------------------------------------------------
# Script Name: brs-site-backup.sh
# Version: 1.3.0
# Description: Creates a ZIP backup containing:
#              1. The complete WordPress wp-content directory
#              2. A WordPress database dump
#              3. Any configured additional directories
#
#              The user can choose whether to include
#              WordPress media uploads (wp-content/uploads).
#
#              Cache directories, generated backup archives,
#              and backup-plugin output are excluded from
#              wp-content. Additional directories are included
#              in full, including ZIP and PDF files.
#
# Author: www.BigRedSEO.com
# Date: 20261119
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

# Restrict the prefix to safe filename characters.
if [[ ! "$SHORTNAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Shortname may contain only letters, numbers, underscores, and hyphens."
    exit 1
fi

# ---------------------------
# 2. Ask About Media Uploads
# ---------------------------

# Default to including uploads to preserve the standard backup.
while true; do
    read -r -p "Include WordPress media uploads (wp-content/uploads)? [Y/n]: " UPLOADS_ANSWER

    case "${UPLOADS_ANSWER,,}" in
        ""|y|yes)
            INCLUDE_UPLOADS=true
            break
            ;;
        n|no)
            INCLUDE_UPLOADS=false
            break
            ;;
        *)
            echo "Please enter Y or N."
            ;;
    esac
done

# ---------------------------
# 3. Define Variables
# ---------------------------

DATE=$(date +%Y%m%d)

# All paths are relative to the directory where the script is run.
# Run this script from the common parent of these directories.
SITE_ROOT="public_html"

# Optional additional directories to include in the backup.
# Leave empty for a normal WordPress backup.
#
# Examples:
#   No additional directories:  ADDITIONAL_DIRS=()
#   One directory:              ADDITIONAL_DIRS=("protected")
#   Multiple directories:       ADDITIONAL_DIRS=("protected" "client_documents")
#
# Each directory must be inside the script's working directory.
# Additional directories are included in full.
ADDITIONAL_DIRS=()

WP_CONFIG="${SITE_ROOT}/wp-config.php"

BACKUP_FILE="${SHORTNAME}_wpcontent_db_backup_${DATE}.zip"
BACKUP_PATH="$(pwd)/${BACKUP_FILE}"

DB_DUMP_FILE="db_backup_${DATE}.sql"
DB_DUMP_PATH="${SITE_ROOT}/${DB_DUMP_FILE}"

# Exclusions are relative to the site's root directory. Section 8
# automatically prepends SITE_ROOT for the ZIP command.
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

    # Generated backup archive files anywhere in wp-content
    "wp-content/*.zip"
    "wp-content/*.tar"
    "wp-content/*.tar.gz"
    "wp-content/*.tgz"
    "wp-content/*.gz"
    "wp-content/*.wpress"
)

# ---------------------------
# 4. Validate Required Files
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

for REQUIRED_COMMAND in mysqldump zip unzip; do
    if ! command -v "$REQUIRED_COMMAND" >/dev/null 2>&1; then
        echo "Required command is not available: $REQUIRED_COMMAND"
        exit 1
    fi
done

# Avoid overwriting or deleting a pre-existing SQL dump.
if [[ -e "$DB_DUMP_PATH" || -L "$DB_DUMP_PATH" ]]; then
    echo "Temporary database dump path already exists: $DB_DUMP_PATH"
    echo "Remove or rename it manually before retrying."
    exit 1
fi

# Validate configured additional directories before starting the dump.
# Only relative paths within the working directory are supported.
ZIP_ADDITIONAL_DIRS=()
for EXTRA_DIR in "${ADDITIONAL_DIRS[@]}"; do
    [[ -z "$EXTRA_DIR" ]] && continue

    if [[ "$EXTRA_DIR" = /* || "$EXTRA_DIR" == *".."* || "$EXTRA_DIR" == "." ]]; then
        echo "Invalid additional directory path: $EXTRA_DIR"
        echo "Use a relative path under the current working directory, without '..'."
        exit 1
    fi

    # Do not follow symlinked directory roots outside the backup directory.
    if [[ -L "$EXTRA_DIR" ]]; then
        echo "Additional directory cannot be a symbolic link: $EXTRA_DIR"
        exit 1
    fi

    if [[ ! -d "$EXTRA_DIR" ]]; then
        echo "Configured additional directory not found: $EXTRA_DIR"
        exit 1
    fi

    ZIP_ADDITIONAL_DIRS+=("$EXTRA_DIR")
done

# ---------------------------
# 5. Cleanup on Exit
# ---------------------------

DUMP_CREATED=false
cleanup() {
    if [[ "$DUMP_CREATED" == true && -f "$DB_DUMP_PATH" ]]; then
        rm -f -- "$DB_DUMP_PATH"
    fi
}
trap cleanup EXIT

# ---------------------------
# 6. Extract DB Credentials
# ---------------------------

DB_NAME=$(grep -m 1 -E "define\([[:space:]]*['\"]DB_NAME['\"]" "$WP_CONFIG" | \
    sed -E "s/.*DB_NAME['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")

DB_USER=$(grep -m 1 -E "define\([[:space:]]*['\"]DB_USER['\"]" "$WP_CONFIG" | \
    sed -E "s/.*DB_USER['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")

DB_PASSWORD=$(grep -m 1 -E "define\([[:space:]]*['\"]DB_PASSWORD['\"]" "$WP_CONFIG" | \
    sed -E "s/.*DB_PASSWORD['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]*)['\"].*/\1/")

DB_HOST=$(grep -m 1 -E "define\([[:space:]]*['\"]DB_HOST['\"]" "$WP_CONFIG" | \
    sed -E "s/.*DB_HOST['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/")

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_HOST" ]]; then
    echo "Unable to extract database credentials from wp-config.php."
    exit 1
fi

# ---------------------------
# 7. Dump the Database
# ---------------------------

echo "Dumping database: $DB_NAME"

# Restrict read access to the temporary SQL dump and resulting ZIP.
umask 077

DUMP_CREATED=true
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
# 8. Build ZIP Exclusions
# ---------------------------

ZIP_EXCLUDES=()
for EXCLUDE_PATH in "${EXCLUDE_PATHS[@]}"; do
    ZIP_EXCLUDES+=("-x" "${SITE_ROOT}/${EXCLUDE_PATH}")
done

# Exclude all media uploads when the user selects No.
# This exclusion only applies to the normal WordPress uploads directory.
if [[ "$INCLUDE_UPLOADS" == false ]]; then
    ZIP_EXCLUDES+=("-x" "${SITE_ROOT}/wp-content/uploads/*")
    echo "WordPress media uploads will be excluded."
else
    echo "WordPress media uploads will be included."
fi

# ---------------------------
# 9. Create the ZIP Archive
# ---------------------------

echo "Creating ZIP archive: $BACKUP_FILE"

ZIP_INCLUDE=(
    "${SITE_ROOT}/wp-content"
    "${SITE_ROOT}/${DB_DUMP_FILE}"
)

for EXTRA_DIR in "${ZIP_ADDITIONAL_DIRS[@]}"; do
    echo "Including additional directory: $EXTRA_DIR"
    ZIP_INCLUDE+=("$EXTRA_DIR")
done

# Remove an existing archive so ZIP never retains stale files.
rm -f -- "$BACKUP_PATH"

zip -r "$BACKUP_PATH" \
    "${ZIP_INCLUDE[@]}" \
    "${ZIP_EXCLUDES[@]}"

# ---------------------------
# 10. Verify the ZIP
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
# 11. Done
# ---------------------------

BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f 1)

echo
echo "Backup created successfully:"
echo "$BACKUP_PATH"
echo "Backup size: $BACKUP_SIZE"
echo
echo "ZIP contents:"
for INCLUDED_PATH in "${ZIP_INCLUDE[@]}"; do
    echo "  ${INCLUDED_PATH}"
done
