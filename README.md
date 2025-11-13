# 1. Operation
## 1.1. Daemon
The daemon is configured to generate a log and send a notification if the backup.sh script has not been used 
- for more than 3 days: every 3 hours
- for more than 5 days: every 2 hours
- for more than 7 days: every hour

## 1.2. Script

The script works in two parts: 
- rsync backs up all files in $HOME
- timeshift backs up the entire system and hidden files in $HOME

The script allows you to make backups on two different hard drives. 

### 1.2.1. backup.sh
**Without parameters**, the script backs up the files to the destination and lists the files recently deleted from the source.
- Files listed in excluded_src are not backed up.
- Files listed in excluded_dst are not listed.

Files deleted from the hard drive are moved to .rsync_trash.

**With the --restore parameter**, the script restores the files to the destination and lists the files recently deleted from the source.
- Files listed in excluded_dst are not backed up.
- Files listed in excluded_src are not listed.

In summary, the files
- excluded_src: contains files that you do not want to copy to the hard drive
- exluded_dst: contains files that you do not want to restore to the computer



1.2.2. Timeshift


There are two timeshift configuration files:
- `/etc/timeshift/timeshift_disk1.json` 
- `/etc/timeshift/timeshift_disk2.json`

And one empty configuration file:
- `/etc/timeshift/default.json`

Before launching timeshift, script replace `/etc/timeshift/timeshift.json` with one of the configuration files (depending on the disk you are backing up). 
Then script replace `/etc/timeshift/timeshift.json` with `/etc/timeshift/default.json` to prevent `/etc/crond.d/timeshift-hourly` from running.


# 2. Configuration

## 2.1. To enable the daemon to display notifications
- Install the **notification-daemon** package


		sudo apt install notification-daemon


-  Create the file **/usr/share/dbus-1/services/org.freedesktop.Notifications.service**

<img width="1067" height="25" alt="image" src="https://github.com/user-attachments/assets/5bc21c13-a764-47eb-a5d8-5dc1e0f8a5c3" />


```
[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=/usr/lib/notification-daemon/notification-daemon
```

- Authorize graphical display for the root user

        echo “xhost +SI:localuser:root >> /dev/null 2>&1” >> ~/.bashrc


## 2.2. Create daemon

- Create file **/etc/systemd/system/backup.service**

<img width="576" height="23" alt="image" src="https://github.com/user-attachments/assets/a1bd04ec-7fee-4a04-9beb-ceea69936033" />


```
[Unit]
Description=This deamon monitors backups. It warns if no backup has been made for more than three days.

[Service]
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$HOME/.Xauthority"
ExecStart=/usr/sbin/backupd
Restart=always

[Install]
WantedBy=multi-user.target
```



- file  **/usr/sbin/backupd**

		ln -s $HOME/backup/backupd.sh /usr/sbin/backupd

- After adding or modifying a daemon

        sudo systemctl daemon-reload

- Enable the new daemon

        sudo systemctl enable backup.service

## 2.3. Creating timeshift configuration files

1. Open the timeshift graphical interface and run the wizard for disk 1
2. Copy and rename the configuration file in `/etc/timeshift/`
   
        sudo cp /etc/timeshift/timeshift.json /etc/timeshift/timeshift_disk1.json
   
3. Do the same for disk 2
4. Create an empty configuration file and name it `/etc/timeshift/default.json`

The folder must contain these files: 

<img width="650" height="92" alt="image" src="https://github.com/user-attachments/assets/425befb0-005d-45de-9f18-473bd3157b83" />


## 2.4. Modifying file variables

Remember to modify the file variables in the backup.sh script (line 160)


## 2.5. Calling the backup.sh script

        ln -s $HOME/backup/backup.sh /usr/sbin/backup

# 3. Usage

## 3.1. backupd.sh daemon

- To start the daemon 

        sudo systemctl start backup.service


- To check its status

        sudo systemctl status backup.service

- To view the daemon logs

        journalctl -f -u backup.service

- To view the logs produced by the daemon

        tail -f /var/log/backup/backup_daemon.log

> [!info] &emsp; If you make a change to the script, you must restart the service

## 3.2. backup.sh script

- To use the script

        backup -h

- To view the logs produced by the script

        cd /var/log/backup/

**sync. log**: lists the files transferred to remote storage

**deleted.log**: lists the files recently deleted from local storage (present in the destination and absent from the source)

**error.log**: displays errors during script execution
