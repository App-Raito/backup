#!/bin/bash

################################ FONCTIONS ################################

function aff_man {
	echo -e "Usage: backup [-d] [-h] [-l] [-r] [-v]\n
	   \rScript : backup.sh - Synchronize files from \$src_dir to \$dst_dir
	   \rWithout argument this command will send the file. File will be deleted with confirmation.
       \r  -d, --delete \t\t Ask confirmation before deleting files in \$dst_dir 
       \r  --disk2 \t\t Backup on disk2  (DEFAULT is disk1)
       \r  -h, --help \t\t Display this help message 
	   \r  -l, --log-only \t Produce only log. No file will be copied or deleted
       \r  --no-system \t\t Ignore timeshift backup of the system
       \r  -r, --restore \t Synchronize files from \$dst_dir to \$src_dir
       \r  -v, --verbose \t Verbose mode\n"
}


# SI $1 = excluded_dst, $2 = src = ordi, $3 = dst = DD
    # Cette fonction affiche les fichiers présent sur le DD et absent sur l'ordi
    # Ne mentionne pas les dossiers qu'on ne veut pas sur l'ordi : CYcours, media, etc..
# SI $1 = excluded_src, $2 = src = DD, $3 = dst = ordi
    # Cette fonction affiche les fichiers présent sur l'ordi et absent sur le DD
    # Ne mentionne pas les dossiers qu'on ne veut pas sur le DD : /.*, snap, etc..
function check_deleted {

    sudo rsync -arvhX --dry-run --delete --exclude-from=$1 $2 $3 > /tmp/delete_output 2>> $error_file
    error=$(($error + $?))

    # On s'occupe des logs dans le deleted_file
    echo -e "\n\n#### Deleted files in $dstdir \n" >> $deleted_file
    grep "deleting" /tmp/delete_output | cut -d ' ' -f 2- > /tmp/deleted_file 
    cat /tmp/deleted_file >> $deleted_file

    missing_file=$(wc -l /tmp/deleted_file | cut -d ' ' -f 1)
    echo -e "\n#-- $(date "+%d %b %Y %T") \t $missing_file Deleted files \n\n\n" >> $deleted_file

}


# SI $1 = excluded_src, $2 = src = ordi, $3 = dst = DD
    # Cette fonction copie les fichiers de l'ordi vers le DD
    # Ne copie pas les éléments qu'on ne veut pas sur le DD : /.*, snap, etc..
# SI $1 = excluded_dst, $2 = src = DD, $3 = dst = ordi
    # Cette fonciton copie les fichiers du dd vers l'ordi
    # Ne copie pas les dossiers qu'on ne veut pas sur l'ordi : CYcours, media, etc..
function execute_sync {

    if [ $log_only -eq 1 ]
    then
        sudo rsync -arvhX --dry-run --exclude-from=$1 $2 $3 >> $log_file 2>> $error_file
        error=$(($error + $?))
    else 
        sudo rsync -arvhX --exclude-from=$1 $2 $3 >> $log_file 2>> $error_file
        error=$(($error + $?))
    fi

}

# Cette fonciton déplace les fichiers dans une poubelle custom au lieu de les supprimer
function delete_file {

    #récupérer le chemin du fichier
    path=$(echo $line_content | awk -F/ '{OFS="/"; $NF=""; print $0}')
    #créer l'arborescence dans rsync_trash si elle existe pas 
    if [ ! -d "$trash_dir$path" ]
    then
       sudo mkdir -p "$trash_dir$path" >> $log_file 2>> $error_file
    fi
    # déplacer le $dst_dir$line content dans $trash_dir$line content 
    #Si c'est un dossier on a pas besoin de le déplacer, on l'a déja créé juste au dessus, il faut juste le supprimer dans la dst
    if [ ! -d "$dst_dir$line_content" ]
    then
        sudo mv "$dst_dir$line_content" "$trash_dir$line_content" >> $log_file 2>> $error_file
    else 
        sudo rmdir "$dst_dir$line_content" >> $log_file 2>> $error_file
    fi
}


# Cette fonction calcule le temps qu'a pris le programme pour s'executer
function execution_time {

    end_time=$(date +%s)
    diff=$((end_time - start_time))
            
    mm=$((diff / 60 ))
    ss=$((diff % 60))

    echo "$mm m $ss s"
}

################################ PARAMETRES ################################

# Paramètres par défaut		
start_time=$(date +%s)
i=1             # Par défaut on fait un backup sur le disk1
backup=1        # Par défaut, on fait un backup
restore=0
verbose=0       # Par défaut, le mode verbose est off
log_only=0		# Par défaut, le mode log only est off
error=0
delete=1        # Par défaut, on ne supprime automatiquement les fichiers dans la destination
nosystem=0      # Par défaut, on fait un backup du système


# $# retrourne le nombre d'argument spécifié par l'utilisateur 
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -d|--delete)
        delete=0
        shift
        ;;

        --disk2)
        i=2
        shift
        ;;

        -h|--help)
        aff_man
        backup=0
        shift
        ;;
     
		-l|--log-only)
        log_only=1
        shift
        ;;

        -v|--verbose)
        verbose=1
        shift
        ;;

        -r|--restore)
        restore=1
        backup=0
        shift
        ;;

        --no-system)
        nosystem=1
        shift
        ;;

        *) 
        echo "$1 : Unknown Parameter"
        aff_man
		backup=0
        shift
        ;;
    esac
done

################################ VARIABLES ################################

# Variable des fichiers
host=$(hostname)
src_dir="/home/raito/"
dst_dir="/media/raito/prDisk$i""_main/bunker/"
trash_dir="/media/raito/prDisk$i""_main/.rsync_trash/$(date -u +%Y-%m-%d)_$host/"

excluded_src="/home/raito/pgm/sh/backup/excluded_src"
excluded_dst="/home/raito/pgm/sh/backup/excluded_dst"

log_file="/var/log/backup/$(date -u +%Y-%m-%d)_$host""_dd$i""_sync.log"
error_file="/var/log/backup/$(date -u +%Y-%m-%d)_$host""_dd$i""_error.log"
deleted_file="/var/log/backup/$(date -u +%Y-%m-%d)_$host""_dd$i""_deleted.log"


################################ MAIN ################################

# Si on est en mode restore, la source devient la dest et la dest devient la source
if [ $restore -eq 1 ]
then
    temp=$src_dir
    src_dir=$dst_dir
    dst_dir=$temp
fi

if [ $backup -eq 1 ] || [ $restore -eq 1 ]
then

    #notif de début de script
    if [ $backup -eq 1 ]
    then
        zenity --notification --text="$(date "+%A %d %b \t %T") \n Backup Starting...\n$src_dir on $dst_dir"
    else
        zenity --notification --text="$(date "+%A %d %b \t %T") \n Restore Starting...\n$src_dir on $dst_dir"
    fi

    #fichier de log
    touch $log_file
    touch $error_file
    touch $deleted_file

    #notif pendant le script
    if [ $backup -eq 1 ]
    then
        tail -f $log_file | zenity --text-info --width=600 --height=400 --title="Disk$i - Backup running" --auto-scroll  &
    else
        tail -f $log_file | zenity --text-info --width=600 --height=400 --title="Restore running" --auto-scroll  &
    fi
    
    #Génération de logs
    echo -e " \n\n\n\n### Starting sync on $host from $src_dir to $dst_dir" >> $log_file

    if [ $log_only -eq 1 ]; then
        echo -e "LOG ONLY\n" >> $log_file
        verbose=1
    fi

    echo -e "\n##### SYNC HOME\n" >> $log_file


    #On vérifie si les dossiers existent
    if [ ! -d $src_dir ] || [ ! -d $dst_dir ]
    then
        echo -e "\nCannot find the source : $src_dir or the destination : $dst_dir\n" >> $log_file
        exit 1
    else 
        if [ $backup -eq 1 ]
        then
            check_deleted $excluded_dst $src_dir $dst_dir
            execute_sync $excluded_src $src_dir $dst_dir

        elif [ $restore -eq 1 ]
        then
            check_deleted $excluded_src $src_dir $dst_dir
            execute_sync $excluded_dst $src_dir $dst_dir
        fi
    fi

    # supression des fichiers superflus dans la destination
    if [ $log_only -eq 0 ]
    then
        nb_line=$(wc -l /tmp/deleted_file | cut -d ' ' -f 1)
        line=1

        while [ $line -le $nb_line ]; do
            line_content=$(awk "NR==$line" /tmp/deleted_file)

            if [ $delete -eq 0 ]
            then 
                read -p "delete  $dst_dir$line_content ? [y/n]   " answer

                if [ $answer = "y" ]; then
                    delete_file $line_content
                fi 
            else 
                echo -e " deletion of $dst_dir$line_content"
                delete_file $line_content
            fi

            ((line++))
        done
    fi

    sleep 1
    # TIMESHIFT : backup system
    if [ $backup -eq 1 ] && [ $log_only -eq 0 ] && [ $nosystem -eq 0 ]
    then
        echo -e "\n##### SYNC SYSTEM\n" >> $log_file
        # On définit la configuraiton timeshift du disk1 comme configuraiton à utiliser
        #si on backup sur disk1
        sudo cp /etc/timeshift/timeshift_disk$i.json /etc/timeshift/timeshift.json
        sleep 0.1
        # avec timeshift --check on lance le backup uniquement si le dernier backup est daté d'une semaine
        # --scripted permet d'utiliser timeshift sans intéraction utilisateur
        sudo timeshift --check --verbose --scripted >> $log_file 2>&1
        error=$(($error + $?))
        sudo timeshift --list >> $log_file 2>&1
        # On empeche les executions de /etc/crond.d/timeshift-hourly
        sudo cp /etc/timeshift/default.json /etc/timeshift/timeshift.json
    fi

    # On vérifie s'il y a eu des erreurs dans le script
    if [ $error != 0 ]
    then 
        echo -e "\n#-- $(date "+%d %b %Y %T") \t Synchronisation Failed \t (time : $(execution_time))\n" >> $log_file
    else 
        echo -e "\n#-- $(date "+%d %b %Y %T") \t Synchronisation Succeeded \t (time : $(execution_time))\n" >> $log_file
    fi

    # Si on effectue un vrai backup et qu'il n'y a pas eu d'erreur
    if [ $backup -eq 1 ] && [ $log_only -eq 0 ] && [ $error -eq 0 ]
    then
        # on enregistre la date actuelle dans un fichier (pour le daemon)
        echo "$(date +%s)" > /var/tmp/last_backup_on_disk$i
        # on ajoute une ligne pour dire que le backup est fait 
        echo -e "$(date -u +%Y-%m-%d) - $(date +%T)\t rsync.sh done on disk$i" >> /var/log/backup/rsync_daemon.log
    fi

    # On supprime les fichiers qui ont été créés et qui sont vides
    if [ $(wc -l $error_file | cut -d ' ' -f 1) = 0 ]; then    
        rm $error_file
    fi
    if [ $(wc -l $deleted_file | cut -d ' ' -f 1) = 0 ]; then    
        rm $deleted_file
    fi

    # On supprime la progression de timeshift dans sync_file
    if [ $nosystem -eq 0 ]
    then
        grep -v "% complete (" $log_file > /var/log/backup/temp.log
        mv "/var/log/backup/temp.log" "$log_file"
    fi

    #notif de fin de script
    if [ $error -eq 0 ]      
    then 
        zenity --notification --text="$(date "+%A %d %b \t %T") \n Synchronisation - Succeed" 
    else 
        zenity --notification --text="$(date "+%A %d %b \t %T") \n Synchronisation - Failed" 
    fi

    # mode verbose
    if [ $verbose -eq 1 ]; then
        more $error_file $log_file $deleted_file
    fi

    
fi


#       /\__
#\_____/  _/
# RAITO  /
