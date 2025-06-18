# bigredseo-wp-tools

Command-line tools to simplify WordPress site management, built by [Big Red SEO](https://bigredseo.com). This repository currently includes a Bash script for generating full-site backups with minimal configuration.

---

## 📦 Script: `backup.sh`

A lightweight shell script that creates a `.zip` archive of a WordPress site — including all files (excluding media uploads) and a full MySQL database dump.

---

### ✅ What It Does

- Prompts for a shortname to use in the filename (e.g., `mamamoonrocks`)
- Backs up everything in `/public_html`, excluding `/wp-content/uploads`
- Automatically finds and uses database credentials from `wp-config.php`
- Dumps and includes a compressed `.sql` database backup
- Packages the site and database into a single `.zip` file
- Cleans up the temporary SQL dump after packaging

---

### 📁 File Structure Assumptions

This script assumes:
- WordPress is installed in `/public_html`
- The script is placed **outside** that directory — e.g., in your account root

```
/home/youruser/
├── backup.sh         ← Place the script here
└── public_html/      ← WordPress site
```

---

### 🚀 How to Use

1. Upload `backup.sh` to your server **one level above** `public_html`
2. SSH into the server
3. Make the script executable:
   ```bash
   chmod +x backup.sh
   ```
4. Run the script:
   ```bash
   ./backup.sh
   ```
5. When prompted, enter a shortname for the domain (e.g., `bigredseo`)

The script will generate a file like:

```
bigredseo_fd_backup_20250618.zip
```

You can download this file via SFTP or your hosting control panel.

---

### 🧑‍💻 Maintained By

**Big Red SEO**  
[https://bigredseo.com](https://bigredseo.com)
