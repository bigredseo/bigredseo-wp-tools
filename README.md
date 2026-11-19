# bigredseo-wp-tools

Command-line tools for WordPress site management, maintained by [Big Red SEO](https://bigredseo.com).

## BRS Site Backup

**Script:** `brs-site-backup.sh`  
**Version:** 1.3.0  
**Updated:** November 19, 2026

Creates a single ZIP archive containing a WordPress site's **`wp-content` directory**, a **MySQL database dump**, and any **optional additional directories** you configure.

> **Backup scope:** This is **not** a complete copy of `public_html`. WordPress core files, `wp-config.php`, and other files outside `wp-content` are not included unless they are located in a separately configured additional directory. Regular media uploads in `wp-content/uploads` are **optional at runtime** (included by default), except for specifically excluded cache and backup-plugin output.

### What it does

- Prompts for a short domain name, such as `bigredseo`, for the backup filename.
- Includes `public_html/wp-content` with its plugins and themes, and prompts whether to include regular media uploads (default: Yes).
- Reads database credentials from `public_html/wp-config.php` and creates a `.sql` dump.
- Optionally includes one or more additional directories, such as `protected` or `client_documents`, **in full** (including PDFs and ZIP files).
- Excludes common cache directories, generated archives, and backup-plugin output **within `wp-content`**.
- Packages the selected folders and SQL dump into a ZIP archive.
- Checks the ZIP archive's integrity and removes the temporary SQL dump on exit.
- Restricts permissions when creating the temporary SQL dump and ZIP archive.

The SQL dump is stored **inside the ZIP**; it is not separately compressed before archiving.

### Requirements

- A Linux server with **Bash**, `mysqldump`, `zip`, and `unzip` available.
- WordPress installed in `public_html` by default, with `wp-config.php` directly in that directory.
- Database credentials defined as literal strings in `wp-config.php` (`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`). Configurations that load credentials from environment variables or other PHP code are not supported by the current extractor.
- SSH or another way to execute shell scripts, plus sufficient disk space and file/database permissions.

### Expected directory structure

Run the script from the account directory that contains `public_html`. The script uses paths relative to the **current working directory**, not automatically relative to the script's own location.

```text
/home/youruser/
├── brs-site-backup.sh
├── public_html/
│   ├── wp-content/
│   ├── wp-config.php
│   └── ...
└── protected/                 # Optional; only included if configured
```

### Configuration

Edit the variables near the top of `brs-site-backup.sh`:

```bash
SITE_ROOT="public_html"

# Normal WordPress client: no additional directories.
ADDITIONAL_DIRS=()
```

For a client with **one** additional directory:

```bash
ADDITIONAL_DIRS=("protected")
```

For a client with **multiple** additional directories:

```bash
ADDITIONAL_DIRS=("protected" "private_files" "client_documents")
```

Directory names are **space-separated Bash array entries**, not comma-separated. Quoting each entry also supports names containing spaces, for example `("protected" "Client Documents")`.

Additional directories must be relative paths within the working directory. Absolute paths, paths containing `..`, and symbolic links used as additional directory roots are rejected. Every configured additional directory must exist; otherwise the script stops rather than producing an incomplete backup. Leave `ADDITIONAL_DIRS=()` when no additional folders are needed.

### How to use

1. Upload `brs-site-backup.sh` to the account directory **one level above** `public_html`.
2. SSH into the server and change to that directory:

   ```bash
   cd /home/youruser
   ```

3. Make the script executable (one time):

   ```bash
   chmod +x brs-site-backup.sh
   ```

4. Run it:

   ```bash
   ./brs-site-backup.sh
   ```

5. At the first prompt, enter a shortname such as `bigredseo`. At the second prompt, choose whether to include `wp-content/uploads`:

   ```text
   Include WordPress media uploads (wp-content/uploads)? [Y/n]:
   ```

   Press **Enter** or type **Y** to include uploads, or type **N** to exclude them. Invalid answers are requested again. This choice applies only to the standard WordPress uploads directory, not to any additional directories.

The archive is created in the directory from which you ran the script. For example:

```text
bigredseo_wpcontent_db_backup_20261119.zip
```

For the default configuration, the ZIP contains:

```text
public_html/
├── wp-content/
│   ├── plugins/
│   ├── themes/
│   └── uploads/             # Contents included only when selected
└── db_backup_20261119.sql
```

If `ADDITIONAL_DIRS=("protected")` is configured, the ZIP also contains:

```text
protected/
└── ...                      # All contents, including ZIP and PDF files
```

Download the archive with SFTP or your hosting control panel, and store it securely. If you run the script again with the same shortname on the same day, the existing ZIP with that filename is **replaced**.

### Exclusions

The script's `EXCLUDE_PATHS` array lists known cache locations, backup-plugin directories, and generated backup archive extensions. These patterns apply to **`SITE_ROOT/wp-content` only**. When uploads are declined, the script additionally excludes all contents under `SITE_ROOT/wp-content/uploads/` (the empty folder entry may remain in the ZIP). They do not filter the contents of optional additional directories.

You can customize `EXCLUDE_PATHS` for a particular client. Review it before relying on the archive as your sole backup, especially if a plugin stores essential data in a directory that resembles cache or backup output.

### Security and operational notes

- The SQL dump is temporarily written to `SITE_ROOT` (by default, `public_html/db_backup_YYYYMMDD.sql`) and deleted when the script exits. **Ensure temporary `.sql` files cannot be served over HTTP.** A private directory outside the web root would be safer for future versions.
- Database passwords are passed to `mysqldump` through a command-line argument, which may trigger a security warning or expose credentials to sufficiently privileged processes on the server.
- ZIP archives are not encrypted. Handle and store them as sensitive data, especially when backing up protected files and databases.
- The script verifies that the ZIP is readable, but this does not replace periodically testing a complete restoration.
- The backup is made from a live site. Files can change while ZIP runs; database transaction consistency depends on table engines and database behavior.

### Maintained by

**[Big Red SEO](https://bigredseo.com)**
