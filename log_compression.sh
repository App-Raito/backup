#!/bin/bash


# This script is used to group and compress the logs produced by backup.sh. 

#This script is launched every 7 days , after a 30mn uptime. Put the following rule in  /etc/anacrontab
#7       30      tar_backup_log  /var/log/backup/.log_compression.sh >> /var/log/backup/anacron.log 2>&1



function createArchive {
    # filename = 2025-02-19_hostanme_dd1_deleted.log
    fileName=$1
    # archiveName = 2025-02-19_hostname
    archiveName="$(echo "$fileName" | cut -d '_' -f 1-2).tar"
    # We add file to archive, (if archive do not exists it will be created)
    tar -rf "$archiveName" "$fileName"
    echo $?
}

echo -e "\n$(date -u +%Y-%m-%d) - $(date +%T)\t Anacron - log_compression.sh started"

#By default anacron is in  /
cd /var/log/backup

for file in *.log
do 
    # check if file exists
    if [[ -e "$file" ]]; then
        creation_date=$(stat -c %W "$file")

        # Ignore files that are not archives
        if [ "$file" == "backup_daemon.log" ] || [ "$file" == "anacron.log" ]; then
            continue
        fi

        if [[ $creation_date -gt 0 ]]; then
            # Calculate date one month ago
            limit_date=$(date -d "1 months ago" +%s)

            # If file has a creation date > 1 month, we change it in archive
            if [[ $creation_date -lt $limit_date ]]; then
                error=$(createArchive "$file")

                if [ $error -eq 0 ]; then
                    rm "$file"
                fi
            fi
        fi
    fi
done

for archive in *.tar
do 
    if [[ -e "$archive" ]]; then
        gzip "$archive"
        echo -e "\t\t\t $archive compressed"
    fi
done


#       /\__
#\_____/  _/
# RAITO  /

