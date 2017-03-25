#!/bin/bash

##################################################################
# Runs the backups
#
# This is called from macOS automator, when you insert a new USB
# disk, automator will notify this scripts with list of mount point,
# this script will check all profiles to see if we have defined a
# backup for any folders in this newly inserted disk.
##################################################################

#######################################################
#       Second Run Main
#######################################################

PATH=$PATH:/usr/local/bin

if [ "$1" == "@second" ]; then
    source $2
    echo $2

    echo
    echo
    echo "**************************************************"
    echo "Backup for ${BACKUP_DIRECTORY}"
    while true; do
        echo "What you want to do?"
        echo "1. Increment (default)"
        echo "2. Increment&Full"
        echo "3. No"
        printf "=> "
        read answer

        case $answer in
            "" ) ./backup.sh incremental; break;;
            "1" ) ./backup.sh incremental; break;;
            "2" ) ./backup.sh incremental; ./backup.sh full; break;;
            "3" ) echo "Don't Backup"; break;;
        esac
    done
    exit 1 # done
fi


#######################################################
#       First Run Main
#######################################################

FULL_NAME=`realpath $0`
DIRECTORY=`dirname ${FULL_NAME}`

function log() {
    echo "[`date`] $1"
}


# backup the profile
# $1 - the profile to backup
# the variables in profile should already be sourced
function backup() {
    log "Start to backup ${BACKUP_DIRECTORY} using profile $1"
    osascript -e "tell application \"Terminal\" to do script \"cd `pwd`; ./run_backup.sh @second ${1}\""
}

# backup the usb drive
# $1 - the mount point for the USB drive
function process_folder() {
    new_folder="`realpath $1`/"
    log "Found new USB drive $new_folder"
    for profile in `ls profile*`; do
        source $profile
        [[ ${BACKUP_DIRECTORY} =~ ^$new_folder ]] && backup $profile
    done
}



cd ${DIRECTORY}
log "cd to ${DIRECTORY}"
for new_folder in "$@"; do
    process_folder $new_folder
done
