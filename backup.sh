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


# IF $1 = excluded_dst, $2 = src = computer, $3 = dst = hard drive
    # This function displays the files present on the hard drive and absent on the computer.
    # Do not mention the folders that you do not want on the computer
# IF $1 = excluded_src, $2 = src = hard drive, $3 = dst = computer
    # This function displays the files present on the computer and absent on the DD.
    # Does not mention the folders that we do not want on the DD: /.*, snap, etc.

function check_deleted {

    sudo rsync -arvhX --dry-run --delete --exclude-from=$1 $2 $3 > /tmp/delete_output 2>> $error_file
    error=$(($error + $?))

    # logs for "deleted file"
    echo -e "\n\n#### Deleted files in $dstdir \n" >> $deleted_file
    grep "deleting" /tmp/delete_output | cut -d ' ' -f 2- > /tmp/deleted_file 
    cat /tmp/deleted_file >> $deleted_file

    missing_file=$(wc -l /tmp/deleted_file | cut -d ' ' -f 1)
    echo -e "\n#-- $(date "+%d %b %Y %T") \t $missing_file Deleted files \n\n\n" >> $deleted_file

}


# IF $1 = excluded_src, $2 = src = computer, $3 = dst = HD
    # This function copies files from the computer to the HD.
    # Does not copy unwanted items to the HD: /.*, snap, etc.
# IF $1 = excluded_dst, $2 = src = HD, $3 = dst = computer
    # This function copies files from the DD to the computer.
    # Do not copy folders that you do not want on the computer
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

# Move file to a specific locations instead of removing them
function delete_file {

    #get file path
    path=$(echo $line_content | awk -F/ '{OFS="/"; $NF=""; print $0}')
    #create trash path if not exist
    if [ ! -d "$trash_dir$path" ]
    then
       sudo mkdir -p "$trash_dir$path" >> $log_file 2>> $error_file
    fi
    # move $dst_dir$line_content to $trash_dir$line_content 
    #If it's a folder, no need to move it, we have already created it
    if [ ! -d "$dst_dir$line_content" ]
    then
        sudo mv "$dst_dir$line_content" "$trash_dir$line_content" >> $log_file 2>> $error_file
    else 
        sudo rmdir "$dst_dir$line_content" >> $log_file 2>> $error_file
    fi
}


# calculate execution time
function execution_time {

    end_time=$(date +%s)
    diff=$((end_time - start_time))
            
    mm=$((diff / 60 ))
    ss=$((diff % 60))

    echo "$mm m $ss s"
}

################################ PARAMETERS ################################

# Default parameters
start_time=$(date +%s)
i=1             # By default, we backup on disk 1
backup=1        # By default, we do the backup (and not the restore)
restore=0
verbose=0       # By default, verbose mode is off
log_only=0		# By default, log only mode is off
error=0
delete=1        # By default, we delete files in destination without asking confirmation
nosystem=0      # By default, we backup the system


# $# return the number of parameters provided by user
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

# file variable
host=$(hostname)
user=$(whoami)
src_dir="/home/$user/"
dst_dir="/media/$user/Disk$i""/folder/"

# WARNING : trash musn't be inside dst_dir
trash_dir="/media/$user/Disk$i""/.rsync_trash/$(date -u +%Y-%m-%d)_$host/"

excluded_src="/home/$user/backup/excluded_src"
excluded_dst="/home/$user/backup/excluded_dst"

log_file="/var/log/backup/$(date -u +%Y-%m-%d)_$host""_dd$i""_sync.log"
error_file="/var/log/backup/$(date -u +%Y-%m-%d)_$host""_dd$i""_error.log"
deleted_file="/var/log/backup/$(date -u +%Y-%m-%d)_$host""_dd$i""_deleted.log"


################################ MAIN ################################

# In restore mode, we exchange source directory and destination directory
if [ $restore -eq 1 ]
then
    temp=$src_dir
    src_dir=$dst_dir
    dst_dir=$temp
fi

if [ $backup -eq 1 ] || [ $restore -eq 1 ]
then

    # Script start notification
    if [ $backup -eq 1 ]
    then
        zenity --notification --text="$(date "+%A %d %b \t %T") \n Backup Starting...\n$src_dir on $dst_dir"
    else
        zenity --notification --text="$(date "+%A %d %b \t %T") \n Restore Starting...\n$src_dir on $dst_dir"
    fi

    #log file
    touch $log_file
    touch $error_file
    touch $deleted_file

    #Script running notification
    if [ $backup -eq 1 ]
    then
        tail -f $log_file | zenity --text-info --width=600 --height=400 --title="Disk$i - Backup running" --auto-scroll  &
    else
        tail -f $log_file | zenity --text-info --width=600 --height=400 --title="Restore running" --auto-scroll  &
    fi
    
    #log generation
    echo -e " \n\n\n\n### Starting sync on $host from $src_dir to $dst_dir" >> $log_file

    if [ $log_only -eq 1 ]; then
        echo -e "LOG ONLY\n" >> $log_file
        verbose=1
    fi

    echo -e "\n##### SYNC HOME\n" >> $log_file


    #Check if files exist
    if [ ! -d $src_dir ]
    then
        echo -e "\nCannot find the source : $src_dir\n" >> $log_file
        exit 1
    elif [ ! -d $dst_dir ]
    then
        echo -e "\nCannot find the destination : $dst_dir\n" >> $log_file
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

    # Removing files in destination
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
        # The timeshift configuration of disk(1 or 2) is defined as the configuration to be used.
        sudo cp /etc/timeshift/timeshift_disk$i.json /etc/timeshift/timeshift.json
        sleep 0.1
        # with timeshift --check we do the backup only if previous snapchot is old enough
        sudo timeshift --check --verbose --scripted >> $log_file 2>&1
        error=$(($error + $?))
        sudo timeshift --list >> $log_file 2>&1
        # To prevent executions of /etc/crond.d/timeshift-hourly
        sudo cp /etc/timeshift/default.json /etc/timeshift/timeshift.json
    fi

    # We check if errors
    if [ $error != 0 ]
    then 
        echo -e "\n#-- $(date "+%d %b %Y %T") \t Synchronisation Failed \t (time : $(execution_time))\n" >> $log_file
    else 
        echo -e "\n#-- $(date "+%d %b %Y %T") \t Synchronisation Succeeded \t (time : $(execution_time))\n" >> $log_file
    fi

    # If we did a real backup and there was no errors
    if [ $backup -eq 1 ] && [ $log_only -eq 0 ] && [ $error -eq 0 ]
    then
        # We save current date in pesistent file (for daemon)
        echo "$(date +%s)" > /var/tmp/last_backup_on_disk$i
        # Add line in daemon logs
        echo -e "$(date -u +%Y-%m-%d) - $(date +%T)\t backup.sh done on disk$i" >> /var/log/backup/backup_daemon.log
    fi

    # We remove empty files
    if [ $(wc -l $error_file | cut -d ' ' -f 1) = 0 ]; then    
        rm $error_file
    fi
    if [ $(wc -l $deleted_file | cut -d ' ' -f 1) = 0 ]; then    
        rm $deleted_file
    fi

    # Unnecessary timeshift log lines are removed.
    if [ $nosystem -eq 0 ]
    then
        grep -v "% complete (" $log_file > /var/log/backup/temp.log
        mv "/var/log/backup/temp.log" "$log_file"
    fi

    #Script end notification
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
