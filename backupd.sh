#!/bin/bash

daemon_log="/var/log/backup/rsync_daemon.log"


while true; do
    if [ -f /var/tmp/last_backup_on_disk1 ] || [ -f /var/tmp/last_backup_on_disk2 ]
    then
        last_run1=$(cat /var/tmp/last_backup_on_disk1)
        last_run2=$(cat /var/tmp/last_backup_on_disk2)
        current_time=$(date +%s)
        diff1=$((current_time - last_run1))
        diff2=$((current_time - last_run2))

        # Calcul de la durée sans backup pour le disk1
        d1=$((diff1 / 86400))
        h1=$(( (diff1 % 86400) / 3600 ))
        m1=$(( (diff1 % 3600) / 60 ))

        # Calcul de la durée sans backup pour le disk1
        d2=$((diff2 / 86400))
        h2=$(( (diff2 % 86400) / 3600 ))
        m2=$(( (diff2 % 3600) / 60 ))

        # Si pas de backup depuis 2 jours on alerte toutes les 3 heures
        between_alert=10800    

        # Affichage de notitication et production de logs
        if [ $d1 -ge 3 ]
        then
            # Affiche des logs dans /var/log/backup/rsync_daemon.log
            echo -e "$(date -u +%Y-%m-%d) - $(date +%T)\t rsync.sh last used on $(date -d @$last_run1) \n\t\t\t On Disk1 - No backup since $d1 days, $h1 hours, $m1 minutes" >> $daemon_log
            # Affiche une notification
            zenity --warning --width=250 --height=50 --title="WARNING - Backup - Disk1" --text="rsync.sh\nNo backup since $d1 days, $h1 h, $m1 mn"
        fi
        if [ $d2 -ge 3 ]
        then
            # Affiche des logs dans /var/log/backup/rsync_daemon.log
            echo -e "$(date -u +%Y-%m-%d) - $(date +%T)\t rsync.sh last used on $(date -d @$last_run2) \n\t\t\t On Disk2 - No backup since $d2 days, $h2 hours, $m2 minutes" >> $daemon_log
            # Affiche une notification
            zenity --warning --width=250 --height=50 --title="WARNING - Backup - Disk2" --text="rsync.sh\nNo backup since $d2 days, $h2 h, $m2 mn"
        fi


        # Reduction de l'intervalle de temps entre 2 execution du daemon
        if [ $d1 -ge 5 ] || [ $d1 -ge 5 ]
        then
            # Si pas de backup depuis 3 jours on alerte toutes les 2 heures
            between_alert=7200

            if [ $d1 -ge 7 ] || [ $d1 -ge 7 ]
            then
                # Si pas de backup depuis 4 jours on alerte toutes les 1 heures
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


