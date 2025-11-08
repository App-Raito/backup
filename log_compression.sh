#!/bin/bash

#Le script est appelé tous les 7 jours, après 30mn de uptime, avec une règle présente dans /etc/anacrontab
#7       30      tar_backup_log  /var/log/backup/.log_compression.sh >> /var/log/backup/anacron.log 2>&1



function createArchive {
    # filename = 2025-02-19_latitude5510_dd1_deleted.log
    fileName=$1
    # archiveName = 2025-02-19_latitude5510
    archiveName="$(echo "$fileName" | cut -d '_' -f 1-2).tar"
    # On ajoute le fichier à l'archive (si l'archive n'existe pas elle est créée)
    tar -rf "$archiveName" "$fileName"
    echo $?
}

echo -e "\n$(date -u +%Y-%m-%d) - $(date +%T)\t Anacron - log_compression.sh started"

#Par défaut anacron est dans /
cd /var/log/backup

for file in *.log
do 
    # Vérifiez si le fichier existe
    if [[ -e "$file" ]]; then
        creation_date=$(stat -c %W "$file")

        # Ignorez les fichiers qui ne sont pas des archives
        if [ "$file" == "rsync_daemon.log" ] || [ "$file" == "anacron.log" ]; then
            continue
        fi

        if [[ $creation_date -gt 0 ]]; then
            # Calculez la date actuelle moins 1 mois
            limit_date=$(date -d "1 months ago" +%s)

            # Si fichier a une date de création > à 1 mois, on le transforme en archive
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

