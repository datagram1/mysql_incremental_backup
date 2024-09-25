#!/bin/bash

# Prompt user for MySQL credentials and backup directory
read -p "Enter MySQL username: " MYSQL_USER
read -sp "Enter MySQL password: " MYSQL_PASS
echo
read -p "Enter backup directory path: " BACKUP_DIR

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Prompt for backup frequency
while true; do
    read -p "Enter backup frequency (Daily/Weekly): " BACKUP_FREQUENCY
    BACKUP_FREQUENCY=$(echo "$BACKUP_FREQUENCY" | tr '[:upper:]' '[:lower:]')
    if [[ "$BACKUP_FREQUENCY" == "daily" || "$BACKUP_FREQUENCY" == "weekly" ]]; then
        break
    else
        echo "Invalid input. Please enter 'Daily' or 'Weekly'."
    fi
done

# If weekly, prompt for day of week
if [ "$BACKUP_FREQUENCY" == "weekly" ]; then
    PS3="Select the day of the week for backups: "
    select DAY_OF_WEEK in Mon Tue Wed Thu Fri Sat Sun
    do
        if [ -n "$DAY_OF_WEEK" ]; then
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

# Prompt for backup time
while true; do
    read -p "Enter backup time (HH:MM in 24-hour format): " BACKUP_TIME
    if [[ $BACKUP_TIME =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        break
    else
        echo "Invalid time format. Please use HH:MM in 24-hour format."
    fi
done

# Extract hour and minute from BACKUP_TIME
BACKUP_HOUR=${BACKUP_TIME%:*}
BACKUP_MINUTE=${BACKUP_TIME#*:}

# Check if my_sql_backup.sh exists in the current directory, if not create it
if [ ! -f "./my_sql_backup.sh" ]; then
    echo "my_sql_backup.sh not found. Creating it now..."
    touch "./my_sql_backup.sh"
    cat << EOF > "./my_sql_backup.sh"
#!/bin/bash

MYSQL_USER="$MYSQL_USER"
MYSQL_PASS="$MYSQL_PASS"
BACKUP_DIR="$BACKUP_DIR"
LAST_POSITION=""

# Perform full backup if no LAST_POSITION
if [ -z "\$LAST_POSITION" ]; then
    mysqldump -u"\$MYSQL_USER" -p"\$MYSQL_PASS" --all-databases --master-data=2 --single-transaction > "\$BACKUP_DIR/full_backup_\$(date +%Y%m%d).sql"
else
    # Perform incremental backup
    mysqldump -u"\$MYSQL_USER" -p"\$MYSQL_PASS" --all-databases --master-data=2 --single-transaction > "\$BACKUP_DIR/incremental_backup_\$(date +%Y%m%d).sql"
    
    IFS=':' read -ra ADDR <<< "\$LAST_POSITION"
    mysqlbinlog --start-position="\${ADDR[1]}" "/var/lib/mysql/\${ADDR[0]}" > "\$BACKUP_DIR/binlog_backup_\$(date +%Y%m%d).sql"
fi

# Update LAST_POSITION
LAST_POSITION=\$(mysql -u"\$MYSQL_USER" -p"\$MYSQL_PASS" -e "SHOW MASTER STATUS\G" | awk '/File:/ {file=\$2} /Position:/ {pos=\$2} END {print file ":" pos}')

# Update this script with new LAST_POSITION
sed -i "s/^LAST_POSITION=.*/LAST_POSITION=\"\$LAST_POSITION\"/" "\$0"
EOF
    chmod +x "./my_sql_backup.sh"
    echo "my_sql_backup.sh created and made executable."
else
    echo "my_sql_backup.sh found in the current directory."
    # Update existing my_sql_backup.sh with new credentials and backup directory
    sed -i "s|^MYSQL_USER=.*|MYSQL_USER=\"$MYSQL_USER\"|" "./my_sql_backup.sh"
    sed -i "s|^MYSQL_PASS=.*|MYSQL_PASS=\"$MYSQL_PASS\"|" "./my_sql_backup.sh"
    sed -i "s|^BACKUP_DIR=.*|BACKUP_DIR=\"$BACKUP_DIR\"|" "./my_sql_backup.sh"
    echo "Updated my_sql_backup.sh with new credentials and backup directory."
fi

# Check if my.cnf exists
MY_CNF="/etc/mysql/my.cnf"
if [ ! -f "$MY_CNF" ]; then
    echo "Error: $MY_CNF not found."
    exit 1
fi

# Check if log-bin is enabled in my.cnf
if ! grep -q "log-bin=" "$MY_CNF"; then
    echo "log-bin not found in $MY_CNF. Adding it now..."
    sudo sed -i '/\[mysqld\]/a log-bin=/var/lib/mysql/mysql-bin' "$MY_CNF"
    echo "log-bin added to $MY_CNF"
    
    # Restart MySQL
    echo "Restarting MySQL..."
    sudo systemctl restart mysql
    
    # Wait for MySQL to restart
    sleep 5
else
    echo "log-bin already configured in $MY_CNF"
fi

# Get current binary log position
BINLOG_INFO=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW MASTER STATUS\G" | awk '/File:/ {file=$2} /Position:/ {pos=$2} END {print file ":" pos}')

if [ -z "$BINLOG_INFO" ]; then
    echo "Error: Could not retrieve binary log information."
    exit 1
fi

# Update my_sql_backup.sh with the current binary log position
sed -i "s/^LAST_POSITION=.*/LAST_POSITION=\"$BINLOG_INFO\"/" "./my_sql_backup.sh"

echo "Updated my_sql_backup.sh with current binary log position: $BINLOG_INFO"

# Set up cron job
if [ "$BACKUP_FREQUENCY" == "daily" ]; then
    CRON_JOB="$BACKUP_MINUTE $BACKUP_HOUR * * * $(pwd)/my_sql_backup.sh"
else
    CRON_JOB="$BACKUP_MINUTE $BACKUP_HOUR * * $DAY_OF_WEEK $(pwd)/my_sql_backup.sh"
fi

(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Cron job set up to run my_sql_backup.sh $BACKUP_FREQUENCY at $BACKUP_TIME"

echo "Setup completed successfully!"
