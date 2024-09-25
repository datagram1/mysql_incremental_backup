# MySQL Backup Setup Script

## Overview

This repository contains a bash script (`setup_mysql_backup.sh`) that automates the process of setting up MySQL database backups. The script creates or updates a backup script (`my_sql_backup.sh`) and configures it to run automatically using cron jobs.

## Features

- Interactive setup process
- Configures MySQL binary logging
- Creates a backup script for full and incremental backups
- Supports daily or weekly backup schedules
- Allows custom backup times
- Updates existing backup scripts with new settings

## Requirements

- Bash shell
- MySQL server
- Sudo privileges (for modifying MySQL configuration)

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/datagram1/mysql_incremental_backup.git
   cd mysql_incremental_backup
   ```

2. Make the script executable:
   ```
   chmod +x setup_mysql_backup.sh
   ```

3. Run the script:
   ```
   sudo ./setup_mysql_backup.sh
   ```

4. Follow the prompts to enter:
   - MySQL username
   - MySQL password
   - Backup directory path
   - Backup frequency (Daily/Weekly)
   - Day of the week for backups (if weekly)
   - Backup time (HH:MM in 24-hour format)

## How It Works

1. The script first prompts for necessary information.
2. It then checks for and creates (if necessary) the `my_sql_backup.sh` script.
3. The MySQL configuration file is checked and updated to enable binary logging.
4. A cron job is set up to run the backup script according to the specified schedule.

## Customization

The `my_sql_backup.sh` script created by this setup performs both full and incremental backups. You can modify this script to add additional functionality, such as:

- Compression of backup files
- Uploading backups to remote storage
- Backup rotation or deletion of old backups

## Contributing

Contributions to improve the functionality of this script are welcome! Please feel free to fork the repository, make your changes, and submit a pull request.

When contributing, please:

1. Clearly describe the problem you're solving or the feature you're adding.
2. Test your changes thoroughly.
3. Update the README.md if your changes add new features or change how the script works.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script interacts with your MySQL installation and file system. While it's designed to be safe, please review the script and understand its actions before running it in a production environment. Always ensure you have up-to-date backups before making changes to your database setup.
