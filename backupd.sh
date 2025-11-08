#!/bin/bash

daemon_log="/var/log/backup/backup_daemon.log"


while true; do
    if [ -f /var/tmp/last_backup_on_disk1 ] || [ -f /var/tmp/last_backup_on_disk2 ]
    then
        # date of last backup in epoch format
        last_run1=$(cat /var/tmp/last_backup_on_disk1)
        last_run2=$(cat /var/tmp/last_backup_on_disk2)


        # time since last backup in epoch format
        current_time=$(date +%s)
        diff1=$((current_time - last_run1))
        diff2=$((current_time - last_run2))

        # transform epoch format to DD, HH, mm format 
        d1=$((diff1 / 86400))
        h1=$(( (diff1 % 86400) / 3600 ))
        m1=$(( (diff1 % 3600) / 60 ))

        d2=$((diff2 / 86400))
        h2=$(( (diff2 % 86400) / 3600 ))
        m2=$(( (diff2 % 3600) / 60 ))

        # If no backup since 3 days we will send alert every 3 hours
        between_alert=10800    

        # Displaying notifications and log production
        if [ $d1 -ge 3 ]
        then
            echo -e "$(date -u +%Y-%m-%d) - $(date +%T)\t backup.sh last used on $(date -d @$last_run1) \n\t\t\t On Disk1 - No backup since $d1 days, $h1 hours, $m1 minutes" >> $daemon_log
            zenity --warning --width=250 --height=50 --title="WARNING - Backup - Disk1" --text="backup.sh\nNo backup since $d1 days, $h1 h, $m1 mn"
        fi
        if [ $d2 -ge 3 ]
        then
            echo -e "$(date -u +%Y-%m-%d) - $(date +%T)\t backup.sh last used on $(date -d @$last_run2) \n\t\t\t On Disk2 - No backup since $d2 days, $h2 hours, $m2 minutes" >> $daemon_log
            zenity --warning --width=250 --height=50 --title="WARNING - Backup - Disk2" --text="backup.sh\nNo backup since $d2 days, $h2 h, $m2 mn"
        fi

        if [ $d1 -ge 5 ] || [ $d1 -ge 5 ]
        then
            # If no backup since 5 days we will send alert every 2 hours
            between_alert=7200

            if [ $d1 -ge 7 ] || [ $d1 -ge 7 ]
            then
                # If no backup since 7 days we will send alert every hours
                between_alert=3600

            fi
        fi
    
    else 
        echo -e "$(date -u +%Y-%m-%d) - $(date +%T)\t /var/tmp/last_backup_on_disk1 or /var/tmp/last_backup_on_disk2 -- not found.\n" >> $daemon_log
        exit 0
    fi

    sleep $between_alert
done


#       /\__
#\_____/  _/
# RAITO  /
