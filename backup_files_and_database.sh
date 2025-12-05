#!/bin/bash

# ---------------------------------------------
# Script Name: backup_fils_and_database.sh
# Description: Creates a zip backup of the WordPress site,
#              excluding wp-content/uploads/, and includes a database dump.
# Author: www.BigRedSEO.com
# Date: 2025-06-18
# ---------------------------------------------

# ---------------------------
# 1. Ask for Filename Prefix
# ---------------------------

read -p "Enter the domain shortname (e.g., bigredseo): " SHORTNAME
if [[ -z "$SHORTNAME" ]]; then
  echo "❌ No shortname entered. Exiting."
  exit 1
fi

# ---------------------------
# 2. Define Variables
# ---------------------------

DATE=$(date +%Y%m%d)
BACKUP_FILE="${SHORTNAME}_fd_backup_${DATE}.zip"
DB_DUMP_FILE="db_backup_${DATE}.sql"
WP_CONFIG="./public_html/wp-config.php"

# Exclusion paths (array)
EXCLUDE_DIRS=(
  "./public_html/wp-content/uploads"
  "./public_html/wp-content/cache" #SiteGround Cache
)

# ---------------------------
# 3. Extract DB Credentials
# ---------------------------

DB_NAME=$(grep DB_NAME "$WP_CONFIG" | cut -d "'" -f 4)
DB_USER=$(grep DB_USER "$WP_CONFIG" | cut -d "'" -f 4)
DB_PASSWORD=$(grep DB_PASSWORD "$WP_CONFIG" | cut -d "'" -f 4)
DB_HOST=$(grep DB_HOST "$WP_CONFIG" | cut -d "'" -f 4)

# ---------------------------
# 4. Dump the Database
# ---------------------------

echo "📦 Dumping database: $DB_NAME"
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$DB_DUMP_FILE"

# ---------------------------
# 5. Create the ZIP Archive
# ---------------------------

echo "🗜 Creating ZIP archive: $BACKUP_FILE"

# Build exclude parameters
EXCLUDES=()
for DIR in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDES+=("-x" "${DIR}/*")
done

zip -r "$BACKUP_FILE" ./public_html "$DB_DUMP_FILE" "${EXCLUDES[@]}"

# Cleanup SQL dump
rm "$DB_DUMP_FILE"

# ---------------------------
# 6. Done
# ---------------------------

echo "✅ Backup created successfully: $BACKUP_FILE"

